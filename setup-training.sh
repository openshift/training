#!/bin/bash

function exec_it() {
  if $verbose 
  then
    echo "$@"
    eval "$@"
  else
    eval "$@" &> /dev/null
  fi
}

function test_exit() {
  if [ $1 -eq 0 ]
  then
    printf '\033[32m✓ \033[0m'
    printf '%s\n' "$2 passed"
    if $verbose
    then
      echo
    fi
  else
    printf '\033[31m✗ \033[0m'
    printf '%s\n' "$2 failed"
    exit 255
  fi
}

function wait_on_pod(){
# arg1 = pod id, arg2 = pod namespace, arg3 = time
test="Waiting up to $3s for pod ($1) deployment..."
for i in $(seq 1 $3)
do
  sleep 1
  exec_it oc get pod "$1" -n "$2" -t \''{{index .status.conditions 0 "type"}}|{{.status.phase}}'\' "|" grep \""Ready|Running"\"
  if [ $? -eq 0 ]
  then
    test_exit 0 "$test"
    return
  fi
done
text_exit 1 "$test"
}

function wait_on_rc(){
# arg1 = rc id, arg2 = rc namespace, arg3 = time
test="Waiting up to $3s for rc ($1) deployer..."
for i in $(seq 1 $3)
do
  sleep 1
  exec_it oc get rc $1 -n $2 -t \''{{.status.replicas}}'\' "|" grep 1
  if [ $? -eq 0 ]
  then
    test_exit 0 "$test"
    return
  fi
done
test_exit 1 "$test"
}

function prepare_dns(){
for node in ose3-master ose3-node1 ose3-node2
do 
  test="Checking $node resolver..."
  exec_it ssh -o StrictHostKeyChecking=no root@$node \""grep 133.4 /etc/resolv.conf"\"
  # need to test whether ssh failed versus whether grep failed
  if [ $? -eq 1 ] 
  then
    test="Setting nameserver for $node..."
    exec_it ssh -o StrictHostKeyChecking=no root@$node \""sed -e '/^nameserver .*/i nameserver 192.168.133.4' -i /etc/resolv.conf"\"
    test_exit $? "$test"
  fi
done
test="Starting dnsmasq..."
exec_it ssh root@ose3-node2 "systemctl start dnsmasq"
test_exit $? "$test"

test="Checking for firewall rule..."
exec_it ssh root@ose3-node2 \""grep 'dport 53' /etc/sysconfig/iptables"\"
# need to test whether ssh failed or grep failed
if [ $? -eq 1 ]
then
  test="Adding iptables rule to sysconfig file..."
  exec_it ssh root@ose3-node2 \""sed -i /etc/sysconfig/iptables -e '/^-A INPUT -p tcp -m state/i -A INPUT -p udp -m udp --dport 53 -j ACCEPT'"\"
  test_exit $? "$test"
fi

test="Checking live firewall..."
exec_it ssh root@ose3-node2 \""iptables-save | grep 'dport 53'"\"
# need to test whether ssh failed or grep failed
if [ $? -eq 1 ]
then
  test="Adding iptables rule to live rules..."
  exec_it ssh root@ose3-node2 \""iptables -I INPUT -p udp -m udp --dport 53 -j ACCEPT"\"
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
if $installoutput
then
  echo "Installation..."
  cd ~/openshift-ansible
  if $trace
  then
    ansible-playbook playbooks/byo/config.yml -vvvv
  else
    ansible-playbook playbooks/byo/config.yml
  fi
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
# let things settle a bit
sleep 10
test="Labeling master..."
exec_it oc label --overwrite node/ose3-master.example.com region=infra zone=default
test_exit $? "$test"
test="Labeling node1..."
exec_it oc label --overwrite node/ose3-node1.example.com region=primary zone=east
test_exit $? "$test"
test="Labeling node2..."
exec_it oc label --overwrite node/ose3-node2.example.com region=primary zone=west
test_exit $? "$test"
test="Making master schedulable..."
exec_it oadm manage-node ose3-master.example.com --schedulable=true
test_exit $? "$test"
}

function configure_routing_domain(){
test="Configure default routing domain..."
exec_it sed -i \''s/^  subdomain.*/\  subdomain: "cloudapps.example.com"/'\' /etc/openshift/master/master-config.yaml
test_exit $? "$test"
}

