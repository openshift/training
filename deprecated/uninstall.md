## Uninstallation

During the beta period the preferred route of testing new beta code is to
redeploy the host machines.  We understand that is not always an automated
process so if you simply want to prepare a previously used host to test another
beta release these are the steps that can be followed:

~~~
# Remove all docker processes and images.  This is not strictly required but
# it's best to start from a clean slate.
docker rm -f $(docker ps -a -q)
docker rmi -f $(docker images -q)

systemctl stop openshift-master openshift-node docker

yum -y erase "*openshift*" "docker*"
# So your repo cache isn't out of date
yum clean all

# Erase all knowledge of the openshift units
systemctl reset-failed
systemctl daemon-reload

# Remove data, config, and training materials
rm -rf /var/lib/openshift
rm -rf /etc/sysconfig/*openshift*
rm -rf /etc/sysconfig/docker*
rm -rf /etc/openshift/*
rm -rf /root/.config/openshift
rm -rf /root/training
rm -rf /root/openshift-ansible
rm -rf /var/lib/docker

# In case this was still around from a previous install
rm -rf /root/.kube/

# Remove the user's that you created to ensure you get the latest training
# materials in their home directories when you start again
userdel -r alice
userdel -r joe

# Wherever you've deployed ansible clean it up, usually your master
yum erase ansible
rm -rf /etc/ansible

# Make sure you're running the latest RHEL 7.1 release
yum update

# This will clear the various virtual NICs
reboot
~~~
