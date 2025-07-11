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

    After the installation is completed you will have **helm**, **kubectl**, **rdctl**, and a few more tools installed.

2. Additional configuration for Rancher Desktop:

    a. Ensure to select a stable version
    
    ![rd1](https://github.com/olegvorobiov/cfl-ctf-challenge/blob/master/rd1.png)
    
    b. Disable Traefik
    
    ![rd2](https://github.com/olegvorobiov/cfl-ctf-challenge/blob/master/rd2.png)
    
    c. Restart Rancher Desktop
### git
* Install git based on your operating system - https://git-scm.com/downloads.
## Setup
### Clone the Challenge repo
* ```git clone https://github.com/olegvorobiov/cfl-ctf-challenge.git```
### Deploy modded NeuVector chart
1. Install ingress-nginx

    ```helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace --version 4.11.2```

2. Pick the hostname you want to use to access NeuVector's UI. Example: **nv.rd.localhost**
    * Add a new entry to your ```/etc/hosts``` file:

        ```127.0.0.1	localhost nv.rd.localhost```
3. Deploy NeuVector to a namespace of your choice, pick the name of the release as you wish:

    ```helm install nv -n nv --create-namespace ./helm/core -f ./helm/core/values.yaml --set manager.ingress.host="nv.rd.localhost"```
4. After installation navigate to Rancher Desktop, go to Port Forwarding and find the webui service and forward it to a port of your choice.

    ![rd3](https://github.com/olegvorobiov/cfl-ctf-challenge/blob/master/rd3.png)
5. Open your favorite browser and navigate to https://nv.rd.localhost:[portForward-number]
## Challenges
### 1. Deploy Farm Services

* Run: ```kubectl apply -f farm-services.yaml```
* Ensure the workloads are being deployed successfully

### 2. Configure Network and Process rules
1. Given the table below use your kubernetes knowledge to create these Network connections. You should not execute inside the pod. `curl` and `wget` are available within all of the pods. 
    
    **FREE HINT:** To filter only the groups related to this challenge type `arm` in filter box.

    | Source Deployment | Source Namespace | Target Deployment | Target Namespace | Port | Allowed |
    |:-----------------:|:----------------:|:-----------------:|:----------------:|:----:|:-------:|
    | chicken              | farmyard             | sheep            | warmfield          | 9000 | V |
    | chicken              | farmyard             | suse.com (external)|                 | 443  | V |
    | chicken              | farmyard             | any other site (external)|               | 443  | X |
    | sheep            | warmfield          | chicken              | farmyard             | 5000 | V |
    | sheep            | warmfield          | cow              | warmfield          | 8090 | V |
    | cow              | warmfield          | bee             | treefarm        | 8000 | V |
    | bee             | treefarm        | cow              | warmfield          | 8090 | V |
    | bee             | treefarm        | rabbit            | charmland             | 8080 | V |

    Refer to a diagram below for graphical representation:
    ![Diagram1](https://github.com/olegvorobiov/cfl-ctf-challenge/blob/master/diagram1.png)
2. Switch the groups into a Protect/Protect mode and now try some of these commands:
* Cow should not be able to talk to sheep:

    `kubectl exec -it --namespace warmfield $(kubectl get pods --namespace warmfield --selector app=cow -o jsonpath='{.items[*].metadata.name}') -- curl sheep-svc.warmfield.svc.cluster.local:9000 --max-time 5`
* You should not be able to execute in any of the pods. Example for bee:

    `kubectl exec -it --namespace treefarm $(kubectl get pods --namespace treefarm --selector app=bee -o jsonpath='{.items[*].metadata.name}') -- bash`
* Rabbit should not be able to talk to bee.

    `kubectl exec -it --namespace charmland $(kubectl get pods --namespace charmland --selector app=rabbit -o jsonpath='{.items[*].metadata.name}') -- curl bee-svc.treefarm.svc.cluster.local:8000 --max-time 5`
    
    **Oops - rabbit pod doesn't have `curl` in allow list. That is why it failed.**
* Chicken should be only able to communicate with suse.com, and not any other outside service. If you weren't able to accomplish this - don't worry it doesn't affect the end goal :-)

    `kubectl exec -it --namespace farmyard $(kubectl get pods --namespace farmyard --selector app=chicken -o jsonpath='{.items[*].metadata.name}') -- curl https://google.com --max-time 5`


### 3. Deploy a second set of workloads

* Run: ```kubectl apply -f addon-services.yaml```
* Ensure the workloads are being deployed successfully

### 4. Configure Network and Process rules
1. Given the table below use your kubernetes knowledge to create these Network connections. You should not execute inside the pod. `curl` and `wget` are available within all of the pods. See the additional rules in the table below.

    **GOOD TO KNOW:** Despite the fact that the farm-services groups are in Protect/Protect mode, the new Network Rules are not still being learned, but allowed to be executed, because NeuVector operates in the least restrictive mode. Process Profile rules stick to the mode they are in.

    Now, make sure that those Network Rules are setup as described below.

    | Source Deployment | Source Namespace | Target Deployment | Target Namespace | Port | Allowed |
    |:-----------------:|:----------------:|:-----------------:|:----------------:|:----:|:-------:|
    | pig              | alarmzone             | chicken         | farmyard          | 5000 | V |
    | rabbit              | charmland             | goat| alarmzone           | 8010  | V |

    Refer to a diagram below for graphical representation:
    ![Diagram2](https://github.com/olegvorobiov/cfl-ctf-challenge/blob/master/diagram2.png)
2. Switch al of the groups filtered by `arm` into a Protect/Protect mode.
### 5. Observe the differences
**At this point all of the groups that filtered by `arm` should be in Protect/Protect mode.**

This includes:
* nv.bee.treefarm
* nv.chicken.farmyard
* nv.cow.warmfield
* nv.goat.alarmzone
* nv.pig.alarmzone
* nv.rabbit.charmland
* nv.sheep.warmfield

Now let's try to run this command `cat /etc/os-release` on all of the workloads. Try to execute the same command 3-4 times:
* `kubectl exec -it --namespace treefarm $(kubectl get pods --namespace treefarm --selector app=bee -o jsonpath='{.items[*].metadata.name}') -- cat /etc/os-release`

* `kubectl exec -it --namespace farmyard $(kubectl get pods --namespace farmyard --selector app=chicken -o jsonpath='{.items[*].metadata.name}') -- cat /etc/os-release`

* `kubectl exec -it --namespace warmfield $(kubectl get pods --namespace warmfield --selector app=cow -o jsonpath='{.items[*].metadata.name}') -- cat /etc/os-release`

* `kubectl exec -it --namespace alarmzone $(kubectl get pods --namespace alarmzone --selector app=goat -o jsonpath='{.items[*].metadata.name}') -- cat /etc/os-release`

* `kubectl exec -it --namespace alarmzone $(kubectl get pods --namespace alarmzone --selector app=pig -o jsonpath='{.items[*].metadata.name}') -- cat /etc/os-release`

* `kubectl exec -it --namespace charmland $(kubectl get pods --namespace charmland --selector app=rabbit -o jsonpath='{.items[*].metadata.name}') -- cat /etc/os-release`

* `kubectl exec -it --namespace warmfield $(kubectl get pods --namespace warmfield --selector app=sheep -o jsonpath='{.items[*].metadata.name}') -- cat /etc/os-release`


## Flag
{baseOSname:ProcessPath} - of the process that executed successfully but should've been denied

**Example: {opensuse-leap:15.6:/usr/bin/ls}**
## Hints
* -5 points for hint 1. Deploy Farm Services
* -5 points for 2. Configure Network and Process rules
* -10 points for flags first word 
* -10 points for flags second word 

