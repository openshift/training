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
        --enable="rhel-7-server-optional-beta-rpms" \
        --enable="rhel-server-7-ose-beta-rpms"

Once you have prepared your VMs, you can do the following on **each** VM:

1. Install deltarpm to make package updates a little faster:

        yum -y install deltarpm

1. Remove NetworkManager:

        yum -y remove NetworkManager*

1. Install missing packages:

        yum install wget vim-enhanced net-tools bind-utils tmux git golang \
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

### On Master
Edit `/etc/sysconfig/openshift-master` and set the `OPTIONS` stanza to read:

    OPTIONS="--loglevel=4 --public-master=fqdn.of.master"
 
### On Nodes
Edit `/etc/sysconfig/openshift-node` and set the `OPTIONS` stanza to read:

    OPTIONS="--master=fqdn.of.master --loglevel=4"

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

    docker tag registry.access.redhat.com/openshift_beta/ose-sti-builder openshift_beta/ose-sti-builder
    docker tag registry.access.redhat.com/openshift_beta/ose-docker-builder openshift_beta/ose-docker-builder
    docker tag registry.access.redhat.com/openshift_beta/ose-deployer openshift_beta/ose-deployer
    docker tag registry.access.redhat.com/openshift_beta/ose-haproxy-router openshift_beta/ose-haproxy-router

## Starting the OpenShift Services
### Running a Master
#### The Master Service
First, we must edit the `/etc/sysconfig/openshift-master` file. Edit the
`OPTIONS` to read:

    OPTIONS="--loglevel=4 --public-master=fqdn.of.master --images=openshift3_beta/ose-${component}"

Then, start the `openshift-master` service:

    systemctl start openshift-master

You may also want to `systemctl enable openshift-master` to ensure the service
automatically starts on the next boot.

#### The OpenShift Node
We are running a "node" service on our master. In other words, the OpenShift
Master will both orchestrate containers and run containers, too.

Edit the `/etc/sysconfig/openshift-node` file and edit the `OPTIONS`:

    OPTIONS="--loglevel=4 --kubeconfig=/var/lib/openshift/openshift.local.certificates/admin/.kubeconfig"

