# Install

The installer provides a guided experience for provisioning the cluster on a particular platform.

## Prerequisites

In the prior step, we downloaded the following:

1. installer (e.g. openshift-install-linux-amd64)
1. pull secret
1. configured env var for OPENSHIFT_PULL_SECRET_PATH

## Wizard

The install asks the user a set of questions to determine the platform and initial shape of the cluster.

### Linux

The following demonstrates an install using the wizard as an example.

```
./openshift-install-linux-amd64 create cluster
? Email Address user@example.com
? Password [? for help] ********
? SSH Public Key ~/.ssh/id_rsa.pub
? Base Domain dev.example.com
? Cluster Name my-cluster
? Pull Secret [? for help] ******
? Platform aws
? Region us-east-2
INFO Using Terraform to create cluster...         
INFO Waiting for bootstrap completion...          
INFO API v1.11.0+d4cacc0 up
INFO Destroying the bootstrap resources...        
INFO Using Terraform to destroy bootstrap resources... 
INFO Install complete! Run 'export KUBECONFIG=./auth/kubeconfig' to manage your cluster. 
INFO After exporting your kubeconfig, run 'oc -h' for a list of OpenShift client commands. 
```

### Mac

The following demonstrates an install using the wizard as an example.

```
./openshift-install-darwin-amd64 create cluster
? Email Address user@example.com
? Password [? for help] ********
? SSH Public Key ~/.ssh/id_rsa.pub
? Base Domain dev.example.com
? Cluster Name my-cluster
? Pull Secret [? for help] ******
? Platform aws
? Region us-east-2
INFO Using Terraform to create cluster...         
INFO Waiting for bootstrap completion...          
INFO API v1.11.0+d4cacc0 up
INFO Destroying the bootstrap resources...        
INFO Using Terraform to destroy bootstrap resources... 
INFO Install complete! Run 'export KUBECONFIG=./auth/kubeconfig' to manage your cluster. 
INFO After exporting your kubeconfig, run 'oc -h' for a list of OpenShift client commands. 
```

## Populated Answers

If you want to avoid the wizard, its useful to setup a set of env vars for a particular cloud platform.

### Amazon Web Services

#### Linux

```
## location of previously downloaded pull secret
export OPENSHIFT_INSTALL_PULL_SECRET_PATH=~/Downloads/pull-secret
## location of SSH public key
export OPENSHIFT_INSTALL_SSH_PUB_KEY_PATH=~/.ssh/id_rsa.pub
export OPENSHIFT_INSTALL_PLATFORM=aws
export OPENSHIFT_INSTALL_EMAIL_ADDRESS=user@example.com
## name of cluster
export OPENSHIFT_INSTALL_CLUSTER_NAME=my-cluster
export OPENSHIFT_INSTALL_PASSWORD=my-password
export OPENSHIFT_INSTALL_AWS_REGION=us-east-2
export OPENSHIFT_INSTALL_BASE_DOMAIN=devcluster.example.com
./openshift-install-linux-amd64 create cluster
```

#### Mac

```
## location of previously downloaded pull secret
export OPENSHIFT_INSTALL_PULL_SECRET_PATH=~/Downloads/pull-secret
## location of SSH public key
export OPENSHIFT_INSTALL_SSH_PUB_KEY_PATH=~/.ssh/id_rsa.pub
export OPENSHIFT_INSTALL_PLATFORM=aws
export OPENSHIFT_INSTALL_EMAIL_ADDRESS=user@example.com
## name of cluster
export OPENSHIFT_INSTALL_CLUSTER_NAME=my-cluster
export OPENSHIFT_INSTALL_PASSWORD=my-password
export OPENSHIFT_INSTALL_AWS_REGION=us-east-2
export OPENSHIFT_INSTALL_BASE_DOMAIN=devcluster.example.com
./openshift-install-darwin-amd64 create cluster
```

Next: [Exploring the Cluster](03-explore.md)
