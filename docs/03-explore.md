# Exploring the Cluster

The following instructions assume that you have deployed the cluster using the 
*openshift-install* tooling, and that the necessary configuration files required
for cluster interaction have been automatically generated for you in your home
directory. If you have been provided with access to an environment (e.g. it has
been deployed for you) or you do **not** have the necessary configuration files
generated, follow these steps; it requires that you have the credentials and API
URI information to hand:

~~~bash
$ oc login --server <your API URI>

The server uses a certificate signed by an unknown authority.
You can bypass the certificate check, but any data you send to the server could be intercepted by others.
Use insecure connections? (y/n): y

Authentication required for https://api.beta-190305-1.ocp4testing.openshiftdemos.com:6443 (openshift)
Username: <your username>
Password: <your password>
Login successful.
(...)

Using project "default".
Welcome! See 'oc help' to get started.

$ cat ~/.kube/config
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://api.beta-190305-1.ocp4testing.openshiftdemos.com:6443
(...)
~~~

> **NOTE**: Your output will vary slightly from the above, you'll just need to make sure to use the API endpoint and credentials that you were provided with. We output the .kube/config file just to verify that it has successfully created our configuration.

Now that your cluster is installed, you will have access to the web console and
can use the CLI. Below are some command-line exercises to explore the cluster.

## Cluster Nodes

The default installation behavior creates 6 nodes: 3 masters and 3 "worker"
application/compute nodes. You can view them with:

~~~bash
$ oc get nodes -o wide
NAME                           STATUS    ROLES     AGE       VERSION              INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                          KERNEL-VERSION              CONTAINER-RUNTIME
ip-10-0-137-104.ec2.internal   Ready     worker    24h       v1.12.4+5dc94f3fda   10.0.137.104   <none>        Red Hat CoreOS 400.7.20190301.0   3.10.0-957.5.1.el7.x86_64   cri-o://1.12.6-1.rhaos4.0.git2f0cb0d.el7
ip-10-0-140-138.ec2.internal   Ready     master    24h       v1.12.4+5dc94f3fda   10.0.140.138   <none>        Red Hat CoreOS 400.7.20190301.0   3.10.0-957.5.1.el7.x86_64   cri-o://1.12.6-1.rhaos4.0.git2f0cb0d.el7
ip-10-0-158-222.ec2.internal   Ready     master    24h       v1.12.4+5dc94f3fda   10.0.158.222   <none>        Red Hat CoreOS 400.7.20190301.0   3.10.0-957.5.1.el7.x86_64   cri-o://1.12.6-1.rhaos4.0.git2f0cb0d.el7
ip-10-0-159-179.ec2.internal   Ready     worker    24h       v1.12.4+5dc94f3fda   10.0.159.179   <none>        Red Hat CoreOS 400.7.20190301.0   3.10.0-957.5.1.el7.x86_64   cri-o://1.12.6-1.rhaos4.0.git2f0cb0d.el7
ip-10-0-168-43.ec2.internal    Ready     master    24h       v1.12.4+5dc94f3fda   10.0.168.43    <none>        Red Hat CoreOS 400.7.20190301.0   3.10.0-957.5.1.el7.x86_64   cri-o://1.12.6-1.rhaos4.0.git2f0cb0d.el7
ip-10-0-171-135.ec2.internal   Ready     worker    24h       v1.12.4+5dc94f3fda   10.0.171.135   <none>        Red Hat CoreOS 400.7.20190301.0   3.10.0-957.5.1.el7.x86_64   cri-o://1.12.6-1.rhaos4.0.git2f0cb0d.el7
~~~

If you want to see the various applied **labels**, you can also do:

