# Operation: Container Storm
**MISSION BRIEFING**

**FROM:** Captain K8s

**TO:** All available units

**CLASSIFICATION:** URGENT

A rogue development team has deployed a compromised container infrastructure protected by NeuVector. Intelligence suggests they've hidden a critical vulnerability in their runtime protection configuration - one that could allow unauthorized code execution.

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

    a. 
### git
* Install git based on your operating system - https://git-scm.com/downloads.
## Setup
### Clone the Challenge repo
* ```git clone ...```
### Deploy modded NeuVector chart
1. Install ingress-nginx

    ```helm upgrade --install ingress-nginx ingress-nginx --repo https://kubernetes.github.io/ingress-nginx --namespace ingress-nginx --create-namespace --version 4.11.2```

2. Pick the hostname you want to use to access NeuVector's UI. Example: **nv.rd.localhost**
    * Add a new entry to your ```/etc/hosts``` file:

        ```127.0.0.1	localhost nv.rd.localhost```
3. Deploy NeuVector to a namespace of your choice, pick the name of the release as you wish:

    ```helm install nv -n nv --create-namespace ./helm/core -f ./helm/core/values.yaml --set manager.ingress.host="nv.rd.localhost"```
## Challenges
### 1. Deploy Farm Services
### 2. Configure Network and Process rules
### 3. Deploy a second set of workloads
### 4. Configure Network and Process rules
### 5. Try these commands now
## Flag
## Hints



| Source Deployment | Source Namespace | Target Deployment | Target Namespace | Port | Allowed |
|:-----------------:|:----------------:|:-----------------:|:----------------:|:----:|:-------:|
| chicken              | farmyard             | sheep            | warmfield          | 9000 | V |
| chicken              | farmyard             | suse.com (external)|                 | 443  | V |
| chicken              | farmyard             | any other site (external)|               | 443  | X |
| sheep            | warmfield          | chicken              | farmyard             | 5000 | V |
| sheep            | warmfield          | cow              | warmfield          | 8090 | V |
| cow              | warmfield          | sheep            | warmfield          | 9000 | X |
| cow              | warmfield          | bee             | treefarm        | 8000 | V |
| bee             | treefarm        | cow              | warmfield          | 8090 | V |
| bee             | treefarm        | rabbit            | charmland             | 8080 | V |
| rabbit            | charmland             | bee             | treefarm        | 8000 | X |

See the diagram below for visual representation:
![alt text](https://github.com/oleg-vorobiov-suse/zero-trust-task/blob/master/neuvector_task.png)





