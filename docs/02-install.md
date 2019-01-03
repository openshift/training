# Install

The installer provides a guided experience for provisioning the cluster on a
particular platform. As of this writing, only AWS is a supported target.


The following demonstrates an install using the wizard as an example. It is
possible to run the installation in one terminal and then have another
terminal on the host available to watch the log file, if desired:

```
$ ./openshift-install create cluster
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

You can watch the installation progress by looking at the
`.openshift_install.log` file which will be located in the working directory
where `openshift-install` was executed:

    tail -f .openshift_install.log

[NOTE]
====
It may take several minutes for the OpenShift web console to become available/reachable after the installation completes.
====

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

[NOTE]
====
The additionally documented instructions and examples have not been tested
recently and may not work.
====

Next: [Exploring the Cluster](03-explore.md)
