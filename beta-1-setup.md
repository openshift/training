# OpenShift Beta 1 Setup Information
## Setting Up the Environment
For **each** VM:

1. el7 minimal installation
Do we need to disable firewalld?
1. SELinux *permissive* or *disabled*
1. subscribed/registered to red hat
1. enable repos:

        subscription-manager repos --enable=rhel-7-server-rpms \
        --enable=rhel-7-server-extras-rpms --enable=rhel-7-server-optional-rpms

1. update:

        yum -y update

    You may wish to restart at this point.

1. install missing packages:

        yum install wget vim-enhanced net-tools bind-utils tmux git golang \
        docker

We suggest running the Docker registry on the OpenShift Master, which is why we
install Docker on all the systems.

1. set up your Go environment:

        mkdir $HOME/go
        sed -i -e '/^PATH\=.*/i \export GOPATH=$HOME/go' \
        -e "s/^PATH=.*/PATH=\$PATH:\$HOME\/bin:\$GOPATH\/bin\//" \
        ~/.bash_profile
        source ~/.bash_profile

1. clone the origin git repository:

        cd; git clone https://github.com/openshift/origin.git

1. build the openshift project:

        cd ~/origin/hack
        ./build-go.sh

1. Since OpenShift doesn't yet have networking overlay support in the box, we
    can use CoreOS'
    [Flannel]( http://www.slideshare.net/lorispack/using-coreos-flannel-for-docker-networking )
    to handle persistent network overlay things.

    The first step is to build Flannel:

        cd; git clone https://github.com/coreos/flannel.git
        cd flannel
        docker run -v `pwd`:/opt/flannel -i -t google/golang /bin/bash \
        -c "cd /opt/flannel && ./build"

1. Since we are going to use Flannel to connect Docker images
on a 10.0.0.0/8 net, we want to configure Docker to trust any insecure registry
that it finds there. The following will instruct the Docker daemon to trust
*any* Docker registry on the subnet, rather than requiring a certificate.

        sed -i -e 's/^OPTIONS.*/OPTIONS=--insecure-registry 10.0.0.0\/8 -H fd:\/\//' /etc/sysconfig/docker

1. Enable Docker

        systemctl enable docker

1. Restart your system.

## Use a Terminal Window Manager
We **strongly** recommend that you use some kind of terminal window manager
(Screen, Tmux).

## Additional Master Setup Steps
1. Grab a Docker registry for OpenShift to use to store images:

        docker pull openshift/docker-registry

## Running a Master
The Beta 1 setup assumes one master and two nodes. Running the master in a tmux
or screen session will help enable you to do other things on the master while
OpenShift is still running.

1. On the VM that you wish to be the OpenShift master, execute the following:

        ~/origin/_output/local/bin/linux/amd64/openshift start master \
        --nodes=IP1,IP2,IP3...

    For example:
    
        ~/origin/_output/local/bin/linux/amd64/openshift start master \
        --nodes=192.168.122.167

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

1. Edit the `OPTIONS=` line of your `/etc/sysconfig/docker` file with this new
information. For exmple:

        OPTIONS=--bip=10.14.96.1/20 --mtu=1472 =--insecure-registry 10.0.0.0/8 -H fd://

1. Restart Docker

        systemctl restart docker

## Running a node
On each VM that we will use as a node, we have to perform the same Docker set up
with Flannel information.  Flannel on the node needs to communicate with etcd on
the master in order to get the configuration information.

1. Run Flannel, specifying the IP address of the OpenShift master as the etcd
server:

        ~/flannel/bin/flanneld --etcd-endpoints="http://192.168.122.10:4001"

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
        --master=MASTER_IP