~~~bash
$ oc get nodes --show-labels
NAME                           STATUS    ROLES     AGE       VERSION              LABELS
ip-10-0-137-104.ec2.internal   Ready     worker    23h       v1.12.4+5dc94f3fda   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.large,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1a,kubernetes.io/hostname=ip-10-0-137-104,node-role.kubernetes.io/worker=
ip-10-0-140-138.ec2.internal   Ready     master    23h       v1.12.4+5dc94f3fda   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.xlarge,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1a,kubernetes.io/hostname=ip-10-0-140-138,node-role.kubernetes.io/master=
ip-10-0-158-222.ec2.internal   Ready     master    23h       v1.12.4+5dc94f3fda   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.xlarge,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1b,kubernetes.io/hostname=ip-10-0-158-222,node-role.kubernetes.io/master=
ip-10-0-159-179.ec2.internal   Ready     worker    23h       v1.12.4+5dc94f3fda   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.large,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1b,kubernetes.io/hostname=ip-10-0-159-179,node-role.kubernetes.io/worker=
ip-10-0-168-43.ec2.internal    Ready     master    23h       v1.12.4+5dc94f3fda   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.xlarge,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1c,kubernetes.io/hostname=ip-10-0-168-43,node-role.kubernetes.io/master=
ip-10-0-171-135.ec2.internal   Ready     worker    23h       v1.12.4+5dc94f3fda   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.large,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1c,kubernetes.io/hostname=ip-10-0-171-135,node-role.kubernetes.io/worker=
~~~

For reference, **labels** are used as a mechanism to tag certain information
onto a node, or a set of nodes, that can help you identify your systems, e.g.
by operating system, system architecture, specification, location of the system
(e.g. region), it's hostname, etc. They can also help with application
scheduling, e.g. make sure that my application (or pod) resides on a specific
system type. The labels shown above are utilising the default labels, but it's
possible to set some custom labels in the form of a key-value pair.

## The Cluster Operator

The Cluster Operator is the most important implementation within OpenShift, it's
a self-hosted operator that is heavily responsible for installation, management,
maintenance, and automated operations on the OpenShift cluster; it's essentially
what turns Kubernetes into OpenShift - it enables all of the additional
operators that we rely on (including the web console, the marketplace, image
registry, and router service, etc) and configures the cluster as we have
specified. We can view it's status by using the following command-

~~~bash
$ oc get deployments -n openshift-cluster-version
NAME                       DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
cluster-version-operator   1         1         1            1           2h
~~~

You can also `rsh` (remote shell access) into the running Operator and see the
various manifests associated with the installed release of OpenShift:

~~~bash
$ oc rsh -n openshift-cluster-version deployments/cluster-version-operator
~~~

Then to list the available manifests:

~~~bash
sh-4.2# ls -l /release-manifests/
total 836
-r--r--r--. 1 root root   171 Jan 15 04:04 0000_07_cluster-network-operator_00_namespace.yaml
-r--r--r--. 1 root root   381 Jan 15 04:04 0000_07_cluster-network-operator_01_crd.yaml
-r--r--r--. 1 root root   316 Jan 15 04:04 0000_07_cluster-network-operator_02_rbac.yaml
-r--r--r--. 1 root root  1904 Jan 15 04:04 0000_07_cluster-network-operator_03_daemonset.yaml
-r--r--r--. 1 root root   960 Jan 15 04:04 0000_08_cluster-dns-operator_00-cluster-role.yaml
-r--r--r--. 1 root root   298 Jan 15 04:04 0000_08_cluster-dns-operator_00-custom-resource-definition.yaml
-r--r--r--. 1 root root   198 Jan 15 04:04 0000_08_cluster-dns-operator_00-namespace.yaml
(...)
~~~

You will see a number of `.yaml` files in this directory; these are manifests
that describe each of the operators and how they're applied. Feel free to take a
look at some of these to give you an idea of what it's doing.

~~~bash
sh4.2# cat /release-manifests/0000_70_console-operator_00-crd.yaml
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: consoles.console.openshift.io
spec:
  group: console.openshift.io
  names:
    kind: Console
    listKind: ConsoleList
    plural: consoles
    singular: console
  scope: Namespaced
  version: v1alpha1

sh4.2# exit
exit
~~~

> **NOTE**: Don't forget to `exit` from your`rsh` session before continuing...

If you want to look at what the Cluster Operator has done since it was launched,
you can execute the following:

~~~bash
$ oc logs deployments/cluster-version-operator -n openshift-cluster-version > operatorlog.txt
$ ls operatorlog.txt
I0306 10:28:10.548869       1 start.go:71] ClusterVersionOperator v4.0.0-0.139.0.0-dirty
I0306 10:28:10.601159       1 start.go:197] Using in-cluster kube client config
I0306 10:28:10.667401       1 leaderelection.go:185] attempting to acquire leader lease  openshift-cluster-version/version...
(...)
~~~

The operator's log is **extremely** long, so it is recommended that you redirect
it to a file instead of trying to look at it directly with the `logs` command.

# Exploring RHEL CoreOS
*WARNING* this requires advanced knowledge of EC2 and is not a thourough set
*of instructions.

The latest installer does not create any public IP addresses for any of the
EC2 instances that it provisions for your OpenShift cluster. In order to be
able to SSH to your OpenShift 4 hosts:

1. Create a security group that allows SSH access into the VPC created by the 
installer
1. Create an EC2 instance yourself:
    * inside the VPC that the installer created
    * on one of the public subnets the installer created
1. Associate a public IP address with the EC2 instance that you created.

Unlike with the OpenShift installation, you must associate the EC2 instance
you create with an SSH keypair that you already have access to.

It does not matter what OS you choose for this instance, as it will simply
serve as an SSH bastion to bridge the internet into your OCP VPC.

Once you have provisioned your EC2 instance and can SSH into it, you will
then need to add the SSH key that you associated with your OCP installation
(**not the key for the bastion instance**). At that point you can follow the
rest of the instructions.

## Cluster Makeup
The OpenShift 4 cluster is made of hosts that are running RHEL CoreOS.
CoreOS is a container optimized, hardened, minimal footprint operating system
designed specifically to work with OpenShift and to run containers.

## Find a Hostname
First, look at the output of `oc get nodes` and pick one of the nodes that is
a master. Its name is something like `ip-10-0-1-163.ec2.internal`. 

From the bastion SSH host you manually deployed into EC2, you can then SSH
into that master host, making sure to use the same SSH key you specified
during the installation:

    ssh -i /path/to/sshkey core@MASTER_HOSTNAME_FROM_ABOVE

**Note: you *must* use the `core` user**.

If it works, you'll see the CoreOS MOTD/prompt:

    Red Hat CoreOS 400.7.20190301.0 Beta
    WARNING: Direct SSH access to machines is not recommended.
    This node has been annotated with machineconfiguration.openshift.io/ssh=accessed
    
    ---
    [core@ip-10-0-135-32 ~]$ 

## Explore RHEL CoreOS
You can check the kernel information with the following:

    uname -rs

You will see something like:

    Linux 3.10.0-957.5.1.el7.x86_64

The following command will show you a little bit about how `Ignition`
contacts remote servers for information and etc:

    journalctl --no-pager|grep "Ignition finished successfully" -B 100

RHEL CoreOS is an immutable operating system. It is predominantly a
read-only image-based OS. Try to create a file:

    touch /usr/test

You will see that you cannot because the FS is read only. However, there is a
place that is writable, but it is only writable by a user with privileges
(not `core`). As the `core` user, attempt to write to `/var/`:

    touch /var/test

You will be denied because of permissions. However, if you use `sudo`, it
will work:

    sudo touch /var/test && ls -l /var/test*

SELinux is enforcing:

    sestatus

You will see something like:

    SELinux status:                 enabled
    SELinuxfs mount:                /sys/fs/selinux
    SELinux root directory:         /etc/selinux
    Loaded policy name:             targeted
    Current mode:                   enforcing
    Mode from config file:          enforcing
    Policy MLS status:              enabled
    Policy deny_unknown status:     allowed
    Max kernel policy version:      31

The following commands will show you more information about the core of
OpenShift:

    systemctl status kubelet
    systemctl status crio
    sudo crictl pods

During the bootstrapping process, we need to run containers, but OpenShift's
core (eg: kubelet) is still not there yet. To accomplish that, `podman` is
used. You can explore `podman` a little:

    podman version

Next: [Scaling the Cluster](04-scaling-cluster.md)
