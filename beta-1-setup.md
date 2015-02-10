# OpenShift Beta 1 Setup Information
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

### Git
You will either need internet access or read and write access to an internal
http-based git server.

### Each VM

Each of the virtual machines should have 4+ GB of memory, 10+ GB of disk space,
and the following configuration:

* RHEL 7.1 Beta
* "Minimal" installation option
* firewalld and NetworkManager **disabled**
* Attach the *OpenShift Enterprise High Touch Beta* subscription with subscription-manager
* Then configure yum as follows:

        subscription-manager repos --disable="*"
        subscription-manager repos \
        --enable="rhel-7-server-beta-rpms" \
        --enable="rhel-7-server-extras-rpms" \
        --enable="rhel-server-7-ose-beta-rpms"

Once you have prepared your VMs, you can do the following on **each** VM:

1. Install deltarpm to make package updates a little faster:

        yum -y install deltarpm

1. Remove NetworkManager:

        yum -y remove NetworkManager*

1. Install missing packages:

        yum install wget vim-enhanced net-tools bind-utils tmux git \
        docker openvswitch iptables-services bridge-utils '*openshift*'

1. Update:

        yum -y update

1. Enable openvswitch:

        systemctl enable openvswitch

1. Edit the `OPTIONS=` line of your `/etc/sysconfig/docker` file:

        OPTIONS=--insecure-registry 0.0.0.0/0 -H fd://

    The `--insecure-registry` option tells Docker to trust any registry on the
    specified subnet, without requiring a certificate. You would want to
    exchange the subnet above with whatever subnet your OpenShift environment is
    running on. Ultimately, we will be running a Docker registry on OpenShift,
    which explains this setting.

1. Enable Docker

        systemctl enable docker

1. Add iptables port rules for OpenShift by editing `/etc/sysconfig/iptables`.
The port range is wide open for now, but will be significantly closed in future
releases. In between the following rules:

        -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
        -A INPUT -p icmp -j ACCEPT

    Add these rules:

         -A INPUT -p tcp -m state --state NEW -m tcp --dport 10250 -j ACCEPT
         -A INPUT -p tcp -m state --state NEW -m tcp --dport 8443:8444 -j ACCEPT
         -A INPUT -p tcp -m state --state NEW -m tcp --dport 7001 -j ACCEPT
         -A INPUT -p tcp -m state --state NEW -m tcp --dport 4001 -j ACCEPT
         -A INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
         -A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT

1. Restart iptables and docker, enable iptables:

        systemctl enable iptables

1. Add the following to `root`'s `.bash_profile`:

        export KUBECONFIG=/var/lib/openshift/openshift.local.certificates/admin/.kubeconfig

1. Restart your system.

### Grab Docker Images
On all of your systems, grab the following docker images:

    docker pull registry.access.redhat.com/openshift3_beta/ose-haproxy-router
    docker pull registry.access.redhat.com/openshift3_beta/ose-deployer
    docker pull registry.access.redhat.com/openshift3_beta/ose-sti-builder
    docker pull registry.access.redhat.com/openshift3_beta/ose-docker-builder
    docker pull registry.access.redhat.com/openshift3_beta/ose-pod
    docker pull openshift/docker-registry

**note: missing:
    openshift/hello-openshift
    sti images (eg: ruby20-centos-sti kind of thing)
**

And re-tag them:

    docker tag registry.access.redhat.com/openshift3_beta/ose-sti-builder openshift3_beta/ose-sti-builder
    docker tag registry.access.redhat.com/openshift3_beta/ose-docker-builder openshift3_beta/ose-docker-builder
    docker tag registry.access.redhat.com/openshift3_beta/ose-deployer openshift3_beta/ose-deployer
    docker tag registry.access.redhat.com/openshift3_beta/ose-haproxy-router openshift3_beta/ose-haproxy-router
    docker tag registry.access.redhat.com/openshift3_beta/ose-pod openshift3_beta/ose-pod

## Starting the OpenShift Services
### Running a Master
#### The Master Service
First, we must edit the `/etc/sysconfig/openshift-master` file. Edit the
`OPTIONS` to read:

    OPTIONS="--loglevel=4 --public-master=fqdn.of.master"

Edit the `IMAGES` to read:

    IMAGES=openshift3_beta/ose-${component}

