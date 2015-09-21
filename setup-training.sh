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

function wait_on_build(){
# arg1 = build id, arg2 = namespace, arg3 = time, arg4 = status
test="Waiting up to $3s for build ($1) status $4..."
printf "  $test\r"
for i in $(seq 1 $3)
do
  sleep 1
  exec_it oc get build "$1" -n "$2" -t \''{{.status.phase}}'\' "|" grep -E \""$4"\"
  if [ $? -eq 0 ]
  then
    test_exit 0 "$test"
    return
  fi
done
test_exit 1 "$test"
}

function wait_on_pod(){
# arg1 = pod id, arg2 = pod namespace, arg3 = time
test="Waiting up to $3s for pod ($1) deployment..."
printf "  $test\r"
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
test_exit 1 "$test"
}

function wait_on_endpoints(){
# arg1 = service name, arg2 = namespace, arg3 = time
test="Waiting up to $3s for service ($1) endpoints..."
printf "  $test\r"
for i in $(seq 1 $3)
do
  sleep 1
  val=$(oc get endpoints -n "$2" "$1" -t '{{len .subsets}}')
  if [ $val -gt 0 ]
  then
    test_exit 0 "$test"
    return
  fi
done
test_exit 1 "$test"
}

function wait_on_rc(){
# arg1 = rc id, arg2 = rc namespace, arg3 = time, arg4 = # replicas
test="Waiting up to $3s for rc ($1) deployer..."
printf "  $test\r"
for i in $(seq 1 $3)
do
  sleep 1
  exec_it oc get rc $1 -n $2 -t \''{{.status.replicas}}'\' "|" grep $4
  if [ $? -eq 0 ]
  then
    test_exit 0 "$test"
    # need to sleep for a bit because the pod probably isn't really there yet
    sleep 5
    return
  fi
done
test_exit 1 "$test"
}

function wait_on_project(){
# arg1 = project id, arg2 = time
test="Waiting up to $2s for project ($1) to be deleted..."
printf "  $test\r"
for i in $(seq 1 $2)
do
  sleep 1
  exec_it oc get project "|" grep "$1"
  if [ $? -eq 1 ]
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
  exec_it ssh -o StrictHostKeyChecking=no root@$node.example.com \""grep 133.4 /etc/resolv.conf"\"
  # need to test whether ssh failed versus whether grep failed
  if [ $? -eq 1 ] 
  then
    test="Setting nameserver for $node..."
    printf "  $test\r"
    exec_it ssh -o StrictHostKeyChecking=no root@$node.example.com \""sed -e '/^nameserver .*/i nameserver 192.168.133.4' -i /etc/resolv.conf"\"
    test_exit $? "$test"
  fi
done
test="Starting dnsmasq..."
printf "  $test\r"
exec_it ssh root@ose3-node2.example.com "systemctl start dnsmasq"
test_exit $? "$test"

test="Checking for firewall rule..."
exec_it ssh root@ose3-node2.example.com \""grep 'dport 53' /etc/sysconfig/iptables"\"
# need to test whether ssh failed or grep failed
if [ $? -eq 1 ]
then
  test="Adding iptables rule to sysconfig file..."
  printf "  $test\r"
  exec_it ssh root@ose3-node2.example.com \""sed -i /etc/sysconfig/iptables -e '/^-A INPUT -p tcp -m state/i -A INPUT -p udp -m udp --dport 53 -j ACCEPT'"\"
  test_exit $? "$test"
fi

test="Checking live firewall..."
exec_it ssh root@ose3-node2.example.com \""iptables-save | grep 'dport 53'"\"
# need to test whether ssh failed or grep failed
if [ $? -eq 1 ]
then
  test="Adding iptables rule to live rules..."
  printf "  $test\r"
  exec_it ssh root@ose3-node2.example.com \""iptables -I INPUT -p udp -m udp --dport 53 -j ACCEPT"\"
  test_exit $? "$test"
fi
}

function pull_content(){
cd

# if the directory doesn't exist
if [ ! -d /root/training ]
then
  test="Pulling training content..."
  printf "  $test\r"
  exec_it git clone https://github.com/thoraxe/training -b php-example
  test_exit $? "$test"
else
  test="Updating training content..."
  printf "  $test\r"
  cd ~/training
  exec_it git pull origin php-example
  test_exit $? "$test"
fi
if [ ! -d /root/openshift-ansible ]
then
  test="Pulling ansible content..."
  printf "  $test\r"
  exec_it git clone https://github.com/openshift/openshift-ansible
  test_exit $? "$test"
else
  test="Updating ansible content..."
  printf "  $test\r"
  cd ~/openshift-ansible
  exec_it git pull origin master
  test_exit $? "$test"
fi
test="Copying hosts file..."
printf "  $test\r"
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
printf "  $test\r"
exec_it /bin/cp /etc/openshift/master/ca.crt /etc/openshift
test_exit $? "$test"
}

