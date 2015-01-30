# OpenShift Beta 1 Setup Information
## Use a Terminal Window Manager
We **strongly** recommend that you use some kind of terminal window manager
(Screen, Tmux).

## Setting Up the Environment
### DNS
You will need to have a wildcard for a DNS zone resolve, ultimately, to the IP
address of the OpenShift router. For now, make sure you point this zone to one
of the IP addresses of your node VMs and use a low TTL. We will adjust the IP
later.

For example:

    *.cloudapps.erikjacobs.com. 300 IN  A 192.168.133.4

In almost all cases, when referencing VMs you must use hostnames and the
hostnames that you use must match the output of `hostname -f` on each of your
nodes. By extension, you must at least have all hostname/ip mappings in
/etc/hosts files or forward DNS should work.

### Github
You will need a Github account for the STI examples, or some internal and
accessible Git repository into which you can place application code.

### Each VM

Each of the virtual machines should have 4+ GB of memory, 10+ GB of disk space,
and the following configuration:

* RHEL 7.1 Beta
* "Minimal" installation option
* firewalld and NetworkManager **disabled**
* SELinux **permissive** or **disabled**
* Subscribed and registered to Red Hat
* With these repositories:

        subscription-manager repos --disable="*"
        subscription-manager repos \
        --enable="rhel-7-server-beta-rpms" \
        --enable="rhel-7-server-extras-rpms" \
        --enable="rhel-7-server-optional-beta-rpms"

TODO: Needs openshift beta repo

Once you have prepared your VMs, you can do the following on **each** VM:

1. Install deltarpm to make package updates a little faster:

        yum -y install deltarpm

1. Remove NetworkManager:

        yum -y remove NetworkManager*

1. Update:

        yum -y update

TODO: will need a repo for the openshift software and openvswitch
http://download.eng.bos.redhat.com/brewroot/packages/openvswitch/2.3.1/2.git20150113.el7/x86_64/openvswitch-2.3.1-2.git20150113.el7.x86_64.rpm

1. Install missing packages:

        yum install wget vim-enhanced net-tools bind-utils tmux git golang \
        docker openvswitch iptables-services bridge-utils 

    We suggest running the Docker registry on the OpenShift Master, which is why we
    install Docker on all the systems.

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

        -A INPUT -p tcp -m state --state NEW -m tcp --dport 80 -j ACCEPT
        -A INPUT -p tcp -m state --state NEW -m tcp --dport 443 -j ACCEPT
        -A INPUT -p tcp -m state --state NEW -m tcp --dport 1024:65535 -j ACCEPT

1. Restart iptables and docker, enable iptables:

        systemctl restart iptables; systemctl restart docker; systemctl enable \
        iptables

1. Install `openshift-sdn`:

        yum install openshift-sdn

1. Add the following to `root`'s `.bash_profile`:

        export KUBECONFIG=/var/lib/openshift/openshift.local.certificates/admin/.kubeconfig

1. Restart your system.

### On Master
1. Install the OpenShift software:

        yum install 'openshift*'

### On Nodes
1. Install the OpenShift software:

        yum install `openshift*`

1. Edit `/etc/sysconfig/openshift-node` and set the `OPTIONS` stanza to read:

        OPTIONS="--master=fqdn.of.master --loglevel=0"

### Grab Docker Images
On all of your systems, grab the following docker images:

        docker pull openshift/docker-registry; \
        docker pull openshift/origin-sti-builder; \
        docker pull openshift/origin-deployer; \
        docker pull openshift/origin-haproxy-router; \
        docker pull google/golang;

## Starting the OpenShift Services
### Running a Master
#### The Master Service
Nothing special is required to start the OpenShift master service. On your
master, simply run:

    systemctl start openshift-master

You may also want to `systemctl enable openshift-master` to ensure the service
automatically starts on the next boot.

#### Setting Up the SDN
Once your master is started, we need to start the SDN (which uses Open vSwitch)
to begin creating our network overlay. The SDN master coordinates all of the SDN
activities. The SDN node actually manipulates the local docker and network
configuration. Since our OpenShift master is also a node, we will also run an
SDN master and node.

