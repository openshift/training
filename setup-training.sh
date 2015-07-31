#!/bin/bash
# prep dns
for node in ose3-master ose3-node1 ose3-node2; do ssh -o StrictHostKeyChecking=no root@$node "sed -e '/^nameserver .*/i nameserver 192.168.133.4' -i /etc/resolv.conf"; done
ssh root@ose3-node2 "systemctl start dnsmasq"
ssh root@ose3-node2 "sed -i /etc/sysconfig/iptables -e '/^-A INPUT -p tcp -m state/i -A INPUT -p udp -m udp --dport 53 -j ACCEPT'"

# pull content and install
cd
git clone https://github.com/openshift/training 
git clone https://github.com/openshift/openshift-ansible
/bin/cp ~/training/content/sample-ansible-hosts /etc/ansible/hosts
cd openshift-ansible
ansible-playbook playbooks/byo/config.yml

# label nodes
oc label node/ose3-master.example.com region=infra zone=default
oc label node/ose3-node1.example.com region=primary zone=east
oc label node/ose3-node2.example.com region=primary zone=west

# configure default nodeselector for system and default namespace
sed -i /etc/openshift/master/master-config.yaml -e 's/defaultNodeSelector: ""/defaultNodeSelector: "region=primary"/'
systemctl restart openshift-master
sleep 5
oc get namespace default -o json | sed -e '/"openshift.io\/sa.scc.mcs"/i "openshift.io/node-selector": "region=infra",' | oc update -f -

# setup dev users
useradd joe
useradd alice
touch /etc/openshift/openshift-passwd
htpasswd -b /etc/openshift/openshift-passwd joe redhat
htpasswd -b /etc/openshift/openshift-passwd alice redhat

# install router
cd
CA=/etc/openshift/master
oadm create-server-cert --signer-cert=$CA/ca.crt \
      --signer-key=$CA/ca.key --signer-serial=$CA/ca.serial.txt \
      --hostnames='*.cloudapps.example.com' \
      --cert=cloudapps.crt --key=cloudapps.key
cat cloudapps.crt cloudapps.key $CA/ca.crt > cloudapps.router.pem
oadm router --default-cert=cloudapps.router.pem \
--credentials=/etc/openshift/master/openshift-router.kubeconfig \
--images='registry.access.redhat.com/openshift3/ose-${component}:${version}'

# prep nfs for registry
mkdir -p /var/export/regvol
chown nfsnobody:nfsnobody /var/export/regvol
chmod 700 /var/export/regvol
echo "/var/export/regvol *(rw,sync,all_squash)" > /etc/exports
iptables -I OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 111 -j ACCEPT
iptables -I OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 2049 -j ACCEPT
iptables -I OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 20048 -j ACCEPT
iptables -I OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 50825 -j ACCEPT
iptables -I OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 53248 -j ACCEPT
sed -i -e '/^COMMIT$/i -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 53248 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 50825 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 20048 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 2049 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 111 -j ACCEPT/' \
/etc/sysconfig/iptables
sed -i -e 's/^RPCMOUNTDOPTS.*/RPCMOUNTDOPTS="-p 20048"/' -e 's/^STATDARG.*/STATDARG="-p 50825"/' /etc/sysconfig/nfs
cat << EOF >> /etc/sysctl.conf
fs.nfs.nlm_tcpport=53248
fs.nfs.nlm_udpport=53248
EOF
systemctl enable rpcbind nfs-server
systemctl start rpcbind nfs-server nfs-lock 
systemctl start nfs-idmap
sysctl -p
systemctl restart nfs
setsebool -P virt_use_nfs=true

# install registry
oadm registry --create \
--credentials=/etc/openshift/master/openshift-registry.kubeconfig \
--images='registry.access.redhat.com/openshift3/ose-${component}:${version}'

# reduce registry scale to zero
oc scale rc/docker-registry-1 --replicas=1
sleep 5

# setup volumes and claims
oc create -f ~/training/content/registry-volume.json
oc create -f ~/training/content/registry-claim.json
sleep 5
oc volume dc/docker-registry --add --overwrite -t persistentVolumeClaim \
--claim-name=registry-claim --name=registry-storage

