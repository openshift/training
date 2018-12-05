# Prerequisites

## Download Required Tools

1. Visit [https://try.openshift.com](https://try.openshift.com) with your web browser
1. Login with a Red Hat Account
1. Download the Pull Secret to location on host (e.g. ~/Downloads/pull-secret)
1. Download the Installer release for your platform
1. Download Terraform
1. Download OpenShift client tools

### Linux

```
wget https://github.com/openshift/installer/releases/download/v0.4.0/openshift-install-linux-amd64
chmod u+x ./openshift-install-linux-amd64
export OPENSHIFT_INSTALL_PULL_SECRET_PATH=~/Downloads/pull-secret
curl -L "https://releases.hashicorp.com/terraform/0.11.8/terraform_0.11.8_linux_amd64.zip" | funzip terraform
wget https://mirror.openshift.com/pub/openshift-v3/clients/4.0.0-0.79.0/linux/oc.tar.gz
tar -xvf oc.tar.gz
```

### Mac

```
curl -O -L https://github.com/openshift/installer/releases/download/v0.4.0/openshift-install-darwin-amd64
chmod +x ./openshift-install-darwin-amd64
export OPENSHIFT_INSTALL_PULL_SECRET_PATH=~/Downloads/pull-secret
curl -L https://releases.hashicorp.com/terraform/0.11.8/terraform_0.11.8_darwin_amd64.zip | funzip terraform
```

Next: [Installing the Cluster](02-install.md)
