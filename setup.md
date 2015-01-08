# Setting Up the Environment
For each VM:

1. el7 minimal installation
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

1. enable and start docker

        systemctl enable docker; systemctl start docker

1. (optional) install ruby/rubygems (for tmuxinator):

        yum install ruby rubygems

1. (optional) install tmuxinator

        gem install tmuxinator

1. set up your Go environment:

        mkdir $HOME/go
        sed -i -e '/^PATH\=.*/i \export GOPATH=$HOME/go' \
        -e "s/^PATH=.*/PATH=\$PATH:\$HOME\/bin:\$GOPATH\/bin\//" \
        ~/.bash_profile
        source ~/.bash_profile

1. clone the origin git repository:

        git clone https://github.com/openshift/origin.git

1. build the openshift project:

        cd origin/hack
        ./build-go.sh

Do we need to disable firewalld?

You definitely need to restart at this point.

# Running a Master
