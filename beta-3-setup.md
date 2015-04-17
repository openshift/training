# OpenShift Beta 2 Setup Information

**Table of contents:**

* [Setting Up the Environment](#setting-up-the-environment)
* [Ansible-based Installer](#ansible-based-installer)
* [Watching Logs](#watching-logs)
* [Auth, Projects, and the Web Console](#auth-projects-and-the-web-console)
 * [Configuring htpasswd Authentication](#auth-projects-and-the-web-console)
 * [A Project for Everything](#a-project-for-everything)
 * [Web Console](#web-console)
* [Installing the Router](#installing-the-router)
* [Preparing for STI and Other Things](#preparing-for-sti-and-other-things)
* [Your First Application](#your-first-application)
 * ["Resources"](#resources)
 * [Applying Quota to Projects](#applying-quota-to-projects)
 * [Login](#login)
 * [The Hello World Definition JSON](#the-hello-world-definition-json)
 * [Run the Pod](#run-the-pod)
 * [Delete the Pod](#delete-the-pod)
* [Adding Nodes](#adding-nodes)
* [Services](#services)
* [Routing](#routing)
* [The Complete Pod-Service-Route](#the-complete-pod-service-route)
 * [Creating the Definition](#creating-the-definition)
 * [Verifying the Service](#verifying-the-service)
 * [Verifying the Routing](#verifying-the-routing)
* [STI - What Is It?](#sti---what-is-it)
 * [Create a New Project](#create-a-new-project)
 * [Switch contexts](#switch-contexts)
 * [A Simple STI Build](#a-simple-sti-build)
 * [Create the Build Process](#create-the-build-process)
 * [Adding a Route to Our Application](#adding-a-route-to-our-application)
* [A Fully-Integrated "Quickstart" Application](#a-fully-integrated-quickstart-application)
 * [A Project for the Quickstart](#a-project-for-the-quickstart)
 * [A Quick Aside on Templates](#a-quick-aside-on-templates)
 * [Creating the Integrated Application](#creating-the-integrated-application)
* [Creating and Wiring Disparate Components](#creating-and-wiring-disparate-components)
 * [Stand Up the Frontend](#stand-up-the-frontend)
 * [Webhooks](#webhooks)
 * [Create the Database Config](#create-the-database-config)
 * [Replication Controllers](#replication-controllers)
* [Rollback/Activate and Code Lifecycle](#rollbackactivate-and-code-lifecycle)
 * [Update the BuildConfig](#update-the-buildconfig)
 * [Change the Code](#change-the-code)
 * [Kick Off Another Build](#kick-off-another-build)
 * [Rollback](#rollback)
 * [Activate](#activate)
* [Customized Build Process](#customized-build-process)
* [Arbitrary Docker Image (Builder)](#arbitrary-docker-image-builder)
 * [That Project Thing](#that-project-thing)
 * [Build Wordpress](#build-wordpress)
 * [Test Your Application](#test-your-application)

**Appendices:**

* [Extra STI code examples](#appendix---extra-sti-code-examples)
* [DNSMasq setup](#appendix---dnsmasq-setup)
* [LDAP Authentication](#appendix---ldap-authentication)
* [Import/Export of Docker Images (Disconnected Use)](#appendix---importexport-of-docker-images-disconnected-use)
* [Cleaning Up](#appendix---cleaning-up)
* [Pretty Output](#appendix---pretty-output)
* [Troubleshooting](#appendix---troubleshooting)
* [Infrastructure Log Aggregation](#appendix---infrastructure-log-aggregation)
* [JBoss Tools for Eclipse](#appendix---jboss-tools-for-eclipse)

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

### OpenShift 3 Components
OpenShift 3, like OpenShift 2, has two primary components:

* masters - the orchestration engines. They figure out where to run workloads
    and do all of the fancy policy things around controlling it
* nodes - where workloads actually run

### Your Environment
The environment for the beta testing as documented is pretty simple. You will
need 3 virtual machines to follow this beta documentation exactly. Each of the
virtual machines should have 4+ GB of memory, 20+ GB of disk space, and the
following configuration:

* RHEL 7.1 (Note: 7.1 kernel is required for openvswitch)
* "Minimal" installation option
* NetworkManager **disabled**

As part of signing up for the beta program, you should have received an
evaluation subscription. This subscription gave you access to the beta software.
You will need to use subscription manager to both register your VMs, and attach
them to the   *OpenShift Enterprise High Touch Beta* subscription.

All of your VMs should be on the same logical network and be able to access one
another.

### Preparing Each VM
Once your VMs are built and you have verified DNS and network connectivity you
can:

* Configure yum as follows:

        subscription-manager repos --disable="*"
        subscription-manager repos \
        --enable="rhel-7-server-rpms" \
        --enable="rhel-7-server-extras-rpms" \
        --enable="rhel-7-server-optional-rpms" \
        --enable="rhel-server-7-ose-beta-rpms"

* Import the GPG key for beta:

        rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-beta

Onn **each** VM:

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

Make sure that you are running at least `docker-1.6.0-1.el7.x86_64`.

You'll need to add `--insecure-registry 0.0.0.0/0` to your
`/etc/sysconfig/docker` `OPTIONS`. Then:

    systemctl start docker

On all of your systems, grab the following docker images:

    docker pull registry.access.redhat.com/openshift3_beta/ose-haproxy-router:v0.4.3.2
    docker pull registry.access.redhat.com/openshift3_beta/ose-deployer:v0.4.3.2
    docker pull registry.access.redhat.com/openshift3_beta/ose-sti-builder:v0.4.3.2
    docker pull registry.access.redhat.com/openshift3_beta/ose-docker-builder:v0.4.3.2
    docker pull registry.access.redhat.com/openshift3_beta/ose-pod:v0.4.3.2
    docker pull registry.access.redhat.com/openshift3_beta/ose-docker-registry:v0.4.3.2

It may be advisable to pull the following Docker images as well, since they are
used during the various labs:

    docker pull openshift/ruby-20-centos7
    docker pull openshift/mysql-55-centos7
    docker pull openshift/hello-openshift
    docker pull centos:centos7

### Clone the Training Repository
On your master, it makes sense to clone the training git repository:

    cd
    git clone https://github.com/openshift/training.git

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
    git clone https://github.com/detiber/openshift-ansible.git -b v3-beta3
    cd ~/openshift-ansible

### Configure Ansible
Copy the staged Ansible configuration files to `/etc/ansible`:

    /bin/cp -r ~/training/beta3/ansible/* /etc/ansible/

### Modify Hosts
If you are not using the "example.com" domain and the training example
hostnames, modify /etc/ansible/hosts accordingly. Do not adjust the commented
lines (`#`) at this time.

### Run the Ansible Installer
Now we can simply run the Ansible installer:

    ansible-playbook playbooks/byo/config.yml

If you looked at the Ansible hosts file, you'll note that our master
(ose3-master.example.com) was present in both the `master` and the `node`
section.

Effectively, Ansible is going to install and configure both the master and node
software on `ose3-master.example.com`. Later, we'll modify the Ansible
configuration to add the extra nodes.

**Note:** Don't get fancy and try to do it now. Trust us, something will break.
You've been warned, but we promise an explanation about *why* it will break soon
enough.

### Add Development Users
In the "real world" your developers would likely be using the OpenShift tools on
their own machines (`osc` and `openshift` and etc). For the Beta training, we
will create user accounts for two non-privileged users of OpenShift, *joe* and
*alice*, on the master. This is done for convenience and because we'll be using
`htpasswd` for authentication.

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

## Installing the Router
Networking in OpenShift v3 is quite complex. Suffice it to say that, while it is
easy to get a complete "multi-tier" "application" deployed, reaching it from
anywhere outside of the OpenShift environment is not possible without something
extra. This extra thing is the routing layer. The router is the ingress point
for all traffic destined for OpenShift v3 services. It currently supports only
HTTP(S) traffic (and "any" TLS-enabled traffic via SNI).

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
up our `.kubeconfig` for the root user, `ex router` is asking us what
credentials the *router* should use to communicate. We also need to specify the
router image, since currently the experimental tooling points to
upstream/origin:

    openshift ex router --create \
    --credentials=/var/lib/openshift/openshift.local.certificates/openshift-router/.kubeconfig \
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

    openshift ex registry --create \
    --credentials=/var/lib/openshift/openshift.local.certificates/openshift-registry/.kubeconfig \
    --images='registry.access.redhat.com/openshift3_beta/ose-${component}:${version}'

You'll get output like:

    docker-registry
    docker-registry

You can use `osc get pods`, `osc get services`, and `osc get deploymentconfig`
to see what happened.

Ultimately, you will have a Docker registry that is being hosted by OpenShift
and that is running on one of your nodes.

To quickly test your Docker registry, you can do the following:

    curl `osc get services | grep registry | awk '{print $4":"$5}' | sed -e 's/\/.*//'`

And you should see:

    "docker-registry server (dev) (v0.9.0)"

If you get "connection reset by peer" you may have to wait a few more moments
after the pod is running for the service proxy to update the endpoints necessary
to fulfill your request. You can check if your service has finished updating its
endpoints with:

    osc describe service docker-registry

And you will eventually see something like:

    W0414 10:28:57.561516    5829 request.go:288] field selector: v1beta1 - events - involvedObject.namespace - default: need to check if this is versioned correctly.
    W0414 10:28:57.561581    5829 request.go:288] field selector: v1beta1 - events - involvedObject.kind - Service: need to check if this is versioned correctly.
    W0414 10:28:57.561587    5829 request.go:288] field selector: v1beta1 - events - involvedObject.uid - 1f41e96d-e2b2-11e4-bf25-525400b33d1d: need to check if this is versioned correctly.
    W0414 10:28:57.561591    5829 request.go:288] field selector: v1beta1 - events - involvedObject.id - docker-registry: need to check if this is versioned correctly.
    Name:                   docker-registry
    Labels:                 docker-registry=default
    Selector:               docker-registry=default
    IP:                     172.30.17.64
    Port:                   <unnamed>       5000/TCP
    Endpoints:              10.1.0.5:5000
    Session Affinity:       None
    No events.

Once there is an endpoint listed, the curl should work.

### Status Report, Captain!
OpenShift provides a handy tool, `status`, to tell you a bit about the
project/namespace you're operating in. As the `root` user, we can run this to
learn about the *default* project:

    osc status

What's a project? Glad that you asked!

## Auth, Projects, and the Web Console
### Configuring htpasswd Authentication
OpenShift v3 supports a number of mechanisms for authentication. The simplest
use case for our testing purposes is `htpasswd`-based authentication.

To start, we will need the `htpasswd` binary, which is made available by
installing:

    yum -y install httpd-tools

From there, we can create a password for our users, Joe and Alice:

    touch /etc/openshift-passwd
    htpasswd -b /etc/openshift-passwd joe redhat
    htpasswd -b /etc/openshift-passwd alice redhat

The OpenShift configuration is kept in a YAML file which currently lives at
`/var/lib/openshift/master.yml`. We need to edit the `oauthConfig`'s
`identityProviders` stanza so that it looks like the following:

    identityProviders:
    - challenge: true
      login: true
      name: apache_auth
      provider:
        apiVersion: v1
        file: /etc/openshift-passwd
        kind: HTPasswdPasswordIdentityProvider

More information on these configuration settings can be found here:

    http://docs.openshift.org/latest/architecture/authentication.html#HTPasswdPasswordIdentityProvider

If you're feeling lazy, use your friend `sed`:

    sed -i -e 's/name: anypassword/name: apache_auth/' \
    -e 's/kind: AllowAllPasswordIdentityProvider/kind: HTPasswdPasswordIdentityProvider/' \
    -e '/kind: HTPasswdPasswordIdentityProvider/i \      file: \/etc\/openshift-passwd' \
    /etc/openshift/master.yaml

Restart `openshift-master`:

    systemctl restart openshift-master

### A Project for Everything
V3 has a concept of "projects" to contain a number of different resources:
services and their pods, builds and etc. They are somewhat similar to
"namespaces" in OpenShift v2. We'll explore what this means in more details
throughout the rest of the labs. Let's create a project for our first
application.

We also need to understand a little bit about users and administration. The
default configuration for CLI operations currently is to be the `master-admin`
user, which is allowed to create projects. We can use the "admin"
OpenShift command to create a project, and assign an administrative user to it:

    openshift admin new-project demo --display-name="OpenShift 3 Demo" \
    --description="This is the first demo project with OpenShift v3" \
    --admin=joe

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

    https://fqdn.of.master:8443

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

## Your First Application
At this point you essentially have a sufficiently-functional V3 OpenShift
environment. It is now time to create the classic "Hello World" application
using some sample code.  But, first, some housekeeping.

Also, don't forget, the materials for these labs are in your `~/training/beta3`
folder.

### "Resources"
There are a number of different resource types in OpenShift 3, and, essentially,
going through the motions of creating/destroying apps, scaling, building and
etc. all ends up manipulating OpenShift and Kubernetes resources under the
covers. Resources can have quotas enforced against them, so let's take a moment
to look at some example JSON for project resource quota might look like:

    {
      "id": "test-quota",
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
to it. Still in a `root` terminal in the `training/beta3` folder:

    osc create -f quota.json --namespace=demo

If you want to see that it was created:

    osc get -n demo quota
    NAME
    test-quota

And if you want to verify limits or examine usage:

    Name:                   test-quota
    Resource                Used    Hard
    --------                ----    ----
    cpu                     0m      2
    memory                  0       512Mi
    pods                    0       3
    replicationcontrollers  0       3
    resourcequotas          1       1
    services                0       3

If you go back into the web console and click into the "OpenShift 3 Demo"
project, and click on the *Settings* tab, you'll see that the quota information
is displayed.

### Login
Since we have taken the time to create the *joe* user as well as a project for
him, we can log into a terminal as *joe* and then set up the command line
tooling.

Open a terminal as `joe`:

    # su - joe

Then, execute:

    osc login -n demo \
    --certificate-authority=/var/lib/openshift/openshift.local.certificates/ca/cert.crt \
    --server=https://ose3-master.example.com:8443

OpenShift, by default, is using a self-signed SSL certificate, so we must point
our tool at the CA file.

This created a file called `.config` in the `~/.config/openshift` folder. Take a
look at it, and you'll see something like the following:

    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority: /var/lib/openshift/openshift.local.certificates/ca/cert.crt
        server: https://ose3-master.example.com:8443
      name: ose3-master-example-com-8443
    contexts:
    - context:
        cluster: ose3-master-example-com-8443
        namespace: demo
        user: joe
      name: demo
    current-context: demo
    kind: Config
    preferences: {}
    users:
    - name: joe
      user:
        token: ZmQwMjBiZjUtYWE3OC00OWE1LWJmZTYtM2M2OTY2OWM0ZGIw

This configuration file has an authorization token, some information about where
our server lives, our project, and etc.

If we now do something like:

    osc status

We should get a response that basically tells us there's nothing to see here.
That's because the core infrastructure, again, lives in the *default* project,
which we're not accessing.

**Note:** See the [troubleshooting guide](#appendix---troubleshooting) for
details on how to fetch a new token once this once expires.  The installer sets
the default token lifetime to 4 hours.

### Grab the Training Repo Again
Since Joe and Alice can't access the training folder in root's home directory,
go ahead and grab it inside Joe's home folder:

    cd
    git clone https://github.com/openshift/training.git
    cd ~/training/beta3

### The Hello World Definition JSON
In the beta3 training folder, you can see the contents of our pod definition by using
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

    pods/hello-openshift

Issue a `get pods` to see that it was, in fact, defined, and to check its
status:

    osc get pods
    POD               IP         CONTAINER(S)      IMAGE(S)                    HOST                                    LABELS                 STATUS    CREATED
    hello-openshift   10.1.0.6   hello-openshift   openshift/hello-openshift   ose3-master.example.com/192.168.133.2   name=hello-openshift   Running   10 seconds

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

### Extra Credit
If you try to curl the pod IP and port, you get "connection refused". See if you
can figure out why.

### Delete the Pod
Go ahead and delete this pod so that you don't get confused in later examples:

    osc delete pod hello-openshift

Take a moment to think about what this pod exercise really did -- it referenced
an arbitrary Docker image, made sure to fetch it (if it wasn't present), and
then ran it. This could have just as easily been an application from an ISV
available in a registry or something already written and built in-house.

This is really powerful. We will explore using "arbitrary" docker images later.

### Quota Enforcement
Since we know we can run a pod directly, we'll go through a simple quota
enforcement exercise. The `hello-quota` JSON will attempt to create four
instances of the "hello-openshift" pod. It will fail when it tries to create the
fourth, because the quota on this project limits us to three total pods.

Go ahead and use `osc create` and you will see the following:

    osc create -f hello-quota.json
    pods/1-hello-openshift
    pods/2-hello-openshift
    pods/3-hello-openshift
    Error: pods "4-hello-openshift" is forbidden: Limited to 3 pods

Let's delete these pods quickly. As `joe` again:

    osc delete pod --all

**Note:** You can delete most resources using "--all" but there is *no sanity
check*. Be careful.

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
application and deployment paradigms.

## Regions and Zones
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
complex topologies you could implement.

And, for an extremely detailed explanation about what these various
configuration flags are doing, check out:

    https://github.com/openshift/openshift-docs/blob/master/using_openshift/scheduler.adoc

First, we need to talk about the "scheduler" and its default configuration.

### Scheduler and Defaults
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

Again, please refer to the documentation link above for deeper details on the
defaults.

In a small environment, these defaults are pretty sane. Let's look at one of the
important predicates (filters) before we move on to "regions" and "zones".

### The NodeSelector
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

### Customizing the Scheduler Configuration
The first step is to edit the OpenShift master's configuration to tell it to
look for a specific scheduler config file. Edit `/etc/openshift/master.yml` and
find the line with `schedulerConfigFile`. Change it to:

    schedulerConfigFile: "/etc/openshift/scheduler.json"

Then, create `/etc/openshift/scheduler.json` with the following content:

    {
      "predicates" : [
        {"name" : "PodFitsResources"},
        {"name" : "PodFitsPorts"},
        {"name" : "NoDiskConflict"},
        {"name" : "Region", "argument" : {"serviceAffinity" : { "labels" : ["region"]}}}
      ],"priorities" : [
        {"name" : "LeastRequestedPriority", "weight" : 1},
        {"name" : "ServiceSpreadingPriority", "weight" : 1},
        {"name" : "Zone", "weight" : 1, "argument" : {"serviceAntiAffinity" : { "label" : "zone" }}}
      ]
    }

To quickly review the above (this explanation sort of assumes that you read the
scheduler documentation, but it's not critically important):

* Filter out nodes that don't fit the resources, don't have the ports, or have
    disk conflicts
* If the pod specifies a label with the key "region", filter nodes by the value.

So, if we have the following nodes and the following labels:

* Node 1 -- "region":"primary"
* Node 2 -- "region":"primary"
* Node 3 -- "region":"infra"

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

### Restart the Master
Go ahead and restart the master. This will make the new scheduler take effect.
As `root` on your master:

    systemctl restart openshift-master

### Label Your Nodes
Just before configuring the scheduler, we added more nodes. If you perform the
following as the `root` user:

    osc get node -o json | sed -e '/"resourceVersion"/d' > ~/nodes.json

You will have the JSON output of the definition of all of your nodes. Go ahead
and edit this file. After the `"metadata": {` line for the block that defines your
master, add the following:

    "labels" : {
      "region" : "infra",
      "zone" : "NA"
    },

For your node1, add the following:

    "labels" : {
      "region" : "primary",
      "zone" : "east"
    },

For your node2, add the following:

    "labels" : {
      "region" : "primary",
      "zone" : "west"
    },

Then, update your nodes using the following:

    osc update node -f ~/nodes.json

Check to the results to ensure the labels were applied:

    osc get nodes
     
    NAME                       LABELS                     STATUS
    ose3-master.example.com    region=infra,zone=NA       Ready
    ose3-node1.example.com     region=primary,zone=east   Ready
    ose3-node2.example.com     region=primary,zone=west   Ready


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
      "kind": "Route",
      "apiVersion": "v1beta1",
      "metadata": {
        "name": "hello-openshift-route"
      },
      "id": "hello-openshift-route",
      "host": "hello-openshift.cloudapps.example.com",
      "serviceName": "hello-openshift-service"
    }

When the `osc` command is used to create this route, a new instance of a route
*resource* is created inside OpenShift. The HAProxy/Router is watching for
changes in route resources. When a new route is detected, an HAProxy pool is
created.

This HAProxy pool contains all pods that are in a service. Which service? The
service that corresponds to the `serviceName` directive.

Let's take a look at an entire Pod-Service-Route definition template and put all
the pieces together.

Don't forget -- the materials are in `~/training/beta3`.

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
environment. Once this is done, go ahead and use `osc` to apply it:

        osc create -f test-complete.json

 You should see something like the following:

    pods/hello-openshift-pod
    services/hello-openshift-service
    routes/hello-openshift-route

You can verify this with other `osc` commands:

    osc get pods

    osc get services

    osc get routes

Don't forget about `osc status`.

### Verifying the Service
Services are not externally accessible without a route being defined, because
they always listen on "local" IP addresses (eg: 172.x.x.x). However, if you have
access to the OpenShift environment, you can still test a service.

    osc get services
    NAME                      LABELS    SELECTOR                     IP              PORT(S)
    hello-openshift-service   <none>    name=hello-openshift-label   172.30.17.229   27017/TCP

We can see that the service has been defined based on the JSON we used earlier.
If the output of `osc get pods` shows that our pod is running, we can try to
access the service:

    curl `osc get services | grep hello-openshift | awk '{print $4":"$5}' | sed -e 's/\/.*//'`
    Hello OpenShift!

This is a good sign! It means that, if the router is working, we should be able
to access the service via the route.

### Verifying the Routing
Verifying the routing is a little complicated, but not terribly so. Since we
created the router when we only had the master running, we know that's where its
Docker container is.

We ultimately want the PID of the container running the router so that we can go
"inside" it. On the master system, as the `root` user, issue the following to
get the PID of the router:

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
          "10.1.2.2:8080": {
            "ID": "10.1.2.2:8080",
            "IP": "10.1.2.2",
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

### Deleting a Project
Since we are done with this "demo" project, and since the `joe` user is a
project administrator, let's go ahead and delete the project. This should also
end up deleting all the pods, and other resources, too.

As the `joe` user:

    osc delete project demo

If you quickly go to the web console and return to the top page, you'll see a
warning icon that will pop-up a hover tip saying the project is marked for
deletion.

If you switch to the `root` user and issue `osc get project` you will see that
the demo project's status is "Terminating". If you do an `osc get pod -n demo`
you may see the pods, still. It takes about 60 seconds for the project deletion
cleanup routine to finish.

Once the project disappears from `osc get project`, doing `osc get pod -n demo`
should return no results.

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

    openshift admin new-project sinatra --display-name="OpenShift 3 Demo" \
    --description="This is the first demo project with OpenShift v3" \
    --admin=joe

At this point, if you click the OpenShift image on the web console you should be
returned to the project overview page where you will see the new project show
up. Go ahead and click the *Sinatra* project - you'll see why soon.

### Switch Projects
As the `joe` user, let's switch to the `sinatra` project:

    osc project sinatra

You should see:

    Now using project "sinatra" on server "https://ose3-master.example.com:8443".

### A Simple STI Build
We'll be using a pre-build/configured code repository. This repository is an
extremely simple "Hello World" type application that looks very much like our
previous example, except that it uses a Ruby/Sinatra application instead of a Go
application.

For this example, we will be using the following application's source code:

    https://github.com/openshift/simple-openshift-sinatra-sti

Let's see some JSON:

    osc new-app -o json https://github.com/openshift/simple-openshift-sinatra-sti.git

Take a look at the JSON that was generated. You will see some familiar items at
this point, and some new ones, like `BuildConfig`, `ImageRepository` and others.

Essentially, the STI process is as follows:

1. OpenShift sets up various components such that it can build source code into
a Docker image.

1. OpenShift will then (on command) build the Docker image with the source code.

1. OpenShift will then deploy the built Docker image as a Pod with an associated
Service.

**Note:** I am wondering if we want to do this via the console now, except for a
bug with services not being created.

### Create the Build Process
Let's go ahead and get everything fired up:

    osc new-app https://github.com/openshift/simple-openshift-sinatra-sti.git

You'll see a bunch of output:

    services/simple-openshift-sinatra
    imageStreams/simple-openshift-sinatra-sti
    buildConfigs/simple-openshift-sinatra-sti
    deploymentConfigs/simple-openshift-sinatra-sti
    Service "simple-openshift-sinatra" created at 172.30.17.127:8080 to talk to pods over port 8080.
    A build was created - you can run `osc start-build simple-openshift-sinatra-sti` to start it.

Take a look at the web console, too. Do you see everything that was created?

Based on using `new-app` against a Git repository, we have created:

* An ImageStream
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

    osc start-build simple-openshift-sinatra-sti

You'll see some output to indicate the build:

    simple-openshift-sinatra-sti-1

OpenShift v3 is in a bit of a transtiion period between authentication
paradigms. Suffice it to say that, for this beta drop, certain actions cannot be
performed by "normal" users, even if it makes sense that they should. Don't
worry, we'll get there.

In order to watch the build logs, you actually need to be a cluster
administratior right now. So, as `root`, you can do the following things:

We can check on the status of a build (it will switch to "Running" in a few
moments):

    osc get builds -n sinatra
    NAME                             TYPE                STATUS    POD
    simple-openshift-sinatra-sti-1   STI                 Pending   simple-openshift-sinatra-sti-1

The web console would've updated the *Overview* tab for the *Sinatra* project to
say:

    A build of simple-openshift-sinatra-sti is pending. A new deployment will be
    created automatically once the build completes.

Let's go ahead and start "tailing" the build log (substitute the proper UUID for
your environment):

    osc build-logs simple-openshift-sinatra-sti-1 -n sinatra

**Note: If the build isn't "Running" yet, or the sti-build container hasn't been
deployed yet, build-logs will give you an error. Just wait a few moments and
retry it.**

### The Web Console Revisited
If you peeked at the web console while the build was running, you probably
noticed a lot of new information in the web console - the build status, the
deployment status, new pods, and more.

If you didn't, go to the web console now. The overview page should show that the
application is running and show the information about the service at the top:

    simple-openshift-sinatra - routing TCP traffic on 172.30.17.20:8080 to port 8080

### Examining the Build
If you go back to your console session where you examined the `build-logs`,
you'll see a number of things happened.

What were they?

### Testing the Application
Using the information you found in the web console, try to see if your service
is working:

    curl `osc get service | grep sin | awk '{print $4":"$5}' | sed -e 's/\/.*//'`
    Hello, Sinatra!

So, from a simple code repository with a few lines of Ruby, we have successfully
built a Docker image and OpenShift has deployed it for us.

The last step will be to add a route to make it publicly accessible.

### Adding a Route to Our Application
When we used `new-app`, the only thing that was not created was a route for
our application.

Remember that routes are associated with services, so, determine the id of your
services from the service output you looked at above.

**Hint:** It is `simple-openshift-sinatra`.

**Hint:** You will need to use `osc get services` to find it.

**Hint:** Do this as `joe`.

When you are done, create your route:

    osc create -f sinatra-route.json

Check to make sure it was created:

    osc get route
    NAME            HOST/PORT                             PATH      SERVICE                    LABELS
    sinatra-route   hello-sinatra.cloudapps.example.com             simple-openshift-sinatra

And now, you should be able to verify everything is working right:

    curl http://hello-sinatra.cloudapps.example.com
    Hello, Sinatra!

If you want to be fancy, try it in your browser!

## A Fully-Integrated "Quickstart" Application
The next example will involve a build of another application, but also a service
that has two pods -- a "front-end" web tier and a "back-end" database tier. This
application also makes use of auto-generated parameters and other neat features
of OpenShift. One thing of note is that this project already has the
wiring/plumbing between the front- and back-end components pre-defined as part
of its JSON and embedded in the source code. Adding resources "after the fact"
will come in a later lab.

This example is effectively a "quickstart" -- a pre-defined application that
comes in a template that you can just fire up and start using or hacking on.

### A Project for the Quickstart
As the `root` user, first we'll create a new project:

    openshift admin new-project quickstart --display-name="Quickstart" \
    --description='A demonstration of a "quickstart/template"' \
    --admin=joe

As the `joe` user, we'll set our context to use the corresponding namespace:

    osc project quickstart

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
using a regex-like string that will be presented as ADMIN_USERNAME.

### Adding the Template
Go ahead and do the following as `root` in the `~/training/beta3` folder:

    osc create -f integrated-template.json -n openshift

What did you just do? The `integrated-template.json` file defined a template. By
"creating" it, you have added it to the `openshift` project. What is the
`openshift` project? This is a special project whose templates are accessible by
all users of the OpenShift environment. Let's take a look at how that works.

### Create an Instance of the Template
In the web console, logged in as `joe`, find the "Quickstart" project, and
then hit the "Create +" button.

Click the "Browse all templates..." button.

You will be taken to a page that lists the current templates that are available
for use.

Click "quickstart-keyvalue-application", and you'll see a modal pop-up that
provides more information about the template.

Click "Select template..."

The next page that you will see is the template "configuration" page. This is
where you can specify certain options for how the application components will be
insantiated.

* It will show you what Docker images are used
* It will let you add label:value pairs that can be used for other things
* It will let you set specific values for any parameters, if you so choose

Leave all of the defaults and simply click "Create".

### The Template is Alive!
Once you hit the "Create" button, the services and pods and
replicationcontrollers and etc. will be instantiated

The cool thing about the template is that it has a built-in route. The not so
cool thing is that route is not configurable at the moment. But, it's there!

If you click "Browse" and then "Services" you will see that there is a route for
the *frontend* service:

    `integrated.cloudapps.example.com`

The build was started for us immediately after creating an instance of the
template, so you can wait for it to finish. Feel free to check the build logs.

Once the build is complete, you can go on to the next step.

### Using Your App
Once the app is built, you should be able to visit the routed URL and
actually use the application!

    http://integrated.cloudapps.example.com

**Note: HTTPS will *not* work for this example because the form submission was
written with HTTP links. Be sure to use HTTP. **

## Creating and Wiring Disparate Components
Quickstarts are great, but sometimes a developer wants to build up the various
components manually. Let's take our quickstart example and treat it like two
separate "applications" that we want to wire together.

### Create a New Project
As the `root` user, create another new project for this "wiring" example. This
time we'll make it belong to `alice`:

    openshift admin new-project wiring --display-name="Exploring Parameters" \
    --description='An exploration of wiring using parameters' \
    --admin=alice

Open a terminal as `alice`:

    # su - alice

Then:

    osc login -n wiring \
    --certificate-authority=/var/lib/openshift/openshift.local.certificates/ca/cert.crt \
    --server=https://ose3-master.example.com:8443

Remember, your password was probably "redhat".

Log into the web console as `alice`. Can you see `joe`'s projects and content?

Before continuing, `alice` will also need the training repository:

    cd
    git clone https://github.com/openshift/training.git
    cd ~/training/beta3

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

As soon as you create this, all of the resources will be created *and* a build
will be started for you. Let's go ahead and wait until this build completes
before continuing. It may take about 20-40 seconds for the automatic build to
start:

    https://github.com/openshift/origin/issues/1738

### Webhooks

**Note**: Since the build auto starts, we may want to move this to a later
example.

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

You should see that the first build had completed. Then, `curl`:

    curl -i -H "Accept: application/json" \
    -H "X-HTTP-Method-Override: PUT" -X POST -k \
    https://ose3-master.example.com:8443/osapi/v1beta1/buildConfigHooks/ruby-sample-build/secret101/generic?namespace=wiring

And now `get build` again:

    osc get build
    NAME                  TYPE      STATUS     POD
    ruby-sample-build-1   STI       Complete   ruby-sample-build-1
    ruby-sample-build-2   STI       Pending    ruby-sample-build-2

You can see that this could have been part of some CI/CD workflow that
automatically called our webhook once the code was tested.

### Visit Your Application
Once the new build is finished and the frontend service's endpoint has been
updated, visit your application. The frontend configuration contained a route
for `wiring.cloudapps.example.com`. You should see a note that the database is
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
value for `MYSQL_PASSWORD`. For example, `mugX5R2B`.

Edit `db-config.json` and set the value for `MYSQL_PASSWORD` to match
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

As `alice`, go ahead and find your frontend pod, and then kill it:

    osc delete pod `osc get pod | grep front | awk '{print $1}'`

You'll see something like:

    pods/frontend-1-b6bgy

That was the generated name of the pod when the replication controller stood it
up the first time. After a few moments, we can look at the list of pods again:

    osc get pod | grep front

And we should see a different name for the pod this time:

    frontend-1-0fs20

This shows that, underneath the covers, the RC restarted our pod. Since it was
restarted, it should have a value for the `DATABASE_SERVICE_HOST` environment
variable. Go to the node where the pod is running, and find the Docker container
id as `root`:

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

## Rollback/Activate and Code Lifecycle
Not every coder is perfect, and sometimes you want to rollback to a previous
incarnation of your application. Sometimes you then want to go forward to a
newer version, too.

The next few labs require that you have a Github account. We will take Alice's
"wiring" application and modify its front-end and then rebuild. We'll roll-back
to the original version, and then go forward to our re-built version.

### Fork the Repository
Our wiring example's frontend service uses the following Github repository:

    https://github.com/openshift/ruby-hello-world

Go ahead and fork this into your own account by clicking the *Fork* Button at
the upper right.

### Update the BuildConfig
Remember that a `BuildConfig`(uration) tells OpenShift how to do a build.
Still as the `alice` user, take a look at the current `BuildConfig` for our
frontend:

    osc get buildconfig ruby-sample-build -o yaml
    apiVersion: v1beta1
    kind: BuildConfig
    metadata:
      creationTimestamp: 2015-03-10T15:40:26-04:00
      labels:
        template: application-template-stibuild
      name: ruby-sample-build
      namespace: wiring
      resourceVersion: "831"
      selfLink: /osapi/v1beta1/buildConfigs/ruby-sample-build?namespace=wiring
      uid: 4cff2e5e-c75d-11e4-806e-525400b33d1d
    parameters:
      output:
        to:
          kind: ImageRepository
          name: origin-ruby-sample
      source:
        git:
          uri: git://github.com/openshift/ruby-hello-world.git
        type: Git
      strategy:
        stiStrategy:
          builderImage: openshift/ruby-20-centos7
          image: openshift/ruby-20-centos7
        type: STI
    triggers:
    - github:
        secret: secret101
      type: github
    - generic:
        secret: secret101
      type: generic
    - imageChange:
        from:
          name: ruby-20-centos7
        image: openshift/ruby-20-centos7
        imageRepositoryRef:
          name: ruby-20-centos7
        tag: latest
      type: imageChange

As you can see, the current configuration points at the
`openshift/ruby-hello-world` repository. Since you've forked this repo, let's go
ahead and re-point our configuration. Assuming your github user is
`alice`, you could do something like the following:

    osc get buildconfig ruby-sample-build -o yaml | sed -e \
    's/openshift\/ruby-hello-world/alice\/ruby-hello-world/' \
    -e '/ref: beta2/d' | osc update \
    buildconfig ruby-sample-build -f -

If you again run `osc get buildconfig ruby-sample-build -o yaml` you should see
that the `uri` has been updated.

### Change the Code
Github's web interface will let you make edits to files. Go to your forked
repository (eg: https://github.com/alice/ruby-hello-world) and find the file
`main.erb` in the `views` folder.

Change the following HTML:

    <div class="page-header" align=center>
      <h1> Welcome to an OpenShift v3 Demo App! </h1>
    </div>

To read (with the typo):

    <div class="page-header" align=center>
      <h1> This is my crustom demo! </h1>
    </div>

You can edit code on Github by clicking the pencil icon which is next to the
"History" button. Provide some nifty commit message like "Personalizing the
application."

### Kick Off Another Build
Now that our code is changed, we can kick off another build process using the
same webhook as before:

    curl -i -H "Accept: application/json" \
    -H "X-HTTP-Method-Override: PUT" -X POST -k \
    https://ose3-master.example.com:8443/osapi/v1beta1/buildConfigHooks/ruby-sample-build/secret101/generic?namespace=wiring

As soon as you issue this curl, you can check the web interface (logged in as
`alice`) and see that the build is running. Once it is complete, point your web
browser at the application:

    http://wiring.cloudapps.example.com/

You should see your big fat typo.

**Note: Remember that it can take a minute for your service endpoint to get
updated. You might get a `503` error if you try to access the application before
this happens.**

### Oops!
Since we failed to properly test our application, and our ugly typo has made it
into production, a nastygram from corporate marketing has told us that we need
to revert to the previous version, ASAP.

If you log into the web console as `alice` and find the `Deployments` section of
the `Browse` menu, you'll see that there are two deployments of our frontend: 1
and 2.

You can also see this information from the cli by doing:

    osc get replicationcontroller

The semantics of this are that a `DeploymentConfig` ensures a
`ReplicationController` is created to manage the deployment of the built `Image`
from the `ImageRepository`.

Simple, right?

### Rollback
You can rollback a deployment using the CLI. Let's go and checkout what a rollback to
`frontend-1` would look like:

    osc rollback frontend-1 --dry-run

Since it looks OK, let's go ahead and do it:

    osc rollback frontend-1

If you look at the `Browse` tab of your project, you'll see that in the `Pods`
section there is a `frontend-3...` pod now. After a few moments, revisit the
application in your web browser, and you should see the old "Welcome..." text.

### Activate
Corporate marketing called again. They think the typo makes us look hip and
cool. Let's now roll forward (activate) the typo-enabled application:

    osc rollback frontend-2

## Customized Build Process
OpenShift v3 supports customization of the build process. Generally speaking,
this involves modifying the various STI scripts from the builder image. When
OpenShift builds your code, it checks to see if any of the scripts in the
`.sti/bin` folder of your repository override/supercede the builder image's
scripts. If so, it will execute the repository script instead.

### Add a Script
You will find a script called `custom-build.sh` in the `beta2` folder. Go to
your Github repository for your application from the previous lab, and find the
`.sti/bin` folder.

* Click the "+" button at the top (to the right of `bin` in the
    breadcrumbs).
* Name your file `assemble`.
* Paste the contents of `custom-build.sh` into the text area.
* Provide a nifty commit message.
* Click the "commit" button.

Once this is complete, we can now do another build. The only difference in this
"custom" assemble script is that it logs some extra output. We will see that
shortly.

### Kick Off a Build
Our old friend `curl` is back:

    curl -i -H "Accept: application/json" \
    -H "X-HTTP-Method-Override: PUT" -X POST -k \
    https://ose3-master.example.com:8443/osapi/v1beta1/buildConfigHooks/ruby-sample-build/secret101/generic?namespace=wiring

### Watch the Build Logs
Using the skills you have learned, watch the build logs for this build. If you
miss them, remember that you can find the Docker container that ran the build
and look at its Docker logs.

### Did You See It?

    2015-03-11T14:57:00.022957957Z I0311 10:57:00.022913       1 sti.go:357]
    ---> CUSTOM STI ASSEMBLE COMPLETE

## Arbitrary Docker Image (Builder)
One of the first things we did with OpenShift was launch an "arbitrary" Docker
image from the Docker Hub. However, we can also build Docker images from Docker
files, too. While this is a "build" process, it's not a "source-to-image"
process -- we're not working with only a source code repo.

As an example, the CentOS community maintains a Wordpress all-in-one Docker
image:

    https://github.com/CentOS/CentOS-Dockerfiles/tree/master/wordpress/centos7

We've taken the content of this subfolder and placed it in the `beta2/wordpress`
folder in the `training` repository. Let's run `ex generate` and see what
happens:

    openshift ex generate --name=wordpress \
    https://github.com/openshift/centos7-wordpress.git | python -m json.tool

This all looks good for now.

### That Project Thing
As `root`, create a new project for Wordpress for `alice`:

    openshift ex new-project wordpress --display-name="Wordpress" \
    --description='Building an arbitrary Wordpress Docker image' \
    --admin=htpasswd:alice

As `alice`:

    cd ~/.kube
    openshift ex config set-context wordpress --cluster=ose3-master.example.com:8443 \
    --namespace=wordpress --user=alice
    openshift ex config use-context wordpress

### Build Wordpress
Let's choose the Wordpress example:

    openshift ex generate --name=wordpress \
    https://github.com/openshift/centos7-wordpress.git | osc create -f -

Then, start the build:

    osc start-build wordpress

**Note: This can take a *really* long time to build.**

You will need a route for this application, as `curl` won't do a whole lot for
us here. Additionally, `ex generate` currently has a bug in the way services are
provided, so we'll have a service for SSH but not one for httpd.

    osc create -f wordpress-addition.json

### Test Your Application
You should be able to visit:

    http://wordpress.cloudapps.example.com

Check it out!

Remember - not only did we use an arbitrary Docker image, we actually built the
Docker image using OpenShift. Technically there was no "code repository". So, if
you allow it, developers can actually simply build Docker containers as their
"apps" and run them directly on OpenShift.

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

# APPENDIX - LDAP Authentication
OpenShift currently supports several authentication methods for obtaining API
tokens.  While OpenID or one of the supported Oauth providers are preferred,
support for services such as LDAP is possible today using either the [Basic Auth
Remote](http://docs.openshift.org/latest/architecture/authentication.html#BasicAuthPasswordIdentityProvider)
identity provider or the [Request
Header](http://docs.openshift.org/latest/architecture/authentication.html#RequestHeaderIdentityProvider)
Identity provider.  This example while demonstrate the ease of running a
`BasicAuthPasswordIdentityProvider` on OpenShift.

For full documentation on the other authentication options please refer to the
[Official
Documentation](http://docs.openshift.org/latest/architecture/authentication.html#authentication-integrations)

### Prerequirements:

* A working Router with a wildcard DNS entry pointed to it
* A working Registry

### Setting up an example LDAP server:

For purposes of this training it is possible to use a preexisting LDAP server
or the example ldap server that comes preconfigured with the users referenced
in this document.  The decision does not need to be made up front.  It is
possible to change the ldap server that is used at any time.

For convenience the example LDAP server can be deployed on OpenShift as
follows:

    osc create -f openldap-example.json

That will create a pod from an OpenLDAP image hosted externally on the Docker
Hub.  You can find the source for it [here](beta3/images/openldap-example/).

To test the example LDAP service you can run the following:

    yum install openldap-clients
    ldapsearch -D 'cn=Manager,dc=example,dc=com' -b "dc=example,dc=com" -s sub "(objectclass=*)" -h 172.30.17.40 -w redhat

You should see ldif output that shows the example.com users.

### Creating the Basic Auth service

While the example OpenLDAP service is itself mostly a toy, the Basic Auth
service created below can easily be made highly available using OpenShift
features.  It's a normal web service that happens to speak the [API required by
the
master](http://docs.openshift.org/latest/architecture/authentication.html#BasicAuthPasswordIdentityProvider)
and talk to an LDAP server.  Since it's stateless simply increasing the
replicas in the replication controller is all that is needed to make the
application highly available.

To make this as easy as possible for the beta training a helper script has been
provided to create a Route, Service, Build Config and Deployment Config.  The
Basic Auth service will be configured to use TLS all the way to the pod by
means of the [Router's SNI
capabilities](http://docs.openshift.org/latest/architecture/routing.html#passthrough-termination).
Since TLS is used this helper script will also generated the required
certificates using OpenShift default CA.

    ./basicauthurl.sh -h

No arguments are required but the help output will show you the defaults:

    --route    basicauthurl.example.com
    --git-repo git://github.com/brenton/basicauthurl-example.git

Once you run the helper script it will output the configuration changes
required for `/etc/openshift/master.yaml` as well as create
`basicauthurl.json`.  You can now feed that to `osc`:

    osc create -f basicauthurl.json

At this point everything is in place to start the build which will trigger the
deployment.

    osc start-build basicauthurl-build

When the build finished you can run the following command to test that the
Service is responding correctly:

    curl -u joe:redhat --cacert /var/lib/openshift/openshift.local.certificates/ca/cert.crt --resolve basicauthurl.example.com:443:172.30.17.56 https://basicauthurl.example.com/validate

In that case in order for SNI to work correctly we had to trick curl with the `--resolve` flag.  If wildcard DNS is set up in your environment to point to the router then the following should test the service end to end:

   curl -u joe:redhat --cacert /var/lib/openshift/openshift.local.certificates/ca/cert.crt https://basicauthurl.example.com/validate

If you've made the required changes to `/etc/openshift/mmaster.yaml` and
restarted `openshift-master` then you should now be able to log it with the
example users `joe` and `alice` with the password `redhat`.

### Using an LDAP server external to OpenShift

For more advanced usage it's best to refer to the
[README](https://github.com/openshift/sti-basicauthurl) for now.  All
mod_authnz_ldap directives are available.

### Upcoming changes

We've recently worked with Kubernetes upstream to add API support for Secrets.
Before GA the need for STI builds in this authentication approach may go away.
What this would mean is that admins would run a script to import an Apache
configuration in to a Secret and the Pod could use this on start up.  In this
case the Build Config would go away and only a Deployment Config would be
needed.

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

    for resource in build buildconfig images imagestream deploymentconfig \
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

# APPENDIX - Infrastructure Log Aggregation
Given the distributed nature of OpenShift you may find it beneficial to
aggregate logs from your OpenShift infastructure services. By default, openshift
services log to the systemd journal and rsyslog persists those log messages to
/var/log/messages. We''ll reconfigure rsyslog to write these entries to
/var/log/openshift and configure the master host to accept log data from the
other hosts.

Uncomment the following lines in your master''s /etc/rsyslog.conf to enable
remote logging services.

```
$ModLoad imtcp
$InputTCPServerRun 514
```

On your master update the filters in /etc/rsyslog.conf to divert openshift logs to /var/log/openshift

```
# Log openshift processes to /var/log/openshift
:programname, contains, "openshift"                     /var/log/openshift

# Log anything (except mail) of level info or higher.
# Don't log private authentication messages!
# Don't log openshift processes to /var/log/messages either
:programname, contains, "openshift" ~
*.info;mail.none;authpriv.none;cron.none                /var/log/messages
```
Restart rsyslogd
```
systemctl restart rsyslogd
```

On your other hosts send openshift logs to your master by adding this line to
/etc/rsyslog.conf

```
:programname, contains, "openshift" @@ose3-master.example.com
```

Restart rsyslogd
```
systemctl restart rsyslogd
```

Now all your openshift related logs will end up in /var/log/openshift on your
master.

You can also configure rsyslog to store logs in a different location
based on the source host. On your master, add these lines immediately prior to
$$InputTCPServerRun 514

```
$template TmplMsg, "/var/log/remote/%HOSTNAME%/%PROGRAMNAME:::secpath-replace%.log"
$RuleSet remote1
authpriv.*   ?TmplAuth
*.info;mail.none;authpriv.none;cron.none   ?TmplMsg
$RuleSet RSYSLOG_DefaultRuleset   #End the rule set by switching back to the default rule set
$InputTCPServerBindRuleset remote1  #Define a new input and bind it to the "remote1" rule set
```

See these documentation sources for additional rsyslog configuration information
https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/s1-basic_configuration_of_rsyslog.html
http://www.rsyslog.com/doc/v7-stable/configuration/filters.html

# APPENDIX - JBoss Tools for Eclipse
Support for OpenShift development using Eclipse is provided through the JBoss Tools plugin.  The plugin is available
from the Jboss Tools nightly build of the Eclipse Mars.  

### Features
Development is ongoing but current features include:

- Connecting to an OpenShift server using Oauth
    - Connections to multiple servers using multiple user names
- OpenShift Explorer
    - Browsing user projects
    - Browsing project resources
- Display of resource properties

### Installation
1. Install the Mars release of Eclipse from the [Eclipse Download site](http://www.eclipse.org/downloads/)
1. Add the update site
  1. Click from the toolbar 'Help > Install New Sofware'
  1. Click the 'Add' button and a dialog appears
  1. Enter a value for the name
  1. Enter 'http://download.jboss.org/jbosstools/updates/nightly/mars/' for the location.  **Note:** Alternative updates are available from
     the [JBoss Tools Downloads](http://tools.jboss.org/downloads/jbosstools/mars/index.html).  The various releases and code
     freeze dates are listed on the [JBoss JIRA site](https://issues.jboss.org/browse/JBIDE/?selectedTab=com.atlassian.jira.jira-projects-plugin:versions-panel)
  1. Click 'OK' to add the update site
1. Type 'OpenShift' in the text input box to filter the choices
1. Check 'JBoss OpenShift v3 Tools' and click 'Next'
1. Click 'Next' again, accept the license agreement, and click 'Finish'

After installation, open the OpenShift explorer view by clicking from the toolbar 'Window > Show View > Other' and typing 'OpenShift'
in the dialog box that appears.

### Connecting to the server
1. Click 'New Connection Wizard' and a dialog appears
1. Select a v3 connection type
1. Uncheck default server
1. Enter the URL to the OpenShift server instance
1. Enter the username and password for the connection

A successful connection will allow you to expand the OpenShift explorer tree and browse the projects associated with the account
and the resources associated with each project.
