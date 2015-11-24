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
Each of the virtual machines should have 4+ GB of memory, 30+ GB of disk space,
and the following configuration:

* RHEL >=7.1 (Note: 7.1 kernel is required for openvswitch)
* "Minimal" installation option
* 15-20GB dedicated to /
* A free/unused partition with the remaining space

The majority of storage requirements are related to Docker and etcd (the data
store). 

You will need to use subscription manager to both register your VMs, and attach
them to the *OpenShift Enterprise* subscription.

All of your VMs should be on the same logical network and be able to access one
another.

In almost all cases, when referencing VMs, you must use hostnames and the
hostnames that you use must match the output of `hostname -f` on each of your
nodes. Forward DNS resolution of hostnames is an **absolute requirement**. This
training document assumes the following configuration:

* ose3-master.example.com (master+node)
* ose3-node1.example.com
* ose3-node2.example.com

We do our best to point out where you will need to change things if your
hostnames do not match.

If you cannot create real forward resolving DNS entries in your DNS system, you
will need to set up your own DNS server on one of the OpenShift nodes. The
Appendix chapter has a section on configuring DNSmasq in your environment.

Remember that NetworkManager may make changes to your DNS
configuration/resolver/etc. You will need to properly configure your interfaces'
DNS settings and/or configure NetworkManager appropriately. See the
NetworkManager appendix for more information.

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

You can also use the sample DNSmasq configuration referenced above.

## Assumptions
In most cases you will see references to "example.com" and other FQDNs related
to it. If you choose not to use "example.com" in your configuration, that is
fine, but remember that you will have to adjust files and actions accordingly.

## Git
You will either need internet access or read and write access to an internal Git
server where you will duplicate the public code repositories used in the labs.

## Preparing Each VM
Once your VMs are built and you have verified DNS and network connectivity you
can:

* Configure yum / subscription manager as follows:

        subscription-manager repos --disable="*"
        subscription-manager repos \
        --enable="rhel-7-server-rpms" \
        --enable="rhel-7-server-extras-rpms" \
        --enable="rhel-7-server-optional-rpms" \
        --enable="rhel-7-server-ose-3.1-rpms"

On **each** VM:

1. Install deltarpm to make package updates a little faster:

        yum -y install deltarpm

1. Install useful missing packages (sub `tmux` for `screen` if you wish):

        yum -y install wget vim-enhanced net-tools bind-utils tmux git

1. Install the installer:

        yum -y install atomic-openshift-utils

1. Update:

        yum -y update

## Docker Storage Setup (optional, recommended)
**IMPORTANT:** The default Docker storage configuration uses loopback devices
and is not appropriate for production. Red Hat considers the dm.thinpooldev
storage option to be the only appropriate configuration for production use at
this time.

If you want to configure the storage for Docker, you'll need to first install
Docker, as the installer currently does not auto-configure this storage setup
for you.

    yum -y install docker

Make sure that you are running at least `docker-1.8.2-8.el7`.

Please see the OpenShift documentation on configuring Docker storage:

    https://docs.openshift.com/enterprise/latest/install_config/install/prerequisites.html#configuring-docker-storage

## Grab Docker Images (optional, recommended)
**If you want** to pre-fetch Docker images to make the first few things in your
environment happen **faster**, you'll need to first install Docker if you didn't
install it when (optionally) configuring the Docker storage previously.

    yum -y install docker

Make sure that you are running at least `docker-1.8.2-8.el7`, then:

    systemctl start docker

On all of your systems, grab the following docker images:

    docker pull registry.access.redhat.com/openshift3/ose-haproxy-router:v3.1.0.4
    docker pull registry.access.redhat.com/openshift3/ose-deployer:v3.1.0.4
    docker pull registry.access.redhat.com/openshift3/ose-sti-builder:v3.1.0.4
    docker pull registry.access.redhat.com/openshift3/ose-docker-builder:v3.1.0.4
    docker pull registry.access.redhat.com/openshift3/ose-pod:v3.1.0.4
    docker pull registry.access.redhat.com/openshift3/ose-docker-registry:v3.1.0.4
    docker pull registry.access.redhat.com/openshift3/ose-keepalived-ipfailover:v3.1.0.4

It may be advisable to pull the following Docker images as well, since they are
used during the various labs:

    docker pull registry.access.redhat.com/rhscl/ruby-22-rhel7
    docker pull registry.access.redhat.com/rhscl/mysql-56-rhel7
    docker pull registry.access.redhat.com/rhscl/php-56-rhel7
    docker pull registry.access.redhat.com/jboss-eap-6/eap-openshift
    docker pull openshift/hello-openshift:v1.0.6

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

    journalctl -f -u atomic-openshift-master
    journalctl -f -u atomic-openshift-node

**Note:** You will want to do this on the other nodes, but you won't need the
"-master" service. You may also wish to watch the Docker logs, too.

**Note:** There is an appendix on configuring [Log
Aggregation](#appendix---infrastructure-log-aggregation)

