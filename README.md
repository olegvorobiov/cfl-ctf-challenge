# Operation: Container Storm
**MISSION BRIEFING**

**FROM:** Captain K8s

**TO:** All available units

**CLASSIFICATION:** URGENT

A Voidbringer unit has deployed a compromised container infrastructure protected by NeuVector. Intelligence suggests they've hidden a critical vulnerability in their runtime protection configuration - one that could allow unauthorized code execution.

Your mission, should you choose to accept it, is to:

* Infiltrate their Rancher Desktop environment
* Navigate through their security controls
* Uncover the hidden vulnerability in their runtime protection

**MISSION OBJECTIVES:**

1. **BREACH** - Overcome admission control to deploy your reconnaissance workloads
2. **SEGMENT** - Implement network isolation to contain potential threats
3. **ADAPT** - Bypass namespace restrictions to establish your foothold
4. **FORTIFY** - Configure advanced network rules for your operations
5. **ANALYZE** - Test runtime protections across multiple container variants
6. **CAPTURE** - Identify the vulnerable base OS and exploit vector

**INTEL PROVIDED:**

* Pre-configured NeuVector deployment (modified for training purposes)
* Network architecture diagrams
* Test command payloads
* Container manifests

**WARNING:** The enemy has enabled full Protect mode. Most attack vectors will be blocked and logged. You must find the one configuration they missed.

**SUCCESS CRITERIA:** Capture the flag

*Time is critical. The security team's audit begins in 3 hours.*

**Good luck, Operator. The infrastructure's security depends on you.**

## Pre-requisites
### Rancher Desktop
1. Install Rancher Desktop on your operating system follwoing the instructions from our documentation - https://docs.rancherdesktop.io/getting-started/installation.

    **!IMPORTANT!** 
    
    After the installation is completed you will have **helm**, **kubectl**, **rdctl**, and a few more tools installed. These utilities are installed in `~/.rd/bin`, check your `$PATH` variable if it contains this string. If not, you can temporary add it by running `export PATH=$PATH:$HOME/.rd/bin`. Remember once you exit the shell session this change will not persist.`

    **IF YOU ARE ALREADY USING RANCHER DESKTOP**

    Please do a Kubernetes Reset to get a clean environment for the challenge. Navigate to Troubleshooting and Click on Reset Kubernetes, it will take a minute or two to come back up.

2. Additional configuration for Rancher Desktop:

    a. Ensure to select a stable version
    
    ![rd1](https://github.com/olegvorobiov/cfl-ctf-challenge/blob/master/images/rd1.png)
    
    b. Disable Traefik
    
    ![rd2](https://github.com/olegvorobiov/cfl-ctf-challenge/blob/master/images/rd2.png)

    c. For smoother operation, allocate Rancher Desktop 4CPUs and 8G RAM.

    ![rd4](https://github.com/olegvorobiov/cfl-ctf-challenge/blob/master/images/rd4.png)
    
    d. Restart Rancher Desktop
### git
* Install git based on your operating system - https://git-scm.com/downloads.
## Setup
### Clone the Challenge repo
1.  ```git clone https://github.com/olegvorobiov/cfl-ctf-challenge.git```
2. change directory inside the clonned repo: `cd cfl-ctf-challenge`
### Deploy modded NeuVector chart

**NOTE:** before proceeding, ensure that your *kubecontext* is configured to talk to Rancher Desktop cluster.

1. Install ingress-nginx
```bash 
helm upgrade --install ingress-nginx ingress-nginx \
  --repo https://kubernetes.github.io/ingress-nginx \
  --namespace ingress-nginx --create-namespace --version 4.11.2
```
Ensure that ingress-nginx pods are running:
```bash
kubectl get pods -n ingress-nginx
```

2. Pick the hostname you want to use to access NeuVector's UI. Example: **nv.rd.localhost**
    * Update the existing "localhost" entry to your ```/etc/hosts``` file:

        ```127.0.0.1	localhost```

        To:

        ```bash 
        127.0.0.1	localhost nv.rd.localhost
        ```

