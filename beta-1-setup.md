# OpenShift Beta 1 Setup Information
## Use a Terminal Window Manager
We **strongly** recommend that you use some kind of terminal window manager
(Screen, Tmux).

## Setting Up the Environment
### Each VM

Each of the virtual machines should have 4+ GB of memory and the following
configuration:

* el7 minimal installation
* firewalld disabled
* SELinux *permissive* or *disabled*
* subscribed/registered to red hat
* enable repos:

        subscription-manager repos --enable=rhel-7-server-rpms \
        --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-optional-rpms

Once you have prepared your VMs, you can do the following on **each** VM:

1. Update:

        yum -y update

    You may wish to restart systems at this point.

1. Install missing packages:

        yum install wget vim-enhanced net-tools bind-utils tmux git golang \
        docker

    We suggest running the Docker registry on the OpenShift Master, which is why we
    install Docker on all the systems.

1. Set up your Go environment and your paths:

        mkdir $HOME/go
        sed -i -e '/^PATH\=.*/i \export GOPATH=$HOME/go' \
        -e '/^PATH\=.*/i \export OSEPATH=~\/origin\/_output\/local\/bin\/linux\/amd64\/' \
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

1. Restart your system.

### Grab Docker Images
On all of your systems (for convenience):

1. Grab a Docker registry for OpenShift to use to store images:

        docker pull openshift/docker-registry

1. Grab the OpenShift Origin haproxy router:

        docker pull openshift/origin-haproxy-router

## Starting the OpenShift Services
### Running a Master
The Beta 1 setup assumes one master and two nodes. Running the master in a tmux
or screen session will help enable you to do other things on the master while
OpenShift is still running.

1. On the VM that you wish to be the OpenShift master, execute the following:

        ~/origin/_output/local/bin/linux/amd64/openshift start master \
        --nodes=hostname1,hostname2,hostname3

    For example:
    
        ~/origin/_output/local/bin/linux/amd64/openshift start master \
        --nodes=ose3-node1.erikjacobs.com,ose3-node2.erikjacobs.com

    You must use hostnames and the hostnames that you use must match the output
    of `hostname -f` on each of your nodes. By extension, you must at least have
    all hostname/ip mappings in /etc/hosts files or forward DNS should work.

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

TODO: pod = group of containers on same host, sharing network namespace
pause container sets up interface so that traffic can get to bound application

In the simplest sense, a *pod* is an application or an instance of something. If
you are familiar with OpenShift V2 terminology, it is similar to a *gear*. We
will learn more about the terms as we explore OpenShift further.

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
    POD                 CONTAINER(S)                       IMAGE(S)
    HOST                         LABELS                 STATUS
    mainrouter          origin-haproxy-router-mainrouter  openshift/origin-haproxy-router   ose3-node2.erikjacobs.com/   <none> Running
    hello-openshift     hello-openshift   openshift/hello-openshift ose3-node2.erikjacobs.com/ name=hello-openshift   Pending

When you first issue `get pods`, you will likely see a pending status for the
`hello-openshift` pod. This is because we did not pre-fetch its Docker image, so
the node is pulling it from a registry. Later we will set up a local Docker
registry for OpenShift to use.

In our case, the hello-openshift application is running on `node2`. On the node
where your `hello-openshift` application is running once the pod status shows
`Running`, look at the list of Docker containers to see the bound ports. We
should see a Kubernetes `pause` container bound to 6061 on the host and bound to
8080 on the container:

    CONTAINER ID        IMAGE                                    COMMAND
    CREATED             STATUS              PORTS                    NAMES
    142e1f263b3b        openshift/hello-openshift:latest         "/hello_openshift"
    2 minutes ago       Up 2 minutes
    k8s_hello-openshift.ef40aae8_hello-openshift.default.etcd_4071b202-a0ea-11e4-80cc-525400b33d1d_2811a558               
    9478243ea9de        kubernetes/pause:go                      "/pause"
    2 minutes ago       Up 2 minutes        0.0.0.0:6061->8080/tcp
    k8s_net.f1ce8da9_hello-openshift.default.etcd_4071b202-a0ea-11e4-80cc-525400b33d1d_10cd9672

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

services are for "inside" kubernetes

routes allow traffic from edge to reach kubernetes service


router watches routes resource on master
osc create routes json
creates new instance of "a route resource"
openshift router is watching that resource
router servicename field 

route "serviceName" matches service id(name)
service selector key/value pair associates with any pods that have matching
  label key/value pair

router watches endpoints of services and will proxy routes directly to service
endpoints