function configure_default_nodeselector(){
test="Configure default nodeselector for system..."
exec_it sed -i /etc/openshift/master/master-config.yaml -e \''s/defaultNodeSelector: ""/defaultNodeSelector: "region=primary"/'\'
test_exit $? "$test"
test="Restart master..."
exec_it systemctl restart openshift-master
test_exit $? "$test"
# wait for things to settle
sleep 10
}

function configure_default_project_selector(){
test="Configure default namespace selector..."
exec_it oc get namespace default -o json "|" sed -e \''/"openshift.io\/sa.scc.mcs"/i "openshift.io/node-selector": "region=infra",'\' "|" oc replace -f -
test_exit $? "$test"
}

function setup_dev_users(){
test="Setting up joe..."
exec_it getent passwd joe
if [ ! $? -eq 0 ]
then
  exec_it useradd joe
  test_exit $? "$test"
fi
test="Setting up alice..."
exec_it getent passwd alice
if [ ! $? -eq 0 ]
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

function delete_joe_project(){
test="Deleting joe project within 30s..."
exec_it oc delete project demo
if [ $? -eq 1 ]
then
  return
else
  for i in {1..30}
  do
    sleep 1
    exec_it oc get project "|" grep demo
    if [ $? -eq 1 ]
    then
      test_exit 0 "$test"
      return
    fi
  done
fi
test_exit 1 "$test"
}

function create_joe_project(){
test="Creating project for joe..."
exec_it oadm new-project demo --display-name=\""OpenShift 3 Demo"\" \
--description=\""This is the first demo project with OpenShift v3"\" \
--admin=joe
test_exit $? "$test"
}

function set_project_quota_limits(){
# is there already a quota?
exec_it oc get quota -n demo "|" grep quota
if [ $? -eq 1 ]
then
  test="Create quota on joe's project..."
  exec_it oc create -f ~/training/content/quota.json -n demo
  test_exit $? "$test"
fi
# is there already a limit?
exec_it oc get limitrange -n demo "|" grep limits
if [ $? -eq 1 ]
then
  test="Create limits on joe's project..."
  exec_it oc create -f ~/training/content/limits.json -n demo
  test_exit $? "$test"
fi
}

function joe_login_pull(){
test="Login as joe..."
exec_it su - joe -c \""oc login -u joe -p redhat \
--certificate-authority=/etc/openshift/ca.crt \
--server=https://ose3-master.example.com:8443"\"
test_exit $? "$test"

if [ ! -d /home/joe/training ]
then
  test="Pulling training content..."
  exec_it su - joe -c \""git clone https://github.com/thoraxe/training -b training-setup"\"
  test_exit $? "$test"
else
  test="Updating training content..."
  exec_it su - joe -c \""cd ~/training && git pull origin training-setup"\"
  test_exit $? "$test"
fi
}

function hello_pod(){
exec_it oc delete all -l hello-openshift -n demo
test="Creating hello-openshift pod..."
exec_it su - joe -c \""oc create -f ~/training/content/hello-pod.json"\"
test_exit $? "$test"
wait_on_pod "hello-openshift" "demo" 30
# if we came out of that successfully, proceed
test="Verifying hello-pod..."
exec_it curl $(oc get pod hello-openshift -n demo -t '{{.status.podIP}}'):8080 "|" grep Hello
test_exit $? "$test"
test="Deleting hello-pod..."
exec_it su - joe -c \""oc delete pod hello-openshift"\"
test_exit $? "$test"
# it takes 10 seconds for quota to update
sleep 10
}

function hello_quota() {
# if there are any pods, nuke 'em and start over
ans=$(oc get pods -n demo | wc -l)
if [ $ans != 1 ]
then
exec_it oc delete pods --all -n demo
# it takes 10 seconds for quota to update
sleep 10
fi
test="Checking if quota is enforced..."
exec_it su - joe -c \""oc create -f ~/training/content/hello-quota.json"\"
if [ $? -eq 1 ] 
then
  # we failed, which we wanted to, so exit successfully
  test_exit 0 "$test"
else
  test_exit 1 "$test"
fi
exec_it oc delete pods --all -n demo
# it takes 10 seconds for quota to update
sleep 10
}

function joe_project(){
# cleanup
exec_it oc delete all -l name=hello-openshift -n demo
exec_it oc delete pods --all -n demo
create_joe_project
set_project_quota_limits
joe_login_pull
hello_pod
hello_quota
}

function create_populate_service(){
# delete hello service
exec_it oc delete service --all -n demo
exec_it oc delete pod --all -n demo
sleep 10
test="Creating hello-service..."
exec_it su - joe -c \""oc create -f ~/training/content/hello-service.json"\"
test_exit $? "$test"
test="Creating pods..."
exec_it su - joe -c \""oc create -f ~/training/content/hello-service-pods.json"\"
test_exit $? "$test"
# there's probably an easier way to do this, but this is pretty easy
wait_on_pod "hello-openshift-1" "demo" 30
wait_on_pod "hello-openshift-2" "demo" 30
wait_on_pod "hello-openshift-3" "demo" 30
# just in case
sleep 5
test="Checking service endpoints..."
# there should be three
exec_it oc get endpoints hello-service -n demo -t \''{{index .subsets 0 "addresses" | len}}'\' "|" grep 3
test_exit $? "$test"
test="Validating service..."
exec_it curl $(oc get service hello-service -n demo -t \''{{.spec.clusterIP}}:8888'\')
test_exit $? "$test"
}

function install_router(){
# just in case
exec_it oc project default
cd
CA=/etc/openshift/master
test="Creating server certificates..."
if [ ! -e /root/cloudapps.router.pem ]
then
  exec_it oadm ca create-server-cert --signer-cert=$CA/ca.crt \
        --signer-key=$CA/ca.key --signer-serial=$CA/ca.serial.txt \
        --hostnames=\''*.cloudapps.example.com'\' \
        --cert=cloudapps.crt --key=cloudapps.key
  test_exit $? "$test"
  test="Combining certificates..."
  exec_it cat cloudapps.crt cloudapps.key $CA/ca.crt ">" cloudapps.router.pem
  test_exit $? "$test"
fi

# check for SA
exec_it oc get sa router
if [ $? -eq 1 ]
then
  test="Creating router service account..."
  exec_it echo \''{"kind":"ServiceAccount","apiVersion":"v1","metadata":{"name":"router"}}'\' "|" oc create -f -
  test_exit $? "$test"
fi

# check scc
exec_it oc get scc privileged -o yaml | grep router
if [ $? -eq 1 ]
then
  test="Adding router service account to privileged scc..."
  exec_it oc get scc privileged -o yaml "|" sed -e \''/openshift-infra:build-controller/a - system:serviceaccount:default:router'\' "|" oc replace -f -
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

# verify that router came up
# first wait for rc to indicate status
wait_on_rc "router-1" "default" 30
# now find the router pod and wait for that to be ready
ans=$(oc get pod | awk '{print $1}'| grep -E "router-1-\w{5}")
wait_on_pod $ans "default" 30

# add router admin iptables port
check_add_iptables_port 1936 tcp

# add iptables rules to sysconfig file
exec_it grep \""dport 1936"\" /etc/sysconfig/iptables
if [ $? -eq 1 ]
then
  test="Adding router iptables rules to sysconfig file..."
  exec_it sed -i -e \''/^COMMIT$/i -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 1936 -j ACCEPT\'\' \
  /etc/sysconfig/iptables
  test_exit $? "$test"
fi
}

function expose_test_service(){
# check for route
exec_it oc get route hello-service -n demo
if [ ! $? -eq 0 ]
then
  test="Exposing hello-service service..."
  exec_it su - joe -c \""oc expose service hello-service -l name=hello-openshift"\"
  test_exit $? "$test"
fi
# wait to settle
sleep 5
test="Verifying the route..."
exec_it curl hello-service.demo.cloudapps.example.com "|" grep Hello
test_exit $? "$test"
}

function complete_pod_service_route(){
# delete everything in the project
exec_it su - joe -c \""oc delete all -l name=hello-openshift"\"
# wait for quota
sleep 10
# create complete def
test="Creating the complete definition..."
exec_it su - joe -c \""oc create -f ~/training/content/test-complete.json"\"
wait_on_rc "hello-openshift-1" "demo" 30
ans=$(oc get pod -n demo | awk '{print $1}'| grep -E "^hello-openshift-1-\w{5}$")
wait_on_pod "$ans" "demo" 60
}

function project_administration(){
test="Add alice to view role..."
exec_it su - joe -c \""oadm policy add-role-to-user view alice"\"
test_exit $? "$test"
test="Login as alice..."
exec_it su - alice -c \""oc login -u alice -p redhat \
--certificate-authority=/etc/openshift/ca.crt \
--server=https://ose3-master.example.com:8443"\"
test_exit $? "$test"
test="Alice should be able to see a pod..."
exec_it su - alice -c \""oc get pod | grep hello-openshift"\"
test_exit $? "$test"
test="Alice can't delete pods..."
ans=$(oc get pod -n demo | awk '{print $1}'| grep -E "^hello-openshift-1-\w{5}$")
exec_it su - alice -c \""oc delete pod $ans"\"
if [ $? -eq 1 ]
then
  test_exit 0 "$test"
else
  text_exit 1 "$test"
fi
test="Add alice to edit role..."
exec_it su - joe -c \""oadm policy add-role-to-user edit alice"\"
test_exit $? "$test"
test="Alice can delete pods..."
ans=$(oc get pod -n demo | awk '{print $1}'| grep -E "^hello-openshift-1-\w{5}$")
exec_it su - alice -c \""oc delete pod $ans"\"
test_exit $? "$test"
test="Add alice to admin role..."
exec_it su - joe -c \""oadm policy add-role-to-user admin alice"\"
test_exit $? "$test"
test="Alice can remove joe..."
exec_it su - alice -c \""oadm policy remove-user joe"\"
test_exit $? "$test"
test="Alice can delete demo project..."
exec_it su - alice -c \""oc delete project demo"\"
test_exit $? "$test"
}

function check_add_iptables_port(){
# $1 = port
# $2 = protocol
exec_it iptables-save "|" grep \""port $1"\"
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
exec_it echo \""/var/export/regvol *(rw,sync,all_squash)"\" ">" /etc/exports
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
  test="Adding NFS iptables rules to sysconfig file..."
  exec_it sed -i -e \''/^COMMIT$/i -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 53248 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 50825 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 20048 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 2049 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 111 -j ACCEPT'\' \
  /etc/sysconfig/iptables
  test_exit $? "$test"
fi

test="Setting NFS args in sysconfig file..."
exec_it sed -i -e \''s/^RPCMOUNTDOPTS.*/RPCMOUNTDOPTS="-p 20048"/'\' -e \''s/^STATDARG.*/STATDARG="-p 50825"/'\' /etc/sysconfig/nfs
test_exit $? "$test"

grep "nlm_tcpport" /etc/sysctl.conf
if [ $? -eq 1 ]
then
  test="Adding sysctl NFS parameters..."
cat << EOF >> /etc/sysctl.conf
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
exec_it oc describe rc docker-registry-1 "|" grep successfulCreate
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
  exec_it oc get rc docker-registry-1 -t '{{.status.replicas}}' "|" grep 1
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
exec_it oc get dc docker-registry -o yaml "|" grep registry-claim
if [ $? -eq 1 ]
then
  test="Adding the claimed volume to the Docker registry..."
  exec_it oc volume dc/docker-registry --add --overwrite -t persistentVolumeClaim \
  --claim-name=registry-claim --name=registry-storage
  test_exit $? "$test"
fi
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
    i) installoutput=true; trace=false ;;
    v) verbose=true ;;
    t) installoutput=true; trace=true ;; 
    *) error "Unexpected option ${flag}" ;;
  esac
done

# should test if build tries to deploy
# should fail if deploy fails

# Chapter 1
echo "Preparations..."
prepare_dns
pull_content
# just in case
if [ -d /root/.config ]
then
  exec_it oc login -u system:admin
  exec_it oc project default
fi
# Chapter 2
run_install
echo "Post installation configuration..."
copy_ca
label_nodes
configure_routing_domain
configure_default_nodeselector
configure_default_project_selector
# Chapter 3
echo "Dev users..."
setup_dev_users
# Chapter 4
delete_joe_project
echo "First joe project..."
joe_project
# Chapter 5
echo "Services..."
create_populate_service
echo "Configuring router..."
install_router
echo "Services and complete definition..."
expose_test_service
complete_pod_service_route
echo "Project administration..."
project_administration
#echo "Configuring registry..."
#prepare_nfs
#setup_storage_volumes_claims
#install_registry
#wait_for_registry
#add_claimed_volume
