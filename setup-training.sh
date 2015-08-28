#!/bin/bash

function exec_it() {
  if [ $verbose == 1 ] 
  then
    echo "$@"
    "$@"
    echo
  else
    "$@" &> /dev/null
  fi
}

function test_exit() {
  if [ $1 -eq 0 ]
  then
    printf '\033[32m✓ \033[0m'
    printf '%s\n' "$2 passed"
  else
    printf '\033[31m✗ \033[0m'
    printf '%s\n' "$2 failed"
    exit 255
  fi
}

function prepare_dns(){
for node in ose3-master ose3-node1 ose3-node2
do 
  test="Checking $node resolver..."
  exec_it ssh -o StrictHostKeyChecking=no root@$node "grep 133.4 /etc/resolv.conf"
  # need to test whether ssh failed versus whether grep failed
  if [ $? -eq 1 ] 
  then
    test="Setting nameserver for $node..."
    exec_it ssh -o StrictHostKeyChecking=no root@$node "sed -e '/^nameserver .*/i nameserver 192.168.133.4' -i /etc/resolv.conf"
    test_exit $? "$test"
  fi
done
test="Starting dnsmasq..."
exec_it ssh root@ose3-node2 "systemctl start dnsmasq"
test_exit $? "$test"

test="Checking for firewall rule..."
exec_it ssh root@ose3-node2 "grep 'dport 53' /etc/sysconfig/iptables"
# need to test whether ssh failed or grep failed
if [ $? -eq 1 ]
then
  test="Adding iptables rule to sysconfig file..."
  exec_it ssh root@ose3-node2 "sed -i /etc/sysconfig/iptables -e '/^-A INPUT -p tcp -m state/i -A INPUT -p udp -m udp --dport 53 -j ACCEPT'"
  test_exit $? "$test"
fi

test="Checking live firewall..."
exec_it ssh root@ose3-node2 "iptables-save | grep 'dport 53'"
# need to test whether ssh failed or grep failed
if [ $? -eq 1 ]
then
  test="Adding iptables rule to live rules..."
  exec_it ssh root@ose3-node2 "iptables -I INPUT -p udp -m udp --dport 53 -j ACCEPT" 
  test_exit $? "$test"
fi
}

function pull_content(){
cd

# if the directory doesn't exist
if [ ! -d /root/training ]
then
  test="Pulling training content..."
  exec_it git clone https://github.com/thoraxe/training -b training-setup
  test_exit $? "$test"
else
  test="Updating training content..."
  cd ~/training
  exec_it git pull origin training-setup
  test_exit $? "$test"
fi
if [ ! -d /root/openshift-ansible ]
then
  test="Pulling ansible content..."
  exec_it git clone https://github.com/openshift/openshift-ansible
  test_exit $? "$test"
else
  test="Updating ansible content..."
  cd ~/openshift-ansible
  exec_it git pull origin master
  test_exit $? "$test"
fi
test="Copying hosts file..."
exec_it /bin/cp -f ~/training/content/sample-ansible-hosts /etc/ansible/hosts
test_exit $? "$test"
}

function run_install(){
date=$(date +%d%m%Y)
test="Running installation..."
if [ $installoutput == 1 ]
then
  echo "Installation..."
  cd ~/openshift-ansible
  ansible-playbook playbooks/byo/config.yml
else
  echo "Installation (takes a while - output logged to /tmp/ansible-$date.log)..."
  cd ~/openshift-ansible
  ansible-playbook playbooks/byo/config.yml > /tmp/ansible-`date +%d%m%Y`.log
fi
test_exit $? "$test"
}

function copy_ca(){
test="Copying CA certificate to a user accessible location..."
exec_it /bin/cp /etc/openshift/master/ca.crt /etc/openshift
test_exit $? "$test"
}

function label_nodes(){
test="Labeling nodes..."
exec_it oc label --overwrite node/ose3-master.example.com region=infra zone=default
test_exit $? "$test"
exec_it oc label --overwrite node/ose3-node1.example.com region=primary zone=east
test_exit $? "$test"
exec_it oc label --overwrite node/ose3-node2.example.com region=primary zone=west
test_exit $? "$test"
}

function configure_routing_domain(){
test="Configure default routing domain..."
exec_it sed -i 's/subdomain: router.default.local/subdomain: cloudapps.example.com/' /etc/openshift/master/master-config.yaml
test_exit $? "$test"
}

function configure_default_nodeselector(){
test="Configure default nodeselector for system..."
exec_it sed -i /etc/openshift/master/master-config.yaml -e 's/defaultNodeSelector: ""/defaultNodeSelector: "region=primary"/'
test_exit $? "$test"
test="Restart master..."
exec_it systemctl restart openshift-master
test_exit $? "$test"
}

function configure_default_project_selector(){
test="Configure default namespace selector..."
exec_it oc get namespace default -o json | sed -e '/"openshift.io\/sa.scc.mcs"/i "openshift.io/node-selector": "region=infra",' | oc replace -f -
test_exit $? "$test"
}

