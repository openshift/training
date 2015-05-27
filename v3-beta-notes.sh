deltarpm iptables-services

curl -i -H "Accept: application/json" -H "X-HTTP-Method-Override: PUT" -X POST
-k
https://ose3-master.example.com:8443/osapi/v1beta1/buildConfigHooks/ruby-sample-build/secret101/generic?namespace=integrated

Docker images:
docker images | grep buildvm | awk {'print $3'} | xargs docker rmi -f
docker images | grep ago | awk {'print $3'} | xargs docker rmi -f
docker images | grep 0.4.1 | awk {'print $3'} | xargs docker rmi -f

for resource in build buildconfig images imagerepository deploymentconfig \
route replicationcontroller service pod; do echo -e "Resource: $resource"; \
osc get $resource; echo -e "\n\n"; done

osc get pods | awk '{print $1"\t"$3"\t"$5"\t"$7"\n"}' | column -t

#beta4
systemctl start docker
yum -y remove '*openshift*'; yum clean all; yum -y install '*openshift*' 
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-haproxy-router:v0.5.2.0
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-deployer:v0.5.2.0
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-builder:v0.5.2.0
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-image-builder:v0.5.2.0
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-builder:v0.5.2.0
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-pod:v0.5.2.0
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-registry:v0.5.2.0
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-haproxy-router:v0.5.2.0 registry.access.redhat.com/openshift3_beta/ose-haproxy-router:v0.5.2.0
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-deployer:v0.5.2.0 registry.access.redhat.com/openshift3_beta/ose-deployer:v0.5.2.0
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-builder:v0.5.2.0 registry.access.redhat.com/openshift3_beta/ose-sti-builder:v0.5.2.0
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-image-builder:v0.5.2.0 registry.access.redhat.com/openshift3_beta/ose-sti-image-builder:v0.5.2.0
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-builder:v0.5.2.0 registry.access.redhat.com/openshift3_beta/ose-docker-builder:v0.5.2.0
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-pod:v0.5.2.0 registry.access.redhat.com/openshift3_beta/ose-pod:v0.5.2.0 
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-registry:v0.5.2.0 registry.access.redhat.com/openshift3_beta/ose-docker-registry:v0.5.2.0

cd
git clone https://github.com/openshift/training.git 
cd ~/training/beta4
/bin/cp ~/training/beta1/dnsmasq.conf /etc/
restorecon -rv /etc/dnsmasq.conf
sed -e '/^nameserver .*/i nameserver 192.168.133.4' -i /etc/resolv.conf
systemctl start dnsmasq
iptables -I INPUT -p udp -m udp --dport 53 -j ACCEPT

sed -e '/^nameserver .*/i nameserver 192.168.133.4' -i /etc/resolv.conf
cd
git clone https://github.com/openshift/training.git
cd
rm -rf openshift-ansible
git clone https://github.com/detiber/openshift-ansible.git -b v3-beta4
cd ~/openshift-ansible
/bin/cp -r ~/training/beta4/ansible/* /etc/ansible/
ansible-playbook playbooks/byo/config.yml

#beta3
systemctl start docker
yum -y remove '*openshift*'; yum clean all; yum -y install '*openshift*' 
docker images -q | xargs -r docker rmi -f
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-haproxy-router:v0.4.3.2
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-deployer:v0.4.3.2
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-builder:v0.4.3.2
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-image-builder:v0.4.3.2
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-builder:v0.4.3.2
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-pod:v0.4.3.2
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-registry:v0.4.3.2
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-haproxy-router:v0.4.3.2 registry.access.redhat.com/openshift3_beta/ose-haproxy-router:v0.4.3.2
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-deployer:v0.4.3.2 registry.access.redhat.com/openshift3_beta/ose-deployer:v0.4.3.2
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-builder:v0.4.3.2 registry.access.redhat.com/openshift3_beta/ose-sti-builder:v0.4.3.2
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-image-builder:v0.4.3.2 registry.access.redhat.com/openshift3_beta/ose-sti-image-builder:v0.4.3.2
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-builder:v0.4.3.2 registry.access.redhat.com/openshift3_beta/ose-docker-builder:v0.4.3.2
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-pod:v0.4.3.2 registry.access.redhat.com/openshift3_beta/ose-pod:v0.4.3.2 
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-registry:v0.4.3.2 registry.access.redhat.com/openshift3_beta/ose-docker-registry:v0.4.3.2
docker pull centos:centos7
docker pull openshift/ruby-20-centos7
docker pull openshift/mysql-55-centos7
docker pull openshift/hello-openshift

cd
git clone https://github.com/openshift/training.git 
cd ~/training/beta3
/bin/cp ~/training/beta1/dnsmasq.conf /etc/
restorecon -rv /etc/dnsmasq.conf
sed -e '/^nameserver .*/i nameserver 192.168.133.4' -i /etc/resolv.conf
systemctl start dnsmasq
iptables -I INPUT -p udp -m udp --dport 53 -j ACCEPT

