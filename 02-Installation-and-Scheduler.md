<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Ansible-based Installer](#ansible-based-installer)
  - [Install Ansible](#install-ansible)
  - [Generate SSH Keys](#generate-ssh-keys)
  - [Distribute SSH Keys](#distribute-ssh-keys)
  - [Clone the Ansible Repository](#clone-the-ansible-repository)
  - [Configure Ansible](#configure-ansible)
  - [Modify Hosts](#modify-hosts)
  - [Run the Ansible Installer](#run-the-ansible-installer)
  - [Add Cloud Domain](#add-cloud-domain)
- [Regions and Zones](#regions-and-zones)
  - [Scheduler and Defaults](#scheduler-and-defaults)
  - [The NodeSelector](#the-nodeselector)
  - [Customizing the Scheduler Configuration](#customizing-the-scheduler-configuration)
  - [Node Labels](#node-labels)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Ansible-based Installer
The installer uses Ansible. Eventually there will be an interactive text-based
CLI installer that leverages Ansible under the covers. For now, we have to
invoke Ansible manually.

## Install Ansible
Ansible currently comes from the EPEL repository.

Install EPEL:

    yum -y install \
    http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm

Disable EPEL so that it is not accidentally used later:

    sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo

Install the packages for Ansible:

    yum -y --enablerepo=epel install ansible

## Generate SSH Keys
Because of the way Ansible works, SSH key distribution is required. First,
generate an SSH key on your master, where we will run Ansible:

    ssh-keygen

Do *not* use a password.

## Distribute SSH Keys
An easy way to distribute your SSH keys is by using a `bash` loop:

    for host in ose3-master.example.com ose3-node1.example.com \
    ose3-node2.example.com; do ssh-copy-id -i ~/.ssh/id_rsa.pub \
    $host; done

Remember, if your FQDNs are different, you would have to modify the loop
accordingly.

## Clone the Ansible Repository
The configuration files for the Ansible installer are currently available on
Github. Clone the repository:

    cd
    git clone https://github.com/detiber/openshift-ansible.git -b rc
    cd ~/openshift-ansible

## Configure Ansible
Copy the staged Ansible configuration files to `/etc/ansible`:

    /bin/cp -r ~/training/beta4/ansible/* /etc/ansible/

## Modify Hosts
If you are not using the "example.com" domain and the training example
hostnames, modify `/etc/ansible/hosts` accordingly. 

Also, if you are using multiple NICs and will be trying to direct various
traffic to different places, you will need to take a look at [Generic Cloud
Install](#generic-cloud-install) to learn more about the syntax of Ansible's
`hosts` file.

## Run the Ansible Installer
Now we can simply run the Ansible installer:

    ansible-playbook ~/openshift-ansible/playbooks/byo/config.yml

If you looked at the Ansible hosts file, note that our master
(ose3-master.example.com) was present in both the `master` and the `node`
section.

Effectively, Ansible is going to install and configure node software on all the
nodes and master software just on `ose3-master.example.com` .

## Add Cloud Domain
If you want default routes (we'll talk about these later) to automatically get
the right domain (the one you configured earlier with your wildcard DNS), then
you should edit `/etc/openshift/master/master-config.yaml` and add the following
to the last line of the file:

    routingConfig:
      subdomain: cloudapps.example.com

Or modify it appropriately for your domain.

Once done, restart the master:

    systemctl restart openshift-master

There was also some information about "regions" and "zones" in the hosts file.
Let's talk about those concepts now.

# Regions and Zones
If you think you're about to learn how to configure regions and zones in
OpenShift 3, you're only partially correct.

In OpenShift 2, we introduced the specific concepts of "regions" and "zones" to
enable organizations to provide some topologies for application resiliency. Apps
would be spread throughout the zones in a region and, depending on the way you
configured OpenShift, you could make different regions accessible to users.

The reason that you're only "partially" correct in your assumption is that, for
OpenShift 3, Kubernetes doesn't actually care about your topology. In other
words, OpenShift is "topology agnostic". In fact, OpenShift 3 provides advanced
controls for implementing whatever topologies you can dream up, leveraging
filtering and affinity rules to ensure that parts of applications (pods) are
either grouped together or spread apart.

For the purposes of a simple example, we'll be sticking with the "regions" and
"zones" theme. But, as you go through these examples, think about what other
complex topologies you could implement. Perhaps "secure" and "insecure" hosts,
or other topologies.

First, we need to talk about the "scheduler" and its default configuration.

## Scheduler and Defaults
The "scheduler" is essentially the OpenShift master. Any time a pod needs to be
created (instantiated) somewhere, the master needs to figure out where to do
this. This is called "scheduling". The default configuration for the scheduler
looks like the following JSON (although this is embedded in the OpenShift code
and you won't find this in a file):

    {
      "predicates" : [
        {"name" : "PodFitsResources"},
        {"name" : "MatchNodeSelector"},
        {"name" : "HostName"},
        {"name" : "PodFitsPorts"},
        {"name" : "NoDiskConflict"}
      ],"priorities" : [
        {"name" : "LeastRequestedPriority", "weight" : 1},
        {"name" : "ServiceSpreadingPriority", "weight" : 1}
      ]
    }

When the scheduler tries to make a decision about pod placement, first it goes
through "predicates", which essentially filter out the possible nodes we can
choose. Note that, depending on your predicate configuration, you might end up
with no possible nodes to choose. This is totally OK (although generally not
desired).

These default options are documented in the link above, but the quick overview
is:

* Place pod on a node that has enough resources for it (duh)
* Place pod on a node that doesn't have a port conflict (duh)
* Place pod on a node that doesn't have a storage conflict (duh)

And some more obscure ones:

* Place pod on a node whose `NodeSelector` matches
* Place pod on a node whose hostname matches the `Host` attribute value

The next thing is, of the available nodes after the filters are applied, how do
we select the "best" one. This is where "priorities" come in. Long story short,
the various priority functions each get a score, multiplied by the weight, and
the node with the highest score is selected to host the pod.

Again, the defaults are:

* Choose the node that is "least requested" (the least busy)
* Spread services around - minimize the number of pods in the same service on
    the same node

And, for an extremely detailed explanation about what these various
configuration flags are doing, check out:

    http://docs.openshift.org/latest/admin_guide/scheduler.html

In a small environment, these defaults are pretty sane. Let's look at one of the
important predicates (filters) before we move on to "regions" and "zones".

## The NodeSelector
`NodeSelector` is a part of the Pod data model. And, if we think back to our pod
definition, there was a "label", which is just a key:value pair. In the case of
a `NodeSelector`, our labels (key:value pairs) are used to help us try to find
nodes that match, assuming that:

* The scheduler is configured to MatchNodeSelector
* The end user creating the pod knows which labels are out there

But this use case is also pretty simplistic. It doesn't really allow for a
topology, and there's not a lot of logic behind it. Also, if I specify a
NodeSelector label when using MatchNodeSelector and there are no matching nodes,
my workload will never get scheduled. Bummer.

How can we make this more intelligent? We'll finally use "regions" and "zones".

## Customizing the Scheduler Configuration
The Ansible installer is configured to understand "regions" and "zones" as a
matter of convenience. However, for the master (scheduler) to actually do
something with them requires changing from the default configuration Take a look
at `/etc/openshift/master/master-config.yaml` and find the line with `schedulerConfigFile`.

You should see:

    schedulerConfigFile: "/etc/openshift/master/scheduler.json"

Then, take a look at `/etc/openshift/master/scheduler.json`. It will have the
following content:

    {
      "predicates" : [
        {"name" : "PodFitsResources"},
        {"name" : "PodFitsPorts"},
        {"name" : "NoDiskConflict"},
        {"name" : "Region", "argument" : {"serviceAffinity" : { "labels" : ["region"]}}}
      ],"priorities" : [
        {"name" : "LeastRequestedPriority", "weight" : 1},
        {"name" : "ServiceSpreadingPriority", "weight" : 1},
        {"name" : "Zone", "weight" : 2, "argument" : {"serviceAntiAffinity" : { "label" : "zone" }}}
      ]
    }

To quickly review the above (this explanation sort of assumes that you read the
scheduler documentation, but it's not critically important):

* Filter out nodes that don't fit the resources, don't have the ports, or have
    disk conflicts
* If the pod specifies a label with the key "region", filter nodes by the value.

So, if we have the following nodes and the following labels:

* Node 1 -- "region":"infra"
* Node 2 -- "region":"primary"
* Node 3 -- "region":"primary"

If we try to schedule a pod that has a `NodeSelector` of "region":"primary",
then only Node 1 and Node 2 would be considered.

OK, that takes care of the "region" part. What about the "zone" part?

Our priorities tell us to:

* Score the least-busy node higher
* Score any nodes who don't already have a pod in this service higher
* Score any nodes whose zone label's value **does not** match higher

Why do we score a zone that **doesn't** match higher? Note that the definition
for the Zone priority is a `serviceAntiAffinity` -- anti affinity. In this case,
our anti affinity rule helps to ensure that we try to get nodes from *different*
zones to take our pod.

If we consider that our "primary" region might be a certain datacenter, and that
each "zone" in that datacenter might be on its own power system with its own
dedicated networking, this would ensure that, within the datacenter, pods of an
application would be spread across power/network segments.

The documentation link has some more complicated examples. The topoligical
possibilities are endless!

## Node Labels
**Note:** There is a bug in the installer right now and labeling the nodes
does not work. You'll have to fix this manually:

    oc label node/ose3-master.example.com region=infra zone=default
    oc label node/ose3-node1.example.com region=primary zone=east
    oc label node/ose3-node2.example.com region=primary zone=west

The assignments of "regions" and "zones" at the node-level are handled by labels
on the nodes. You can look at how the labels were implemented by doing:

    osc get nodes

    NAME                      LABELS                                                                     STATUS
    ose3-master.example.com   kubernetes.io/hostname=ose3-master.example.com,region=infra,zone=default   Ready
    ose3-node1.example.com    kubernetes.io/hostname=ose3-node1.example.com,region=primary,zone=east     Ready
    ose3-node2.example.com    kubernetes.io/hostname=ose3-node2.example.com,region=primary,zone=west     Ready

At this point we have a running OpenShift environment across three hosts, with
one master and three nodes, divided up into two regions -- "*infra*structure"
and "primary".

From here we will start to deploy "applications" and other resources into
OpenShift.