function setup_dev_users(){
test="Setting up joe..."
exec_it getent passwd joe
if [ $? -eq 0 ]
then
  exec_it useradd joe
  test_exit $? "$test"
fi
test="Setting up alice..."
exec_it getent passwd alice
if [ $? -eq 0 ]
then
  useradd alice
  test_exit $? "$test"
fi
test="Creating passwd file..."
exec_it touch /etc/openshift/openshift-passwd
test_exit $? "$test"
test="Setting joe password..."
exec_it htpasswd -b /etc/openshift/openshift-passwd joe redhat
test_exit $? "$test"
test="Setting alice password..."
exec_it htpasswd -b /etc/openshift/openshift-passwd alice redhat
test_exit $? "$test"
}

function install_router(){
cd
CA=/etc/openshift/master
test="Creating server certificates..."
oadm ca create-server-cert --signer-cert=$CA/ca.crt \
      --signer-key=$CA/ca.key --signer-serial=$CA/ca.serial.txt \
      --hostnames='*.cloudapps.example.com' \
      --cert=cloudapps.crt --key=cloudapps.key
test_exit $? "$test"
test="Combining certificates..."
cat cloudapps.crt cloudapps.key $CA/ca.crt > cloudapps.router.pem
test_exit $? "$test"

# check for SA
exec_it oc get sa router
if [ $? -eq 1 ]
then
  test="Creating router service account..."
  exec_it echo '{"kind":"ServiceAccount","apiVersion":"v1","metadata":{"name":"router"}}' | oc create -f -
  test_exit $? "$test"
fi

# check scc
exec_it oc get scc privileged -o yaml | grep router
if [ $? -eq 1 ]
then
  test="Adding router service account to privileged scc..."
  exec_it oc get scc privileged -o yaml | sed -e '/openshift-infra:build-controller/a - system:serviceaccount:default:router' | oc replace -f -
  test_exit $? "$test"
fi

# check for router
exec_it oadm router --dry-run --credentials='/etc/openshift/master/openshift-router.kubeconfig' --service-account=router

# if no router
if [ $? -eq 1 ]
then
  test="Installing router..."
  exec_it oadm router router --replicas=1 --default-cert=cloudapps.router.pem --credentials='/etc/openshift/master/openshift-router.kubeconfig' --service-account=router
  test_exit $? "$test"
fi
}

function check_add_iptables_port(){
# $1 = port
# $2 = protocol
exec_it iptables-save | grep "port $1"
if [ $? -eq 1 ]
then
  test="Adding live iptables rule for $2 port $1..."
  exec_it iptables -I OS_FIREWALL_ALLOW -p $2 -m state --state NEW -m $2 --dport $1 -j ACCEPT
  test_exit $? "$test"
fi
}

function prepare_nfs(){
test="Create NFS export folder..."
exec_it install -d -m 0777 -o nobody -g nobody /var/export/regvol
test_exit $? "$test"
test="Create exports file..."
exec_it echo "/var/export/regvol *(rw,sync,all_squash)" > /etc/exports
test_exit $? "$test"

# add iptables rules to running iptables
check_add_iptables_port 111 tcp
check_add_iptables_port 2049 tcp
check_add_iptables_port 20048 tcp
check_add_iptables_port 50825 tcp
check_add_iptables_port 53248 tcp

# add iptables rules to sysconfig file
grep "dport 53248" /etc/sysconfig/iptables
if [ $? -eq 1 ]
then
  test="Adding iptables rules to sysconfig file..."
  exec_it sed -i -e '/^COMMIT$/i -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 53248 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 50825 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 20048 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 2049 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 111 -j ACCEPT' \
  /etc/sysconfig/iptables
  test_exit $? "$test"
fi

test="Setting NFS args in sysconfig file..."
exec_it sed -i -e 's/^RPCMOUNTDOPTS.*/RPCMOUNTDOPTS="-p 20048"/' -e 's/^STATDARG.*/STATDARG="-p 50825"/' /etc/sysconfig/nfs
test_exit $? "$test"

grep "nlm_tcpport" /etc/sysctl.conf
if [ $? -eq 1 ]
then
  test="Adding sysctl NFS parameters..."
exec_it cat << EOF >> /etc/sysctl.conf
fs.nfs.nlm_tcpport=53248
fs.nfs.nlm_udpport=53248
EOF
test_exit $? "$test"
fi

test="Enable rpcbind and nfs-server..."
exec_it systemctl enable rpcbind nfs-server
test_exit $? "$test"

test="Start rpcbind, nfs-server, nfs-lock..."
exec_it systemctl start rpcbind nfs-server nfs-lock
test_exit $? "$test"

test="Start nfs-idmap..."
exec_it systemctl start nfs-idmap
test_exit $? "$test"

test="Persisting sysctl parameters..."
exec_it sysctl -p
test_exit $? "$test"

test="Restarting nfs..."
exec_it systemctl restart nfs 
test_exit $? "$test"

test="Setting NFS seboolean..."
exec_it setsebool -P virt_use_nfs=true
test_exit $? "$test"
}

