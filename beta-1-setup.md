# OpenShift Beta 1 Setup Information
## Use a Terminal Window Manager
We **strongly** recommend that you use some kind of terminal window manager
(Screen, Tmux).

## Setting Up the Environment
### Each VM

1. el7 minimal installation
    firewalld disabled
1. SELinux *permissive* or *disabled*
1. subscribed/registered to red hat
1. enable repos:

        subscription-manager repos --enable=rhel-7-server-rpms \
        --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-optional-rpms

1. Update:

        yum -y update

    You may wish to restart systems at this point.

1. Install missing packages:

        yum install wget vim-enhanced net-tools bind-utils tmux git golang \
        docker

    We suggest running the Docker registry on the OpenShift Master, which is why we
    install Docker on all the systems.

1. Set up your Go environment and your paths:
    TODO: add openshift path

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

1. Since OpenShift doesn't yet have networking overlay support in the box, we
    can use CoreOS'
    [Flannel]( http://www.slideshare.net/lorispack/using-coreos-flannel-for-docker-networking )
    to handle persistent network overlay things. We are using 10.0.0.0/8 as
    our example.

    The first step is to build Flannel:

        cd; git clone https://github.com/coreos/flannel.git
        cd ~/flannel
        docker run -v `pwd`:/opt/flannel -i -t google/golang /bin/bash \
        -c "cd /opt/flannel && ./build"

1. Enable Docker

        systemctl enable docker

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

TODO: flannel replaced by OVS stuff in beta1
1. Now that OpenShift is running, we have a running etcd. So we can tell it about
our Flannel network config:

        curl -L http://127.0.0.1:4001/v2/keys/coreos.com/network/config \
        -XPUT -d value='{
        "Network": "10.0.0.0/8",
        "SubnetLen": 20,
        "SubnetMin": "10.10.0.0",
        "SubnetMax": "10.99.0.0",
        "Backend": {"Type": "udp",
        "Port": 7890}}'

1. And we can now run Flannel:

        ~/flannel/bin/flanneld

1. With Flannel running, we need to ask it what subnet was assigned for this
particular Docker host:

        cat /run/flannel/subnet.env

    You will see something like:

        FLANNEL_SUBNET=10.14.96.1/20
        FLANNEL_MTU=1472

1. Set Docker's interface's IP to our new bridge IP:

        ifconfig docker0 10.14.96.1/20

1. Edit the `OPTIONS=` line of your `/etc/sysconfig/docker` file with this new
information. For exmple:

        OPTIONS=--bip=10.14.96.1/20 --mtu=1472 --insecure-registry 10.0.0.0/8 -H fd://

    The `--insecure-registry` option tells Docker to trust any registry on the
    specified subnet, without requiring a certificate.

** firewall stuff is still in progress -- don't do this **

1. Add iptables port rules for flanneld and OpenShift by editing
`/etc/sysconfig/iptables`. In between the following rules:

        -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
        -A INPUT -p icmp -j ACCEPT

    Add these rules:

        -A INPUT -p tcp -m state --state NEW -m tcp --dport 4001 -j ACCEPT
        -A INPUT -p tcp -m state --state NEW -m tcp --dport 7001 -j ACCEPT
        -A INPUT -p tcp -m state --state NEW -m tcp --dport 7890 -j ACCEPT
        -A INPUT -p tcp -m state --state NEW -m tcp --dport 8080 -j ACCEPT
        -A INPUT -p tcp -m state --state NEW -m tcp --dport 8081 -j ACCEPT

1. Restart iptables and docker:

        systemctl restart iptables; systemctl restart docker;

### Running a node
On each VM that we will use as a node, we have to perform the same Docker set up
with Flannel information.  Flannel on the node needs to communicate with etcd on
the master in order to get the configuration information.

1. Run Flannel, specifying the IP address of the OpenShift master as the etcd
server. For example:

        ~/flannel/bin/flanneld --etcd-endpoints="http://192.168.133.2:4001"

1. Get the subnet assignment:

        cat /run/flannel/subnet.env

1. Edit the `OPTIONS=` line of your `/etc/sysconfig/docker` file. For example:

        OPTIONS=--bip=10.11.0.1/20 --mtu=1472 --insecure-registry 10.0.0.0/8 -H fd://

1. Set Docker's interface's IP to our new bridge IP:

        ifconfig docker0 10.11.0.1/20

1. Restart Docker

        systemctl restart docker

1. Now you can run OpenShift's node:

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

    # osc get pods
    POD                 CONTAINER(S)                       IMAGE(S)                          HOST                         LABELS              STATUS
    mainrouter          origin-haproxy-router-mainrouter   openshift/origin-haproxy-router   ose3-node2.erikjacobs.com/   <none>              Running
