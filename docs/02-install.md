# Basic Installations

The scope of the new OpenShift 4 installer is purposefully narrow. It is
designed for simplicity and ensured success. Many of the items and
configurations that were previously handled by the installer are now expected
to be "Day 1" operations, performed just after the installation of the
control plane and basic workers completes. The installer provides a guided
experience for provisioning the cluster on a particular platform. As of this
writing, only AWS is a supported target.

This section demonstrates an install using the wizard as an example. It is
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
You may wish to use the `--dir <something>` flag to place the installation
artifacts into a specific directory. This makes cleanup easier, and makes it
easier to handle multiple clusters at the same time.

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
INFO API v1.11.0+c69f926354 up
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
`.openshift_install.log` file which is likely in the same folder in which you executed
`openshift-install` (or the dir that you specified). For example:

    tail -n5 /path/to/dir/.openshift_install.log

### Note
If you open another terminal or log-out and log-in to the terminal again and
lose your `KUBECONFIG` environment variable, look for the `auth/kubeconfig`
file in your installation artifacts directory and simply re-export it:

    export KUBECONFIG=/path/to/something/auth/kubeconfig

# Advanced Installations
While the OpenShift 4 installer's purpose in life is to streamline operations
in order to guarantee success, there are a few options that you can adjust by
using a configuration file. For example, you can change the default number of
instances of workers and masters, and you can change both the master and
initial worker EC2 instance types.

## Generate Installer Configuration File
This example will use the `--dir` option. The first step is to ask the
installer to pre-generate an installer configuration file,
`install-config.yaml`:

```sh
openshift-install --dir /path/to/something create install-config
```

After following the same interactive prompts you saw earlier when performing
a basic/default installation, this will generate a file called
`install-config.yaml` in the folder `/path/to/something`. The important
stanzas in the file to examine are the two `machines` stanzas:

```yaml
machines:
- name: master
  platform: {}
  replicas: 3
- name: worker
  platform: {}
  replicas: 3
```

The platform sections are empty, deferring per-platform implementation
decisions for these machines to the installer. There is also a platform
section at the bottom of the file. That section is for per-platform cluster
config for non-machine properties.

Let's modify our config file to specify that we want 6 initial workers, all
of size `c5.xlarge`. Again, the only section to modify is the `machines`
section:

```yaml
machines:
- name: master
  platform: {}
  replicas: 3
- name: worker
  platform: 
    aws:
      type: c5.xlarge
  replicas: 6
```

Then, as before, run the installer with the `--dir` option:

    openshift-install --dir /path/to/something create cluster

The installer will notice the `install-config.yaml` and not prompt you for
any input. It will simply begin to perform the installation. When you get to
the exercises for scaling/exploring your cluster, note the starting machine
types and quantities.

### NOTE
It's also possible to change the volume configuration for the EC2 instance.
In the case of large or busy clusters, tuning the volume parameters to get
more IOPS for etcd may improve performance and stability. The example below
shows changing both the instance type and the root volume for the masters:

```YAML
machines:
- name: master
  platform:
    aws:
      type: m5.large
      rootVolume:
        iops: 700
        size: 220
        type: io1
```

### NOTE
When providing an `install-config.yaml` to the installer, the YAML file is
actually consumed (deleted) during the installation process. The installation
options chosen ultimately end up represented in the state of the cluster in
the JSON and Terraform state files. If you have any desire to retain the
original `intsall-config.yaml` file, be sure to make a copy.

# Problems?
If you had installation issues, see the [troubleshooting](06-troubleshooting.md) section.

Next: [Exploring the Cluster](03-explore.md)
