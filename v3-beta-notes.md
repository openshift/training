deltarpm iptables-services

Docker images:
docker images | grep ago | awk {'print $3'} | xargs docker rmi -f
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-haproxy-router
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-deployer
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-builder
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-image-builder
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-builder
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-pod
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/docker-registry
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-builder openshift3_beta/ose-sti-builder
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-image-builder openshift3_beta/ose-sti-image-builder
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-builder openshift3_beta/ose-docker-builder
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-deployer openshift3_beta/ose-deployer
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-haproxy-router openshift3_beta/ose-haproxy-router
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-pod openshift3_beta/ose-pod
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/docker-registry openshift3_beta/ose-docker-registry
docker pull google/golang

DOCKER_OPTIONS='--insecure-registry=0.0.0.0/0 -b=lbr0 --mtu=1450 --selinux-enabled'

## start master
sed -i -e 's/^OPTIONS=.*/OPTIONS="--loglevel=4 --public-master=ose3-master.example.com"/' \
-e 's/^IMAGES=.*/IMAGES=openshift3_beta\/ose-\$\{component\}/' \
/etc/sysconfig/openshift-master
sed -i -e 's/^OPTIONS=.*/OPTIONS=-v=4/' /etc/sysconfig/openshift-sdn-master
sed -i -e 's/^MASTER_URL=.*/MASTER_URL=http:\/\/ose3-master.example.com:4001/' \
-e 's/^MINION_IP=.*/MINION_IP=192.168.133.2/' \
-e 's/^OPTIONS=.*/OPTIONS=-v=4/' \
-e 's/^DOCKER_OPTIONS=.*/DOCKER_OPTIONS="--insecure-registry=0.0.0.0\/0 -b=lbr0 --mtu=1450 --selinux-enabled"/' \
/etc/sysconfig/openshift-sdn-node
sed -i -e 's/OPTIONS=.*/OPTIONS="--loglevel=4 --master=ose3-master.example.com"/' \
-e 's/IMAGES=.*/IMAGES=openshift3_beta\/ose-\$\{component\}/' \
/etc/sysconfig/openshift-node

systemctl start openshift-master; systemctl start openshift-sdn-master; systemctl start openshift-sdn-node; systemctl start openshift-node

## start node 1
sed -i -e 's/^MASTER_URL=.*/MASTER_URL=http:\/\/ose3-master.example.com:4001/' \
-e 's/^MINION_IP=.*/MINION_IP=192.168.133.3/' \
-e 's/^OPTIONS=.*/OPTIONS=-v=4/' \
-e 's/^DOCKER_OPTIONS=.*/DOCKER_OPTIONS="--insecure-registry=0.0.0.0\/0 -b=lbr0 --mtu=1450 --selinux-enabled"/' \
/etc/sysconfig/openshift-sdn-node
sed -i -e 's/OPTIONS=.*/OPTIONS="--loglevel=4 --master=ose3-master.example.com"/' \
-e 's/IMAGES=.*/IMAGES=openshift3_beta\/ose-\$\{component\}/' \
/etc/sysconfig/openshift-node
rsync -av root@ose3-master.example.com:/var/lib/openshift/openshift.local.certificates /var/lib/openshift/

## start node 2
sed -i -e 's/^MASTER_URL=.*/MASTER_URL=http:\/\/ose3-master.example.com:4001/' \
-e 's/^MINION_IP=.*/MINION_IP=192.168.133.4/' \
-e 's/^OPTIONS=.*/OPTIONS=-v=4/' \
-e 's/^DOCKER_OPTIONS=.*/DOCKER_OPTIONS="--insecure-registry=0.0.0.0\/0 -b=lbr0 --mtu=1450 --selinux-enabled"/' \
/etc/sysconfig/openshift-sdn-node
sed -i -e 's/OPTIONS=.*/OPTIONS="--loglevel=4 --master=ose3-master.example.com"/' \
-e 's/IMAGES=.*/IMAGES=openshift3_beta\/ose-\$\{component\}/' \
/etc/sysconfig/openshift-node
rsync -av root@ose3-master.example.com:/var/lib/openshift/openshift.local.certificates /var/lib/openshift/

docker run -i -t google/golang /bin/bash
