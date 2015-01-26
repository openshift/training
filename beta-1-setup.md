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

### Github
You will need a Github account for the STI examples, or some internal and
accessible Git repository into which you can place application code.

### Each VM

Each of the virtual machines should have 4+ GB of memory and the following
configuration:

* RHEL 7.1 Beta
* "Minimal" installation option
* firewalld and NetworkManager **disabled**
* SELinux **permissive** or **disabled**
* Subscribed and registered to Red Hat
* With these repositories:

        subscription-manager repos --enable=rhel-7-server-rpms \
        --enable=rhel-7-server-extras-rpms \
        --enable=rhel-7-server-optional-rpms \
        --enable=rhel-7-server-openstack-5.0-rpms

TODO: Needs openshift beta repo

Once you have prepared your VMs, you can do the following on **each** VM:

1. Update:

        yum -y update

    You may wish to restart systems at this point.

1. Install missing packages:

        yum install wget vim-enhanced net-tools bind-utils tmux git golang \
        docker openvswitch

    We suggest running the Docker registry on the OpenShift Master, which is why we
    install Docker on all the systems.

1. Enable openvswitch:

        systemctl enable openvswitch

1. Set up your Go environment and your paths:

        mkdir $HOME/go
        sed -i -e '/^PATH\=.*/i \export GOPATH=$HOME/go' \
        -e '/^PATH\=.*/i \export OSEPATH=~\/origin\/_output\/local\/go\/bin\/' \
        -e '/^PATH\=.*/i \export SDNPATH=~\/openshift-sdn\/_output\/local\/go\/bin\/' \
        -e "s/^PATH=.*/PATH=\$PATH:\$HOME\/bin:\$GOPATH\/bin\/:\$OSEPATH/" \
        ~/.bash_profile
        source ~/.bash_profile

1. Clone the origin git repository:

        cd; git clone https://github.com/openshift/origin.git

1. Build the openshift project:

        cd ~/origin/hack
        ./build-go.sh

1. Create an `osc` symlink:

        ln -s ~/origin/_output/local/bin/linux/amd64/openshift \
        ~/origin/_output/local/bin/linux/amd64/osc

1. Edit the `OPTIONS=` line of your `/etc/sysconfig/docker` file:

        OPTIONS=--insecure-registry 192.0.0.0/8 -H fd://

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

        git clone https://github.com/openshift/openshift-sdn
        cd openshift-sdn
        make clean        # optional
        make              # build

1. Restart your system.

### Grab Docker Images
On all of your nodes, grab the following docker images:

        docker pull openshift/docker-registry
        docker pull openshift/origin-sti-builder
        docker pull openshift/origin-deployer
        docker pull openshift/origin-haproxy-router

## Starting the OpenShift Services
### Running a Master
The Beta 1 setup assumes one master and two nodes. Running the master in a tmux
or screen session will help enable you to do other things on the master while
OpenShift is still running.

** workaround for SSL issues with router **

--listen=http://0.0.0.0:8080

1. On the VM that you wish to be the OpenShift master, execute the following:

        ~/origin/_output/local/bin/linux/amd64/openshift start master \
        --nodes=hostname1,hostname2,hostname3

    For example:
    
        ~/origin/_output/local/bin/linux/amd64/openshift start master \
        --nodes=ose3-node1.erikjacobs.com,ose3-node2.erikjacobs.com

    You must use hostnames and the hostnames that you use must match the output
    of `hostname -f` on each of your nodes. By extension, you must at least have
    all hostname/ip mappings in /etc/hosts files or forward DNS should work.

### Setting Up the SDN
Once your master is started, we need to start the SDN (which uses Open vSwitch)
to begin creating our network overlay. Simply execute:

    openshift-sdn

### Running a node
Running a node is similar to running the master. Instead of specifying which
nodes we will look for, we tell the OpenShift program to look for the master:

        ~/origin/_output/local/bin/linux/amd64/openshift start node \
        --master=MASTER_HOSTNAME

### Starting the Router
Earlier, we created the symbolic link for the `osc` program. There is a script
that will configure and start a pod for the HAProxy router that leverages this
command.

On your **master** host, execute the following:

    ~/origin/hack/install-router.sh mainrouter IP_OF_MASTER \
    ~/origin/_output/local/bin/linux/amd64/osc

This command will generate a JSON file for the command-line tool to ingest, and
then will create a pod using this JSON file. Here are sample JSON contents:

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
                        "ports": [{
                            "containerPort": 80,
                            "hostPort": 80
                        }],
                        "command": ["--master=192.168.133.2:8080"],
                        "imagePullPolicy": "PullIfNotPresent"
                    }
                ],
                "restartPolicy": {
                    "always": {}
                }
            }
        }
    }

If this works, you should see the pod status change to "running" after a few
moments:

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
    I0122 10:23:28.599763    4537 apply.go:65] Creation succeeded for Service
    with name docker-registry
    E0122 10:23:28.599777    4537 apply.go:69] Config.item[1].create: invalid
    value '<*>(0xc208209100)deploymentConfig "docker-registry" is invalid:
    template.controllerTemplate.template.spec.containers[0].privileged:
    forbidden 'true'': unable to create:
    {"kind":"DeploymentConfig","apiVersion":"v1beta1","metadata":{"name":"docker-registry","creationTimestamp":null},"triggers":[{"type":"ConfigChange"}],"template":{"strategy":{"type":"Recreate"},"controllerTemplate":{"replicas":1,"replicaSelector":{"name":"registrypod"},"podTemplate":{"desiredState":{"manifest":{"version":"v1beta2","id":"","volumes":[{"name":"registry-storage","source":{"hostDir":{"path":"/tmp/openshift.local.registry"},"emptyDir":null,"persistentDisk":null,"gitRepo":null}}],"containers":[{"name":"registry-container","image":"openshift/docker-registry","command":["sh","-c","REGISTRY_URL=${DOCKER_REGISTRY_SERVICE_HOST}:${DOCKER_REGISTRY_SERVICE_PORT}
    OPENSHIFT_URL=https://${KUBERNETES_SERVICE_HOST}:${KUBERNETES_SERVICE_PORT}/osapi/v1beta1
    OPENSHIFT_INSECURE=true exec
    docker-registry"],"ports":[{"containerPort":5000,"protocol":"TCP"}],"env":[{"name":"STORAGE_PATH","key":"STORAGE_PATH","value":"/tmp/openshift.local.registry"}],"volumeMounts":[{"name":"registry-storage","mountPath":"/tmp/openshift.local.registry","path":"/tmp/openshift.local.registry"}],"privileged":true,"imagePullPolicy":"PullIfNotPresent"}],"restartPolicy":{}}},"labels":{"name":"registrypod"}}}}}

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

