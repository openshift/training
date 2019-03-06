# Exploring the Cluster

Now that your cluster is installed, you have access to the web console and
can use the CLI. Below are some command-line exercises to explore the
cluster:

## Cluster Nodes

The default installation behavior creates 6 nodes: 3 masters and 3 "worker"
application/compute nodes. You can view them with:

    oc get nodes

If you want to see the various applied labels, you can also do:

    oc get nodes --show-labels

## The Cluster Operator
The Cluster Operator is heavily responsible for
installation/management/maintenance/automated operations on the OpenShift
cluster.

    oc get deployments -n openshift-cluster-version

You can `rsh` into the running Operator and see the various manifests
associated with the installed release of OpenShift:

    oc rsh -n openshift-cluster-version deployments/cluster-version-operator

Then:

    ls /release-manifests

You will see a number of `.yaml` files. Don't forget to `exit` from your
`rsh` session before continuing

If you want to look at what the Cluster Operator has done since it was
launched, you can execute the following:

    oc logs deployments/cluster-version-operator -n openshift-cluster-version > operatorlog.txt

The operator's log is **extremely** long, so it is recommended that you
redirect it to a file instead of trying to look at it directly with the
`logs` command.

# Exploring RHEL CoreOS
The latest installer does not create any public IP addresses for any of the
EC2 instances that it provisions for your OpenShift cluster. In order to be
able to SSH to your OpenShift 4 hosts, you will first need to create a
security group that allows SSH access into the VPC. Then, you will need to
create an EC2 instance yourself inside the VPC that the installer created
during the provisioning process. Lastly, you will need to associate a public
IP address with the EC2 instance that you created.

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