First, edit the
`/etc/sysconfig/openshift-sdn-master` file and edit the `OPTIONS` to read:

    OPTIONS="-etcd-endpoints=http://fqdn-of-master:4001 -v=4"

Then you can start the SDN master:

    systemctl start openshift-sdn-master

Then, edit the `/etc/sysconfig/openshift-sdn-node` file:

    MASTER_URL="http://fqdn.of.master:4001"
    
    MINION_IP="ip.address.of.public.interface"
    
    OPTIONS="-v=4 -hostname fqdn.of.node"

Then you can start the SDN node:

    systemctl start openshift-sdn-node

**BUG** You need to go back and edit `/etc/sysconfig/docker` to re-add the
insecure registry options.

#### The OpenShift Node
We are running a "node" service on our master. In other words, the OpenShift
Master will both orchestrate containers and run containers, too.

Edit the `/etc/sysconfig/openshift-node` file and edit the `OPTIONS`:

    OPTIONS="--loglevel=4"

Start the node service:

    systemctl start openshift-node

### Running a Node
Perform the following steps, in order, on both nodes.

#### The Node SDN
Edit the `/etc/sysconfig/openshift-sdn-node` file:

    MASTER_URL="http://fqdn.of.master:4001"
    
    MINION_IP="ip.address.of.public.interface"
    
    OPTIONS="-v=4 -hostname fqdn.of.node"

And start the SDN node:

    systemctl start openshift-sdn node

Note that you **must** start the SDN before starting the OpenShift node service.

**BUG** You need to go back and edit `/etc/sysconfig/docker` to re-add the
insecure registry options.

#### The OpenShift Node
Edit the `/etc/sysconfig/openshift-node` file and edit the `OPTIONS` to read:

    OPTIONS="--loglevel=4 --master=fqdn.of.master"

Start the node service:

    systemctl start openshift-node

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
                        "image": "openshift/origin-haproxy-router",
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
change to "running" after a few moments:

    osc get pods
    POD                 CONTAINER(S)                       IMAGE(S)                          HOST                         LABELS              STATUS
    mainrouter          origin-haproxy-router-mainrouter   openshift/origin-haproxy-router   ose3-node2.erikjacobs.com/   <none>              Running

At this point you must update your DNS wildcard entry to point to the IP address
of the host on which the router instance is running.

## Your First Application
At this point you should essentially have a fully-functional V3 OpenShift
environment. It is now time to create the classic "Hello World" application
using some sample code. 

### Grab the Definition JSON
On your **master** node, go ahead and grab the JSON definition:

    cd
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

    cd
    osc create -f ./hello-pod.json

You should see the ID of the pod returned to you:

    hello-openshift

Issue a `get pods` to see that it was, in fact, defined, and to check its
status:

    osc get pods
    # osc get pods
    POD                 CONTAINER(S)                       IMAGE(S)                              HOST                         LABELS                 STATUS
    mainrouter          origin-haproxy-router-mainrouter   openshift/origin-haproxy-router       ose3-node2.erikjacobs.com/   <none>                 Running
    hello-openshift     hello-openshift                    openshift/hello-openshift             ose3-node2.erikjacobs.com/   name=hello-openshift   Pending

When you first issue `get pods`, you will likely see a pending status for the
`hello-openshift` pod. This is because we did not pre-fetch its Docker image, so
the node is pulling it from a registry. Later we will set up a local Docker
registry for OpenShift to use.  In our case, the hello-openshift application is
running on `node2`. 

On the node where your `hello-openshift` application is running once the pod
status shows `Running`, look at the list of Docker containers to see the bound
ports. We should see a Kubernetes `pause` container bound to 6061 on the host
and bound to 8080 on the container.

    docker ps

The `pause` container exists because of the way network namespacing works in
Kubernetes. For the sake of simplicity, think of the `pause` container as
nothing more than a way for the host OS to get an interface created for the
corresponding pod to be able to receive traffic. Deeper understanding of
networking in OpenShift is outside the scope of this material.