function setup_storage_volumes_claims(){
# check for volume
exec_it oc get pv registry-volume
if [ $? -eq 1 ]
then
  test="Setting up registry storage volume..."
  exec_it oc create -f ~/training/content/registry-volume.json
  test_exit $? "$test"
fi
exec_it oc get pvc registry-claim
if [ $? -eq 1 ]
then
  test="Setting up registry volume claim..."
  exec_it oc create -f ~/training/content/registry-claim.json
  test_exit $? "$test"
fi
sleep 5
}

function install_registry(){
# check for registry
test="Installing Docker registry..."
exec_it oadm registry --dry-run \
--config=/etc/openshift/master/admin.kubeconfig \
--credentials=/etc/openshift/master/openshift-registry.kubeconfig
# if no registry
if [ $? -eq 1 ]
then
  exec_it oadm registry \
  --config=/etc/openshift/master/admin.kubeconfig \
  --credentials=/etc/openshift/master/openshift-registry.kubeconfig
fi
test_exit $? "$test"
# wait 5 seconds for things to settle
sleep 5
}

function wait_for_registry(){
# if registry is already scaled to zero we can skip
# check if rc 1 was ever successful
exec_it oc describe rc docker-registry-1 | grep successfulCreate
if [ $? -eq 0 ]
then
  # check if status = spec = 0
  ans=$(oc get rc docker-registry-1 -t '{{.spec.replicas}}{{.status.replicas}}')
  if [ $ans -eq 00 ]
  then
    return
  fi
fi

# we need to wait for the registry to get deployed before we can scale it down
test="Waiting up to 30s for registry deployment..."
for i in {1..30}
do
  sleep 1
  exec_it oc get rc docker-registry-1 -t '{{.status.replicas}}' | grep 1
  if [ $? -eq 0 ]
  then
    test_exit 0 "$test"
    return
  fi
done
test_exit 1 "$test"
}

function add_claimed_volume(){
# check for claim
exec_it oc get dc docker-registry -o yaml | grep registry-claim
if [ $? -eq 1 ]
then
  test="Adding the claimed volume to the Docker registry..."
  exec_it oc volume dc/docker-registry --add --overwrite -t persistentVolumeClaim \
  --claim-name=registry-claim --name=registry-storage
  test_exit $? "$test"
fi
}

function create_joe_project(){
# check for joe's project first
oc get project | grep demo
if [ $? -eq 1 ]
then
  test="Creating project for joe..."
  exec_it oadm new-project demo --display-name="OpenShift 3 Demo" \
  --description="This is the first demo project with OpenShift v3" \
  --admin=joe
  test_exit $? "$test"
fi
}

function add_project_resources(){
test="Create quota on joe's project..."
exec_it oc create -f ~/training/content/quota.json
test_exit $? "$test"
test="Create limits on joe's project..."
exec_it oc create -f ~/training/content/limits.json
test_exit $? "$test"
}

function wait_for_pod(){
# should wait for pod in a loop
echo
echo "Waiting 40 seconds for pod to come up..."
sleep 40
# should fail if we wait too long
}

function test_routing(){
echo
echo "Testing routing..."
curl -sSf --cacert /etc/openshift/master/ca.crt https://hello-openshift-service.demo.cloudapps.example.com
if [[ $? == 0 ]]; then
        echo 'Router is working!'
else
        echo "**** ROUTER IS FAILED ****"
fi
}

function setup_s2i_project(){
echo
echo "Setting up S2I project..."
oadm new-project sinatra --display-name="Sinatra Example" \
--description="This is your first build on OpenShift 3" \
--admin=joe
}

function new_app_project(){
echo
echo "Using new-app to create content..."
oc new-app https://github.com/openshift/simple-openshift-sinatra-sti.git -n sinatra
}

function create_project_route(){
echo
echo "Creating route..."
oc expose service simple-openshift-sinatra -n sinatra
}

function build_should_complete(){
# should expect build to start at some point before waiting to complete
echo
echo "Waiting for build to complete..."
until [[ $(oc get pod -n sinatra | grep build | awk '{print $3}') == *"Exit"* ]]; do
        echo -n "."
        sleep 1
done
echo ""
# should fail if we wait too long
}

verbose='false'
installoutput='false'

while getopts 'iv' flag; do
  case "${flag}" in
    i) installoutput=1 ;;
    v) verbose=1 ;;
    *) error "Unexpected option ${flag}" ;;
  esac
done

# should test if build tries to deploy
# should fail if deploy fails

# Chapter 1
echo "Preparations..."
prepare_dns
pull_content
# Chapter 2
run_install
echo "Post installation configuration..."
oc login -u system:admin
oc project default
copy_ca
label_nodes
configure_routing_domain
configure_default_nodeselector
configure_default_project_selector
# Chapter 3
setup_dev_users
create_joe_project
add_project_resources
echo "Configuring router..."
install_router
echo "Configuring registry..."
prepare_nfs
setup_storage_volumes_claims
install_registry
wait_for_registry
add_claimed_volume