function label_nodes(){
# let things settle a bit
sleep 10
test="Labeling master..."
printf "  $test\r"
exec_it oc label --overwrite node/ose3-master.example.com region=infra zone=default
test_exit $? "$test"
test="Labeling node1..."
printf "  $test\r"
exec_it oc label --overwrite node/ose3-node1.example.com region=primary zone=east
test_exit $? "$test"
test="Labeling node2..."
printf "  $test\r"
exec_it oc label --overwrite node/ose3-node2.example.com region=primary zone=west
test_exit $? "$test"
test="Making master schedulable..."
printf "  $test\r"
exec_it oadm manage-node ose3-master.example.com --schedulable=true
test_exit $? "$test"
}

function configure_routing_domain(){
test="Configure default routing domain..."
printf "  $test\r"
exec_it sed -i \''s/^  subdomain.*/\  subdomain: "cloudapps.example.com"/'\' /etc/openshift/master/master-config.yaml
test_exit $? "$test"
}

function configure_default_nodeselector(){
test="Configure default nodeselector for system..."
printf "  $test\r"
exec_it sed -i /etc/openshift/master/master-config.yaml -e \''s/defaultNodeSelector: ""/defaultNodeSelector: "region=primary"/'\'
test_exit $? "$test"
test="Restart master..."
printf "  $test\r"
exec_it systemctl restart openshift-master
test_exit $? "$test"
# wait for things to settle
sleep 10
}

function configure_default_project_selector(){
test="Configure default namespace selector..."
printf "  $test\r"
exec_it oc get namespace default -o json "|" sed -e \''/"openshift.io\/sa.scc.mcs"/i "openshift.io/node-selector": "region=infra",'\' "|" oc replace -f -
test_exit $? "$test"
}

function setup_dev_users(){
test="Setting up joe..."
printf "  $test\r"
exec_it getent passwd joe
if [ ! $? -eq 0 ]
then
  exec_it useradd joe
  test_exit $? "$test"
fi
test="Setting up alice..."
printf "  $test\r"
exec_it getent passwd alice
if [ ! $? -eq 0 ]
then
  useradd alice
  test_exit $? "$test"
fi
test="Creating passwd file..."
printf "  $test\r"
exec_it touch /etc/openshift/openshift-passwd
test_exit $? "$test"
test="Setting joe password..."
printf "  $test\r"
exec_it htpasswd -b /etc/openshift/openshift-passwd joe redhat
test_exit $? "$test"
test="Setting alice password..."
printf "  $test\r"
exec_it htpasswd -b /etc/openshift/openshift-passwd alice redhat
test_exit $? "$test"
}

function create_joe_project(){
# check for project
exec_it oc get project demo
if [ $? -eq 0 ]
then
  exec_it oc delete project demo
  wait_on_project demo 30
fi
# a little extra time
sleep 3
test="Creating project for joe..."
printf "  $test\r"
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
  printf "  $test\r"
  exec_it oc create -f ~/training/content/quota.json -n demo
  test_exit $? "$test"
fi
# is there already a limit?
exec_it oc get limitrange -n demo "|" grep limits
if [ $? -eq 1 ]
then
  test="Create limits on joe's project..."
  printf "  $test\r"
  exec_it oc create -f ~/training/content/limits.json -n demo
  test_exit $? "$test"
fi
}

function joe_login_pull(){
test="Login as joe..."
printf "  $test\r"
exec_it su - joe -c \""oc login -u joe -p redhat \
--certificate-authority=/etc/openshift/ca.crt \
--server=https://ose3-master.example.com:8443"\"
test_exit $? "$test"
# make sure to set the right project in case this is a re-run
exec_it su - joe -c \""oc project demo"\"
if [ ! -d /home/joe/training ]
then
  test="Pulling training content..."
  printf "  $test\r"
  exec_it su - joe -c \""git clone https://github.com/thoraxe/training -b php-example"\"
  test_exit $? "$test"
else
  test="Updating training content..."
  printf "  $test\r"
  exec_it su - joe -c \""cd ~/training && git pull origin php-example"\"
  test_exit $? "$test"
fi
}

