lvcreate -s /dev/ose/base-el7 -L 10G -n ose3-master

git clone https://github.com/coreos/flannel.git
cd flannel
docker run -v `pwd`:/opt/flannel -i -t google/golang /bin/bash -c "cd /opt/flannel && ./build"

sed -i -e 's/^el7base/ose3-master.erikjacobs.com/' /etc/hostname; hostname \
ose3-master.erikjacobs.com; exit

sed -i -e 's/^el7base/ose3-node1.erikjacobs.com/' /etc/hostname; hostname \
ose3-node1.erikjacobs.com; exit