Do **not** start the openshift-node service yet. We must start the openshift-sdn-node
first in order to set up the proper bridges, and the openshift-sdn-node service
will automatically start the openshift-node service for us.

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
                        "name": "origin-haproxy-router-mainrouter",
                        "image": "openshift_beta/ose-haproxy-router",
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
                                "value": ""
                            },
                            {
                                "name": "OPENSHIFT_INSECURE",
                                "value": "true"
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

Download this file onto your master and be sure to edit the `OPENSHIFT_MASTER`
value to have the correct FQDN:

    wget https://raw.githubusercontent.com/openshift/training/master/router.json

Then, use the `osc` tool to create the router:

    osc create -f router.json

If this works, in the output of `osc get pods` you should see the pod status
change to "running" after a few moments (it may take up to a few minutes):

    osc get pods
    POD        IP       CONTAINER(S)                     IMAGE(S)                          HOST                                   LABELS STATUS
    mainrouter 10.1.0.3 origin-haproxy-router-mainrouter openshift_beta/ose-haproxy-router ose3-master.example.com/192.168.133.2  <none> Running

At this point you must update your DNS wildcard entry to point to the IP address
of the host on which the router instance is running.

## Your First Application
At this point you should essentially have a fully-functional V3 OpenShift
environment. It is now time to create the classic "Hello World" application
using some sample code. 

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
To define the pod from our JSON file, execute the following:

    osc create -f hello-pod.json

You should see the ID of the pod returned to you:

    hello-openshift

Issue a `get pods` to see that it was, in fact, defined, and to check its
status:

    osc get pods
    # osc get pods
    POD             IP       CONTAINER(S)                     IMAGE(S)                          HOST                                  LABELS                 STATUS
    hello-openshift 10.1.0.4 hello-openshift                  openshift/hello-openshift         ose3-master.example.com/192.168.133.2 name=hello-openshift   Running
    mainrouter      10.1.0.3 origin-haproxy-router-mainrouter openshift_beta/ose-haproxy-router ose3-master.example.com/192.168.133.2 <none>                 Running


**note: we might pre-fetch**
When you first issue `get pods`, you will likely see a pending status for the
`hello-openshift` pod. This is because we did not pre-fetch its Docker image, so
the node is pulling it from a registry. Later we will set up a local Docker
registry for OpenShift to use.

Look at the list of Docker containers with `docker ps` to see the bound ports.
We should see an `openshift/origin-pod` container bound to 6061 on the host and
bound to 8080 on the container.

The `openshift/origin-pod` container exists because of the way network
namespacing works in Kubernetes. For the sake of simplicity, think of the
container as nothing more than a way for the host OS to get an interface created
for the corresponding pod to be able to receive traffic. Deeper understanding of
networking in OpenShift is outside the scope of this material.

To verify that the app is working, you can issue a curl to the app's port:

    curl http://localhost:6061
    Hello OpenShift!

Hooray!

Go ahead and delete this pod so that you don't get confused in later examples:

    osc delete pod hello-openshift

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

    OPTIONS="--loglevel=4 --master=fqdn.of.master --kubeconfig=/var/lib/openshift/openshift.local.certificates/admin/.kubeconfig"

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
node:

    osc get minions
    NAME                      LABELS              STATUS
    ose3-master.example.com   <none>              Ready
    ose3-node1.example.com    <none>              Ready
    ose3-node2.example.com    <none>              Ready

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

In a simplification of the process, the `openshift/origin-haproxy-router`
container is a pre-configured instance of HAProxy as well as some of the
OpenShift framework. The OpenShift instance running in this container watches a
routes resource on the OpenShift master. This is why we specified the master's
IP address when we installed the router.

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

Once you have this file, go ahead and use `osc` to apply it. You should see
something like the following:

        osc create -f test-complete.json 
        hello-openshift-pod
        hello-openshift-service

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

### Verifying the Routing
Verifying the routing is a little complicated, but not terribly so. First, find
where the router is running using `osc get pods`:

    osc get pods | grep router | awk '{print $4}'
    ose3-node1.example.com/

We ultimately want the PID of the container running the router so that we can go
"inside" it. On the node, issue the following to get the PID:

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

## Preparing for STI and Other Things
We mentioned a few times that OpenShift would host its own Docker registry in
order to pull images "locally". Let's take a moment to set that up.

The Docker registry requires some information about our environment (SSL info,
namely), so we will use an install script to process a template. Go ahead and
grab the following files:

    wget https://raw.githubusercontent.com/openshift/training/master/install-registry.sh
    wget https://raw.githubusercontent.com/openshift/training/master/docker-registry-template.json

Make the script executable:

    chmod 755 install-registry.sh

And now run it the following way:

    CERT_DIR=/var/lib/openshift/openshift.local.certificates/master \
    KUBERNETES_MASTER=https://ose3-master.example.com:8443 ./install-registry.sh

You'll get output like:

    [INFO] Submitting docker-registry template file for processing
    docker-registry
    docker-registry

You can use `osc get pods`, `osc get services`, and `osc get deploymentconfig`
to see what happened.

Ultimately, you will have a Docker registry that is being hosted by OpenShift
and that is running on one of your nodes.

## STI - What Is It?
STI stands for *source-to-image* and is the process where OpenShift will take
your application source code and build a Docker image for it. In the real world,
you would need to have a code repository (where OpenShift can introspect an
appropriate Docker image to build and use to support the code) or a code
repository + a Dockerfile (so that OpenShift can pull or build the Docker image
for you).

### A Project for Everything
V3 has a concept of "projects" to contain a number of different services and
their pods, builds and etc. Let's create a project for our first STI
applciation.

    wget \
    https://raw.githubusercontent.com/openshift/training/master/sinatra-project.json

    osc create -f sinatra-project.json

### A Simple STI Build
We'll be using a pre-build/configured code repository. This repository is an
extremely simple "Hello World" type application that looks very much like our
previous example, except that it uses a Ruby/Sinatra application instead of a Go
application.

For this example, we will be using the following application's source code:

    https://github.com/thoraxe/simple-openshift-sinatra-sti

    cd
    git clone https://github.com/thoraxe/simple-openshift-sinatra-sti
    cd ~/simple-openshift-sinatra-sti
    rm Dockerfile
    /path/to/app-gen -p 9292 | python -m json.tool > ~/simple-sinatra.json

Look at json

    osc apply -f ~/simple-sinatra.json
    I0128 14:34:32.200333   15887 apply.go:65] Creation succeeded for
    BuildConfig with name simple-openshift-sinatra-sti
    I0128 14:34:32.200345   15887 apply.go:65] Creation succeeded for
    ImageRepository with name simple-openshift-sinatra-sti
    I0128 14:34:32.200348   15887 apply.go:65] Creation succeeded for
    DeploymentConfig with name ruby-20-centos
    I0128 14:34:32.200351   15887 apply.go:65] Creation succeeded for Service
    with name ruby-20-centos-9292

No webhook - Need to manually trigger build. Find "password"/secret:

    grep generic simple-sinatra.json -A1 | grep secret \
    | awk '{print $2}' | cut -d\" -f2

Builds can be triggered by hitting a URL on OpenShift. We can simulate this with
`curl`. Substitute the UUID you found (password/secret) in the below:

    curl -k -X POST
    https://localhost:8443/osapi/v1beta1/buildConfigHooks/simple-openshift-sinatra-sti/7d962a54-fe5a-4385-9a99-9222e12186d0/generic?namespace=default

Now we can look at the console to check on the progress of our build.

## OpenShift Console
Open the console by visiting the FQDN of your master at port 8444:

    https://master-fqdn.domain.com:8444

You should see the project we previously created (Hello, Sinatra!). Click it.

