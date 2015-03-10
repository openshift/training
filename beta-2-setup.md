# OpenShift Beta 2 Setup Information
# WIP - NOT COMPLETE

**Table of contents:**

* [Setting Up the Environment](#setting-up-the-environment)
* [Ansible-based Installer](#ansible-based-installer)
* [Watching Logs](#watching-logs)
* [Installing the Router](#installing-the-router)
* [Preparing for STI and Other Things](#preparing-for-sti-and-other-things)
* [Projects and the Web Console](#projects-and-the-web-console)
* [Your First Application](#your-first-application)
* [Adding Nodes](#adding-nodes)
* [Services](#services)
* [Routing](#routing)
* [The Complete Pod-Service-Route](#the-complete-pod-service-route)
* [STI - What Is It?](#sti---what-is-it)

**Appendices:**

* [Extra STI code examples](#appendix---extra-sti-code-examples)
* [DNSMasq setup](#appendix---dnsmasq-setup)
* [Import/Export of Docker Images (Disconnected Use)](#appendix---importexport-of-docker-images-disconnected-use)
* [Cleaning Up](#appendix---cleaning-up)
* [Pretty Output](#appendix---pretty-output)
* [Troubleshooting](#appendix---troubleshooting)

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

* RHEL 7.1 (Note: 7.1 kernel is required for openvswitch)
* "Minimal" installation option
* NetworkManager **disabled**
* SELinux in **permissive** mode
* Attach the *OpenShift Enterprise High Touch Beta* subscription with subscription-manager
* Then configure yum as follows:

        subscription-manager repos --disable="*"
        subscription-manager repos \
        --enable="rhel-7-server-rpms" \
        --enable="rhel-7-server-extras-rpms" \
        --enable="rhel-7-server-optional-rpms" \
        --enable="rhel-server-7-ose-beta-rpms"

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
environment happen **faster**, you'll need to first install Docker:

    yum -y install docker

You'll need to add `--insecure-registry 0.0.0.0/0` to your
`/etc/sysconfig/docker` `OPTIONS`. Then:

    systemctl start docker

On all of your systems, grab the following docker images:

    docker pull registry.access.redhat.com/openshift3_beta/ose-haproxy-router:v0.4
    docker pull registry.access.redhat.com/openshift3_beta/ose-deployer:v0.4
    docker pull registry.access.redhat.com/openshift3_beta/ose-sti-builder:v0.4
    docker pull registry.access.redhat.com/openshift3_beta/ose-docker-builder:v0.4
    docker pull registry.access.redhat.com/openshift3_beta/ose-pod:v0.4
    docker pull registry.access.redhat.com/openshift3_beta/ose-docker-registry:v0.4

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

## Ansible-based Installer
The installer uses Ansible. Eventually there will be an interactive text-based
CLI installer that leverages Ansible under the covers. For now, we have to
invoke Ansible manually.

### Install Ansible
Ansible currently comes from the EPEL repository.

Install EPEL:

    yum -y install \
    http://dl.fedoraproject.org/pub/epel/7/x86_64/e/epel-release-7-5.noarch.rpm

Disable EPEL so that it is not accidentally used later:

    sed -i -e "s/^enabled=1/enabled=0/" /etc/yum.repos.d/epel.repo

Install the packages for Ansible:

    yum --enablerepo=epel -y install ansible 

### Generate SSH Keys
Because of the way Ansible works, SSH key distribution is required. First,
generate an SSH key on your master, where we will run Ansible:

    ssh-keygen

Do *not* use a password.

### Distribute SSH Keys
An easy way to distribute your SSH keys is by using a `bash` loop:

    for host in ose3-master.example.com ose3-node1.example.com \
    ose3-node2.example.com; do ssh-copy-id -i ~/.ssh/id_rsa.pub \
    $host; done

Remember, if your FQDNs are different, you would have to modify the loop
accordingly.

### Clone the Ansible Repository
The configuration files for the Ansible installer are currently available on
Github. Clone the repository:

    cd
    git clone https://github.com/detiber/openshift-ansible.git -b v3-beta2
    cd ~/openshift-ansible

### Configure Ansible
Move the staged Ansible configuration files to `/etc/ansible`:

    "cp" -r ~/training/beta2/ansible/* /etc/ansible/

### Modify Hosts
If you are not using the "example.com" domain and the training example
hostnames, modify /etc/ansible/hosts accordingly. Do not adjust the commented
lines (`#`) at this time.

### Run the Ansible Installer
Now we can simply run the Ansible installer:

    ansible-playbook playbooks/byo/config.yml

### Add Development Users
In the "real world" your developers would likely be using the OpenShift tools on
their own machines (`osc` and `openshift` and etc). For the Beta training, we
will create user accounts for two non-privileged users of OpenShift, *joe* and
*alice*.

    useradd joe
    useradd alice

We will come back to these users later.

## Watching Logs
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

## Auth, Projects and the Web Console
### Configuring htpasswd Authentication
OpenShift v3 supports a number of mechanisms for authentication. The simplest
use case for our testing purposes is `htpasswd`-based authentication.

To start, we will need the `htpasswd` binary, which is made available by
installing:

    yum -y install httpd-tools

From there, we can create a password for our users, Joe and Alice:

    touch /etc/openshift-passwd
    htpasswd -b /etc/openshift-passwd joe redhat
    Adding password for user joe
    htpasswd -b /etc/openshift-passwd alice redhat
    Adding password for user alice

Then, add the following lines to `/etc/sysconfig/openshift-master`:

    cat <<EOF >> /etc/sysconfig/openshift-master
    OPENSHIFT_OAUTH_REQUEST_HANDLERS=session,basicauth
    OPENSHIFT_OAUTH_HANDLER=login
    OPENSHIFT_OAUTH_PASSWORD_AUTH=htpasswd
    OPENSHIFT_OAUTH_HTPASSWD_FILE=/etc/openshift-passwd
    OPENSHIFT_OAUTH_ACCESS_TOKEN_MAX_AGE_SECONDS=172800
    EOF

Restart `openshift-master`:

    systemctl restart openshift-master

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
    --admin=htpasswd:joe

This command creates a project:
* with the id `demo`
* with a display name
* with a description 
* with an administrative user `joe` who can login with the password defined by
    htpasswd

Future use of command line statements will have to reference this project in
order for things to land in the right place.

Now that you have a project created, it's time to look at the web console, which
has been completely redesigned for V3.

### Web Console
Open your browser and visit the following URL:

    https://fqdn.of.master:8444

It may take up to 90 seconds for the web console to be available after
restarting the master (when you changed the authentication settings).
    
You will first need to accept the self-signed SSL certificate. You will then be
asked for a username and a password. Remembering that we created a user
previously, `joe`, go ahead and enter that and use the password (redhat) you set
earlier.

Once you are in, click the *OpenShift 3 Demo* project. There really isn't
anything of interest at the moment, because we haven't put anything into our
project. While we created the router, it's not part of this project (it is core
infrastructure), so we do not see it here. If you had access to the *default*
project, you would see things like the router and other core infrastructure
components.

## Installing the Router
Networking in OpenShift v3 is quite complex. Suffice it to say that, while it is
easy to get a complete "multi-tier" "application" deployed, reaching it from
anywhere outside of the OpenShift environment is not possible without something
extra. This extra thing is the routing layer. The router is the ingress point
for all traffic destined for OpenShift v3 services. It currently supports only
HTTP(S) traffic.

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
SSL and uses various certificates and authentication methods. Even though we set
up our `.kubeconfig`, unfortunately, ex router does not seem to look in the
default location for it. We also need to specify the router image, since
currently the experimental tooling points to upstream/origin:

    openshift ex router --create --credentials=/root/.kube/.kubeconfig \
    --images='registry.access.redhat.com/openshift3_beta/ose-${component}:${version}'

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

Note: You may or may not see the deploy pod, depending on when you run this
command.

## Preparing for STI and Other Things
One of the really interesting things about OpenShift v3 is that it will build
Docker images from your source code and deploy and manage their lifecycle. In
order to do this, OpenShift can host its own Docker registry in
order to pull images "locally". Let's take a moment to set that up.

`openshift ex` again comes to our rescue with a handy installer for the
registry:

    openshift ex registry --create --credentials=/root/.kube/.kubeconfig \
    --images='registry.access.redhat.com/openshift3_beta/ose-${component}:${version}'

You'll get output like:

    docker-registry
    docker-registry

You can use `osc get pods`, `osc get services`, and `osc get deploymentconfig`
to see what happened.

Ultimately, you will have a Docker registry that is being hosted by OpenShift
and that is running on one of your nodes.

To quickly test your Docker registry, you can do the following:

    curl `osc get services | grep registry | awk '{print $4":"$5}'`

And you should see:

    "docker-registry server (dev) (v0.9.0)"

If you get "connection reset by peer" you may have to wait a few more moments
after the pod is running for the service proxy to update the endpoints necessary
to fulfill your request. You can check if your service has finished updating its
endpoints with:

    osc describe service docker-registry

And you will eventually see something like:

    Name:           docker-registry
    Labels:         docker-registry=default
    Selector:       docker-registry=default
    Port:           5000
    Endpoints:      10.1.0.7:5000
    No events.

Once there is an endpoint listed, the curl should work.

## Your First Application
At this point you essentially have a sufficiently-functional V3 OpenShift
environment. It is now time to create the classic "Hello World" application
using some sample code.  But, first, some housekeeping.

Also, don't forget, the materials for these labs are in your `~/training/beta2`
folder.

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
to it. Still in a `root` terminal:

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

### Login
Since we have taken the time to create the *joe* user as well as a project for
him, now we will login from the command line to set up our tooling.

Open a terminal as `joe`:

    # su - joe

Make a `.kube` folder:

    mkdir .kube

Then, change to that folder and login:

    cd ~/.kube
    openshift ex login \
    --certificate-authority=/var/lib/openshift/openshift.local.certificates/ca/root.crt \
    --cluster=master --server=https://ose3-master.example.com:8443 \
    --namespace=demo 

This created a file called `.kubeconfig`. Take a look at it:

    cat .kubeconfig 
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority: /var/lib/openshift/openshift.local.certificates/ca/root.crt
        server: https://ose3-master.example.com:8443
      name: ose3-master.example.com:8443
    contexts:
    - context:
        cluster: ose3-master.example.com:8443
        namespace: demo
        user: joe
      name: ose3-master.example.com:8443-joe
    current-context: ose3-master.example.com:8443-joe
    kind: Config
    preferences: {}
    users:
    - name: joe
      user:
        token: MDU5ZWFjMGUtYWZmOS00MzY4LWE3N2MtNzFiNTYyOWJkZjY4

This configuration file has an authorization token, some information about where
our server lives, our project, and etc. If we now do something like:

    osc get pod

We should get a response, but not see anything. That's because the core
infrastructure, again, lives in the *default* project, which we're not
accessing.

The reason we perform the `login` inside of the `.kube` folder is that all of
the command line tooling eventually looks in there for `.kubeconfig`.

**Note:** See the [troubleshooting guide](#appendix---troubleshooting) for details on how to fetch a new token
once this once expires.  This training document sets the default token lifetime
to 48 hours.

### Grab the Training Repo Again
Since Joe and Alice can't access the training folder in root's home directory,
go ahead and grab it inside Joe's home folder:

    cd
    git clone https://github.com/openshift/training.git
    cd ~/training/beta2

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

Remember, we've "logged in" to OpenShift and our project, so this will create
the pod inside of it. The command should display the ID of the pod:

    hello-openshift

Issue a `get pods` to see that it was, in fact, defined, and to check its
status:

    osc get pods
    POD             IP       CONTAINER(S)                     IMAGE(S)                           HOST                                  LABELS                 STATUS
    hello-openshift 10.1.0.4 hello-openshift                  openshift/hello-openshift          ose3-master.example.com/192.168.133.2 name=hello-openshift   Pending

Look at the list of Docker containers with `docker ps` (in a `root` terminal) to
see the bound ports.  We should see an `openshift3_beta/ose-pod` container bound
to 6061 on the host and bound to 8080 on the container, along with several other
`ose-pod` containers.

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
* You'll see the host port that the pod is bound to
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
It is extremely easy to add nodes to an existing OpenShift environment. Return
to a `root` terminal.

### Modifying the Ansible Configuration
On your master, edit the `/etc/ansible/hosts` file and uncomment the nodes, or
add them as appropriate for your DNS/hostnames.

Then, run the ansible playbook again:

    cd ~/openshift-ansible/
    ansible-playbook playbooks/byo/config.yml

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

Don't forget -- the materials are in `~/training/beta2`.

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

Logged in as `joe`, edit `test-complete.json` and change the `host` stanza for
the route to have the correct domain, matching the DNS configuration for your
environment. Once this is done, go ahead and use `osc` to apply it. You should
see something like the following:

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

    curl `osc get services | grep hello-openshift | awk '{print $4":"$5}'`
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

    "demo/hello-openshift-service": {
      "Name": "demo/hello-openshift-service",
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
    }

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
As the `root` user, we will create a new project to put our first STI example
into. Grab the project definition and create it:

    openshift ex new-project sinatra --display-name="Ruby/Sinatra" \
    --description="Our Simple Sintra STI Example" \
    --admin=htpasswd:joe

At this point, if you click the OpenShift image on the web console you should be
returned to the project overview page where you will see the new project show
up. Go ahead and click the *Sinatra* project - you'll see why soon.

We can also apply the same quota we used before to this new project:

    osc create -n sinatra -f demo-quota.json

### Switch contexts
As the `joe` user, let's create a new context for interacting with the new
project you just created:

    cd ~/.kube
    openshift ex config set-context sinatra --cluster=ose3-master.example.com:8443 \
    --namespace=sinatra --user=joe
    openshift ex config use-context sinatra

**Note:**
If you ever get confused about what context you're using, or what contexts are
defined, you can look at `~/.kube/.kubeconfig`:

    cat ~/.kube/.kubeconfig 
    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority: /var/lib/openshift/openshift.local.certificates/ca/root.crt
        server: https://ose3-master.example.com:8443
      name: ose3-master.example.com:8443
    contexts:
    - context:
        cluster: ose3-master.example.com:8443
        namespace: demo
        user: joe
      name: ose3-master.example.com:8443-joe
    - context:
        cluster: ose3-master.example.com:8443
        namespace: sinatra
        user: joe
      name: sinatra
    current-context: sinatra
    kind: Config
    preferences: {}
    users:
    - name: joe
      user:
        token: MDU5ZWFjMGUtYWZmOS00MzY4LWE3N2MtNzFiNTYyOWJkZjY4

Or, to quickly get your current context:

    grep current ~/.kube/.kubeconfig
    current-context: sinatra

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

**NOTE: there's a bug that makes this not work (forbidden)** 

**Note: If the build isn't "Running" yet, or the sti-build container hasn't been
deployed yet, build-logs will give you an error. Just wait a few moments and
retry it.**

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

    curl `osc get services | grep sin | awk '{print $4":"$5}'`
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
Right now, OpenShift doesn't "clean up" after the build process - pods that were
generated to build your application code will stick around. If you do a few
builds, and go to the *Settings* tab for the *Sinatra* project, you'll see that
you can reach or exceed your pod quote (3). These issues are understood and will
be fixed.

Since we are not doing anything else with the *Sinatra* project, we can ignore
these artifacts for now.

## A Fully-Integrated "Quickstart" Application
The next example will involve a build of another application, but also a service
that has two pods -- a "front-end" web tier and a "back-end" database tier. This
application also makes use of auto-generated parameters and other neat features
of OpenShift. One thing of note is that this project already has the
wiring/plumbing between the front- and back-end components pre-defined as part
of its JSON. Adding resources "after the fact" will come in a later lab.

This example is effectively a "quickstart" -- a pre-defined application that
comes in a template that you can just fire up and start using or hacking on.

### A Project for the Quickstart
As the `root` user, first we'll create a new project:

    openshift ex new-project integrated --display-name="Frontend/Backend" \
    --description='A demonstration of a "quickstart/template"' \
    --admin=htpasswd:joe

As the `joe` user, we'll set our context to use the corresponding namespace:

    cd ~/.kube
    openshift ex config set-context int --cluster=ose3-master.example.com:8443 \
    --namespace=integrated --user=joe
    openshift ex config use-context int

**Note:** You could also have specified `--kubeconfig=~/.kube/.kubeconfig` with
`set-context`.

**Note:** You can also `export KUBECONFIG=~/.kube/.kubeconfig`.

### A Quick Aside on Templates
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

### Using Your App
Now that the app is built, you should be able to visit the routed URL and
actually use the application!

    http://integrated.cloudapps.example.com

**Note: HTTPS will *not* work for this example because the form submission was
written with HTTP links. Be sure to use HTTP. **

## Creating and Wiring Disparate Components
Quickstarts are great, but sometimes a developer wants to build up the various
components manually. Let's take our quickstart example and treat it like two
separate "applications" that we want to wire together.

### Create a New Project
As the `root` user, create another new project for this "wiring" example:

    openshift ex new-project wiring --display-name="Exploring Parameters" \
    --description='An exploration of wiring using parameters' \
    --admin=htpasswd:alice

As `alice`, let's set up our `.kubeconfig`. Open a terminal as `alice`:

    # su - alice

Make a `.kube` folder:

    mkdir .kube

Then, change to that folder and login:

    cd ~/.kube
    openshift ex login \
    --certificate-authority=/var/lib/openshift/openshift.local.certificates/ca/root.crt \
    --cluster=master --server=https://ose3-master.example.com:8443 \
    --namespace=wiring

Remember, your password was probably "redhat". 

Log into the web console as `alice`. Can you see `joe`'s projects and content?

Before continuing, `alice` will also need the training repository:

    cd
    git clone https://github.com/openshift/training.git
    cd ~/training/beta2

### Stand Up the Frontend
The first step will be to stand up the frontend of our application. For
argument's sake, this could have just as easily been brand new vanilla code.
However, to make things faster, we'll start with an application that already is
looking for a DB, but won't fail spectacularly if one isn't found.

Go ahead and process the frontend template and then examine it:

    osc process -f frontend-template.json > frontend-config.json

**Note:** If you are using a different domain, you will need to edit the route
before running `create`.

In the config, you will see that a DB password and other parameters have been
generated (remember the template and parameter info from earlier?).

Go ahead and create the configuration:
   
    osc create -f frontend-config.json

### Webhooks
Webhooks are a way to integrate external systems into your OpenShift
environment. They can be used to fire off builds. Generally speaking, one would
make code changes, update the code repository, and then some process would hit
OpenShift's webhook URL in order to start a build with the new code.

Visit the web console, click into the project, click on *Browse* and then on
*Builds*. You'll see two webhook URLs. Copy the *Generic* one. It should look
like:

    https://ose3-master.example.com:8443/osapi/v1beta1/buildConfigHooks/ruby-sample-build/secret101/generic?namespace=wiring

If you look at the `frontend-config.json` file that you created earlier, you'll
notice these same "secrets". These are kind of like user/password combinations
to secure the build. More access control will be added around these webhooks,
but, for now, this is the simple way it is achieved.

This time, in order to run a build for the frontend, we'll use `curl` to hit our
webhook URL.

First, look at the list of builds:

    osc get build

You should see that there aren't any. Then, `curl`:

    curl -i -H "Accept: application/json" \
    -H "X-HTTP-Method-Override: PUT" -X POST -k \
    https://ose3-master.example.com:8443/osapi/v1beta1/buildConfigHooks/ruby-sample-build/secret101/generic?namespace=wiring

And now `get build` again:

    osc get build
    NAME                                                   TYPE STATUS  POD
    ruby-sample-build-9ae35312-c687-11e4-a4a6-525400b33d1d STI  Running build-ruby-sample-build-9ae35312-c687-11e4-a4a6-525400b33d1d

You can see that this could have been part of some CI/CD workflow that
automatically called our webhook once the code was tested.

### Visit Your Application
Once the build is finished and the frontend service's endpoint has been updated,
visit your application. The frontend configuration contained a route for
`wiring.cloudapps.example.com`. You should see a note that the database is
missing. So, let's create it!

### Create the Database Config
Remember, `osc process` will examine a template, generate any desired
parameters, and spit out a JSON `config`uration that can be `create`d with
`osc`.

First, we will generate a config for the database:

    osc process -f db-template.json > db-config.json

Processing the template for the db will generate some values for the DB root
user and password, but they don't actually match what was previously generated
when we set up the front-end. In the "quickstart" example, we generated these
values and used them for both the frontend and the back-end at the exact same
time. In this case, we need to do some manual intervention.

In the future, you'll be able to pass values into the template when it is
processed, or things will be auto-populated (like in OpenShift v2).

So, look at the frontend configuration (`frontend-config.json`) and find the
value for `MYSQL_ROOT_PASSWORD`. For example, `mugX5R2B`.

Edit `db-config.json` and set the value for `MYSQL_ROOT_PASSWORD` to match
whatever is in your `frontend-config.json`. Once you are finished, you can
create the backend:

    osc create -f db-config.json

All we are doing is leveraging the standard Dockerhub MySQL container, which
knows to take some env-vars when it fires up (eg: the MySQL root password).

It may take a little while for the mysql container to download from the Docker
Hub (if you didn't pre-fetch it), which can cause the frontend application to
appear broken if it is restarted.  In reality it's simply polling for the
database connection to become active.  It's a good idea to verify that that
database is running at this point.  If you don't happen to have a mysql client
installed you can verify it's running with curl:

    curl `osc get services | grep database | awk '{print $4}'`:5434

Obviously mysql doesn't speak HTTP so you'll see garbled output like this
(however, you'll know your database is running!):

    5.6.2K\l-7mA<��F/T:emsy'TR~mysql_native_password!��#08S01Got packets out of order

### Visit Your Application Again
Visit your application again with your web browser. Why does it still say that
there is no database?

When the frontend was first built and created, there was no service called
"database", so the environment variable `DATABASE_SERVICE_HOST` did not get
populated with any values. Our database does exist now, and there is a service
for it, but OpenShift did not "inject" those values into the running container.

### Replication Controllers
The easiest way to get this going? Just nuke the existing pod. There is a
replication controller running for both the frontend and backend:

    osc get replicationcontroller

The replication controller will ensure that we always have however many
replicas (instances) running. We can look at how many that should be:

    osc describe rc frontend-1

So, if we kill the pod, the RC will detect that, and fire it back up. When it
gets fired up this time, it will then have the `DATABASE_SERVICE_HOST` value,
which means it will be able to connect to the DB, which means that we should no
longer see these errors!

Go ahead and find your frontend pod, and then kill it:

    osc delete pod `osc get pod | grep front | awk '{print $1}'`

You'll see something like:

    frontend-1-hvxiy

That was the generated name of the pod when the replication controller stood it
up the first time. After a few moments, we can look at the list of pods again:

    osc get pod | grep front

And we should see a different name for the pod this time:

    frontend-1-0fs20

This shows that, underneath the covers, the RC restarted our pod. Since it was
restarted, it should have a value for the `DATABASE_SERVICE_HOST` environment
variable. Go to the node where the pod is running, and find the Docker container
id:

    docker inspect `docker ps | grep wiring | grep front | grep run | awk \
    '{print $1}'` | grep DATABASE

The output will look like:

    "MYSQL_DATABASE=root",
    "DATABASE_PORT_5434_TCP_ADDR=172.30.17.106",
    "DATABASE_PORT=tcp://172.30.17.106:5434",
    "DATABASE_PORT_5434_TCP=tcp://172.30.17.106:5434",
    "DATABASE_PORT_5434_TCP_PROTO=tcp",
    "DATABASE_SERVICE_HOST=172.30.17.106",
    "DATABASE_SERVICE_PORT=5434",
    "DATABASE_PORT_5434_TCP_PORT=5434",

### Revisit the Webpage
Go ahead and revisit `http://wiring.cloudapps.example.com` (or your appropriate
FQDN) in your browser, and you should see that the application is now fully
functional!

Remember, wiring up apps yourself right now is a little clunky. These things
will get much easier with future beta drops and will also be more accessible
from the web console.

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
* All of a sudden authentication seems broken for non-admin users.  Whenever I run osc commands I see output such as:

        F0310 14:59:59.219087   30319 get.go:164] request 
        [&{Method:GET URL:https://ose3-master.example.com:8443/api/v1beta1/pods?namespace=demo
        Proto:HTTP/1.1 ProtoMajor:1 ProtoMinor:1 Header:map[] Body:<nil> ContentLength:0 TransferEncoding:[] 
        Close:false Host:ose3-master.example.com:8443 Form:map[] PostForm:map[] 
        MultipartForm:<nil> Trailer:map[] RemoteAddr: RequestURI: TLS:<nil>}] 
        failed (401) 401 Unauthorized: Unauthorized

    In most cases if admin (certificate) auth is still working this means the token is invalid.  Soon there will be more polish in the osc tooling to handle this edge case automatically but for now the simplist thing to do is to recreate the .kubeconfig.

        # The login command creates a .kubeconfig file in the CWD.
        # But we need it to exist in ~/.kube
        cd ~/.kube

        # If a stale token exists it will prevent the beta2 login command from working
        rm .kubeconfig

        openshift ex login \
        --certificate-authority=/var/lib/openshift/openshift.local.certificates/ca/root.crt \
        --cluster=master --server=https://ose3-master.example.com:8443 \
        --namespace=[INSERT NAMESPACE HERE]

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

* When issuing a `curl` to my service, I see `curl: (56) Recv failure:
    Connection reset by peer`

    It can take as long as 90 seconds for the service URL to start working.
    There is some internal house cleaning that occurs inside Kubernetes
    regarding the endpoint maps.

    If you look at the log for the node, you might see some messages about
    looking at endpoint maps and not finding an endpoint for the service.

    To find out if the endpoints have been updated you can run:

    `osc describe service $name_of_service` and check the value of `Endpoints:`
