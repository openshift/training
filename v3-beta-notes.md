deltarpm iptables-services

Docker images:
docker images | grep ago | awk {'print $3'} | xargs docker rmi -f
docker pull 10.3.13.28:5000/openshift/origin-haproxy-router
docker pull 10.3.13.28:5000/openshift/origin-deployer
docker pull 10.3.13.28:5000/openshift/origin-sti-builder
docker pull 10.3.13.28:5000/openshift/origin-docker-builder
docker pull google/golang
docker tag 10.3.13.28:5000/openshift/origin-haproxy-router openshift/origin-haproxy-router
docker tag 10.3.13.28:5000/openshift/origin-deployer openshift/origin-deployer
docker tag 10.3.13.28:5000/openshift/origin-sti-builder openshift/origin-sti-builder
docker tag 10.3.13.28:5000/openshift/origin-docker-builder openshift/origin-docker-builder

DOCKER_OPTIONS='--insecure-registry=0.0.0.0/0 -b=lbr0 --mtu=1450 --selinux-enabled'

## start master
sed -i -e 's/^OPTIONS=.*/OPTIONS="--loglevel=4 --public-master=ose3-master.example.com --nodes=ose3-master.example.com,ose3-node1.example.com,ose3-node2.example.com"/' /etc/sysconfig/openshift-master
sed -i -e 's/^OPTIONS=.*/OPTIONS=-v=4/' /etc/sysconfig/openshift-sdn-master
sed -i -e 's/^MASTER_URL=.*/MASTER_URL=http:\/\/ose3-master.example.com:4001/' \
-e 's/^MINION_IP=.*/MINION_IP=192.168.133.2/' \
-e 's/^OPTIONS=.*/OPTIONS=-v=4/' \
-e 's/^DOCKER_OPTIONS=.*/DOCKER_OPTIONS="--insecure-registry=0.0.0.0\/0 -b=lbr0 --mtu=1450 --selinux-enabled"/' \
/etc/sysconfig/openshift-sdn-node
sed -i -e 's/OPTIONS=.*/OPTIONS="--loglevel=4 --master=ose3-master.example.com --kubeconfig=\/var\/lib\/openshift\/openshift.local.certificates\/admin\/.kubeconfig"/' /etc/sysconfig/openshift-node

systemctl start openshift-master; systemctl start openshift-sdn-master; systemctl start openshift-sdn-node; systemctl start openshift-node

## start node 1
sed -i -e 's/^MASTER_URL=.*/MASTER_URL=http:\/\/ose3-master.example.com:4001/' \
-e 's/^MINION_IP=.*/MINION_IP=192.168.133.3/' \
-e 's/^OPTIONS=.*/OPTIONS=-v=4/' \
-e 's/^DOCKER_OPTIONS=.*/DOCKER_OPTIONS="--insecure-registry=0.0.0.0\/0 -b=lbr0 --mtu=1450 --selinux-enabled"/' \
/etc/sysconfig/openshift-sdn-node
sed -i -e 's/OPTIONS=.*/OPTIONS="--loglevel=4 --master=ose3-master.example.com --kubeconfig=\/var\/lib\/openshift\/openshift.local.certificates\/admin\/.kubeconfig"/' /etc/sysconfig/openshift-node
rsync -av root@ose3-master.example.com:/var/lib/openshift/openshift.local.certificates /var/lib/openshift/

## start node 2
sed -i -e 's/^MASTER_URL=.*/MASTER_URL=http:\/\/ose3-master.example.com:4001/' \
-e 's/^MINION_IP=.*/MINION_IP=192.168.133.4/' \
-e 's/^OPTIONS=.*/OPTIONS=-v=4/' \
-e 's/^DOCKER_OPTIONS=.*/DOCKER_OPTIONS="--insecure-registry=0.0.0.0\/0 -b=lbr0 --mtu=1450 --selinux-enabled"/' \
/etc/sysconfig/openshift-sdn-node
sed -i -e 's/OPTIONS=.*/OPTIONS="--loglevel=4 --master=ose3-master.example.com --kubeconfig=\/var\/lib\/openshift\/openshift.local.certificates\/admin\/.kubeconfig"/' /etc/sysconfig/openshift-node
rsync -av root@ose3-master.example.com:/var/lib/openshift/openshift.local.certificates /var/lib/openshift/

## install router
~/origin/hack/install-router.sh mainrouter \
https://ose3-master.erikjacobs.com:8443 \
/root/origin/_output/local/go/bin/osc

docker run -i -t google/golang /bin/bash

shifter / PqSFcreJYuto