To verify that the app is working, on the node running `hello-openshift` you can
issue a curl to the app's port:

    curl http://localhost:6061
    Hello OpenShift!

Hooray!

Go ahead and delete this pod so that you don't get confused in later examples:

    osc delete pod hello-openshift
    
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
          "host": "hello-openshift.cloudapps.erikjacobs.com",
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
  * with the FQDN `hello-openshift.cloudapps.erikjacobs.com`
  * with the `serviceName` directive `hello-openshift-service`

If we work from the route down to the pod:

* The route for `hello-openshift.cloudapps.erikjacobs.com` has an HAProxy pool
* The pool is for any pods in the service whose ID is `hello-openshift-service`,
    via the `serviceName` directive of the route.
* The service `hello-openshift-service` includes every pod who has a label
    `name=hello-openshift-label`
* There is a single pod with a single container that has the label
    `name=hello-openshift-label`

Create the JSON file above on your **master** host in root's home directory. Or
use wget to grab it:

    cd
    wget \
    https://raw.githubusercontent.com/openshift/training/master/test-complete.json

Once you have this file, go ahead and use `osc` to apply it. You should see
something like the following:

    osc apply -f test-complete.json 
    I0121 14:43:40.987895    2202 apply.go:65] Creation succeeded for Pod with name hello-openshift-pod
    I0121 14:43:40.987911    2202 apply.go:65] Creation succeeded for Service with name hello-openshift-service
    I0121 14:43:40.987914    2202 apply.go:65] Creation succeeded for Route with name

You can verify this with other `osc` commands:

    osc get pods
    ...
    hello-openshift-pod/172.17.0.2 ...

    osc get services
    ...
    hello-openshift-service ...

    osc get routes
    ...
    cd0dba9a-a1a5-11e4-bf82-525400b33d1d hello-openshift.cloudapps.erikjacobs.com ...

### Verifying the Routing
Verifying the routing is a little complicated, but not terribly so. First, find
where the router is running using `osc get pods`:

    osc get pods | grep router | awk '{print $4}'
    ose3-node1.erikjacobs.com/

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
        "hello-openshift.cloudapps.erikjacobs.com"
      ],

You know that "it" worked -- the router watcher detected the creation of the
route in OpenShift and added the corresponding configuration to HAProxy.

Go ahead and `exit` from the container, and then curl your fancy,
publicly-accessible OpenShift application!

    [root@mainrouter /]# exit
    logout
    # curl http://hello-openshift.cloudapps.erikjacobs.com
    Hello OpenShift!

Hooray!

## Preparing for STI and Other Things
We mentioned a few times that OpenShift would host its own Docker registry in
order to pull images "locally". Let's take a moment to set that up.

Go ahead and grab the following JSON file -- it contains a number of
configurations to tell OpenShift to stand up the Docker registry image as a
service within OpenShift:

    cd
    wget \
    https://raw.githubusercontent.com/openshift/origin/master/examples/sample-app/docker-registry-config.json

View the contents of the file if you like. When you are ready, go ahead and
apply it with `osc` and you will see some output:

    osc apply -f ~/docker-registry-config.json
    I0126 13:56:20.160177    2189 apply.go:65] Creation succeeded for Service
    with name docker-registry
    I0126 13:56:20.160194    2189 apply.go:65] Creation succeeded for
    DeploymentConfig with name docker-registry

You can use `osc get pods` and `osc get services` to see what happened.

Ultimately, you will have a Docker registry that is being hosted by OpenShift
and that is running on one of your nodes.

TODO: There should be some way once the network overlay is up to be able to
reach the registry from somewhere.

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

need to substitute docker registry ip

    cd
    git clone https://github.com/thoraxe/simple-openshift-sinatra-sti
    cd ~/simple-openshift-sinatra-sti
    rm Dockerfile
    app-gen.go --docker-registry="172.30.17.5:5001" | python -m json.tool >
    ~/simple-sinatra.json

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

