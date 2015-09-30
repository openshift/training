<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Architecture and Requirements](#architecture-and-requirements)
  - [Architecture](#architecture)
  - [Requirements](#requirements)
- [Preparing the Environment](#preparing-the-environment)
  - [Use a Terminal Window Manager](#use-a-terminal-window-manager)
  - [DNS](#dns)
  - [Assumptions](#assumptions)
  - [Git](#git)
  - [Preparing Each VM](#preparing-each-vm)
  - [Docker Storage Setup (optional, recommended)](#docker-storage-setup-optional-recommended)
  - [Grab Docker Images (optional, recommended)](#grab-docker-images-optional-recommended)
  - [Clone the Training Repository](#clone-the-training-repository)
  - [Add Development Users](#add-development-users)
  - [Useful OpenShift Logs](#useful-openshift-logs)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Architecture and Requirements
## Architecture
The examples in this documentation assume the following architecture. There are
three systems:

* Master + Node
* Node
* Node

The master is the scheduler/orchestrator and the API endpoint for all commands.
This is similar to V2's "broker". We are also running the node software on the
master.

The "node" is just like in OpenShift 2 -- it hosts user applications. The main
difference is that "gears" have been replaced with Docker container instances.
You will learn much more about the inner workings of OpenShift throughout the
rest of the document.

## Requirements
Each of the virtual machines should have 4+ GB of memory, 20+ GB of disk space,
and the following configuration:

* RHEL >=7.1 (Note: 7.1 kernel is required for openvswitch)
* "Minimal" installation option

The majority of storage requirements are related to Docker and etcd (the data
store). Both of their contents live in /var, so it is recommended that the
majority of the storage be allocated to /var.

As part of signing up for the beta program, you should have received an
evaluation subscription. This subscription gave you access to the beta software.
You will need to use subscription manager to both register your VMs, and attach
them to the *OpenShift Enterprise High Touch Beta* subscription.

All of your VMs should be on the same logical network and be able to access one
another.

In almost all cases, when referencing VMs you must use hostnames and the
hostnames that you use must match the output of `hostname -f` on each of your
nodes. Forward DNS resolution of hostnames is an **absolute requirement**. This
training document assumes the following configuration:

* ose3-master.example.com (master+node)
* ose3-node1.example.com
* ose3-node2.example.com

We do our best to point out where you will need to change things if your
hostnames do not match.

If you cannot create real forward resolving DNS entries in your DNS system, you
will need to set up your own DNS server in the beta testing environment.
Documentation is provided on DNSMasq in an appendix, [APPENDIX - DNSMasq
setup](APPENDIX.md#appendix---dnsmasq-setup)

Remember that NetworkManager may make changes to your DNS
configuration/resolver/etc. You will need to properly configure your interfaces'
DNS settings and/or configure NetworkManager appropriately.

More information on NetworkManager can be found in this comment:

    https://github.com/openshift/training/issues/193#issuecomment-105693742

# Preparing the Environment
## Use a Terminal Window Manager
We **strongly** recommend that you use some kind of terminal window manager
(Screen, Tmux).

## DNS
You will need to have a wildcard for a DNS zone resolve, ultimately, to the IP
address of the OpenShift router. For this training, we will ensure that the
router will end up on the OpenShift server that is running the master. Go
ahead and create a wildcard DNS entry for "cloudapps" (or something similar),
with a low TTL, that points to the public IP address of your master.

For example:

    *.cloudapps.example.com. 300 IN  A 192.168.133.2

It is possible to use dnsmasq inside of your beta environment to handle these
duties. See the [appendix on dnsmasq](APPENDIX.md#appendix---dnsmasq-setup) if you can't
easily manipulate your existing DNS environment.

## Assumptions
In most cases you will see references to "example.com" and other FQDNs related
to it. If you choose not to use "example.com" in your configuration, that is
fine, but remember that you will have to adjust files and actions accordingly.

## Git
You will either need internet access or read and write access to an internal
http-based git server where you will duplicate the public code repositories used
in the labs.

## Preparing Each VM
Once your VMs are built and you have verified DNS and network connectivity you
can:

* Configure yum / subscription manager as follows:

        subscription-manager repos --disable="*"
        subscription-manager repos \
        --enable="rhel-7-server-rpms" \
        --enable="rhel-7-server-extras-rpms" \
        --enable="rhel-7-server-optional-rpms" \
        --enable="rhel-7-server-ose-3.0-rpms"

On **each** VM:

1. Install deltarpm to make package updates a little faster:

        yum -y install deltarpm

1. Install useful missing packages:

        yum -y install wget vim-enhanced net-tools bind-utils tmux git

1. Install prerequisites for the installer:

        yum -y install python-virtualenv gcc

    The installer complies python dependencies on the fly, which is why we
    require `gcc`.

1. Update:

        yum -y update

## Docker Storage Setup (optional, recommended)
**IMPORTANT:** The default docker storage configuration uses loopback devices
and is not appropriate for production. Red Hat considers the dm.thinpooldev
storage option to be the only appropriate configuration for production use at
this time.

If you want to configure the storage for Docker, you'll need to first install
Docker, as the installer currently does not auto-configure this storage setup
for you.

    yum -y install docker

Make sure that you are running at least `docker-1.6.2-6.el7.x86_64`.

In order to use dm.thinpooldev you must have an LVM thinpool available, the
`docker-storage-setup` package will assist you in configuring LVM. However you
must provision your host to fit one of these three scenarios :

*  Root filesystem on LVM with free space remaining on the volume group. Run
`docker-storage-setup` with no additional configuration, it will allocate the
remaining space for the thinpool.

*  A dedicated LVM volume group where you'd like to reate your thinpool

        echo <<EOF > /etc/sysconfig/docker-storage-setup
        VG=docker-vg
        SETUP_LVM_THIN_POOL=yes
        EOF
        docker-storage-setup

*  A dedicated block device, which will be used to create a volume group and thinpool

        cat <<EOF > /etc/sysconfig/docker-storage-setup
        DEVS=/dev/vdc
        VG=docker-vg
        SETUP_LVM_THIN_POOL=yes
        EOF
        docker-storage-setup

Once complete you should have a thinpool named `docker-pool` and docker should
be configured to use it in `/etc/sysconfig/docker-storage`.

    # lvs
    LV                  VG        Attr       LSize  Pool Origin Data%  Meta% Move Log Cpy%Sync Convert
    docker-pool         docker-vg twi-a-tz-- 48.95g             0.00   0.44

    # cat /etc/sysconfig/docker-storage
    DOCKER_STORAGE_OPTIONS=--storage-opt dm.fs=xfs --storage-opt dm.thinpooldev=/dev/mapper/openshift--vg-docker--pool

**Note:** If you had previously used docker with loopback storage you should
clean out `/var/lib/docker` This is a destructive operation and will delete all
images and containers on the host.

    systemctl stop docker
    rm -rf /var/lib/docker/*
    systemctl start docker

## Grab Docker Images (optional, recommended)
**If you want** to pre-fetch Docker images to make the first few things in your
environment happen **faster**, you'll need to first install Docker if you didn't
install it when (optionally) configuring the Docker storage previously.

    yum -y install docker

Make sure that you are running at least `docker-1.6.2-6.el7.x86_64`.

You'll need to add `--insecure-registry 0.0.0.0/0` to your
`/etc/sysconfig/docker` `OPTIONS`. Then:

    systemctl start docker

On all of your systems, grab the following docker images:

    docker pull registry.access.redhat.com/openshift3/ose-haproxy-router
    docker pull registry.access.redhat.com/openshift3/ose-deployer
    docker pull registry.access.redhat.com/openshift3/ose-sti-builder
    docker pull registry.access.redhat.com/openshift3/ose-docker-builder
    docker pull registry.access.redhat.com/openshift3/ose-pod
    docker pull registry.access.redhat.com/openshift3/ose-docker-registry
    docker pull registry.access.redhat.com/openshift3/ose-keepalived-ipfailover

It may be advisable to pull the following Docker images as well, since they are
used during the various labs:

    docker pull registry.access.redhat.com/openshift3/ruby-20-rhel7
    docker pull registry.access.redhat.com/openshift3/mysql-55-rhel7
    docker pull registry.access.redhat.com/openshift3/php-55-rhel7
    docker pull registry.access.redhat.com/jboss-eap-6/eap-openshift
    docker pull openshift/hello-openshift

**Note:** If you built your VM for a previous (beta) version and at some point
used an older version of Docker, you need to *reinstall* or *remove+install*
Docker after removing `/etc/sysconfig/docker`. The options in the config file
changed and RPM will not overwrite your existing file if you just do a "yum
update".

    yum -y remove docker
    rm /etc/sysconfig/docker*
    yum -y install docker

## Clone the Training Repository
On your master, it makes sense to clone the training git repository:

    cd
    git clone https://github.com/openshift/training.git

**REMINDER**
Almost all of the files for this training are in the training folder you just
cloned.

## Add Development Users
In the "real world" your developers would likely be using the OpenShift tools on
their own machines (`oc` and the web console). For these examples, we will
create user accounts for two non-privileged users of OpenShift, *joe* and
*alice*, on the master. This is done for convenience and because we'll be using
`htpasswd` for authentication.

    useradd joe
    useradd alice

We will come back to these users later. Remember to do this on the `master`
system, and not the nodes.

## Useful OpenShift Logs
RHEL 7 uses `systemd` and `journal`. As such, looking at logs is not a matter of
`/var/log/messages` any longer. You will need to use `journalctl`.

Since we are running all of the components in higher loglevels, it is suggested
that you use your terminal emulator to set up windows for each process. If you
are familiar with the Ruby Gem, `tmuxinator`, there is a config file in the
training repository. Otherwise, you should run each of the following in its own
window:

    journalctl -f -u openshift-master
    journalctl -f -u openshift-node

**Note:** You will want to do this on the other nodes, but you won't need the
"-master" service. You may also wish to watch the Docker logs, too.

**Note:** There is an appendix on configuring [Log
Aggregation](APPENDIX.md#appendix---infrastructure-log-aggregation)
