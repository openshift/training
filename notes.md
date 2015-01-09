lvcreate -s /dev/ose/base-el7 -L 10G -n ose3-master

git clone https://github.com/coreos/flannel.git
cd flannel
docker run -v `pwd`:/opt/flannel -i -t google/golang /bin/bash -c "cd /opt/flannel && ./build"

sed -i -e 's/^el7base/ose3-master.erikjacobs.com/' /etc/hostname; hostname \
ose3-master.erikjacobs.com; exit

sed -i -e 's/^el7base/ose3-node1.erikjacobs.com/' /etc/hostname; hostname \
ose3-node1.erikjacobs.com; exit


curl -L http://127.0.0.1:4001/v2/keys/coreos.com/network/config \
-XPUT -d value='{
"Network": "192.168.133.0/24",
"SubnetLen": 29,
"SubnetMin": "192.168.133.8",
"SubnetMax": "192.168.133.248",
"Backend": {"Type": "udp",
"Port": 7890}}'


docker run -i -t google/golang /bin/bash
