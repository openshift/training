# Install

The installer provides a guided experience for provisioning the cluster on a
particular platform. As of this writing, only AWS is a supported target.

The following demonstrates an install using the wizard as an example. It is
possible to run the installation in one terminal and then have another
terminal on the host available to watch the log file, if desired.

The installer is interactive and you will use the cursor/arrow keys to select
various options when necessary. The installer will use the AWS credentials
associated with the profile you exported earlier (eg:
`AWS_PROFILE=openshift4-beta-admin`) and interrogate the account associated
to populate certain items.

## Start the Installation
Previously you downloaded the `openshift-install` command and now you will
run it and follow the interactive prompts.

### NOTE
You may wish to use the `--dir <something>` flag to place the installation artifacts into a specific directory. This makes cleanup easier, and makes it easier to handle multiple clusters at the same time.

To do so, run the following to start your installation:

    ./openshift-install --dir /some/path/to/artifacts create cluster

Otherwise, run the following:

```
$ ./openshift-install create cluster
? SSH Public Key /path/to/.ssh/id_rsa.pub
? Platform aws
? Region us-east-1
? Base Domain openshift4-beta-abcorp.com
? Cluster Name demo1
? Pull Secret [? for help] *********************************************************
```

The installer will then start (you will see output similar to the following):

```
INFO Creating cluster...                     	 
INFO Waiting up to 30m0s for the Kubernetes API...
INFO API v1.11.0+85a0623 up                  	 
INFO Waiting up to 30m0s for the bootstrap-complete event...
INFO Destroying the bootstrap resources...   	 
INFO Waiting up to 10m0s for the openshift-console route to be created...
INFO Install complete!                       	 
INFO Run 'export KUBECONFIG=<your working directory>/auth/kubeconfig' to manage the cluster with 'oc', the OpenShift CLI.
INFO The cluster is ready when 'oc login -u kubeadmin -p <provided>' succeeds (wait a few minutes).
INFO Access the OpenShift web-console here: https://console-openshift-console.apps.demo1.openshift4-beta-abcorp.com
INFO Login to the console with user: kubeadmin, password: <provided>
```

### NOTE
The `oc login` command will ask for a server. The installer output did not
tell you the API endpoint to use. You can find this by running:

    grep server /root/auth/kubeconfig

If you `export KUBECONFIG` as instructed, the `oc login` will work.

If you want to use some `bash` to make the login command easier without
having to `export KUBECONFIG`, you can execute the following:

    oc login -u kubeadmin -p `cat /root/auth/kubeadmin-password` \
    `grep server /root/auth/kubeconfig | awk '{print $2}'`

## Watch the Installation
You can watch the installation progress by looking at the
`.openshift_install.log` file which will be located in the working directory
where `openshift-install` was executed:

    tail -f .openshift_install.log

## Configure the CLI
Make sure to run the `export KUBECONFIG=...` command in the installer output.
Then, if you have the `oc` client in your `PATH` and executable, you should
be able to execute:

    oc get clusterversion

And you will see some output like:

```
NAME      VERSION   AVAILABLE   PROGRESSING   SINCE     STATUS
version   4.0.0-9   True        False         22s       Cluster version is 4.0.0-9
```

For more details, you can use `oc describe clusterversion`:

```
Name:         version
Namespace:    
Labels:       <none>
Annotations:  <none>
API Version:  config.openshift.io/v1
Kind:         ClusterVersion
Metadata:
...
    Version:     4.0.0-9
  Generation:    1
  Version Hash:  h5rmLF13-LA=
Events:          <none>
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

### Note
If you lose either the password or the console URL, you can find them in the
`output.txt` file which is likely in the same folder in which you executed
`openshift-install`.

# Problems?
If you had installation issues, see the [troubleshooting](06-troubleshooting.md) section.

Next: [Exploring the Cluster](03-explore.md)
