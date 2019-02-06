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

The operator's log is **extremely** long, so it is recommended that you redirect it to a file instead of trying to look at it directly with the `logs` command.

# Exploring RHEL CoreOS
The OpenShift 4 cluster is made of hosts that are running RHEL CoreOS
(`RHELCOS`). CoreOS is a container optimized, hardened, minimal footprint
operating system designed specifically to work with OpenShift and to run
containers.

Only the masters are publicly accessible via SSH (only they have public IPs).
You can SSH into one of the masters and could also proxy/SSH tunnel to nodes
through a master. For this exercise, we will only explore one of the masters.

## Find the Master Public Hostname
First, look at the output of `oc get nodes` and pick one of the nodes that is
a master. Its name is something like `ip-10-0-1-163.ec2.internal`. Also, take
note of the `clusterid` you used during the installation. The following
command will give you the public DNS name of that master:

    aws ec2 describe-instances --filters "Name=private-dns-name,Values=HOSTNAME_HERE" \
    "Name=tag:clusterid,Values=CLUSTERID_HERE" --query "Reservations[*].Instances[*].[PublicDnsName]"

**Note:** You will need to add the `--region` flag if you have provisioned a
*cluster that is not in your default region (default as far as `aws`'s CLI is
*concerned.)

## SSH to the Master
You can then SSH into that master, making sure to specify the same SSH key
you specified during the installation:

    ssh -i /path/to/sshkey core@MASTER_HOSTNAME_FROM_ABOVE

**Note: you *must* use the `core` user**.

If it works, you'll see the CoreOS MOTD/prompt:

    RHEL CoreOS 4.0
     Information: https://url.corp.redhat.com/redhat-coreos
     Bugs: https://github.com/openshift/os

    ---

## Explore RHEL CoreOS
You can check the kernel information with the following:

    uname -rs

You will see something like:

    Linux 3.10.0-957.1.3.el7.x86_64

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
