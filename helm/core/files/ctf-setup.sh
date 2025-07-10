#!/bin/bash
set -x
NAMESPACE="{{ .Release.Namespace }}"

# Determine readiness of NeuVector instance
echo $(date +%Y%m%d_%H%M%S) starting the 10 minutes timeout on checking API accessibility
count=0
while (( ${count} <= 600 ))
do
    API_LIVENESS=$(curl -k -s -H "Content-Type: application/json" "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/eula" --fail)
    # --fail needed so when the instance is not up and ready it won't generate any output like 404 or 502 errors
    if [[ -z "$API_LIVENESS" ]]; then
        ((count++))
        echo $(date +%Y%m%d_%H%M%S) the API endpoint is not ready yet
        sleep 1
    else
        break
    fi
done
echo $(date +%Y%m%d_%H%M%S) API endpoint is ready

# Get the token
echo $(date +%Y%m%d_%H%M%S) getting a token
TOKEN=$(curl -k -s -H "Content-Type: application/json" -d '{"password": {"username": "admin", "password": "admin"}}' "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/auth" | jq -r '.token.token')

# Check if the token was successfully retrieved
if [ -z "${TOKEN}" ]; then
  echo "Error: Failed to retrieve token"
  exit 1
fi

# Accept EULA
echo $(date +%Y%m%d_%H%M%S) accepting EULA
curl -k -H "Content-Type: application/json" -H "X-Auth-Token: ${TOKEN}" -d '{"eula":{"accepted":true}}' "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/eula"

# Enable admission control
echo $(date +%Y%m%d_%H%M%S) enabling admission control
curl -k -s -X "PATCH" -H "Content-Type: application/json" -H "X-Auth-Token: ${TOKEN}" -d '{"k8s_env":true,"state":{"adm_client_mode":"service","adm_client_mode_options":{"service":"neuvector-svc-admission-webhook.'${NAMESPACE}'.svc","url":"https://neuvector-svc-admission-webhook.'${NAMESPACE}'.svc:443"},"adm_svc_type":"ClusterIP","cfg_type":"user_created","ctrl_states":{"validate":true},"default_action":"allow","enable":true,"failure_policy":"ignore","mode":"monitor"}}' "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/admission/state"

# Extend Admin's session timeout
echo $(date +%Y%m%d_%H%M%S) extending the admins session timeout 
curl -k -X PATCH -H "Content-Type: application/json" -H "X-Auth-Token: ${TOKEN}" -d '{"config":{"timeout":3600,"username":"admin","fullname":"admin","role":"admin"}}' "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/user/admin"


# Logout from NeuVector
echo $(date +%Y%m%d_%H%M%S) log out from NeuVector
curl -k -X 'DELETE' -H "Content-Type: application/json" -H "X-Auth-Token: ${TOKEN}" "https://neuvector-svc-controller-api.${NAMESPACE}.svc.cluster.local:10443/v1/auth"

# Wait until the CRD exists
echo $(date +%Y%m%d_%H%M%S) waiting for NvAdmissionControlSecurityRule CRD to become available
count=0
until kubectl get crd nvadmissioncontrolsecurityrules.neuvector.com > /dev/null 2>&1 || [ $count -ge 30 ]; do
  ((count++))
  echo $(date +%Y%m%d_%H%M%S) still waiting... attempt $count
  sleep 5
done

# Apply the custom rule
echo $(date +%Y%m%d_%H%M%S) applying admission control rule from embedded YAML
kubectl apply -f /scripts/rules.yaml

# If everything is successful, exit with 0
exit 0