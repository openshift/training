# Install

The installer provides a guided experience for provisioning the cluster on a
particular platform. As of this writing, only AWS is a supported target.

## Start the Installation
The following demonstrates an install using the wizard as an example. It is
possible to run the installation in one terminal and then have another
terminal on the host available to watch the log file, if desired.

The installer is interactive and you will use the cursor/arrow keys to select
various options when necessary. The installer will use the AWS credentials
associated with the profile you exported earlier (eg:
`AWS_PROFILE=openshift4-beta-admin`) and interrogate the account associated
to populate certain items.

```
$ ./openshift-install create cluster
? SSH Public Key /path/to/.ssh/id_rsa.pub
? Platform aws
? Region us-east-1
? Base Domain openshift4-beta-abcorp.com
? Cluster Name demo1
? Pull Secret [? for help] *********************************************************
```

The installer will then start:

```
INFO Creating cluster...                     	 
INFO Waiting up to 30m0s for the Kubernetes API...
INFO API v1.11.0+85a0623 up                  	 
INFO Waiting up to 30m0s for the bootstrap-complete event...
INFO Destroying the bootstrap resources...   	 
INFO Waiting up to 10m0s for the openshift-console route to be created...
INFO Install complete!                       	 
INFO Run 'export KUBECONFIG=<your working directory>/auth/kubeconfig' to manage the cluster with 'oc', the OpenShift CLI.
INFO The cluster is ready when 'oc login -u kubeadmin -p <passwd>' succeeds (wait a few minutes).
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.demo1.openshift4-beta-abcorp.com
INFO Login to the console with user: kubeadmin, password: <provided>
```

## Watch the Installation
You can watch the installation progress by looking at the
`.openshift_install.log` file which will be located in the working directory
where `openshift-install` was executed:

    tail -f .openshift_install.log

## Configure the CLI
Make sure to run the `export KUBECONFIG=...` command in the installer output. Then, if you have the `oc` client in your `PATH` and executable, you should be able to execute:

    oc get clusterversion

And you will see some output like:

```
NAME  	VERSION   AVAILABLE   PROGRESSING   SINCE 	STATUS
version   4.0.0-8   True    	False     	7m    	Cluster version is 4.0.0-8
$oc describe clusterversion
Name:     	version
Namespace:    
Labels:   	<none>
...
```

### NOTE
The installer also suggests `oc login`. The process of logging in with the
CLI creates/updates/modifies a kube config file. The installer automatically
generates a kube config file with the `kubeadmin` credentials. Logging in or
exporting the `KUBECONFIG` path are essentially doing the same thing in this
scenario.

## Web Console
It may take several minutes for the OpenShift web console to become
available/reachable after the installation completes. But, be sure to visit
it when it does. You can find the URL for the web console for your installed
cluster in the output of the installer. For example:

https://console-openshift-console.apps.demo1.openshift4-beta-abcorp.com

### Note
The username is always `kubeadmin` and the password is also in the output
from the installer. At the time of this writing, `kubeadmin` is the only user
and it is not possible to create additional users or integrate with an
identity store.

### Note
When visiting the web console you will receive a certificate error in your
browser. This is because the installation uses a self-signed certificate. You
will need to accept it in order to continue.

# Problems?
As of the time of this writing, if you encounter failures, you will need to
do a fresh install.

Do the following:
1. Please capture the console output and the installer log. 

        mv .openshift_install.log openshift_install_fail_logs

1. Clean up the install process and start fresh as following: 

        ./openshift-install destroy cluster
        rm .openshift_install_state.json

1. Re-start the install process

        ./openshift-install create cluster

Next: [Exploring the Cluster](03-explore.md)