3. Deploy NeuVector to a namespace of your choice, pick the name of the release as you wish:

```bash
helm install nv -n nv --create-namespace ./helm/core \
  -f ./helm/core/values.yaml --set manager.ingress.host="nv.rd.localhost"
```

4. After installation, give it about two minutes for NeuVector to startup, then navigate to Rancher Desktop, go to Port Forwarding and find the webui service and forward it to a port `8443`.

    ![rd5](https://github.com/olegvorobiov/cfl-ctf-challenge/blob/master/images/rd5.png)

5. Open your favorite browser and navigate to https://nv.rd.localhost:8443

    Default login:
    * **Username:** `admin`
    * **Password:** `admin`

## Challenges
### 1. Deploy Farm Services

**NOTE:** DO NOT tamper with Admission Control Rules themsleves. DO NOT disable Admission Control Rules, rather make sure that NeuVector allows that deployment to pass. See the logs.

* Run: 
```bash
kubectl apply -f farm-services.yaml
```
This command will result in partial failure.
<details>
<summary>Free Hint</summary>
Navigate to Notifications => Risk Reports to see Admission Control related errors
</details>

* Ensure the workloads are being deployed successfully

### 2. Configure Network and Process rules

**IMPORTANT NOTE:** 

If you restart Rancher Desktop at any point of this challenge, your progress will reset, and you will need to resume from **THIS STEP HERE:**

1. Given the table below use your kubernetes knowledge to create these Network connections. You should not execute inside the pod. `curl` is available within all of the pods. 
    
    <details>
    <summary>Free Hint</summary>
    To filter only the groups related to this challenge type `arm` in filter box. Filter box is in the top right corner of the Policy => Groups section
    </details>

    | Source Deployment | Source Namespace | Target Deployment | Target Namespace | Port (TCP) | Allowed |
    |:-----------------:|:----------------:|:-----------------:|:----------------:|:----:|:-------:|
    | chicken              | farmyard             | sheep            | warmfield          | 9000 | Y |
    | chicken              | farmyard             | suse.com (external)|                 | 443  | Y |
    | chicken              | farmyard             | any other site (external)|               | 443  | N |
    | sheep            | warmfield          | chicken              | farmyard             | 5000 | Y |
    | sheep            | warmfield          | cow              | warmfield          | 8090 | Y |
    | cow              | warmfield          | bee             | treefarm        | 8000 | Y |
    | bee             | treefarm        | cow              | warmfield          | 8090 | Y |
    | bee             | treefarm        | rabbit            | charmland             | 8080 | Y |

    Refer to a diagram below for graphical representation:
    ![Diagram1](https://github.com/olegvorobiov/cfl-ctf-challenge/blob/master/images/diagram1.png)

2. Switch the groups into a Protect/Protect mode and now try some of these commands:

* Cow should not be able to talk to sheep:
```bash
kubectl exec -it --namespace warmfield \
  $(kubectl get pods --namespace warmfield --selector app=cow -o jsonpath='{.items[*].metadata.name}') \
  -- curl sheep-svc.warmfield.svc.cluster.local:9000 --max-time 5
```

* You should not be able to execute in any of the pods. Example for bee:
```bash
kubectl exec -it --namespace treefarm \
  $(kubectl get pods --namespace treefarm --selector app=bee -o jsonpath='{.items[*].metadata.name}') \
  -- bash
```

* Sheep should not be able to talk to rabbit.
```bash
kubectl exec -it --namespace warmfield \
  $(kubectl get pods --namespace warmfield --selector app=sheep -o jsonpath='{.items[*].metadata.name}') \
  -- curl rabbit-svc.charmland.svc.cluster.local:8080 --max-time 5
```
    
* Chicken should be only able to communicate with suse.com, and not any other outside service. If you weren't able to accomplish this - don't worry it doesn't affect the end goal :-)
```bash
kubectl exec -it --namespace farmyard \
  $(kubectl get pods --namespace farmyard --selector app=chicken -o jsonpath='{.items[*].metadata.name}') \
  -- curl https://google.com --max-time 5
```

### 3. Deploy a second set of workloads

* Run: 
```bash
kubectl apply -f addon-services.yaml
```
This command will result in partial failure.
<details>
<summary>Free Hint</summary>
Navigate to Notifications => Risk Reports to see Admission Control related errors
</details>

* Ensure the workloads are being deployed successfully

### 4. Wrap up and Flag
1. Keep the groups in the modes they are in right now. This, first set of workloads should be in Protect/Protect mode:
* **nv.bee.treefarm**
* **nv.chicken.farmyard**
* **nv.cow.warmfield**
* **nv.rabbit.charmland**
* **nv.sheep.warmfield**

    and the following, second set should be in Discover/Discover:
* **nv.goat.alarmzone**
* **nv.pig.alarmzone**

The following table and diagram represent the connections we will attempt to make. Please proceed to the next step. 

| Source Deployment | Source Namespace | Target Deployment | Target Namespace | Port (TCP) | Allowed |
|:-----------------:|:----------------:|:-----------------:|:----------------:|:----:|:-------:|
| pig              | alarmzone             | chicken         | farmyard          | 5000 | Y |
| rabbit              | charmland             | goat| alarmzone           | 8010  | Y |

![Diagram2](https://github.com/olegvorobiov/cfl-ctf-challenge/blob/master/images/diagram2.png)

2. Run the following commands:
* 
```bash 
kubectl exec -it --namespace alarmzone \
  $(kubectl get pods --namespace alarmzone --selector app=pig -o jsonpath='{.items[*].metadata.name}') \
  -- curl chicken-svc.farmyard.svc.cluster.local:5000 --max-time 5
```
This command should succeed and you would get a following message:

**Bawk bawk! Welcome to the farmyard - I'm pecking away at your requests with farm-fresh efficiency!**

*
```bash 
kubectl exec -it --namespace charmland \
  $(kubectl get pods --namespace charmland --selector app=rabbit -o jsonpath='{.items[*].metadata.name}') \
  -- curl goat-svc.alarmzone.svc.cluster.local:8010 --max-time 5
```

   **THIS COMMAND SHOULD RESULT IN FAILURE BY DESIGN**    


| **FLAG part 1** |
|:---:|
| Rabbit workload is a source of this request. Identify the **destination** workload and use NeuVector's UI to find out the **destination's** workload **BaseOS**. |
| Click on a **Security Event** in **Notifications** => **Security Events** Tab and add `curl` to a list of allowed commands. |

 *   Run the last command again:

```bash
kubectl exec -it --namespace charmland \
  $(kubectl get pods --namespace charmland --selector app=rabbit -o jsonpath='{.items[*].metadata.name}') \
  -- curl goat-svc.alarmzone.svc.cluster.local:8010 --max-time 5
```
Now you should get a response that will look like this:

**Meh-eh-eh! I'm the G.O.A.T. of alarm handling - no need to panic, I've got your requests covered!**

| **FLAG parts 2 & 3** |
|:---|
| Now you might notice that not all of the **Network Rules** have been learned. The reason for that is because how **Network Rules** are learned when two groups are in different modes within NeuVector. |
| Identify the **missing** Network Rule. If you would to build the rule yourself, which group will be the source and which one would be the destination? |

| **FLAG  part 2** |
|:---|
| Source NeuVector Group |
| **FLAG part 3** |
| Destination NeuVector Group |

<details>
<summary>Free Hint</summary>
Consult the last diagram for all of the Network Rules. Navigate to Policy => Network Rules and find the missing rule. Disregard anything "coredns" related.
</details>

## Flag
|FLAG| |
|:---|:---|
| **Part 1:** | BaseOS of the destination of the call that failed in a previous section |
| **Part 2:** | Source Group Name for the Rule that hasn't been learned | 
| **Part 3:** | Destination Group Name for the Rule that hasn't been learned | 
| Final Result |**{baseOSname:SourceGroupName:DestinationGroupName}**|

**Example: flag{opensuse-leap:15.6:nv.ping-warrior.monarch:nv.arcade-server.arcbyte}**