function hello_pod(){
test="Creating hello-openshift pod..."
printf "  $test\r"
exec_it su - joe -c \""oc create -f ~/training/content/hello-pod.json"\"
test_exit $? "$test"
wait_on_pod "hello-openshift" "demo" 30
# if we came out of that successfully, proceed
test="Verifying hello-pod..."
printf "  $test\r"
exec_it curl $(oc get pod hello-openshift -n demo -t '{{.status.podIP}}'):8080 "|" grep Hello
test_exit $? "$test"
test="Deleting hello-pod..."
printf "  $test\r"
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
printf "  $test\r"
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
printf "  $test\r"
exec_it su - joe -c \""oc create -f ~/training/content/hello-service.json"\"
test_exit $? "$test"
test="Creating pods..."
printf "  $test\r"
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
printf "  $test\r"
exec_it oc get endpoints hello-service -n demo -t \''{{index .subsets 0 "addresses" | len}}'\' "|" grep 3
test_exit $? "$test"
test="Validating service..."
printf "  $test\r"
exec_it curl $(oc get service hello-service -n demo -t \''{{.spec.clusterIP}}:8888'\')
test_exit $? "$test"
}

function install_router(){
# just in case
exec_it oc project default
cd
CA=/etc/openshift/master
if [ ! -e /root/cloudapps.router.pem ]
then
  test="Creating server certificates..."
  printf "  $test\r"
  exec_it oadm ca create-server-cert --signer-cert=$CA/ca.crt \
        --signer-key=$CA/ca.key --signer-serial=$CA/ca.serial.txt \
        --hostnames=\''*.cloudapps.example.com'\' \
        --cert=cloudapps.crt --key=cloudapps.key
  test_exit $? "$test"
  test="Combining certificates..."
  printf "  $test\r"
  exec_it cat cloudapps.crt cloudapps.key $CA/ca.crt ">" cloudapps.router.pem
  test_exit $? "$test"
fi

# check for SA
exec_it oc get sa router
if [ $? -eq 1 ]
then
  test="Creating router service account..."
  printf "  $test\r"
  exec_it echo \''{"kind":"ServiceAccount","apiVersion":"v1","metadata":{"name":"router"}}'\' "|" oc create -f -
  test_exit $? "$test"
fi

# check scc
exec_it oc get scc privileged -o yaml | grep router
if [ $? -eq 1 ]
then
  test="Adding router service account to privileged scc..."
  printf "  $test\r"
  exec_it oc get scc privileged -o yaml "|" sed -e \''/openshift-infra:build-controller/a - system:serviceaccount:default:router'\' "|" oc replace -f -
  test_exit $? "$test"
fi

# check for router
exec_it oadm router --dry-run --credentials='/etc/openshift/master/openshift-router.kubeconfig' --service-account=router

# if no router
if [ $? -eq 1 ]
then
  test="Installing router..."
  printf "  $test\r"
  exec_it oadm router router --replicas=1 --default-cert=cloudapps.router.pem --credentials='/etc/openshift/master/openshift-router.kubeconfig' --service-account=router
  test_exit $? "$test"
fi

# verify that router came up
# first wait for rc to indicate status
wait_on_rc "router-1" "default" 30 1
# now find the router pod and wait for that to be ready
ans=$(oc get pod | awk '{print $1}'| grep -E "^router-1-\w{5}$")
wait_on_pod $ans "default" 30

# add router admin iptables port
check_add_iptables_port 1936 tcp

# add iptables rules to sysconfig file
exec_it grep \""dport 1936"\" /etc/sysconfig/iptables
if [ $? -eq 1 ]
then
  test="Adding router iptables rules to sysconfig file..."
  printf "  $test\r"
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
  printf "  $test\r"
  exec_it su - joe -c \""oc expose service hello-service -l name=hello-openshift"\"
  test_exit $? "$test"
fi
# wait to settle
sleep 5
test="Verifying the route..."
printf "  $test\r"
exec_it curl hello-service-demo.cloudapps.example.com "|" grep Hello
test_exit $? "$test"
}

function complete_pod_service_route(){
# delete everything in the project
exec_it su - joe -c \""oc delete all -l name=hello-openshift"\"
# wait for quota
sleep 10
# create complete def
test="Creating the complete definition..."
printf "  $test\r"
exec_it su - joe -c \""oc create -f ~/training/content/test-complete.json"\"
test_exit $? "$test"
wait_on_rc "hello-openshift-1" "demo" 30 1
ans=$(oc get pod -n demo | awk '{print $1}'| grep -E "^hello-openshift-1-\w{5}$")
wait_on_pod "$ans" "demo" 60
}

function project_administration(){
test="Add alice to view role..."
printf "  $test\r"
exec_it su - joe -c \""oadm policy add-role-to-user view alice"\"
test_exit $? "$test"
# things settle
sleep 5
test="Login as alice..."
printf "  $test\r"
exec_it su - alice -c \""oc login -u alice -p redhat \
--certificate-authority=/etc/openshift/ca.crt \
--server=https://ose3-master.example.com:8443 --loglevel=8"\"
test_exit $? "$test"
exec_it su - alice -c \""oc project demo"\"
test="Alice should be able to see a pod..."
printf "  $test\r"
exec_it su - alice -c \""oc get pod | grep hello-openshift"\"
test_exit $? "$test"
test="Alice can't delete pods..."
printf "  $test\r"
ans=$(oc get pod -n demo | awk '{print $1}'| grep -E "^hello-openshift-1-\w{5}$")
exec_it su - alice -c \""oc delete pod $ans"\"
if [ $? -eq 1 ]
then
  test_exit 0 "$test"
else
  text_exit 1 "$test"
fi
test="Add alice to edit role..."
printf "  $test\r"
exec_it su - joe -c \""oadm policy add-role-to-user edit alice"\"
test_exit $? "$test"
test="Set alice project to demo..."
printf "  $test\r"
exec_it su - alice -c \""oc project demo"\"
test_exit $? "$test"
test="Alice can delete pods..."
printf "  $test\r"
ans=$(oc get pod -n demo | awk '{print $1}'| grep -E "^hello-openshift-1-\w{5}$")
exec_it su - alice -c \""oc delete pod $ans"\"
test_exit $? "$test"
test="Add alice to admin role..."
printf "  $test\r"
exec_it su - joe -c \""oadm policy add-role-to-user admin alice"\"
test_exit $? "$test"
test="Alice can remove joe..."
printf "  $test\r"
exec_it su - alice -c \""oadm policy remove-user joe"\"
test_exit $? "$test"
test="Alice can delete demo project..."
printf "  $test\r"
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
  printf "  $test\r"
  exec_it iptables -I OS_FIREWALL_ALLOW -p $2 -m state --state NEW -m $2 --dport $1 -j ACCEPT
  test_exit $? "$test"
fi
}

function prepare_nfs(){
test="Create NFS export folder..."
printf "  $test\r"
exec_it install -d -m 0777 -o nfsnobody -g nfsnobody /var/export/regvol
test_exit $? "$test"
test="Create exports file..."
printf "  $test\r"
exec_it echo \""/var/export/regvol *(rw,sync,all_squash)"\" ">" /etc/exports
test_exit $? "$test"

# add iptables rules to running iptables
check_add_iptables_port 111 tcp
check_add_iptables_port 2049 tcp
check_add_iptables_port 20048 tcp
check_add_iptables_port 50825 tcp
check_add_iptables_port 53248 tcp

# add iptables rules to sysconfig file
exec_it grep \""dport 53248"\" /etc/sysconfig/iptables
if [ $? -eq 1 ]
then
  test="Adding NFS iptables rules to sysconfig file..."
  printf "  $test\r"
  exec_it sed -i -e \''/^COMMIT$/i -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 53248 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 50825 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 20048 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 2049 -j ACCEPT\
-A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 111 -j ACCEPT'\' \
  /etc/sysconfig/iptables
  test_exit $? "$test"
fi

test="Setting NFS args in sysconfig file..."
printf "  $test\r"
exec_it sed -i -e \''s/^RPCMOUNTDOPTS.*/RPCMOUNTDOPTS="-p 20048"/'\' -e \''s/^STATDARG.*/STATDARG="-p 50825"/'\' /etc/sysconfig/nfs
test_exit $? "$test"

exec_it grep \""nlm_tcpport"\" /etc/sysctl.conf
if [ $? -eq 1 ]
then
  test="Adding sysctl NFS parameters..."
  printf "  $test\r"
  exec_it sed -i -e \""\\\$afs.nfs.nlm_tcpport=53248"\" -e \""\\\$afs.nfs.nlm_udpport=53248"\" /etc/sysctl.conf
  test_exit $? "$test"
fi

test="Enable rpcbind and nfs-server..."
printf "  $test\r"
exec_it systemctl enable rpcbind nfs-server
test_exit $? "$test"

test="Start rpcbind, nfs-server, nfs-lock..."
printf "  $test\r"
exec_it systemctl start rpcbind nfs-server nfs-lock
test_exit $? "$test"

test="Start nfs-idmap..."
printf "  $test\r"
exec_it systemctl start nfs-idmap
test_exit $? "$test"

test="Persisting sysctl parameters..."
printf "  $test\r"
exec_it sysctl -p
test_exit $? "$test"

test="Restarting nfs..."
printf "  $test\r"
exec_it systemctl restart nfs 
test_exit $? "$test"

test="Setting NFS seboolean..."
printf "  $test\r"
exec_it setsebool -P virt_use_nfs=true
test_exit $? "$test"
}

function setup_storage_volumes_claims(){
# check for volume
exec_it oc get pv registry-volume
if [ $? -eq 1 ]
then
  test="Setting up registry storage volume..."
  printf "  $test\r"
  exec_it oc create -f ~/training/content/registry-volume.json
  test_exit $? "$test"
fi
exec_it oc get pvc registry-claim
if [ $? -eq 1 ]
then
  test="Setting up registry volume claim..."
  printf "  $test\r"
  exec_it oc create -f ~/training/content/registry-claim.json
  test_exit $? "$test"
fi
sleep 5
}

function install_registry(){
# check for registry
exec_it oadm registry --dry-run \
--config=/etc/openshift/master/admin.kubeconfig \
--credentials=/etc/openshift/master/openshift-registry.kubeconfig
# if no registry
if [ $? -eq 1 ]
then
  test="Installing Docker registry..."
  printf "  $test\r"
  exec_it oadm registry \
  --config=/etc/openshift/master/admin.kubeconfig \
  --credentials=/etc/openshift/master/openshift-registry.kubeconfig
  test_exit $? "$test"
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
  wait_on_rc "docker-registry-1" "default" 30 1
fi
}

function add_claimed_volume(){
# check for claim
exec_it oc get dc docker-registry -o yaml "|" grep registry-claim
if [ $? -eq 1 ]
then
  test="Adding the claimed volume to the Docker registry..."
  printf "  $test\r"
  exec_it oc volume dc/docker-registry --add --overwrite -t persistentVolumeClaim \
  --claim-name=registry-claim --name=registry-storage
  test_exit $? "$test"
  wait_on_rc "docker-registry-2" "default" 30 1
  sleep 5
  pod=$(oc get pod | awk '{print $1}' | grep -v deploy | grep -E "^docker-registry-2-\w{5}")
  wait_on_pod "$pod" "default" 60
fi
}

function s2i_project(){
# check for project
exec_it oc get project sinatra
if [ $? -eq 0 ]
then
  exec_it oc delete project sinatra
  wait_on_project sinatra 30
fi
# a little extra time
sleep 3
test="Creating sinatra S2I project..."
printf "  $test\r"
exec_it su - joe -c \""oc new-project sinatra --display-name=\""Sinatra Example"\" \
  --description=\""This is your first build on OpenShift 3\"""\"
test_exit $? "$test"
test="Using new-app to create content..."
printf "  $test\r"
exec_it su - joe -c \""oc new-app https://github.com/openshift/simple-openshift-sinatra-sti.git \
  --name=ruby-example"\"
test_exit $? "$test"
test="Exposing the service..."
printf "  $test\r"
exec_it su - joe -c \""oc expose service ruby-example"\"
test_exit $? "$test"
# may take up to 120 seconds for build to start
wait_on_build "ruby-example-1" "sinatra" 120 "Running"
# now wait up to 2 mins for build to complete
wait_on_build "ruby-example-1" "sinatra" 180 "Complete"
wait_on_rc "ruby-example-1" "sinatra" 30 1
ans=$(oc get pod -n sinatra | grep -v build | grep example | grep -v deploy | awk {'print $1'})
wait_on_pod "$ans" "sinatra" 30
# some extra sleep
sleep 5
test="Testing the service..."
printf "  $test\r"
exec_it curl `oc get service -n sinatra ruby-example -t '{{.spec.portalIP}}:{{index .spec.ports 0 "port"}}'` "|" grep Hello
test_exit $? "$test"
test="Testing the route..."
printf "  $test\r"
exec_it curl ruby-example-sinatra.cloudapps.example.com "|" grep Hello
test_exit $? "$test"
test="Adding quota to sinatra project..."
printf "  $test\r"
exec_it oc create -f ~/training/content/quota.json -n sinatra
test_exit $? "$test"
test="Adding limits to sinatra project..."
printf "  $test\r"
exec_it oc create -f ~/training/content/limits.json -n sinatra
test_exit $? "$test"
test="Scaling joe's app..."
printf "  $test\r"
exec_it su - joe -c \""oc scale --replicas=3 rc/ruby-example-1"\"
test_exit $? "$test"
wait_on_rc "ruby-example-1" "sinatra" 30 3
# find the pods
# 3 pods should run
for pod in $(oc get pod -n sinatra | grep example | grep -v build | awk {'print $1'})
do
  wait_on_pod "$pod" "sinatra" 30
done
# start new build
exec_it su - joe -c \""oc start-build ruby-example"\"
# build will never schedule so we need to look at the events with describe
# forbidden will immediately be show
test="Build should be forbidden..."
printf "  $test\r"
exec_it su - joe -c \""oc describe build ruby-example-2 | grep forbidden"\"
# build should be forbidden
test_exit $? "$test"
}

function templates_project() {
# check for project
exec_it oc get project quickstart
if [ $? -eq 0 ]
then
  exec_it oc delete project quickstart
  wait_on_project quickstart 30
fi
# a little extra time
sleep 3
# create the project
test="Creating quickstart project..."
printf "  $test\r"
exec_it su - joe -c \""oc new-project quickstart --display-name=\"Quickstart\" \
    --description='A demonstration of a \"quickstart/template\"'"\"
test_exit $? "$test"
# add the quickstart sample app template if it's not already there
exec_it oc get template -n openshift quickstart-keyvalue-application
if [ $? -eq 1 ]
then
  test="Adding the quickstart template..."
  printf "  $test\r"
  exec_it oc create -f ~/training/content/quickstart-template.json -n openshift
  test_exit $? "$test"
fi
# create via joe
test="Instantiating the quickstart application..."
printf "  $test\r"
exec_it su - joe -c \""oc new-app quickstart-keyvalue-application"\"
test_exit $? "$test"
# wait for the build to start
wait_on_build "ruby-sample-build-1" "quickstart" 120 "Running"
# wait for build to finish
wait_on_build "ruby-sample-build-1" "quickstart" 180 "Complete"
# wait for rc to deploy
wait_on_rc "frontend-1" "quickstart" 30 2
# find the deployed pods
pods=$(oc get pod -n quickstart | grep frontend | grep -v deploy | awk {'print $1'})
for pod in $pods
do
  wait_on_pod "$pod" "quickstart" 30
done
# test the application
test="Testing the application..."
printf "  $test\r"
exec_it curl keyvalue-route-quickstart.cloudapps.example.com "|" grep OpenShift
test_exit $? "$test"
}

function wiring_project() {
# check for project
exec_it oc get project wiring
if [ $? -eq 0 ]
then
  exec_it oc delete project wiring
  wait_on_project wiring 30
fi
# a little extra time
sleep 3
# create the project
test="Creating wiring project..."
printf "  $test\r"
exec_it su - alice -c \""oc new-project wiring --display-name='Exploring Parameters' \
    --description='An exploration of wiring using parameters'"\"
test_exit $? "$test"
# pull the training material
if [ ! -d /home/alice/training ]
then
  test="Pulling training content..."
  printf "  $test\r"
  exec_it su - alice -c \""git clone https://github.com/thoraxe/training -b php-example"\"
  test_exit $? "$test"
else
  test="Updating training content..."
  printf "  $test\r"
  exec_it su - alice -c \""cd ~/training && git pull origin php-example"\"
  test_exit $? "$test"
fi
test="Change alice's project..."
printf "  $test\r"
exec_it su - alice -c \""oc project wiring"\"
test_exit $? "$test"
test="Creating the frontend application..."
printf "  $test\r"
exec_it su - alice -c \""oc new-app -i openshift/ruby https://github.com/thoraxe/ruby-hello-world"\"
test_exit $? "$test"
test="Setting environment variables..."
printf "  $test\r"
exec_it su - alice -c \""oc env dc/ruby-hello-world MYSQL_USER=root MYSQL_PASSWORD=redhat MYSQL_DATABASE=mydb"\"
test_exit $? "$test"
wait_on_build "ruby-hello-world-1" "wiring" 120 "Running"
wait_on_build "ruby-hello-world-1" "wiring" 180 "Complete"
wait_on_rc "ruby-hello-world-1" "wiring" 30 1
sleep 3
# find the pod
pod=$(oc get pod -n wiring | grep hello-world | grep -v -E "deploy|build" | awk {'print $1'})
wait_on_pod "$pod" "wiring" 30
wait_on_endpoints "ruby-hello-world" "wiring" 30
sleep 3
test="Check if frontend service is working..."
printf "  $test\r"
exec_it curl `oc get service -n wiring ruby-hello-world -t '{{.spec.portalIP}}:{{index .spec.ports 0 "port"}}'`
test_exit $? "$test"
test="Expose the service..."
printf "  $test\r"
exec_it su - alice -c \""oc expose service ruby-hello-world"\"
# ruby-hello-world.wiring.cloudapps.example.com
test_exit $? "$test"
sleep 3
test="Creating the database backend..."
printf "  $test\r"
exec_it su - alice -c \""oc new-app mysql-ephemeral -p DATABASE_SERVICE_NAME=database,MYSQL_USER=root,MYSQL_PASSWORD=redhat,MYSQL_DATABASE=mydb"\"
test_exit $? "$test"
wait_on_rc "database-1" "wiring" 30 1
sleep 3
pod=$(oc get pod -n wiring | grep database | grep -v deploy | awk {'print $1'})
wait_on_pod "$pod" "wiring" 30
wait_on_endpoints "database" "wiring" 30
sleep 5
test="Checking the MySQL service..."
printf "  $test\r"
exec_it curl $(oc get service database -n wiring -t '{{.spec.portalIP}}:{{index .spec.ports 0 "targetPort"}}') "|" grep mysql
test_exit $? "$test"
# delete the existing frontend pod
test="Deleting the existing frontend pod..."
printf "  $test\r"
exec_it oc delete pod -n wiring $(oc get pod -n wiring | grep -e "hello-world-[0-9]" | grep -v build | awk '{print $1}')
test_exit $? "$test"
# find the new frontend pod
pod=$(oc get pod -n wiring | grep -e "hello-world-[0-9]" | grep -v build | awk '{print $1}')
# wait for it
wait_on_pod "$pod" "wiring" 30
wait_on_endpoints "ruby-hello-world" "wiring" 30
# test the app
sleep 3
test="Revalidating the app..."
printf "  $test\r"
exec_it curl ruby-hello-world-wiring.cloudapps.example.com "|" grep -i database
if [ $? -eq 1 ]
then
  test_exit 0 "$test"
else
  test_exit 1 "$test"
fi
}

function activate_rollback() {
# requires wiring project
# get webhook url
url=$(oc get bc ruby-hello-world -n wiring -t 'https://ose3-master.example.com:8443{{.metadata.selfLink}}/webhooks/{{(index .spec.triggers 1 "generic").secret}}/generic')
# curl the webhook url
test="Initiating the webhook build..."
printf "  $test\r"
exec_it curl -i -H \""Accept: application/json"\" \
    -H \""X-HTTP-Method-Override: PUT"\" -X POST -k \
    "$url" "|" grep 200
test_exit $? "$test"
wait_on_build "ruby-hello-world-2" "wiring" 30 "Running"
wait_on_build "ruby-hello-world-2" "wiring" 180 "Complete"
wait_on_rc "ruby-hello-world-2" "wiring" 30 1
# get pod name
pod=$(oc get pod -n wiring | grep -v -E "deploy|build|database" | grep world | awk '{print $1}' | grep -E "ruby-hello-world-2-\w{5}")
wait_on_pod "$pod" "wiring" 30
wait_on_endpoints "ruby-hello-world" "wiring" 30
# test the app
sleep 3
test="Revalidating the app..."
printf "  $test\r"
exec_it curl ruby-hello-world-wiring.cloudapps.example.com "|" grep OpenShift
test_exit $? "$test"
# rollback to first deployment
test="Rolling back to first deployment..."
printf "  $test\r"
exec_it oc rollback ruby-hello-world-1 -n wiring
test_exit $? "$test"
wait_on_rc "ruby-hello-world-3" "wiring" 30 1
pod=$(oc get pod -n wiring | grep -v -E "deploy|build|database" | grep world | awk '{print $1}' | grep -E "ruby-hello-world-3-\w{5}")
wait_on_pod "$pod" "wiring" 30
wait_on_endpoints "ruby-hello-world" "wiring" 30
# test the app
sleep 3
test="Revalidating the app..."
printf "  $test\r"
exec_it curl ruby-hello-world-wiring.cloudapps.example.com "|" grep OpenShift
test_exit $? "$test"
# roll forward
test="Rolling forward to second deployment..."
printf "  $test\r"
exec_it oc rollback ruby-hello-world-2 -n wiring
test_exit $? "$test"
wait_on_rc "ruby-hello-world-4" "wiring" 30 1
pod=$(oc get pod -n wiring | grep -v -E "deploy|build|database" | grep world | awk '{print $1}' | grep -E "ruby-hello-world-4-\w{5}")
wait_on_pod "$pod" "wiring" 30
wait_on_endpoints "ruby-hello-world" "wiring" 30
# test the app
sleep 3
test="Revalidating the app..."
printf "  $test\r"
exec_it curl ruby-hello-world-wiring.cloudapps.example.com "|" grep OpenShift
test_exit $? "$test"
}

function php_upload() {
# check for project
exec_it oc get project php-upload
if [ $? -eq 0 ]
then
  exec_it oc delete project php-upload
  wait_on_project php-upload 30
fi
# a little extra time
sleep 3
# create the project
test="Login as alice..."
printf "  $test\r"
exec_it su - alice -c \""oc login -u alice -p redhat \
--certificate-authority=/etc/openshift/ca.crt \
--server=https://ose3-master.example.com:8443 --loglevel=8"\"
test_exit $? "$test"
test="Creating php-upload project..."
printf "  $test\r"
exec_it su - alice -c \""oc new-project php-upload --display-name='PHP Uploader' \
    --description='A PHP app for uploading files'"\"
test_exit $? "$test"
exec_it su - alice -c \""oc project php-upload"\"
# do the NFS setup stuff here
test="Creating the php volume folder..."
printf "  $test\r"
exec_it install -d -m 0777 -o nfsnobody -g nfsnobody /var/export/vol1
test_exit $? "$test"
# check for exported volume
exec_it grep vol1 /etc/exports
if [ $? -eq 1 ]
then
  # there was no export
  test="Adding the export stanza for vol1..."
  printf "  $test\r"
  exec_it echo \""/var/export/vol1 *(rw,sync,all_squash)"\" ">>" /etc/exports
  test_exit $? "$test"
fi
test="Re-exporting NFS volumes..."
printf "  $test\r"
exec_it exportfs -r
test_exit $? "$test"
test="Creating the application..."
printf "  $test\r"
exec_it su - alice -c \""oc new-app php~https://github.com/thoraxe/openshift-php-upload-demo --name=demo --strategy=source"\"
test_exit $? "$test"
test="Exposing the service..."
printf "  $test\r"
exec_it su - alice -c \""oc expose service demo"\"
test_exit $? "$test"
wait_on_build "demo-1" "php-upload" 120 "Running"
wait_on_build "demo-1" "php-upload" 180 "Complete"
wait_on_rc "demo-1" "php-upload" 30 1
# get pod name
pod=$(oc get pod -n php-upload | grep -v -E "deploy|build" | grep demo | awk '{print $1}' | grep -E "demo-1-\w{5}")
wait_on_pod "$pod" "php-upload" 30
wait_on_endpoints "demo" "php-upload" 30
# test the app
sleep 3
test="Validating the app..."
printf "  $test\r"
exec_it curl demo-php-upload.cloudapps.example.com "|" grep Upload
test_exit $? "$test"
# create test file
exec_it su - alice -c \""echo 'test' > file"\"
# test upload should error
test="Trying to upload a file (should fail)..."
printf "  $test\r"
exec_it su - alice -c \""curl -i -F \"fto=@file\" http://demo-php-upload.cloudapps.example.com/upload.php"\" "|" grep fail
test_exit $? "$test"
exec_it oc get pvc registry-claim
if [ $? -eq 0 ]
then
  exec_it oc delete pvc php-claim
fi
exec_it oc get pv php-volume
if [ $? -eq 0 ]
then
  exec_it oc delete pv php-volume
fi
sleep 5
test="Setting up php storage volume..."
printf "  $test\r"
exec_it oc create -f ~/training/content/php-volume.json
test_exit $? "$test"
test="Setting up php volume claim..."
printf "  $test\r"
exec_it oc create -f ~/training/content/php-claim.json -n php-upload
test_exit $? "$test"
sleep 5
# add volume to dc
test="Adding volume to DC..."
printf "  $test\r"
exec_it su - alice -c \""oc volume dc/demo --add -t pvc --claim-name php-claim -m /opt/app-root/src/uploaded --name=php-volume"\"
test_exit $? "$test"
wait_on_rc "demo-2" "php-upload" 30 1
# get pod name
pod=$(oc get pod -n php-upload | grep -v -E "deploy|build" | grep demo | awk '{print $1}' | grep -E "demo-2-\w{5}")
wait_on_pod "$pod" "php-upload" 30
wait_on_endpoints "demo" "php-upload" 30
# try upload again
test="Trying to upload a file (should succeed)..."
printf "  $test\r"
exec_it su - alice -c \""curl -i -F \"fto=@file\" http://demo-php-upload.cloudapps.example.com/upload.php"\" "|" grep 200
test_exit $? "$test"
# examine file
test="Validating upload..."
printf "  $test\r"
exec_it su - alice -c \""curl http://demo-php-upload.cloudapps.example.com/uploaded/file"\" "|" grep test
test_exit $? "$test"
}

function customized_build() {
# switch alice back to wiring project
exec_it su - alice -c \""oc project wiring"\"
# check if the build is already modified
exec_it oc get bc ruby-hello-world -o json -n wiring "|" grep custom-assemble
if [ $? -eq 1 ]
then
  test="Modifying build configuration to use custom-assemble..."
  printf "  $test\r"
  # we have a staged repo with the assemble script so we need to
  # edit the existing build config
  exec_it su - alice -c \""oc get bc ruby-hello-world -o yaml | sed -e '/thoraxe\/ruby-hello-world/a \      ref: custom-assemble' | oc replace -f -"\"
  test_exit $? "$test"
fi
# check if we already have a third build
exec_it oc get build ruby-hello-world-3 -n wiring
if [ $? -eq 1 ]
then
  # get webhook url
  url=$(oc get bc ruby-hello-world -n wiring -t 'https://ose3-master.example.com:8443{{.metadata.selfLink}}/webhooks/{{(index .spec.triggers 1 "generic").secret}}/generic')
  # curl the webhook url
  test="Initiating the webhook build..."
  printf "  $test\r"
  exec_it curl -i -H \""Accept: application/json"\" \
      -H \""X-HTTP-Method-Override: PUT"\" -X POST -k \
      "$url" "|" grep 200
  test_exit $? "$test"
  # this will be the third build of the project
  # wait for build to start
  wait_on_build "ruby-hello-world-3" "wiring" 30 "Running"
  # wait for build to finish
  wait_on_build "ruby-hello-world-3" "wiring" 180 "Complete"
fi
# check log for custom message
test="Looking for CUSTOM S2I message in build logs..."
printf "  $test\r"
exec_it oc build-logs ruby-hello-world-3 -n wiring "|" grep \""CUSTOM S2I"\"
test_exit $? "$test"
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
# Chapter 6
echo "Project administration..."
project_administration
# Chapter 7
echo "Configuring registry..."
prepare_nfs
setup_storage_volumes_claims
install_registry
add_claimed_volume
# Chapter 08
echo "S2I Project..."
s2i_project
# Chapter 09
echo "Templates and Quickstarts..."
templates_project
# Chapter 10
echo "Wiring components..."
wiring_project
# Chapter 11
echo "Rollback and Activate..."
activate_rollback
# Chapter 12
echo "PHP Upload..."
php_upload
# Chapter 13
echo "Customized build..."
customized_build
