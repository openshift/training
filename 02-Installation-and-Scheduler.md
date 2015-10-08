<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Installation and Scheduler](#installation-and-scheduler)
  - [Generate SSH Keys](#generate-ssh-keys)
  - [Distribute SSH Keys](#distribute-ssh-keys)
  - [Run the Installer](#run-the-installer)
  - [Define installation user](#define-installation-user)
  - [Master Configuration](#master-configuration)
  - [Node Configuration](#node-configuration)
  - [General Confirmation](#general-confirmation)
  - [Finish the Installation](#finish-the-installation)
  - [Copy the CA certificate](#copy-the-ca-certificate)
  - [Add Cloud Domain](#add-cloud-domain)
- [Regions and Zones](#regions-and-zones)
  - [Scheduler and Defaults](#scheduler-and-defaults)
  - [The NodeSelector](#the-nodeselector)
  - [Customizing the Scheduler Configuration](#customizing-the-scheduler-configuration)
  - [Node Labels](#node-labels)
  - [Edit Default NodeSelector](#edit-default-nodeselector)
  - [Make Master Schedulable](#make-master-schedulable)
  - [Tweak Default Project](#tweak-default-project)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Installation and Scheduler
Much like with OpenShift Enterprise 2.x and prior, we provide a convenient
web-sourced installer at `http://install.openshift.com`. First, we must prepare
for using the installer.

## Generate SSH Keys
The installer uses ssh underneath the covers to access the hosts in the
environment and configure them. To do this without passwords, we require that
SSH keys be generated and distributed. The standaard tool to do this is
`ssh-keygen`. You can run it with no arguments:

    ssh-keygen

Do *not* use a password when prompted.

## Distribute SSH Keys
An easy way to distribute your SSH keys is by using a `bash` loop:

    for host in ose3-master.example.com ose3-node1.example.com \
    ose3-node2.example.com; do ssh-copy-id -i ~/.ssh/id_rsa.pub \
    $host; done

Remember, if your FQDNs are different, you would have to modify the command
accordingly.

## Run the Installer
Go ahead and run the installer:

    sh <(curl -s https://install.openshift.com/ose/)

It will take a few moments to download and compile its dependencies, and then it
will run. You will be prompted to answer various questions about your
environment. The first screen, once ready, will look like:

    Welcome to the OpenShift Enterprise 3 installation.
    
    Please confirm that following prerequisites have been met:
    
    * All systems where OpenShift will be installed are running Red Hat Enterprise
      Linux 7.
    * All systems are properly subscribed to the required OpenShift Enterprise 3
      repositories.
    * All systems have run docker-storage-setup (part of the Red Hat docker RPM).
    * All systems have working DNS that resolves not only from the perspective of
      the installer but also from within the cluster.
    
    When the process completes you will have a default configuration for Masters
    and Nodes.  For ongoing environment maintenance it's recommended that the
    official Ansible playbooks be used.
    
    For more information on installation prerequisites please see:
    https://docs.openshift.com/enterprise/latest/admin_guide/install/prerequisites.html
    
    Are you ready to continue?  y/Y to confirm, or n/N to abort [n]: 

Type `y` and hit enter to continue.

## Define installation user
The installer supports operation as non-root, but, for this training, we will
use root. We have already distributed our ssh keys as root. You will see a
prompt like:

    This installation process will involve connecting to remote hosts via ssh.  Any
    account may be used however if a non-root account is used it must have
    passwordless sudo access.
    
    User for ssh access [root]: 

Hit enter to conintue.

## Master Configuration
The next step is to configure master(s). After pressing a key to continue, the
default system editor will open. Be sure to specify our lone master:

    ose3-master.example.com

Save and exit the editor. You will be asked to confirm:

    1) ose3-master.example.com
    Please confirm the following masters.  y/Y to confirm, or n/N to edit [n]: 

Type `y` and hit enter to coninue.

## Node Configuration
The next step is to configure node(s). After pressing a key to continue, the
default system editor will open. You will notice that your master is already
present. **Do not delete it**. The master **must** be configured as a node
presently, because this is how it is able to participate on / access the SDN.
The master needs to be able to access some of the deployed application instances
(pods).

Be sure to enter all nodes:

    ose3-node1.example.com
    ose3-node2.example.com

Save and exit the editor. You will be asked to confirm:

    1) ose3-master.example.com
    2) ose3-node1.example.com
    3) ose3-node2.example.com
    Please confirm the following nodes.  y/Y to confirm, or n/N to edit [n]:

Type `y` and hit enter to continue.

## General Confirmation
The installer will now show you an overview of the installation details. You
should see something like the following:

    ose3-node2.example.com,192.168.133.4,192.168.133.4,ose3-node2.example.com,ose3-node2.example.com
    ose3-node1.example.com,192.168.133.3,192.168.133.3,ose3-node1.example.com,ose3-node1.example.com
    ose3-master.example.com,192.168.133.2,192.168.133.2,ose3-master.example.com,ose3-master.example.com
    
    # Everything after this line is ignored.
    
    Format:
    
    installation host,IP,public IP,hostname,public hostname
    
    Notes:
     * The installation host is the hostname from the installer's perspective.
     * The IP of the host should be the internal IP of the instance.
     * The public IP should be the externally accessible IP associated with the instance
     * The hostname should resolve to the internal IP from the instances
       themselves.
     * The public hostname should resolve to the external ip from hosts outside of
       the cloud.

If you are installing in a cloud-like environment (AWS, OpenStack, etc), please
take special note of the *Notes* section, as it contains very important details
about how to change the final configuration to handle public vs private
resources and etc.

When you are satisfied, save and exit the editor.

## Finish the Installation
You will now see something like the following:

    Ready to run installation process.
    
    If changes are needed to the values recorded by the installer please update /root/.config/openshift/installer.cfg.yml.
    
    Proceed? y/Y to confirm, or n/N to exit [y]: 

Type `y` and hit enter to finish the installation. You will then begin to see
the installer do its work. At the end of the installation process, you should
see something like the following:

    PLAY RECAP ******************************************************************** 
    localhost                  : ok=9    changed=0    unreachable=0    failed=0   
    ose3-master.example.com    : ok=144  changed=36   unreachable=0    failed=0   
    ose3-node1.example.com     : ok=43   changed=13   unreachable=0    failed=0   
    ose3-node2.example.com     : ok=43   changed=13   unreachable=0    failed=0   

    
    The installation was successful!
    
    If this is your first time installing please take a look at the Administrator
    Guide for advanced options related to routing, storage, authentication and much
    more:
    
    http://docs.openshift.com/enterprise/latest/admin_guide/overview.html

Press any key to continue and exit the installer. You now have a working
OpenShift Enterprise environment!

## Copy the CA certificate
The `/etc/openshift/master` folder is not group or world readable. This is good
because the keyfiles are in there, and "random" users should not have access to
them.

However, the self-signed CA certificate that the installer generated needs to be
accessible to users on the system. So, copy it to somewhere accessible:

    /bin/cp /etc/openshift/master/ca.crt /etc/openshift

## Add Cloud Domain
If you want default routes (we'll talk about these later) to automatically get
the right domain (the one you configured earlier with your wildcard DNS), then
you should edit `/etc/openshift/master/master-config.yaml` and edit the
following:

    routingConfig:
      subdomain: cloudapps.example.com

Or modify it appropriately for your domain.

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

    https://docs.openshift.com/enterprise/3.0/admin_guide/scheduler.html

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
      "predicates": [
        {"name": "MatchNodeSelector"},
        {"name": "PodFitsResources"},
        {"name": "PodFitsPorts"},
        {"name": "NoDiskConflict"},
        {"name": "Region", "argument": {"serviceAffinity" : {"labels" : ["region"]}}}
      ],"priorities": [
        {"name": "LeastRequestedPriority", "weight": 1},
        {"name": "ServiceSpreadingPriority", "weight": 1},
        {"name": "Zone", "weight" : 2, "argument": {"serviceAntiAffinity" : {"label": "zone"}}}
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
then only Node 2 and Node 3 would be considered.

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

    oc get nodes

    NAME                      LABELS                                                                     STATUS
    ose3-master.example.com   kubernetes.io/hostname=ose3-master.example.com,region=infra,zone=default   Ready,SchedulingDisabled
    ose3-node1.example.com    kubernetes.io/hostname=ose3-node1.example.com,region=primary,zone=east     Ready
    ose3-node2.example.com    kubernetes.io/hostname=ose3-node2.example.com,region=primary,zone=west     Ready

At this point we have a running OpenShift environment across three hosts, with
one master and three nodes, divided up into two regions -- "*infra*structure"
and "primary". *BUT* the master is currently tagged as "SchedulingDisabled". The
installer will, by default, not configure the master's node to receive workload
(SchedulingDisabled).

## Edit Default NodeSelector
We want our apps to land in the primary region, and not in the infra region. We
can do this by setting a default `nodeSelector` for our OpenShift environment.
Edit the `/etc/openshift/master/master-config.yaml` again, and make the
following change:

    projectConfig:
      defaultNodeSelector: "region=primary"

Once complete, restart your master. This will make both our default
`nodeSelector` and routing changes take effect:

    systemctl restart openshift-master

## Make Master Schedulable
We can use the `oc edit` command to make the master schedulable (allow it to
receive workloads). Be sure to change the name of the node to match your
environment:

    oc edit node ose3-master.example.com

You will see a bunch of YAML come up in your default editor. Make sure that you
**delete** the following line:

      unschedulable: true

Make sure that you do not change any indentation/spacing on any of the other
lines. Save and exit your editor, and then run the following:

    oc get node

You should see that now your master is set to receive workloads:

    NAME                      LABELS                                                                     STATUS
    ose3-master.example.com   kubernetes.io/hostname=ose3-master.example.com,region=infra,zone=default   Ready
    ose3-node1.example.com    kubernetes.io/hostname=ose3-node1.example.com,region=primary,zone=east     Ready
    ose3-node2.example.com    kubernetes.io/hostname=ose3-node2.example.com,region=primary,zone=west     Ready

## Tweak Default Project
The *default* project/namespace is a special one where we will put some of our
infrastructure-related resources. This project does not have a `nodeSelector` by
default. Since we have configured a default `nodeSelector`, and it is not the
*infra* region, we need to make a tweak so that things that go in the *infra*
region.

Execute the following:

    oc edit namespace default

In the annotations list, add this line:

    openshift.io/node-selector: region=infra

Save and exit the editor. Remember, indentation matters -- this entry should be
at the same indentation level as the rest of the `openshift.io` items.

From here we will start to deploy "applications" and other resources into
OpenShift.

