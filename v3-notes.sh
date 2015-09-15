#!/bin/bash
systemctl start docker
yum -y remove '*openshift*'; yum clean all; yum -y install '*openshift*' --exclude=openshift-clients 
docker images  | grep -v jboss | awk {'print $3'} | xargs -r docker rmi -f
docker pull registry.access.redhat.com/openshift3/ose-haproxy-router:v3.0.2.0
docker pull registry.access.redhat.com/openshift3/ose-deployer:v3.0.2.0
docker pull registry.access.redhat.com/openshift3/ose-sti-builder:v3.0.2.0
docker pull registry.access.redhat.com/openshift3/ose-docker-builder:v3.0.2.0
docker pull registry.access.redhat.com/openshift3/ose-pod:v3.0.2.0
docker pull registry.access.redhat.com/openshift3/ose-docker-registry:v3.0.2.0
docker pull registry.access.redhat.com/openshift3/ose-keepalived-ipfailover:v3.0.2.0
docker pull registry.access.redhat.com/openshift3/ruby-20-rhel7
docker pull registry.access.redhat.com/openshift3/mysql-55-rhel7
docker pull registry.access.redhat.com/openshift3/php-55-rhel7
docker pull registry.access.redhat.com/jboss-eap-6/eap-openshift
docker pull openshift/hello-openshift

docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-haproxy-router:v3.0.2.0
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-deployer:v3.0.2.0
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-sti-builder:v3.0.2.0
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-docker-builder:v3.0.2.0
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-pod:v3.0.2.0
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-docker-registry:v3.0.2.0
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-keepalived-ipfailover:v3.0.2.0
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ruby-20-rhel7
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/mysql-55-rhel7
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/php-55-rhel7

docker tag rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-haproxy-router:v3.0.2.0 registry.access.redhat.com/openshift3/ose-haproxy-router:v3.0.2.0
docker tag rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-deployer:v3.0.2.0 registry.access.redhat.com/openshift3/ose-deployer:v3.0.2.0
docker tag rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-sti-builder:v3.0.2.0 registry.access.redhat.com/openshift3/ose-sti-builder:v3.0.2.0
docker tag rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-docker-builder:v3.0.2.0 registry.access.redhat.com/openshift3/ose-docker-builder:v3.0.2.0
docker tag rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-pod:v3.0.2.0 registry.access.redhat.com/openshift3/ose-pod:v3.0.2.0
docker tag rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-docker-registry:v3.0.2.0 registry.access.redhat.com/openshift3/ose-docker-registry:v3.0.2.0
docker tag rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-keepalived-ipfailover:v3.0.2.0 registry.access.redhat.com/openshift3/ose-keepalived-ipfailover:v3.0.2.0
docker tag rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ruby-20-rhel7 registry.access.redhat.com/openshift3/ruby-20-rhel7
docker tag rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/mysql-55-rhel7 registry.access.redhat.com/openshift3/mysql-55-rhel7
docker tag rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/php-55-rhel7 registry.access.redhat.com/openshift3/php-55-rhel7