Then, start the `openshift-master` service:

    systemctl start openshift-master

You may also want to `systemctl enable openshift-master` to ensure the service
automatically starts on the next boot.

#### The OpenShift Node
We are running a "node" service on our master. In other words, the OpenShift
Master will both orchestrate containers and run containers, too.

Edit the `/etc/sysconfig/openshift-node` file and edit the `OPTIONS`:

    OPTIONS="--loglevel=4"
    
Edit the `IMAGES` to read:

    IMAGES=openshift3_beta/ose-${component}

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

Then you can start the SDN master:

    systemctl start openshift-sdn-master

You may also want to enable the service.

Then, edit the `/etc/sysconfig/openshift-sdn-node` file:

    MASTER_URL="http://fqdn.of.master:4001"
    
    MINION_IP="ip.address.of.public.interface"
    
    OPTIONS="-v=4"

    DOCKER_OPTIONS='--insecure-registry=0.0.0.0/0 -b=lbr0 --mtu=1450 --selinux-enabled'

Then you can start the SDN node:

    systemctl start openshift-sdn-node

You may also want to enable the service.

Starting the sdn-node service will automatically start the openshift-node
service.

We will start our testing and operations with only one OpenShift "node" -- the
master. Later, we will add the other two nodes.

### Running the Router
Networking in OpenShift v3 is quite complex. Suffice it to say that, while it is
easy to get a complete "multi-tier" "application" deployed, reaching it from
anywhere outside of the OpenShift environment is not possible without something
extra. This extra thing is the routing layer. The router is the ingress point
for all traffic destined for OpenShift v3 services. It currently supports only
HTTP(S) traffic.

