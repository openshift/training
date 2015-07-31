#!/bin/bash
echo
echo "Preparing DNS..."
for node in ose3-master ose3-node1 ose3-node2; do ssh -o StrictHostKeyChecking=no root@$node "sed -e '/^nameserver .*/i nameserver 192.168.133.4' -i /etc/resolv.conf"; done
ssh root@ose3-node2 "systemctl start dnsmasq"
ssh root@ose3-node2 "sed -i /etc/sysconfig/iptables -e '/^-A INPUT -p tcp -m state/i -A INPUT -p udp -m udp --dport 53 -j ACCEPT'"

echo
echo "Pulling content and running installation..."
cd
git clone https://github.com/openshift/training 
git clone https://github.com/openshift/openshift-ansible
/bin/cp ~/training/content/sample-ansible-hosts /etc/ansible/hosts
cd openshift-ansible
ansible-playbook playbooks/byo/config.yml

echo
echo "Labeling nodes..."
oc label node/ose3-master.example.com region=infra zone=default
oc label node/ose3-node1.example.com region=primary zone=east
oc label node/ose3-node2.example.com region=primary zone=west

echo
echo "Configure default routing domain..."
sed -i 's/subdomain: router.default.local/subdomain: cloudapps.example.com/' /etc/openshift/master/master-config.yaml

echo
echo "Configure default nodeselector for system and default namespace..."
sed -i /etc/openshift/master/master-config.yaml -e 's/defaultNodeSelector: ""/defaultNodeSelector: "region=primary"/'
systemctl restart openshift-master
sleep 5
oc get namespace default -o json | sed -e '/"openshift.io\/sa.scc.mcs"/i "openshift.io/node-selector": "region=infra",' | oc update -f -

echo
echo "Setting up development users..."
useradd joe
useradd alice
touch /etc/openshift/openshift-passwd
htpasswd -b /etc/openshift/openshift-passwd joe redhat
htpasswd -b /etc/openshift/openshift-passwd alice redhat

echo
echo "Installing router..."
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

echo
echo "Preparing NFS on master for registry..."
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

echo
echo "Installing Docker registry..."
oadm registry --create \
--credentials=/etc/openshift/master/openshift-registry.kubeconfig \
--images='registry.access.redhat.com/openshift3/ose-${component}:${version}'

echo
echo "Scaling first registry to zero..."
oc scale rc/docker-registry-1 --replicas=0
sleep 5

echo
echo "Setting up storage volumes and claims..."
oc create -f ~/training/content/registry-volume.json
oc create -f ~/training/content/registry-claim.json
sleep 5

echo
echo "Adding the claimed volume to the Docker registry..."
oc volume dc/docker-registry --add --overwrite -t persistentVolumeClaim \
--claim-name=registry-claim --name=registry-storage

# should wait until registry is ready with a loop
echo
echo "Waiting 30 seconds for registry to come up..."
sleep 30
# should fail if we wait too long

echo
echo "Creating project for joe..."
oadm new-project demo --display-name="OpenShift 3 Demo" \
--description="This is the first demo project with OpenShift v3" \
--admin=joe

echo
echo "Adding complete definition in demo project..."
oc create -f ~/training/content/test-complete.json -n demo

# should wait for pod in a loop
echo
echo "Waiting 40 seconds for pod to come up..."
sleep 40
# should fail if we wait too long

echo
echo "Testing routing..."
curl -sSf --cacert /etc/openshift/master/ca.crt https://hello-openshift.cloudapps.example.com
if [[ $? == 0 ]]; then
        echo 'Router is working!'
else
        echo "**** ROUTER IS FAILED ****"
fi

echo
echo "Setting up S2I project..."
oadm new-project sinatra --display-name="Sinatra Example" \
--description="This is your first build on OpenShift 3" \
--admin=joe

echo
echo "Using new-app to create content..."
oc new-app https://github.com/openshift/simple-openshift-sinatra-sti.git -n sinatra

echo
echo "Creating route..."
oc expose service simple-openshift-sinatra -n sinatra

# should expect build to start at some point before waiting to complete

echo
echo "Waiting for build to complete..."
until [[ $(oc get pod -n sinatra | grep build | awk '{print $3}') == *"Exit"* ]]; do
        echo -n "."
        sleep 1
done
echo ""
# should fail if we wait too long

# should test if build tries to deploy
# should fail if deploy fails