sed -e '/^nameserver .*/i nameserver 192.168.133.4' -i /etc/resolv.conf
cd
git clone https://github.com/openshift/training.git
cd
rm -rf openshift-ansible
git clone https://github.com/detiber/openshift-ansible.git -b v3-beta3
cd ~/openshift-ansible
/bin/cp -r ~/training/beta3/ansible/* /etc/ansible/
ansible-playbook playbooks/byo/config.yml
sed -i -e 's/name: anypassword/name: apache_auth/' \
-e 's/kind: AllowAllPasswordIdentityProvider/kind: HTPasswdPasswordIdentityProvider/' \
-e '/kind: HTPasswdPasswordIdentityProvider/i \      file: \/etc\/openshift-passwd' \
/etc/openshift/master.yaml
useradd joe
useradd alice
touch /etc/openshift-passwd
htpasswd -b /etc/openshift-passwd joe redhat
htpasswd -b /etc/openshift-passwd alice redhat
systemctl restart openshift-master
osadm router --create \
--credentials=/var/lib/openshift/openshift.local.certificates/openshift-router/.kubeconfig \
--images='registry.access.redhat.com/openshift3_beta/ose-${component}:${version}'
osadm registry --create \
--credentials=/var/lib/openshift/openshift.local.certificates/openshift-registry/.kubeconfig \
--images='registry.access.redhat.com/openshift3_beta/ose-${component}:${version}'

# beta2
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-haproxy-router:v0.4
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-deployer:v0.4
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-builder:v0.4
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-image-builder:v0.4
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-builder:v0.4
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-pod:v0.4
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-registry:v0.4
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-haproxy-router:v0.4 registry.access.redhat.com/openshift3_beta/ose-haproxy-router:v0.4
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-deployer:v0.4 registry.access.redhat.com/openshift3_beta/ose-deployer:v0.4
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-builder:v0.4 registry.access.redhat.com/openshift3_beta/ose-sti-builder:v0.4
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-image-builder:v0.4 registry.access.redhat.com/openshift3_beta/ose-sti-image-builder:v0.4
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-builder:v0.4 registry.access.redhat.com/openshift3_beta/ose-docker-builder:v0.4
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-pod:v0.4 registry.access.redhat.com/openshift3_beta/ose-pod:v0.4 
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-registry:v0.4 registry.access.redhat.com/openshift3_beta/ose-docker-registry:v0.4

cd
git clone https://github.com/openshift/training.git
cd ~/training/beta2
/bin/cp ~/training/beta1/dnsmasq.conf /etc/
restorecon -rv /etc/dnsmasq.conf
sed -e '/^nameserver .*/i nameserver 192.168.133.2' -i /etc/resolv.conf
systemctl start dnsmasq
cd
rm -rf openshift-ansible
git clone https://github.com/detiber/openshift-ansible.git -b v3-beta2
cd ~/openshift-ansible
mv -f ~/training/beta2/ansible/* /etc/ansible
ansible-playbook playbooks/byo/config.yml
useradd joe
useradd alice
yum -y install httpd-tools
touch /etc/openshift-passwd
htpasswd -b /etc/openshift-passwd joe redhat
htpasswd -b /etc/openshift-passwd alice redhat
cat <<EOF >> /etc/sysconfig/openshift-master
OPENSHIFT_OAUTH_REQUEST_HANDLERS=session,basicauth
OPENSHIFT_OAUTH_HANDLER=login
OPENSHIFT_OAUTH_PASSWORD_AUTH=htpasswd
OPENSHIFT_OAUTH_HTPASSWD_FILE=/etc/openshift-passwd
OPENSHIFT_OAUTH_ACCESS_TOKEN_MAX_AGE_SECONDS=172800
EOF
systemctl restart openshift-master
openshift ex router --create --credentials=/root/.kube/.kubeconfig \
--images='registry.access.redhat.com/openshift3_beta/ose-${component}:${version}'
openshift ex registry --create --credentials=/root/.kube/.kubeconfig \
--images='registry.access.redhat.com/openshift3_beta/ose-${component}:${version}'

cd
mkdir .kube
cd ~/.kube
openshift ex login \
--certificate-authority=/var/lib/openshift/openshift.local.certificates/ca/root.crt \
--cluster=master --server=https://ose3-master.example.com:8443 \
--namespace=demo

cd
git clone https://github.com/openshift/training.git
cd ~/training/beta2

cd
mkdir .kube
cd ~/.kube
openshift ex login \
--certificate-authority=/var/lib/openshift/openshift.local.certificates/ca/root.crt \
--cluster=master --server=https://ose3-master.example.com:8443 \
--namespace=wiring

cd
git clone https://github.com/openshift/training.git
cd ~/training/beta2

osc get buildconfig ruby-sample-build -o yaml | sed -e \
's/openshift\/ruby-hello-world/thoraxe\/ruby-hello-world/' | osc update \
buildconfig ruby-sample-build -f -

sed -e '/^nameserver .*/i nameserver 192.168.133.2' -i /etc/resolv.conf

