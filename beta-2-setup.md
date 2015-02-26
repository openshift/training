# OpenShift Beta 2 Setup Information
# WIP - NOT COMPLETE
## Use a Terminal Window Manager
We **strongly** recommend that you use some kind of terminal window manager
(Screen, Tmux).

## Assumptions
In most cases you will see references to "example.com" and other FQDNs related
to it. If you choose not to use "example.com" in your configuration, that is
fine, but remember that you will have to adjust files and actions accordingly.

## Setting Up the Environment
### DNS
You will need to have a wildcard for a DNS zone resolve, ultimately, to the IP
address of the OpenShift router. The way we start the various services, the
router will always end up on the OpenShift server that is running the master. Go
ahead and create a wildcard DNS entry for "cloudapps" (or something similar),
with a low TTL, that points to the public IP address of your master.

For example:

    *.cloudapps.example.com. 300 IN  A 192.168.133.2

In almost all cases, when referencing VMs you must use hostnames and the
hostnames that you use must match the output of `hostname -f` on each of your
nodes. By extension, you must at least have all hostname/ip mappings in
/etc/hosts files or forward DNS should work.

It is possible to use dnsmasq inside of your beta environment to handle these
duties. See the [appendix on
dnsmasq](#appendix---dnsmasq-setup) if you can't easily manipulate your existing
DNS environment.

### Git
You will either need internet access or read and write access to an internal
http-based git server where you will duplicate the public code repositories used
in the labs.

### Preparing Each VM

Each of the virtual machines should have 4+ GB of memory, 10+ GB of disk space,
and the following configuration:

* RHEL 7.1 Beta (Note: beta kernel is required for openvswitch)
* "Minimal" installation option
* NetworkManager **disabled**
* Attach the *OpenShift Enterprise High Touch Beta* subscription with subscription-manager
* Then configure yum as follows:

        subscription-manager repos --disable="*"
        subscription-manager repos \
        --enable="rhel-7-server-beta-rpms" \
        --enable="rhel-7-server-extras-rpms" \
        --enable="rhel-7-server-optional-beta-rpms" \
        --enable="rhel-server-7-ose-beta-rpms"

**TODO: need ansible/epel repo**

Once you have prepared your VMs, you can do the following on **each** VM:

1. Install deltarpm to make package updates a little faster:

        yum -y install deltarpm

1. Remove NetworkManager:

        yum -y remove NetworkManager*

1. Install missing packages:

        yum install wget vim-enhanced net-tools bind-utils tmux git

1. Update:

        yum -y update

### Grab Docker Images (Optional, Recommended)
**If you want** to pre-fetch Docker images to make the first few things in your
environment happen **faster**, you'll need to first install and start Docker:

    yum -y install docker
    systemctl start docker

On all of your systems, grab the following docker images:

    docker pull registry.access.redhat.com/openshift3_beta/ose-haproxy-router:v0.3.2
    docker pull registry.access.redhat.com/openshift3_beta/ose-deployer:v0.3.2
    docker pull registry.access.redhat.com/openshift3_beta/ose-sti-builder:v0.3.2
    docker pull registry.access.redhat.com/openshift3_beta/ose-docker-builder:v0.3.2
    docker pull registry.access.redhat.com/openshift3_beta/ose-pod:v0.3.2
    docker pull registry.access.redhat.com/openshift3_beta/ose-docker-registry:v0.3.2

It may be advisable to pull the following Docker images as well, since they are
used during the various labs:

    docker pull openshift/ruby-20-centos7
    docker pull mysql
    docker pull openshift/hello-openshift

### Clone the Training Repository
On your master, it makes sense to clone the training git repository:

    cd
    git clone https://github.com/openshift/training.git
    cd ~/training/beta2

### REMINDER
Almost all of the files for this training are in the training folder you just
cloned.

### Ansible-based Installer
The installer uses Ansible. Eventually there will be an interactive text-based
CLI installer that leverages Ansible under the covers. For now, we have to
incant Ansible manually.

#### Install Ansible
Ansible currently comes from the EPEL repository.

Install EPEL:

    yum install \
    http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm

Disable EPEL so that it is not accidentally used later:

    sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo

Install the packages for Ansible:

    yum --enablerepo=epel install ansible util-linux

#### Generate SSH Keys
Because of the way Ansible works, SSH key distribution is required. First,
generate an SSH key on your master, where we will run Ansible:

    ssh-keygen

Do *not* use a password.

#### Distribute SSH Keys
An easy way to distribute your SSH keys is by using a `bash` loop:

    for host in ose3-master.example.com ose3-node1.example.com \
    ose3-node2.example.com; do ssh-copy-id -i ~/.ssh/id_rsa.pub \
    $host; done

#### Clone the Ansible Repository
The configuration files for the Ansible installer are currently available on
Github. Clone the repository:

    cd
    git clone https://github.com/detiber/openshift-ansible.git
    cd ~/openshift-ansible
    git checkout enterprise2

#### Configure Ansible
Move the staged Ansible configuration files to `/etc/ansible`:

    mv -f ~/training/beta2/ansible/* /etc/ansible

#### Run the Ansible Installer
Now we can simply run the Ansible installer:

    ansible-playbook playbooks/byo/config.yml

#### Cleanup
When the Ansible installer is finished, your master will be completely installed
and configured. However, because of the way the installer adds the node running
on master, the `openshift-sdn-master` service will have failed to start, which
prevents `openshift-sdn-node` from starting, which, in turn, prevents
`openshift-node` from starting.

Simply restart `openshift-sdn-master` and you should be ready to go:

    systemctl restart openshift-sdn-master

Ansible modified our profile, so go ahead and source it:

        source ~/.bash_profile

## Starting the OpenShift Services
### Running a Master
#### The Master Service
First, we must edit the `/etc/sysconfig/openshift-master` file. Edit the
`OPTIONS` to read:

    OPTIONS="--loglevel=4 --public-master=fqdn.of.master"

You may also want to `systemctl enable openshift-master` to ensure the service
automatically starts on the next boot.

#### The OpenShift Node
We are running a "node" service on our master. In other words, the OpenShift
Master will both orchestrate containers and run containers, too.

Edit the `/etc/sysconfig/openshift-node` file and edit the `OPTIONS`:

    OPTIONS="--loglevel=4"
 
Do **not** start the openshift-node service yet. We must configure and start the
openshift-sdn-node first in order to set up the proper bridges, and the
openshift-sdn-node service will automatically start the openshift-node service
for us.

#### Setting Up the SDN
Once your master is started, we need to start the SDN (which uses Open vSwitch)
to begin creating our network overlay. The SDN master coordinates all of the SDN
activities. The SDN node actually manipulates the local docker and network
configuration. Since our OpenShift master is also a node, we will also run an
SDN master and node.

First, edit the
`/etc/sysconfig/openshift-sdn-master` file and edit the `OPTIONS` to read:

    OPTIONS="-v=4"

You can ignore the `DOCKER_OPTIONS`.

You may want to enable the `openshift-sdn-master` service.

Then, edit the `/etc/sysconfig/openshift-sdn-node` file:

    MASTER_URL="http://fqdn.of.master:4001"
    
    MINION_IP="ip.address.of.node.public.interface"
    
    OPTIONS="-v=4"

    DOCKER_OPTIONS='--insecure-registry=0.0.0.0/0 -b=lbr0 --mtu=1450 --selinux-enabled'

You may also want to enable the `openshift-sdn-node` service.

Remember, starting the sdn-node service will automatically start the openshift-node
service.

We will start our testing and operations with only one OpenShift "node" -- the
master. Later, we will add the other two nodes.

### Start All Services
Now that all of the services are configured, we can start them all in one fell
swoop:

    systemctl start openshift-master; systemctl start openshift-sdn-master;\
    systemctl start openshift-sdn-node;

### Watching Logs
RHEL 7 uses `systemd` and `journal`. As such, looking at logs is not a matter of
`/var/log/messages` any longer. You will need to use `journalctl`.

Since we are running all of the components in higher loglevels, it is suggested
that you use your terminal emulator to set up windows for each process. If you
are familiar with the Ruby Gem, `tmuxinator`, there is a config file in the
training repository. Otherwise, you should run each of the following in its own
window:

    journalctl -f -u openshift-master
    journalctl -f -u openshift-node
    journalctl -f -u openshift-sdn-master
    journalctl -f -u openshift-sdn-node

**Note: You will want to do this on the other nodes as they are added, but you
will not need the `master`-related services. These instructions will not appear
again.**

### Installing the Router
Networking in OpenShift v3 is quite complex. Suffice it to say that, while it is
easy to get a complete "multi-tier" "application" deployed, reaching it from
anywhere outside of the OpenShift environment is not possible without something
extra. This extra thing is the routing layer. The router is the ingress point
for all traffic destined for OpenShift v3 services. It currently supports only
HTTP(S) traffic.

As with most things in OpenShift v3, resources are defined via JSON. The
following JSON file could describe the router:

    {
        "kind": "Pod",
        "apiVersion": "v1beta1",
        "id": "ROUTER_ID",
        "desiredState": {
            "manifest": {
                "version": "v1beta2",
                "containers": [
                    {
                        "name": "origin-haproxy-router-ROUTER_ID",
                        "image": "registry.access.redhat.com/openshift3_beta/ose-haproxy-router:v0.3.1",
                        "ports": [
                            {
                                "containerPort": 80,
                                "hostPort": 80
                            },
                            {
                                "containerPort": 443,
                                "hostPort": 443
                            }
                        ],
                        "env": [
                            {
                                "name": "OPENSHIFT_MASTER",
                                "value": "${OPENSHIFT_MASTER}"
                            },
                            {
                                "name": "OPENSHIFT_CA_DATA",
                                "value": "${OPENSHIFT_CA_DATA}"
                            },
                            {
                                "name": "OPENSHIFT_INSECURE",
                                "value": "${OPENSHIFT_INSECURE}"
                            }
                        ],
                        "command": ["--loglevel=4"],
                        "imagePullPolicy": "PullIfNotPresent"
                    }
                ],
                "restartPolicy": {
                    "always": {}
                }
            }
        }
    }

OpenShift's "experimental" command set enables you to install the router
automatically. Try running it with no options and you should see the note that a
router is needed:

    openshift ex router
    F0223 11:50:57.985423    2610 router.go:143] Router "router" does not exist
    (no service). Pass --create to install.

So, go ahead and do what it says:

    openshift ex router --create
    F0223 11:51:19.350154    2617 router.go:148] You must specify a .kubeconfig
    file path containing credentials for connecting the router to the master
    with --credentials

Just about every form of communication with OpenShift components is secured by
SSL and uses various certificates and authentication methods. Just like how we
previously edited our `bash` configuration to point to our authentication
configuration, we need to tell the router installer about it, too. We also need
to specify the router image, since currently the experimental tooling points to
upstream/origin:

    openshift ex router --create --credentials=$KUBECONFIG \
    --images="registry.access.redhat.com/openshift3_beta/ose-haproxy-router:v0.3.2"

**Note: if you failed to correctly edit your `.bash_profile` and source it, this
will probably do something unexpected.**

If this works, you'll see some output:

    router
    router

Let's check the pods with the following:

    osc get pods | awk '{print $1"\t"$3"\t"$5"\t"$7"\n"}' | column -t

In the output, you should see the router pod status change to "running" after a
few moments (it may take up to a few minutes):

    POD                   CONTAINER(S)  HOST                                   STATUS
    deploy-router-1f99mb  deployment    ose3-master.example.com/192.168.133.2  Succeeded
    router-1-58u3j        router        ose3-master.example.com/192.168.133.2  Running

### Preparing for STI and Other Things
One of the really interesting things about OpenShift v3 is that it will build
Docker images from your source code and deploy and manage their lifecycle. In
order to do this, OpenShift can host its own Docker registry in
order to pull images "locally". Let's take a moment to set that up.

`openshift ex` again comes to our rescue with a handy installer for the
registry:

    openshift ex registry --create --credentials=$KUBECONFIG \
    --images="registry.access.redhat.com/openshift3_beta/ose-docker-registry:v0.3.2"

You'll get output like:

    docker-registry
    docker-registry

You can use `osc get pods`, `osc get services`, and `osc get deploymentconfig`
to see what happened.

Ultimately, you will have a Docker registry that is being hosted by OpenShift
and that is running on one of your nodes.

To quickly test your Docker registry, you can do the following:

    curl `osc get services docker-registry -o template --template="{{ .portalIP}}:{{ .port }}"`

And you should see:

    "docker-registry server (dev) (v0.9.0)"

**Note: if you get "connection reset by peer" you may have to wait a few more
moments after the pod is running for the service proxy to update the endpoints
necessary to fulfill your request**

## Projects and the Web Console
### A Project for Everything
V3 has a concept of "projects" to contain a number of different services and
their pods, builds and etc. They are somewhat similar to "namespaces" in
OpenShift v2. We'll explore what this means in more details throughout the rest
of the labs. Let's create a project for our first application. 

We also need to understand a little bit about users and administration. The
default configuration for CLI operations currently is to be the `master-admin`
user, which is allowed to create projects. We can use the "experimental"
OpenShift command to create a project, and assign an administrative user to it:

    openshift ex new-project demo --display-name="OpenShift 3 Demo" \
    --description="This is the first demo project with OpenShift v3" \
    --admin=anypassword:joe

This command creates a project:
* with the id `demo`
* with a display name
* with a description 
* with an administrative user `joe` who can login with any password

Future use of command line statements will have to reference this project in
order for things to land in the right place.

The "anypassword" authentication mechanism is not intended for production use,
but it will work just fine for testing. On your first login to the web console,
any password can be used. Future access to the console from the same browser
(session) will require the same password (stored via cookie). 

Unfortunately, anyone that goes to the console will be able to also login, since
the password is not stored in any data store inside OpenShift. Again, this is
fine for non-production use, and perfect for our demo

Now that you have a project created, it's time to look at the web console, which
has been completely redesigned for V3.

### Web Console
Open your browser and visit the following URL:

    https://fqdn.of.master:8444

You will first need to accept the self-signed SSL certificate. You will then be
asked for a username and a password. Remembering that we created a user
previously, `joe`, go ahead and enter that and use `any` as the password (it
doesn't matter what password you use).

Once you are in, click the *OpenShift 3 Demo* project. There really isn't anything of
interest at the moment, because we haven't put anything into our project. While
we created the router, it's not part of this project (it is core infrastructure),
so we do not see it here. If you were to look in the *default* project, you
would see things like the router and other core infrastructure components.

**Note: You will see the other projects until
https://github.com/openshift/origin/pull/1074**

## Your First Application
At this point you essentially have a sufficiently-functional V3 OpenShift
environment. It is now time to create the classic "Hello World" application
using some sample code.  But, first, some housekeeping.

### "Resources"
There are a number of different resource types in OpenShift 3, and, essentially,
going through the motions of creating/destroying apps, scaling, building and
etc. all ends up manipulating OpenShift and Kubernetes resources under the
covers. Resources can have quotas enforced against them, so let's take a moment
to look at some example JSON for project resource quota might look like:

    {
      "id": "demo-quota",
      "kind": "ResourceQuota",
      "apiVersion": "v1beta1",
      "spec": {
        "hard": {
          "memory": "512000000",
          "cpu": "3",
          "pods": "3",
          "services": "3",
          "replicationcontrollers":"4",
          "resourcequotas":"1",
        },
      }
    }

The above quota (simply called *quota*) defines limits for several resources. In
other words, within a project, users cannot "do stuff" that will cause these
resource limits to be exceeded.

The memory figure is in bytes, and it and CPU are somewhat self explanatory. We
will get into a description of what pods, services and replication controllers
are over the next few labs. Lastly, we can ignore "resourcequotas", as it is a
bit of a trick so that Kubernetes doesn't accidentally try to apply two quotas
to the same namespace.

**Note: CPU is not really all that self-explanatory. But we'll explain it
eventually**

### Applying Quota to Projects
At this point we have created our "demo" project, so let's apply the quota above
to it. 

    osc create -f demo-quota.json --namespace=demo

If you want to see that it was created:

    osc get -n demo quota
    NAME
    demo-quota

And if you want to verify limits or examine usage:

    osc describe -n demo quota demo-quota
    Name:                   demo-quota
    Resource                Used    Hard
    --------                ----    ----
    cpu                     0m      3
    memory                  0       500000Ki
    pods                    0       3
    replicationcontrollers  0       4
    resourcequotas          1       1
    services                0       3

If you go back into the web console and click into the "OpenShift 3 Demo"
project, and click on the *Settings* tab, you'll see that the quota information
is displayed.

### Set the namespace (project) you are using
The concept of a project in OpenShift v3 provides a scope for creating
resources. The corresponding concept in Kubernetes is a *namespace*.  Thus far
we have created a router and a Docker registry, both of which went into the
`default` namespace.

In order to start creating things inside of our "Demo" project, we will need to
configure the CLI to use our new project:

     openshift ex config set-context demo --cluster=master --user=joe --namespace=demo
     openshift ex config use-context demo

This is a bit cryptic, and client configuration is experimental at this
point, but here is a brief explanation:

1. `openshift ex` provides some experimental subcommands that could go
   away at any time (probably with the next beta). One of these subcommands
   is `config` which manipulates your $KUBECONFIG file (we set the env var
   above; otherwise it would be `~/.kubeconfig`).
2. The "context" referred to by `set-context` is a section in the
   $KUBECONFIG that encapsulates the OpenShift server, the account to access
   it with, and the current namespace (if any). A single user might very
   well have multiple namespaces, accounts, and servers to interact with,
   so it can be helpful to define a context for each combination. Here we
   are defining a new context `demo` (to be distinguished from the initial
   context under which we created the router, `master-admin` with namespace
   `default`). In the new context, the current namespace is `demo`
   (the project we just created).
3. Having created the new `demo` context, we set that context to be used
   by default. (It could be overridden in subsequent commands with the `--context` flag.)

Any `osc create` or `osc get` or `osc delete` (etc.) will now operate only with
entities in the `betaproject` namespace.

**Note:**
Creating nodes or projects currently ignores the current/set context.

### The Hello World Definition JSON
In the beta2 training folder, you can see the contents of our pod definition by using
`cat`:

    cat hello-pod.json 
    {
      "id": "hello-openshift",
      "kind": "Pod",
      "apiVersion":"v1beta2",
      "labels": {
        "name": "hello-openshift"
      },
      "desiredState": {
        "manifest": {
          "version": "v1beta1",
          "id": "hello-openshift",
          "containers": [{
            "name": "hello-openshift",
            "image": "openshift/hello-openshift",
            "ports": [{
              "hostPort": 6061,
              "containerPort": 8080
            }]
          }]
        }
      },
    }

In the simplest sense, a *pod* is an application or an instance of something. If
you are familiar with OpenShift V2 terminology, it is similar to a *gear*.
Reality is more complex, and we will learn more about the terms as we explore
OpenShift further.

### Run the Pod
To create the pod from our JSON file, execute the following:

    osc create -f hello-pod.json

Remember, we already set our context earlier using `ex config`, so this pod will
land in our `betaproject` namespace. The command should display the ID of the pod:

    hello-openshift

Issue a `get pods` to see that it was, in fact, defined, and to check its
status:

    osc get pods
    POD             IP       CONTAINER(S)                     IMAGE(S)                           HOST                                  LABELS                 STATUS
    hello-openshift 10.1.0.4 hello-openshift                  openshift/hello-openshift          ose3-master.example.com/192.168.133.2 name=hello-openshift   Pending

You should note that we no longer see the router pod in the output. This is
because the router is part of the `default` namespace, used for core
infrastructure components.

Look at the list of Docker containers with `docker ps` to see the bound ports.
We should see an `openshift3_beta/ose-pod` container bound to 6061 on the host and
bound to 8080 on the container, along with several other `ose-pod` containers.

The `openshift3_beta/ose-pod` container exists because of the way network
namespacing works in Kubernetes. For the sake of simplicity, think of the
container as nothing more than a way for the host OS to get an interface created
for the corresponding pod to be able to receive traffic. Deeper understanding of
networking in OpenShift is outside the scope of this material.

To verify that the app is working, you can issue a curl to the app's port:

    curl http://localhost:6061
    Hello OpenShift!

Hooray!

### Looking at the Pod in the Web Console
Go to the web console and go to the *Overview* tab for the *OpenShift 3 Demo*
project. You'll see some interesting things:

* You'll see the pod is running (eventually)
* You'll see the SDN IP address that the pod is associated with (10....)
* You'll see the internal port that the pod's container's "application"/process
    is using
* You'll see that there's no service yet - we'll get to services soon.

### Quota Usage
If you click on the *Settings* tab, you'll see our pod usage has increased to 1.

### Delete the Pod
Go ahead and delete this pod so that you don't get confused in later examples:

    osc delete pod hello-openshift

Take a moment to think about what this pod exercise really did -- it referenced
an arbitrary Docker image, made sure to fetch it (if it wasn't present), and
then ran it. This could have just as easily been an application from an ISV
available in a registry or something already written and built in-house.

This is really powerful. We will explore using "arbitrary" docker images later.

## Adding Nodes
It is extremely easy to add nodes to an existing OpenShift environment.

### Configuring a Node
Perform the following steps, in order, on both nodes.

#### Grab the SSL certificates
You should grab the SSL certificates and other information from your master. You
can do the following on your node:

    rsync -av root@fqdn.of.master:/var/lib/openshift/openshift.local.certificates \
    /var/lib/openshift/

#### The OpenShift Node
Edit the `/etc/sysconfig/openshift-node` file and edit the `OPTIONS` to read:

    OPTIONS="--loglevel=4 --master=fqdn.of.master"

Do **not** start the openshift-node service. We will let openshift-sdn-node
handle that for us (like before).

#### The Node SDN
Edit the `/etc/sysconfig/openshift-sdn-node` file:

    MASTER_URL="http://fqdn.of.master:4001"
    
    MINION_IP="ip.address.of.node.public.interface"
    
    OPTIONS="-v=4"

    DOCKER_OPTIONS='--insecure-registry=0.0.0.0/0 -b=lbr0 --mtu=1450 --selinux-enabled'

And start the SDN node:

    systemctl start openshift-sdn-node

You may also want to enable the service.

**Note:** 
Since we are starting the sdn-node before we have actually created the entry for
our node with the OpenShift master, if you check status on openshift-sdn-node
(`journalctl -u openshift-sdn-node`) you will see that the service blocks with
an error (and does not start openshift-node) until the node has been defined in
the next section.

### Adding the Node Via OpenShift's API
The following JSON describes a node:

    cat node.json
    {
      "metadata":{
        "name":"add-two-nodes"
      },
      "kind":"Config",
      "apiVersion":"v1beta1",
      "creationTimestamp":"2014-09-18T18:28:38-04:00",
      "items":[
        {
          "id": "ose3-node1.example.com",
          "kind": "Node",
          "apiVersion": "v1beta1",
          "resources": {
            "capacity": {
              "cpu": 1,
              "memory": 80% of freemem (bytes)
            },
          },
        },
        {
          "id": "ose3-node2.example.com",
          "kind": "Node",
          "apiVersion": "v1beta1",
          "resources": {
            "capacity": {
              "cpu": 1,
              "memory": 80% of freemem (bytes)
            },
          },
        }
      ]
    }

You will need to edit the `node.json` file and replace the memory line with the
correct value for your system. For example, given the output of `free`:

    free -b
                  total        used        free      shared  buff/cache   available
    Mem:     1041629184   284721152   321036288     7761920   435871744   577949696
    Swap:    1073737728           0  1073737728

You might set your `node.json` to have:

    "memory": 256000000

Once edited, add the nodes via the API:

    osc create -f node.json

You should now have two running nodes in addition to your original "master"
node (it may take a minute for all to reach "Ready" status):

    osc get nodes
    NAME                      LABELS              STATUS
    ose3-master.example.com   <none>              Ready
    ose3-node1.example.com    <none>              Ready
    ose3-node2.example.com    <none>              Ready

Note that nodes are not scoped by namespace.

Now that we have a larger OpenShift environment, let's examine more complicated
application paradigms.

## Services
From the [Kubernetes
documentation](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/docs/services.md):

    A Kubernetes service is an abstraction which defines a logical set of pods and a
    policy by which to access them - sometimes called a micro-service. The goal of
    services is to provide a bridge for non-Kubernetes-native applications to access
    backends without the need to write code that is specific to Kubernetes. A
    service offers clients an IP and port pair which, when accessed, redirects to
    the appropriate backends. The set of pods targetted is determined by a label
    selector.

If you think back to the simple pod we created earlier, there was a "label":

      "labels": {
        "name": "hello-openshift"
      },

Now, let's look at a *service* definition:

    {
      "id": "hello-openshift",
      "kind": "Service",
      "apiVersion": "v1beta1",
      "port": 27017,
      "selector": {
        "name": "hello-openshift"
      }
    }

The *service* has a `selector` element. In this case, it is a key:value pair of
`name:hello-openshift`. If you look at the output of `osc get pods` on your
master, you see that the `hello-openshift` pod has a label:

    name=hello-openshift

The definition of the *service* tells Kubernetes that any pods with the label
"name=hello-openshift" are associated, and should have traffic distributed
amongst them. In other words, the service itself is the "connection to the
network", so to speak, or the input point to reach all of the pods. Generally
speaking, pod containers should not bind directly to ports on the host. We'll
see more about this later.

But, to really be useful, we want to make our application accessible via a FQDN,
and that is where the router comes in.

## Routing
Routes allow FQDN-destined traffic to ultimately reach the Kubernetes service,
and then the pods/containers.

In a simplification of the process, the `openshift3_beta/ose-haproxy-router`
container is a pre-configured instance of HAProxy as well as some of the
OpenShift framework. The OpenShift instance running in this container watches a
routes resource on the OpenShift master.

Here is an example route JSON definition:

    {
      "id": "hello-route",
      "kind": "Route",
      "apiVersion": "v1beta1",
      "host": "hello-openshift.cloudapps.example.com",
      "serviceName": "hello-openshift"
    }

When the `osc` command is used to create this route, a new instance of a route
*resource* is created inside OpenShift. The HAProxy/Router is watching for
changes in route resources. When a new route is detected, an HAProxy pool is
created.

This HAProxy pool contains all pods that are in a service. Which service? The
service that corresponds to the `serviceName` directive.

Let's take a look at an entire Pod-Service-Route definition template and put all
the pieces together.

## The Complete Pod-Service-Route
### Creating the Definition
The following is a complete definition for a pod with a corresponding service
with a corresponding route:

    {
      "metadata":{
        "name":"hello-complete-definition"
      },
      "kind":"Config",
      "apiVersion":"v1beta1",
      "creationTimestamp":"2014-09-18T18:28:38-04:00",
      "items":[
        {
          "id": "hello-openshift-pod",
          "kind": "Pod",
          "apiVersion":"v1beta2",
          "labels": {
            "name": "hello-openshift-label"
          },
          "desiredState": {
            "manifest": {
              "version": "v1beta1",
              "id": "hello-openshift-manifest-id",
              "containers": [{
                "name": "hello-openshift-container",
                "image": "openshift/hello-openshift",
                "ports": [{
                  "containerPort": 8080
                }]
              }]
            }
          },
        },
        {
          "kind": "Service",
          "apiVersion": "v1beta1",
          "id": "hello-openshift-service",
          "port": 27017,
          "selector": {
            "name": "hello-openshift-label"
          }
        },
        {
          "kind": "Route",
          "apiVersion": "v1beta1",
          "metadata": {
              "name": "hello-openshift-route"
          },
          "id": "hello-openshift-route",
          "host": "hello-openshift.cloudapps.example.com",
          "serviceName": "hello-openshift-service"
        }
      ]
    }

In the JSON above:

* There is a pod whose containers have the label `name=hello-openshift-label`
* There is a service:
  * with the id `hello-openshift-service`
  * with the selector `name=hello-openshift-label`
* There is a route:
  * with the FQDN `hello-openshift.cloudapps.example.com`
  * with the `serviceName` directive `hello-openshift-service`

If we work from the route down to the pod:

* The route for `hello-openshift.cloudapps.example.com` has an HAProxy pool
* The pool is for any pods in the service whose ID is `hello-openshift-service`,
    via the `serviceName` directive of the route.
* The service `hello-openshift-service` includes every pod who has a label
    `name=hello-openshift-label`
* There is a single pod with a single container that has the label
    `name=hello-openshift-label`

Edit `test-complete.json` and change the `host` stanza for the route to have
the correct domain, matching the DNS configuration for your environment. Once
this is done, go ahead and use `osc` to apply it. You should see something like
the following:

        osc create -f test-complete.json
        hello-openshift-pod
        hello-openshift-service
        hello-openshift-route

You can verify this with other `osc` commands:

    osc get pods
    ...
    hello-openshift-pod/10.X.X.X ...

    osc get services
    ...
    hello-openshift-service ...

    osc get routes
    ...
    cd0dba9a-a1a5-11e4-bf82-525400b33d1d hello-openshift.cloudapps.example.com ...

### Verifying the Service
Services are not externally accessible without a route being defined, because
they always listen on "local" IP addresses (eg: 172.x.x.x). However, if you have
access to the OpenShift environment, you can still test a service.

    osc get services
    NAME                      LABELS              SELECTOR                     IP                  PORT
    hello-openshift-service   <none>              name=hello-openshift-label   172.30.17.230       27017

We can see that the service has been defined based on the JSON we used earlier.
If the output of `osc get pods` shows that our pod is running, we can try to
access the service:

    curl http://172.30.17.230:27017
    Hello OpenShift!

This is a good sign! It means that, if the router is working, we should be able
to access the service via the route.

### Verifying the Routing
Verifying the routing is a little complicated, but not terribly so. Since we
created the router when we only had the master running, we know that's where its
Docker container is.

We ultimately want the PID of the container running the router so that we can go
"inside" it. On the master system, issue the following to get the PID of the
router:

    docker inspect --format {{.State.Pid}}   \
      `docker ps | grep haproxy-router | awk '{print $1}'`
    2239

The output will be a PID -- in this case, the PID is `2239`. We can use
`nsenter` to jump inside that container:

    nsenter -m -u -n -i -p -t 2239
    [root@mainrouter /]#

You are now in a bash session *inside* the container running the router.

Since we are using HAProxy as the router, we can cat the `routes.json` file:

    cat /var/lib/containers/router/routes.json

If you see some content that looks like:

    "hello-openshift-service": {
      "Name": "hello-openshift-service",
      "EndpointTable": {
        "10.1.0.4:8080": {
          "ID": "10.1.0.4:8080",
          "IP": "10.1.0.4",
          "Port": "8080"
        }
      },
      "ServiceAliasConfigs": {
        "hello-openshift.cloudapps.example.com-": {
          "Host": "hello-openshift.cloudapps.example.com",
          "Path": "",
          "TLSTermination": "",
          "Certificates": null
        }
      }
    },

You know that "it" worked -- the router watcher detected the creation of the
route in OpenShift and added the corresponding configuration to HAProxy.

Go ahead and `exit` from the container, and then curl your fancy,
publicly-accessible OpenShift application!

    [root@mainrouter /]# exit
    logout
    # curl http://hello-openshift.cloudapps.example.com
    Hello OpenShift!

Hooray!

### The Web Console
Take a moment to look in the web console to see if you can find everything that
was just created.

And, while you're at it, you can verify that visiting your app with HTTPS will
also work (albeit with a self-signed certificate):

    https://hello-openshift.cloudapps.example.com

## STI - What Is It?
STI stands for *source-to-image* and is the process where OpenShift will take
your application source code and build a Docker image for it. In the real world,
you would need to have a code repository (where OpenShift can introspect an
appropriate Docker image to build and use to support the code) or a code
repository + a Dockerfile (so that OpenShift can pull or build the Docker image
for you).

### Create a New Project
We will create a new project to put our first STI example into. Grab the project
definition and create it:

    osc create -f ~/training/beta2/sinatraproject.json

At this point, if you click the OpenShift image on the web console you should be
returned to the project overview page where you will see the new project show
up. Go ahead and click the *Sinatra* project - you'll see why soon.

We can also apply the same quota we used before to this new project:

    osc create -n sinatraproject -f demo-quota.json

### Switch contexts
Let's update and use the `user` context for interacting with the new project you just created:

    openshift ex config set-context sinatra --cluster=master --user=joe \
    --namespace=sinatraproject
    openshift ex config use-context sinatra

**Note:**
If you ever get confused about what context you're using, or what contexts are
defined, you can look at `$KUBECONFIG`:

    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority: root.crt
        server: https://192.168.133.2:8443
      name: master
    contexts:
    - context:
        cluster: master
        user: admin
      name: master-admin
    - context:
        cluster: master
        namespace: sinatraproject
        user: admin
      name: user
    current-context: user
    kind: Config
    preferences: {}
    users:
    - name: admin
      user:
        client-certificate: cert.crt
        client-key: key.key

Or, to quickly get your current context:

    grep current $KUBECONFIG
    current-context: user

### A Simple STI Build
We'll be using a pre-build/configured code repository. This repository is an
extremely simple "Hello World" type application that looks very much like our
previous example, except that it uses a Ruby/Sinatra application instead of a Go
application.

For this example, we will be using the following application's source code:

    https://github.com/openshift/simple-openshift-sinatra-sti

Let's clone the repository and then generate a config for OpenShift to create:

    cd
    openshift ex generate --name=sin \
    https://github.com/openshift/simple-openshift-sinatra-sti.git \
    | python -m json.tool > ~/simple-sinatra.json

** note: bug in length of build name **

`ex generate` is a tool that will examine a directory tree, a remote repo, or
other sources and attempt to generate an appropriate JSON configuration so that,
when created, OpenShift can build the resulting image to run. 

Go ahead and take a look at the JSON that was generated. You will see some
familiar items at this point, and some new ones, like `BuildConfig`,
`ImageRepository` and others.

    cat ~/simple-sinatra.json

Essentially, the STI process is as follows:

1. OpenShift sets up various components such that it can build source code into
a Docker image.

1. OpenShift will then (on command) build the Docker image with the source code.

1. OpenShift will then deploy the Docker image as a Pod with an associated
Service.

### Create the Build Process
Let's go ahead and get everything fired up:

    osc create -f ~/simple-sinatra.json

As soon as you execute this command, go back to the web console and see if you
can figure out what is different.

To learn a little more about what happened, run the following:

    for i in imagerepository buildconfig deploymentconfig service; do \
    echo $i; osc get $i; echo -e "\n\n"; done

Based on the JSON from `ex generate`, we have created:

* An ImageRepository entry
* A BuildConfig
* A DeploymentConfig
* A Service

If you run:

    osc get pods

You will see that there are currently no pods. That is because we have not
actually gone through a build yet. While OpenShift has the capability of
automatically triggering builds based on source control pushes (eg: Git(hub)
webhooks, etc), we will be triggering builds manually.

By the way, most of these things can (SHOULD!) also be verified in the web
console. If anything, it looks prettier!

To start our build, execute the following:

    osc start-build sin

You'll see some output to indicate the build:

    sin-fcae9c05-bd31-11e4-8e35-525400b33d1d

That's the UUID of our build. We can check on its status (it will switch to
"Running" in a few moments):

    osc get builds
    NAME                                       TYPE                STATUS  POD
    sin-fcae9c05-bd31-11e4-8e35-525400b33d1d   STI                 Pending build-sin-fcae9c05-bd31-11e4-8e35-525400b33d1d

Almost immediately, the web console would've updated the *Overview* tab for the
*Sinatra* project to say:

    A build of sin. A new deployment will be created automatically once the
    build completes.

Let's go ahead and start "tailing" the build log (substitute the proper UUID for
your environment):

    osc build-logs sin-fcae9c05-bd31-11e4-8e35-525400b33d1d

**Note: If the build isn't "Running" yet, or the sti-build container hasn't been
deployed yet, build-logs will give you an error**

### The Web Console Revisited
If you peeked at the web console while the build was running, you probably
noticed a lot of new information in the web console - the build status, the
deployment status, new pods, and more.

If you didn't, go to the web console now. The overview page should show that the
application is running and show the information about the service at the top:

    simple-openshift-sinatra - routing TCP traffic on 172.30.17.47:9292 to port 9292

### Examining the Build
If you go back to your console session where you examined the `build-logs`,
you'll see a number of things happened.

What were they?

### Testing the Application
Using the information you found in the web console, try to see if your service
is working:

    curl http://172.30.17.47:9292
    Hello, Sinatra!

So, from a simple code repository with a few lines of Ruby, we have successfully
built a Docker image and OpenShift has deployed it for us.

The last step will be to add a route to make it publicly accessible.

### Adding a Route to Our Application
When we used `ex generate`, the only thing that was not created was a route for
our application.

Remember that routes are associated with services, so, determine the id of your
services from the service output you looked at above. For example, it might be
`simple-openshift-sinatra`.

**Hint:** You will need to use `osc get services` to find it.

Edit `sinatra-route.json` it to incorporate the service name you determined.
Hint: you need to edit the `serviceName` field.

When you are done, create your route:

    osc create -f sinatra-route.json
    a8b8c72b-b07c-11e4-b390-525400b33d1d

Check to make sure it was created:

    osc get route
    NAME                HOST/PORT                             PATH                SERVICE             LABELS
    sinatra-route       hello-sinatra.cloudapps.example.com                       sin

And now, you should be able to verify everything is working right:

    curl http://hello-sinatra.cloudapps.example.com
    Hello, Sinatra!

If you want to be fancy, try it in your browser!

### Notes on Cleanup, Enforcement
Currently the STI process involves a pod that is created to build your code
(sti-build) as well as a pod that is used to deploy your code (ose-deployer).
Right now, OpenShift doesn't "clean up" after the build process. So, if you go
to the *Settings* tab for the *Sinatra* project, you'll see that you have hit
your pod quote (3). This issue is understood and will be fixed.

Since we are not doing anything else with the *Sinatra* project, we can ignore
these artifacts for now.

### A Fully-Integrated Application
The next example will involve a build of another application, but also a service
that has two pods -- a "front-end" web tier and a "back-end" database tier. This
application also makes use of auto-generated parameters and other neat features
of OpenShift. One thing of note is that this project already has the
wiring/plumbing between the front- and back-end components pre-defined as part
of its JSON. Adding resources "after the fact" will come in a later lab.

First we'll create a new project:

    osc create -f ~/training/beta2/integrated-project.json

We'll set our context to use the corresponding namespace:

    openshift ex config set-context int --cluster=master --user=joe \
    --namespace=integratedproject
    openshift ex config use-context int

#### A Quick Aside on Templates
From the [OpenShift
documentation](https://ci.openshift.redhat.com/openshift-docs-master-testing/latest/using_openshift/templates.html):

    A template describes a set of resources intended to be used together that
    can be customized and processed to produce a configuration. Each template
    can define a list of parameters that can be modified for consumption by
    containers.

As we mentioned previously, this template has some auto-generated parameters.
For example, take a look at the following JSON:

    "parameters": [
      {
        "name": "ADMIN_USERNAME",
        "description": "administrator username",
        "generate": "expression",
        "from": "admin[A-Z0-9]{3}"
      },

This portion of the template's JSON tells OpenShift to generate an expression
using a regex-like string that will be presnted as ADMIN_USERNAME.

Go ahead and do the following:

    osc process -f ~/training/beta2/integrated-build.json \
    | python -m json.tool

Take a moment to examine the JSON that is generated and see how the different
parameters are placed into the actual processable config. If you look closely,
you'll see that some of these items are passed into the "env" of the container
-- they're passed in as environment variables inside the Docker container.

If the application or container is built correctly, it's various processes will
use these environment variables. In this example, the front-end will use the
information about where the back-end is, as well as user and password
information that was generated.

### Creating the Integrated Application
Examine `integrated-build.json` to see how parameters and other things are
handled. Then go ahead and process it and create it:

    osc process -f ~/training/beta2/integrated-build.json | osc create -f -

The build configuration, in this case, is called `ruby-sample-build`. So, let's
go ahead and start the build and watch the logs:

    osc start-build ruby-sample-build
    277f6eac-b07d-11e4-b390-525400b33d1d

    osc build-logs 277f6eac-b07d-11e4-b390-525400b33d1d

Don't forget that the web console will show information about the build status,
although in much less detail. And, don't forget that if you are too quick on the
`build-logs` you will catch it before the build actually starts.

### Routing Our Integrated Application
Remember our experiments with routing from earlier? Well, our STI example
doesn't include a route definition in its template. So, we can create one:

    {
        "kind": "Route",
        "apiVersion": "v1beta1",
        "metadata": {
            "name": "integrated-route"
        },
        "id": "integrated-route",
        "host": "integrated.cloudapps.example.com",
        "serviceName": "frontend"
    }

Go ahead and edit `integrated-route.json` to have the appropriate domain, and
then create it:

    osc create -f ~/training/beta2/integrated-route.json

Now, in your browser, you should be able to visit the website and actually use
the application!

    http://integrated.cloudapps.example.com

**Note: HTTPS will *not* work for this example because the form submission was
written with HTTP links. Be sure to use HTTP. **

## Conclusion
This concludes the Beta 2 training. Look for more example applications to come!

# APPENDIX - Extra STI code examples
## Wildfly
A Wildfly-based JEE application example is here:

    https://github.com/bparees/javaee7-hol

If you have successfully built and deployed the "integrated" example above, you
can simply create a new project, change your context, and then:

    osc process \
    -f https://raw.githubusercontent.com/bparees/javaee7-hol/master/application-template-jeebuild.json \
    | osc create -f -

Once created, you can go through the same build process as before.

**Note: You should wait for the database/mysql pod to come up before starting
your build.**

**Note: You will want to create a route for this app so that you can access it
with your browser.**

**Note: If you needed to pre-pull the Docker images, you will want to fetch
`openshift/wildfly-8-centos` ahead of time. Also, if you were using sneakernet,
you should also include that image in the list in the appendix below.**

# APPENDIX - DNSMasq setup
In this training repository is a sample `dnsmasq.conf` file and a sample `hosts`
file. If you do not have the ability to manipulate DNS in your environment, or
just want a quick and dirty way to set up DNS, you can install dnsmasq on your
master:

    yum -y install dnsmasq

Replace `/etc/dnsmasq.conf` with the one from this repository, and replace
`/etc/hosts` with the `hosts` file from this repository.

Enable and start the dnsmasq service:

    systemctl enable dnsmasq; systemctl start dnsmasq

You will need to ensure the following, or fix the following:

* Your IP addresses match the entries in `/etc/hosts`
* Your hostnames for your machines match the entries in `/etc/hosts`
* Your `cloudapps` domain points to the correct ip in `dnsmasq.conf`
* Each of your systems has the same `/etc/hosts` file
* Your master and nodes `/etc/resolv.conf` points to the master IP address as
    the first nameserver
* The second nameserver in `/etc/resolv.conf` on master points to your corporate
    or upstream DNS resolver (eg: Google DNS @ 8.8.8.8)
* That you also open port 53 (UDP) to allow DNS queries to hit the master

Following this setup for dnsmasq will ensure that your wildcard domain works,
that your hosts in the `example.com` domain resolve, that any other DNS requests
resolve via your configured local/remote nameservers, and that DNS resolution
works inside of all of your containers. Don't forget to start and enable the
`dnsmasq` service.

### Verifying DNSMasq

You can query the local DNS on the master using `dig` (provided by the
`bind-utils` package) to make sure it returns the correct records:

    dig ose3-master.example.com
    
    ...
    ;; ANSWER SECTION:
    ose3-master.example.com. 0  IN  A 192.168.133.2
    ...
   
The returned IP should be the public interface's IP on the master. Repeat for
your nodes. To verify the wildcard entry, simply dig an arbitrary domain in the
wildcard space:

    dig foo.cloudapps.example.com

    ...
    ;; ANSWER SECTION:
    foo.cloudapps.example.com 0 IN A 192.168.133.2
    ...

# APPENDIX - Import/Export of Docker Images (Disconnected Use)
Docker supports import/save of Images via tarball. You can do something like the
following on your connected machine:

    docker pull registry.access.redhat.com/openshift3_beta/ose-haproxy-router
    docker pull registry.access.redhat.com/openshift3_beta/ose-deployer
    docker pull registry.access.redhat.com/openshift3_beta/ose-sti-builder
    docker pull registry.access.redhat.com/openshift3_beta/ose-docker-builder
    docker pull registry.access.redhat.com/openshift3_beta/ose-pod
    docker pull registry.access.redhat.com/openshift3_beta/ose-docker-registry
    docker pull openshift/ruby-20-centos7
    docker pull mysql
    docker pull openshift/hello-openshift

This will fetch all of the images. You can then save them to a tarball:

    docker save -o beta1-images.tar \
    registry.access.redhat.com/openshift3_beta/ose-haproxy-router \
    registry.access.redhat.com/openshift3_beta/ose-deployer \
    registry.access.redhat.com/openshift3_beta/ose-sti-builder \
    registry.access.redhat.com/openshift3_beta/ose-docker-builder \
    registry.access.redhat.com/openshift3_beta/ose-pod \
    registry.access.redhat.com/openshift3_beta/ose-docker-registry \
    openshift/ruby-20-centos7 \
    mysql \
    openshift/hello-openshift

**Note: On an SSD-equipped system this took ~2 min and uses 1.8GB of disk
space**

Sneakernet that tarball to your disconnected machines, and then simply load the
tarball:

    docker load -i beta1-images.tar

**Note: On an SSD-equipped system this took ~4 min**

# APPENDIX - Cleaning Up
Figuring out everything that you have deployed is a little bit of a bear right
now. The following command will show you just about everything you might need to
delete. Be sure to change your context across all the namespaces and the
master-admin to find everything:

    for resource in build buildconfig images imagerepository deploymentconfig \
    route replicationcontroller service pod; do echo -e "Resource: $resource"; \
    osc get $resource; echo -e "\n\n"; done

# APPENDIX - Pretty Output
If the output of `osc get pods` is a little too busy, you can use the following
to limit some of what it returns:

    osc get pods | awk '{print $1"\t"$3"\t"$5"\t"$7"\n"}' | column -t

# APPENDIX - Troubleshooting
* When using an "osc" command like "osc get pods" I see a "certificate signed by
  unknown authority error":

        F0212 16:15:52.195372   13995 create.go:79] Post
        https://ose3-master.example.net:8443/api/v1beta1/pods?namespace=default:
        x509: certificate signed by unknown authority
  
    Check the value of $KUBECONFIG:

        echo $kubeconfig

    If you don't see anything, you may have changed your `.bash_profile` but
    have not yet sourced it. Make sure that you followed the step of adding
    `$KUBECONFIG`'s export to your `.bash_profile` and then source it:

        source ~/.bash_profile
