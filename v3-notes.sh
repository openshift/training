#!/bin/bash
systemctl start docker
yum -y remove '*openshift*'; yum clean all;  
yum --enablerepo=ose install 'openshift*' --exclude='openshift-clients' --exclude='*elastic*'
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

docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-haproxy-router
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-deployer
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-sti-builder
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-docker-builder
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-pod
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-docker-registry
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-keepalived-ipfailover
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ruby-20-rhel7
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/mysql-55-rhel7
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/php-55-rhel7
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/nodejs-010-rhel7
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/metrics-deployer
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/metrics-hawkular-metrics
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/metrics-cassandra
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/metrics-heapster
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/logging-fluentd
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/logging-elasticsearch
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/logging-kibana
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/logging-auth-proxy
docker pull rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/logging-deployment

docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-haproxy-router:latest registry.access.redhat.com/openshift3/ose-haproxy-router:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-deployer:latest registry.access.redhat.com/openshift3/ose-deployer:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-sti-builder:latest registry.access.redhat.com/openshift3/ose-sti-builder:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-docker-builder:latest registry.access.redhat.com/openshift3/ose-docker-builder:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-pod:latest registry.access.redhat.com/openshift3/ose-pod:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-docker-registry:latest registry.access.redhat.com/openshift3/ose-docker-registry:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ose-keepalived-ipfailover:latest registry.access.redhat.com/openshift3/ose-keepalived-ipfailover:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/ruby-20-rhel7 registry.access.redhat.com/openshift3/ruby-20-rhel7:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/mysql-55-rhel7 registry.access.redhat.com/openshift3/mysql-55-rhel7:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/php-55-rhel7 registry.access.redhat.com/openshift3/php-55-rhel7:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/nodejs-010-rhel7 registry.access.redhat.com/openshift3/nodejs-010-rhel7:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/metrics-deployer registry.access.redhat.com/openshift3/metrics-deployer:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/metrics-hawkular-metrics registry.access.redhat.com/openshift3/metrics-hawkular-metrics:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/metrics-cassandra registry.access.redhat.com/openshift3/metrics-cassandra:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/metrics-heapster registry.access.redhat.com/openshift3/metrics-heapster:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/logging-fluentd registry.access.redhat.com/openshift3/logging-fluentd:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/logging-elasticsearch registry.access.redhat.com/openshift3/logging-elasticsearch:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/logging-kibana registry.access.redhat.com/openshift3/logging-kibana:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/logging-auth-proxy registry.access.redhat.com/openshift3/logging-auth-proxy:v3.1.0.4
docker tag -f rcm-img-docker01.build.eng.bos.redhat.com:5001/openshift3/logging-deployment registry.access.redhat.com/openshift3/logging-deployment:v3.1.0.4