for resource in build buildconfig images imagerepository deploymentconfig \
route replicationcontroller service pod; do echo -e "Resource: $resource"; \
osc delete $resource; echo -e "\n\n"; done

for resource in build buildconfig images imagerepository deploymentconfig \
route replicationcontroller service pod; do echo -e "Resource: $resource"; \
osc get $resource; echo -e "\n\n"; done

# beta1
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-haproxy-router:v0.3
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-registry:v0.3
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-deployer:v0.3
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-builder:v0.3
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-builder:v0.3
docker pull docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-pod:v0.3
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-haproxy-router:v0.3 registry.access.redhat.com/openshift3_beta/ose-haproxy-router:v0.3
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-deployer:v0.3 registry.access.redhat.com/openshift3_beta/ose-deployer:v0.3
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-sti-builder:v0.3 registry.access.redhat.com/openshift3_beta/ose-sti-builder:v0.3
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-builder:v0.3 registry.access.redhat.com/openshift3_beta/ose-docker-builder:v0.3
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-pod:v0.3 registry.access.redhat.com/openshift3_beta/ose-pod:v0.3 
docker tag docker-buildvm-rhose.usersys.redhat.com:5000/openshift3_beta/ose-docker-registry:v0.3 registry.access.redhat.com/openshift3_beta/ose-docker-registry:v0.3

DOCKER_OPTIONS='--insecure-registry=0.0.0.0/0 -b=lbr0 --mtu=1450 --selinux-enabled'

## start master
cd ~/training
git pull origin master
mv -f ~/training/beta1/dnsmasq.conf /etc/
restorecon -rv /etc/dnsmasq.conf
sed -e '/^nameserver .*/i nameserver 192.168.133.2' -i /etc/resolv.conf
systemctl start dnsmasq
sed -i -e 's/^OPTIONS=.*/OPTIONS="--loglevel=4 --public-master=ose3-master.example.com"/' \
/etc/sysconfig/openshift-master
sed -i -e 's/^OPTIONS=.*/OPTIONS=-v=4/' /etc/sysconfig/openshift-sdn-master
sed -i -e 's/^MASTER_URL=.*/MASTER_URL=http:\/\/ose3-master.example.com:4001/' \
-e 's/^MINION_IP=.*/MINION_IP=192.168.133.2/' \
-e 's/^OPTIONS=.*/OPTIONS=-v=4/' \
-e 's/^DOCKER_OPTIONS=.*/DOCKER_OPTIONS="--insecure-registry=0.0.0.0\/0 -b=lbr0 --mtu=1450 --selinux-enabled"/' \
/etc/sysconfig/openshift-sdn-node
sed -i -e 's/OPTIONS=.*/OPTIONS="--loglevel=4 --master=ose3-master.example.com"/' \
/etc/sysconfig/openshift-node
systemctl start openshift-master; systemctl start openshift-sdn-master; systemctl start openshift-sdn-node;

## start node 1
sed -e '/^nameserver .*/i nameserver 192.168.133.2' -i /etc/resolv.conf
sed -i -e 's/^MASTER_URL=.*/MASTER_URL=http:\/\/ose3-master.example.com:4001/' \
-e 's/^MINION_IP=.*/MINION_IP=192.168.133.3/' \
-e 's/^OPTIONS=.*/OPTIONS=-v=4/' \
-e 's/^DOCKER_OPTIONS=.*/DOCKER_OPTIONS="--insecure-registry=0.0.0.0\/0 -b=lbr0 --mtu=1450 --selinux-enabled"/' \
/etc/sysconfig/openshift-sdn-node
sed -i -e 's/OPTIONS=.*/OPTIONS="--loglevel=4 --master=ose3-master.example.com"/' \
/etc/sysconfig/openshift-node
rsync -av root@ose3-master.example.com:/var/lib/openshift/openshift.local.certificates /var/lib/openshift/

## start node 2
sed -e '/^nameserver .*/i nameserver 192.168.133.2' -i /etc/resolv.conf
sed -i -e 's/^MASTER_URL=.*/MASTER_URL=http:\/\/ose3-master.example.com:4001/' \
-e 's/^MINION_IP=.*/MINION_IP=192.168.133.4/' \
-e 's/^OPTIONS=.*/OPTIONS=-v=4/' \
-e 's/^DOCKER_OPTIONS=.*/DOCKER_OPTIONS="--insecure-registry=0.0.0.0\/0 -b=lbr0 --mtu=1450 --selinux-enabled"/' \
/etc/sysconfig/openshift-sdn-node
sed -i -e 's/OPTIONS=.*/OPTIONS="--loglevel=4 --master=ose3-master.example.com"/' \
/etc/sysconfig/openshift-node
rsync -av root@ose3-master.example.com:/var/lib/openshift/openshift.local.certificates /var/lib/openshift/

docker run -i -t google/golang /bin/bash

alias denter='bash -c '"'"' nsenter --mount --uts --ipc --net --pid --target $(docker inspect --format {{.State.Pid}} $0)'"'"