As with most things in OpenShift v3, resources are defined via JSON. The
following JSON file describes the router:

    {
        "kind": "Pod",
        "apiVersion": "v1beta1",
        "id": "mainrouter",
        "desiredState": {
            "manifest": {
                "version": "v1beta2",
                "containers": [
                    {
                        "name": "ose-haproxy-router-mainrouter",
                        "image": "openshift3_beta/ose-haproxy-router",
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
                                "value": "https://fqdn.of.master:8443"
                            },
                            {
                                "name": "OPENSHIFT_CA_DATA",
                                "value": "/var/lib/openshift/openshift.local.certificates/ca/cert.crt"
                            },
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

Download this file onto your master:

    wget https://raw.githubusercontent.com/openshift/training/master/router.json

and **be sure to edit** the `OPENSHIFT_MASTER` value to have the correct FQDN.
Then, use the `osc` tool to create the router:

    osc create -f router.json

If this works, in the output of `osc get pods` you should see the pod status
change to "running" after a few moments (it may take up to a few minutes):

    osc get pods
    POD        IP       CONTAINER(S)                     IMAGE(S)                           HOST                                   LABELS STATUS
    mainrouter 10.1.0.3 ose-haproxy-router-mainrouter    openshift3_beta/ose-haproxy-router ose3-master.example.com/192.168.133.2  <none> Running

At this point you must update your DNS wildcard entry to point to the IP address
of the host on which the router instance is running.

## Projects and the Web Console
### A Project for Everything
V3 has a concept of "projects" to contain a number of different services and
their pods, builds and etc. We'll explore what this means in more details
throughout the rest of the labs, but, first, let's create a project for our
first application.

    wget https://raw.githubusercontent.com/openshift/training/master/betaproject.json
    osc create -f betaproject.json

Since we have a project, future use of command line statements will have to
reference this project in order for things to land in the right place.

Now that you have a project created, it's time to look at the web console, which
has been completely redesigned for V3.

### Web Console
Open your browser and visit the following URL:

    https://fqdn.of.master:8444

You will first need to accept the self-signed SSL certificate. You will then be
asked for a username and a password - anything will work. Just enter `foo` as
the user and `bar` as the password, for now.

Once you are in, click the *Demo* project. There really isn't anything of
interest at the moment, because we haven't put anything into our project. While
we created the router, it's not part of our project (it is core infrastructure),
so we do not see it here.

## Your First Application
At this point you have a sufficiently-functional V3 OpenShift environment. It is
now time to create the classic "Hello World" application using some sample code. 

### Grab the Definition JSON
On your **master** node, go ahead and grab the JSON definition:

    wget https://raw.githubusercontent.com/openshift/origin/master/examples/hello-openshift/hello-pod.json

You can see the contents of our pod definition by using `cat`:

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

    osc create -f hello-pod.json -n betaproject

Notice that we specfied the namespace, or project id, in the above command. This
ensures that our pod is created (placed) into our namespace (project). The
command should display the ID of the pod:

    hello-openshift

Issue a `get pods` to see that it was, in fact, defined, and to check its
status:

    osc get pods -n betaproject
    POD             IP       CONTAINER(S)                     IMAGE(S)                           HOST                                  LABELS                 STATUS
    hello-openshift 10.1.0.4 hello-openshift                  openshift/hello-openshift          ose3-master.example.com/192.168.133.2 name=hello-openshift   Pending

**note: we might pre-fetch**
When you first issue `get pods`, you will likely see a pending status for the
`hello-openshift` pod. This is because we did not pre-fetch its Docker image, so
the node is pulling it from a registry. Later we will set up a local Docker
registry for OpenShift to use. You should also note that we no longer see the
router pod in the output. This is because the router is part of the "default"
namespace, used for core infrastructure components.

Look at the list of Docker containers with `docker ps` to see the bound ports.
We should see an `openshift3_beta/ose-pod` container bound to 6061 on the host and
bound to 8080 on the container.

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
In the web console, if you click "Browse" and then "Pods", you'll see the pod we
just created and some information about it.

Go ahead and delete this pod so that you don't get confused in later examples:

    osc delete pod hello-openshift -n betaproject

Take a moment to think about what this pod definition really did -- it
referenced an arbitrary Docker image, made sure to fetch it (if it wasn't
present), and then ran it. This could have just as easily been an application
from an ISV available in a registry or something already written and built
in-house.

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

Edit `IMAGES` to read:

    IMAGES=openshift3_beta/ose-${component}"

Do **not** start the openshift-node service. We will let openshift-sdn-node
handle that for us (like before).

#### The Node SDN
Edit the `/etc/sysconfig/openshift-sdn-node` file:

    MASTER_URL="http://fqdn.of.master:4001"
    
    MINION_IP="ip.address.of.public.interface"
    
    OPTIONS="-v=4"

    DOCKER_OPTIONS='--insecure-registry=0.0.0.0/0 -b=lbr0 --mtu=1450 --selinux-enabled'

And start the SDN node:

    systemctl start openshift-sdn-node

You may also want to enable the service.

### Adding the Node Via OpenShift's API
The following JSON describes a node:

    {
      "id": "ose3-node1.example.com",
      "kind": "Minion",
      "apiVersion": "v1beta1",
    }

Grab this node definition from the training repository:

    wget https://raw.githubusercontent.com/openshift/training/master/node.json

Then, add the node via the API:

    osc create -f node.json

You can then edit the file to exchange `node1` for `node2` and then use `osc`
again:

    osc create -f node.json

You should now have two running nodes in addition to your original "master"
node (it may take a minute for all to reach "Ready" status):

    osc get minions
    NAME                      LABELS              STATUS
    ose3-master.example.com   <none>              Ready
    ose3-node1.example.com    <none>              Ready
    ose3-node2.example.com    <none>              Ready

Note that these commands do not take a namespace, because we are modifying core
OpenShift components.

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
routes resource on the OpenShift master. This is why we specified the master's
address when we installed the router.

Here is an example route JSON definition:

    {
      "id": "hello-route",
      "kind": "Route",
      "apiVersion": "v1beta1",
      "host": "hello-openshift.v3.rhcloud.com",
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
          "id": "hello-openshift-service",
          "kind": "Service",
          "apiVersion": "v1beta1",
          "port": 27017,
          "selector": {
            "name": "hello-openshift-label"
          }
        },
        {
          "id": "hello-openshift-route",
          "kind": "Route",
          "apiVersion": "v1beta1",
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

Create the JSON file above on your **master** host in root's home directory. Or
use wget to grab it:

    wget https://raw.githubusercontent.com/openshift/training/master/test-complete.json

Once you have this file, you must edit the `host` stanza for the route to have
the correct domain, matching the DNS configuration for your environment. Once
this is done, go ahead and use `osc` to apply it. You should see something like
the following:

        osc create -f test-complete.json -n betaproject
        hello-openshift-pod
        hello-openshift-service
        6b8b66e4-b078-11e4-b390-525400b33d1d

You can verify this with other `osc` commands:

    osc get pods -n betaproject
    ...
    hello-openshift-pod/10.X.X.X ...

    osc get services -n betaproject
    ...
    hello-openshift-service ...

    osc get routes -n betaproject
    ...
    cd0dba9a-a1a5-11e4-bf82-525400b33d1d hello-openshift.cloudapps.example.com ...

**Make sure that you specified your namespace when you created the example!**

### Verifying the Service
Services are not externally accessible without a route being defined, because
they always listen on "local" IP addresses (eg: 172.x.x.x). However, if you have
access to the OpenShift environment, you can still test a service.

    osc get services -n betaproject
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

    docker inspect `docker ps | grep haproxy-router | awk '{print $1}'` | grep \
    Pid | awk '{print $2}' | cut -f1 -d,
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
      "HostAliases": [
        "hello-openshift.cloudapps.example.com"
      ],

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

## Preparing for STI and Other Things
We mentioned a few times that OpenShift would host its own Docker registry in
order to pull images "locally". Let's take a moment to set that up.

The Docker registry requires some information about our environment (SSL info,
namely), so we will use an install script to process a template. Go ahead and
grab the following files:

    wget https://raw.githubusercontent.com/openshift/training/master/install-registry.sh
    wget https://raw.githubusercontent.com/openshift/training/master/docker-registry-template.json

Edit `docker-registry-template.json` and find `OPENSHIFT_MASTER` -- set it to
the proper URL, for example:

    https://ose3-master.example.com:8443

Make the script executable:

    chmod 755 install-registry.sh

And now run it the following way:

    CERT_DIR=/var/lib/openshift/openshift.local.certificates/master \
    KUBERNETES_MASTER=https://ose3-master.example.com:8443 \
    CONTAINER_ACCESSIBLE_API_HOST=ose3-master.example.com \
    ./install-registry.sh

You'll get output like:

    [INFO] Submitting docker-registry template file for processing
    docker-registry
    docker-registry

You can use `osc get pods`, `osc get services`, and `osc get deploymentconfig`
to see what happened, again noting that we do not specify a namespace when
dealing with core OpenShift components.

Ultimately, you will have a Docker registry that is being hosted by OpenShift
and that is running on one of your nodes.

To quickly test your Docker registry, you can do the following:

    curl `osc get services docker-registry -o template --template="{{ .portalIP}}:{{ .port }}"`

And you should see:

    "docker-registry server (dev) (v0.9.0)"

## STI - What Is It?
STI stands for *source-to-image* and is the process where OpenShift will take
your application source code and build a Docker image for it. In the real world,
you would need to have a code repository (where OpenShift can introspect an
appropriate Docker image to build and use to support the code) or a code
repository + a Dockerfile (so that OpenShift can pull or build the Docker image
for you).

### A Simple STI Build
We'll be using a pre-build/configured code repository. This repository is an
extremely simple "Hello World" type application that looks very much like our
previous example, except that it uses a Ruby/Sinatra application instead of a Go
application.

For this example, we will be using the following application's source code:

    https://github.com/thoraxe/simple-openshift-sinatra-sti

Grab the code and process it using the following:

    cd
    git clone https://github.com/thoraxe/simple-openshift-sinatra-sti
    cd ~/simple-openshift-sinatra-sti
    rm -f Dockerfile
    openshift ex generate | python -m json.tool > ~/simple-sinatra.json

`ex generate` is a tool that will examine the current directory tree and attempt
to generate an appropriate JSON template so that, when processed, OpenShift can
build the resulting image to run. 

need explanation of template -> config

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

### Create a New Project
We will create a new project to put our first STI example into. Grab the project
definition and create it:

    wget https://raw.githubusercontent.com/openshift/training/master/sinatraproject.json
    osc create -f sinatraproject.json

At this point, if you click the OpenShift image on the web console you should be
returned to the project overview page where you will see the new project show
up. Go ahead and click the *Sinatra* project - you'll see why soon.

### Create the Build Process
Let's go ahead and get everything fired up:

    osc create -f ~/simple-sinatra.json -n sinatraproject

As soon as you execute this command, go back to the web console and see if you
can figure out what is different.

To learn a little more about what happened, run the following:

    for i in imagerepository buildconfig deploymentconfig service; do \
    echo $i; osc --namespace=sinatraproject get $i; done

Based on the JSON from `ex generate`, we have created:

* An ImageRepository entry
* A BuildConfig
* A DeploymentConfig
* A Service

If you run:

    osc --namespace=sinatraproject get pods

You will see that there are currently no pods. That is because we have not
actually gone through a build yet. While OpenShift has the capability of
automatically triggering builds based on source control pushes (eg: Git(hub)
webhooks, etc), we will be triggering builds manually.

To start our build, execute the following:

    osc --namespace=sinatraproject start-build simple-openshift-sinatra-sti

You'll see some output to indicate the build:

    a1aa7e35-ad82-11e4-8f5f-525400b33d1d

That's the UUID of our build. We can check on its status (it will switch to
"Running" in a few moments):

    osc --namespace=sinatraproject get builds
    NAME                                   TYPE                STATUS  POD
    a1aa7e35-ad82-11e4-8f5f-525400b33d1d   STI                 Pending build-a1aa7e35-ad82-11e4-8f5f-525400b33d1d

Let's go ahead and start "tailing" the build log (substitute the proper UUID for
your environment):

    osc build-logs a1aa7e35-ad82-11e4-8f5f-525400b33d1d -n sinatraproject

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

**Hint:** You will need to use `osc get services` with a namespace to find it.

Grab the route JSON file:

    wget https://raw.githubusercontent.com/openshift/training/master/sinatra-route.json

And edit it to incorporate the service name you determined. Hint: you need to
edit the `serviceName` field.

When you are done, create your route:

    osc --namespace=sinatraproject create -f sinatra-route.json
    a8b8c72b-b07c-11e4-b390-525400b33d1d

Check to make sure it was created:

    osc --namespace=sinatraproject get route
    NAME                                 HOST/PORT                              PATH SERVICE                  LABELS
    a8b8c72b-b07c-11e4-b390-525400b33d1d hello-sinatra.cloudapps.example.com         simple-openshift-sinatra 

And now, you should be able to verify everything is working right:

    curl http://hello-sinatra.cloudapps.example.com
    Hello, Sinatra!

If you want to be fancy, try it in your browser!

### A Fully-Integrated Application
The next example will involve a build of another application, but also a service
that has two pods -- a "front-end" web tier and a "back-end" database tier. This
application also makes use of auto-generated parameters and other neat features
of OpenShift.

First we'll create a new project:

    wget https://raw.githubusercontent.com/openshift/training/master/integrated-project.json
    osc create -f integrated-project.json

Go ahead and fetch the definition for this application:

    wget https://raw.githubusercontent.com/openshift/training/master/integrated-build.json

Examine it to see how parameters and other things are handled. Tthen go ahead
and process and create it:

    osc process -n integratedproject -f integrated-build.json | osc create \
    -n integratedproject -f -

The build configuration, in this case, is called `ruby-sample-build`. So, let's
go ahead and start the build and watch the logs:

    osc --namespace=integratedproject start-build ruby-sample-build
    277f6eac-b07d-11e4-b390-525400b33d1d

    osc --namespace=integratedproject build-logs 277f6eac-b07d-11e4-b390-525400b33d1d

Don't forget that the web console will show information about the build status,
although in much less detail.

### Routing Our Integrated Application
Remember our experiments with routing from earlier? Well, our STI example
doesn't include a route definition in its template. So, we can create one:

    {
      "id": "frontend-route",
      "kind": "Route",
      "apiVersion": "v1beta1",
      "host": "integrated.cloudapps.example.com",
      "serviceName": "hello-openshift"
    }

Go ahead and grab this route from the Git repository, and then create it:

    wget https://raw.githubusercontent.com/openshift/training/master/integrated-route.json
    osc --namespace=integratedproject create -f integrated-route.json

Now, in your browser, you should be able to visit the website and actually use
the application!

    http://integrated.cloudapps.example.com

**Note: HTTPS will *not* work for this example because the form submission was
written with HTTP links. Be sure to use HTTP. **

## Conclusion
This concludes the Beta 1 training. Look for more example applications to come!
