#!/bin/bash
set -uo pipefail
NAMESPACE="{{ .Release.Namespace }}"
LOCKFILE="/tmp/setup.lock"

echo "$(date +%Y%m%d_%H%M%S) Starting NeuVector persistent setup loop"

# === Infinite Loop ===
while true; do
    if [[ -f "$LOCKFILE" ]]; then
        echo "$(date +%Y%m%d_%H%M%S) Lockfile found. Setup already completed."
        sleep 2h
        continue
    fi

    # === Setup Functions ===
    function wait_for_api() {
        echo "$(date +%Y%m%d_%H%M%S) Waiting for NeuVector API to become available..."
        count=0
        while (( count < 600 )); do
            if curl -k -s -H "Content-Type: application/json" \
                 "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/eula" --fail > /dev/null; then
                echo "$(date +%Y%m%d_%H%M%S) NeuVector API is reachable"
                return
            fi
            ((count++))
            echo "$(date +%Y%m%d_%H%M%S) API is not ready yet"
            sleep 1
        done
        echo "$(date +%Y%m%d_%H%M%S) ERROR: Timeout waiting for API"
        exit 1
    }

    function delayed_enforcer_restart() {
    echo "$(date +%Y%m%d_%H%M%S) Starting 5-minute countdown to restart enforcer pod..."
    sleep 300
    echo "$(date +%Y%m%d_%H%M%S) Restarting enforcer pod"
    kubectl delete pod -l app=neuvector-enforcer-pod -n "${NAMESPACE}" --grace-period=0 --force
    }

    function get_token() {
        echo "$(date +%Y%m%d_%H%M%S) Retrieving token..."
        TOKEN=$(curl -k -s -H "Content-Type: application/json" \
            -d '{"password": {"username": "admin", "password": "admin"}}' \
            "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/auth" | jq -r '.token.token')
        if [[ -z "$TOKEN" ]]; then
            echo "$(date +%Y%m%d_%H%M%S) ERROR: Failed to retrieve token"
            exit 1
        fi
    }

    function get_api_key() {
    echo "$(date +%Y%m%d_%H%M%S) Creating API key..."
    API_KEY=$(curl -k -s -X "POST" -H "Content-Type: application/json" -H "X-Auth-Token: ${TOKEN}" \
        -d '{"apikey":{"apikey_name":"demo_key","description":"Key used for local API automation","expiration_hours":0,"expiration_type":"oneyear","role":"admin"}}' \
        "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/api_key" \
        | jq -r '.apikey.apikey_name + ":" + .apikey.apikey_secret')
    if [[ -z "$API_KEY" ]]; then
        echo "$(date +%Y%m%d_%H%M%S) ERROR: Failed to create API key"
        exit 1
    fi
    }

    function accept_eula() {
        echo "$(date +%Y%m%d_%H%M%S) Accepting EULA..."
        curl -k -s -H "Content-Type: application/json" -H "X-Auth-Apikey: ${API_KEY}" \
            -d '{"eula":{"accepted":true}}' \
            "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/eula"
    }

    function enable_admission_control() {
        echo "$(date +%Y%m%d_%H%M%S) Enabling admission control..."
        curl -k -s -X "PATCH" -H "Content-Type: application/json" -H "X-Auth-Apikey: ${API_KEY}" \
            -d '{"k8s_env":true,"state":{"adm_client_mode":"service","adm_client_mode_options":{"service":"neuvector-svc-admission-webhook.'${NAMESPACE}'.svc","url":"https://neuvector-svc-admission-webhook.'${NAMESPACE}'.svc:443"},"adm_svc_type":"ClusterIP","cfg_type":"user_created","ctrl_states":{"validate":true},"default_action":"allow","enable":true,"failure_policy":"ignore","mode":"monitor"}}' \
            "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/admission/state"
    }

    function extend_admin_timeout() {
        echo "$(date +%Y%m%d_%H%M%S) Extending admin session timeout..."
        curl -k -s -X PATCH -H "Content-Type: application/json" -H "X-Auth-Apikey: ${API_KEY}" \
            -d '{"config":{"timeout":3600,"username":"admin","fullname":"admin","role":"admin"}}' \
            "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/user/admin"
    }

    function logout() {
        echo "$(date +%Y%m%d_%H%M%S) Logging out..."
        curl -k -s -X DELETE -H "Content-Type: application/json" -H "X-Auth-Apikey: ${API_KEY}" \
            "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/auth"
    }

    function finish_config() {
        timeout=$(curl -s -k -X GET -H "Content-Type: application/json" -H "X-Auth-Apikey: ${API_KEY}" \
            "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/user/admin" | jq -r .user.timeout)

        if [[ "$timeout" == "3600" ]]; then
            echo "$(date +%Y%m%d_%H%M%S) Admin timeout is already set to 3600"
            logout
        else
            extend_admin_timeout
            logout
        fi
    }
    # === Setup Execution ===
    wait_for_api
    delayed_enforcer_restart &
    get_token
    get_api_key

    if curl -k -s -H "Content-Type: application/json" \
        "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/eula" --fail | jq -e '.eula.accepted == true' > /dev/null; then

        echo "$(date +%Y%m%d_%H%M%S) EULA already accepted"

        if curl -k -s -X GET -H "Content-Type: application/json" -H "X-Auth-Apikey: ${API_KEY}" \
            "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/admission/state" | jq -e '.state.enable == true' > /dev/null; then
            echo "$(date +%Y%m%d_%H%M%S) Admission control already enabled"
            finish_config
        else
            enable_admission_control
            finish_config
        fi

    else
        accept_eula
        enable_admission_control
        extend_admin_timeout
        logout
    fi

    echo "$(date +%Y%m%d_%H%M%S) Applying CRDs..."
    kubectl apply -f /scripts/rules.yaml

    touch "$LOCKFILE"
    echo "$(date +%Y%m%d_%H%M%S) Setup complete. Lockfile created."

    sleep 2h
done