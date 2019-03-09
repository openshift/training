# Exploring the Cluster

The following instructions assume that you have deployed the cluster using the 
*openshift-install* tooling, and that the necessary configuration files required
for cluster interaction have been automatically generated for you in your home
directory. If you have been provided with access to an environment (e.g. it has
been deployed for you) or you do **not** have the necessary configuration files
generated, follow these steps; it requires that you have the credentials and API
URI information to hand:

~~~bash
$ oc login --server <your API URI>

The server uses a certificate signed by an unknown authority.
You can bypass the certificate check, but any data you send to the server could be intercepted by others.
Use insecure connections? (y/n): y

Authentication required for https://api.beta-190305-1.ocp4testing.openshiftdemos.com:6443 (openshift)
Username: <your username>
Password: <your password>
Login successful.
(...)

Using project "default".
Welcome! See 'oc help' to get started.
~~~

You can now check that your config has been written successfully:

~~~bash
$ cat ~/.kube/config
apiVersion: v1
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://api.beta-190305-1.ocp4testing.openshiftdemos.com:6443
(...)
~~~

> **NOTE**: Your output will vary slightly from the above, you'll just need to
make sure to use the API endpoint and credentials that you were provided with.

Now that your cluster is installed, you will have access to the web console and
can use the CLI. Below are some command-line exercises to explore the cluster.

## Cluster Nodes

The default installation behavior creates 6 nodes: 3 masters and 3 "worker"
application/compute nodes. You can view them with:

~~~bash
$ oc get nodes -o wide
NAME                           STATUS    ROLES     AGE       VERSION              INTERNAL-IP    EXTERNAL-IP   OS-IMAGE                          KERNEL-VERSION              CONTAINER-RUNTIME
ip-10-0-137-104.ec2.internal   Ready     worker    24h       v1.12.4+5dc94f3fda   10.0.137.104   <none>        Red Hat CoreOS 400.7.20190301.0   3.10.0-957.5.1.el7.x86_64   cri-o://1.12.6-1.rhaos4.0.git2f0cb0d.el7
ip-10-0-140-138.ec2.internal   Ready     master    24h       v1.12.4+5dc94f3fda   10.0.140.138   <none>        Red Hat CoreOS 400.7.20190301.0   3.10.0-957.5.1.el7.x86_64   cri-o://1.12.6-1.rhaos4.0.git2f0cb0d.el7
ip-10-0-158-222.ec2.internal   Ready     master    24h       v1.12.4+5dc94f3fda   10.0.158.222   <none>        Red Hat CoreOS 400.7.20190301.0   3.10.0-957.5.1.el7.x86_64   cri-o://1.12.6-1.rhaos4.0.git2f0cb0d.el7
ip-10-0-159-179.ec2.internal   Ready     worker    24h       v1.12.4+5dc94f3fda   10.0.159.179   <none>        Red Hat CoreOS 400.7.20190301.0   3.10.0-957.5.1.el7.x86_64   cri-o://1.12.6-1.rhaos4.0.git2f0cb0d.el7
ip-10-0-168-43.ec2.internal    Ready     master    24h       v1.12.4+5dc94f3fda   10.0.168.43    <none>        Red Hat CoreOS 400.7.20190301.0   3.10.0-957.5.1.el7.x86_64   cri-o://1.12.6-1.rhaos4.0.git2f0cb0d.el7
ip-10-0-171-135.ec2.internal   Ready     worker    24h       v1.12.4+5dc94f3fda   10.0.171.135   <none>        Red Hat CoreOS 400.7.20190301.0   3.10.0-957.5.1.el7.x86_64   cri-o://1.12.6-1.rhaos4.0.git2f0cb0d.el7
~~~

If you want to see the various applied **labels**, you can also do:

~~~bash
$ oc get nodes --show-labels
NAME                           STATUS    ROLES     AGE       VERSION              LABELS
ip-10-0-137-104.ec2.internal   Ready     worker    23h       v1.12.4+5dc94f3fda   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.large,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1a,kubernetes.io/hostname=ip-10-0-137-104,node-role.kubernetes.io/worker=
ip-10-0-140-138.ec2.internal   Ready     master    23h       v1.12.4+5dc94f3fda   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.xlarge,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1a,kubernetes.io/hostname=ip-10-0-140-138,node-role.kubernetes.io/master=
ip-10-0-158-222.ec2.internal   Ready     master    23h       v1.12.4+5dc94f3fda   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.xlarge,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1b,kubernetes.io/hostname=ip-10-0-158-222,node-role.kubernetes.io/master=
ip-10-0-159-179.ec2.internal   Ready     worker    23h       v1.12.4+5dc94f3fda   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.large,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1b,kubernetes.io/hostname=ip-10-0-159-179,node-role.kubernetes.io/worker=
ip-10-0-168-43.ec2.internal    Ready     master    23h       v1.12.4+5dc94f3fda   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.xlarge,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1c,kubernetes.io/hostname=ip-10-0-168-43,node-role.kubernetes.io/master=
ip-10-0-171-135.ec2.internal   Ready     worker    23h       v1.12.4+5dc94f3fda   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.large,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-east-1,failure-domain.beta.kubernetes.io/zone=us-east-1c,kubernetes.io/hostname=ip-10-0-171-135,node-role.kubernetes.io/worker=
~~~

For reference, **labels** are used as a mechanism to tag certain information
onto a node, or a set of nodes, that can help you identify your systems, e.g.
by operating system, system architecture, specification, location of the system
(e.g. region), it's hostname, etc. They can also help with application
scheduling, e.g. make sure that my application (or pod) resides on a specific
system type. The labels shown above are utilising the default labels, but it's
possible to set some custom labels in the form of a key-value pair.

## The Cluster Operator

The cluster version operator is the core of what defines an OpenShift deployment
. The cluster version operator pod(s) contains the set of manifests which are
used to deploy, updated, and/or manage the OpenShift services in the cluster.
This operator ensures that the other services, also deployed as operators, are
at the version which matches the release definition and takes action to remedy
discrepancies when necessary.

~~~bash
$ oc get deployments -n openshift-cluster-version
NAME                       DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
cluster-version-operator   1         1         1            1           2h
~~~

You can also view the current version of the OpenShift cluster and give you
a high-level indication of the status:

~~~bash
$ oc get clusterversion
NAME      VERSION     AVAILABLE   PROGRESSING   SINCE   STATUS
version   4.0.0-0.7   True        False         28h     Cluster version is 4.0.0-0.7
~~~

If you want to review a list of operators that the cluster version operator is
controlling, along with their status, you can ask for a list of the cluster
operators:

~~~bash
$ oc get clusteroperator
NAME                                  VERSION   AVAILABLE   PROGRESSING   FAILING   SINCE
cluster-autoscaler                              True        False         False     29h
cluster-storage-operator                        True        False         False     29h
console                                         True        False         False     28h
dns                                             True        False         False     29h
image-registry                                  True        False         False     29h
ingress                                         True        False         False     28h
kube-apiserver                                  True        False         False     29h
kube-controller-manager                         True        False         False     29h
kube-scheduler                                  True        False         False     29h
machine-api                                     True        False         False     29h
machine-config                                  True        False         False     17h
marketplace-operator                            True        False         False     29h
monitoring                                      True        False         False     80m
network                                         True        False         False     81m
node-tuning                                     True        False         False     28h
openshift-apiserver                             True        False         False     81m
openshift-authentication                        True        False         False     29h
openshift-cloud-credential-operator             True        False         False     29h
openshift-controller-manager                    True        False         False     29h
openshift-samples                               True        False         False     29h
operator-lifecycle-manager                      True        False         False     29h
~~~

Or a more comprehensive way of getting a list of operators running on the
cluster, along with the link to the code, the documentation, and the commit that
provided the functionality is as follows:

~~~bash
$ oc adm release info --commits
Name:      4.0.0-0.7
Digest:    sha256:641c0e4f550af59ec20349187a31751ae5108270f13332d1771935520ebf34c1
Created:   2019-03-05 18:33:12 +0000 GMT
OS/Arch:   linux/amd64
Manifests: 248

Release Metadata:
  Version:  4.0.0-0.7
  Upgrades: 4.0.0-0.6
  Metadata:
    description: Beta 2

Images:
  NAME                                          REPO                                                                       COMMIT
  aws-machine-controllers                       https://github.com/openshift/cluster-api-provider-aws                      17d5aacdeb2df8898b20286970ace7d42f0c376a
  cli                                           https://github.com/openshift/ose                                           e268aada53a27b7cba51e4267d035dad207a1d8a
  cloud-credential-operator                     https://github.com/openshift/cloud-credential-operator                     97e00568622e2a82cde1e964be7ea7c37fe85b4f
  cluster-authentication-operator               https://github.com/openshift/cluster-authentication-operator               88650bd64069ed79a411098b481ac2416526ce0e
  cluster-autoscaler                            https://github.com/openshift/kubernetes-autoscaler                         e1a6a0960a100132abc5f8398ff73dbb0f45ae28
  cluster-autoscaler-operator                   https://github.com/openshift/cluster-autoscaler-operator                   0c2284a7a7cff0e123ace8d5e43337e4cc9739e9
  cluster-bootstrap                             https://github.com/openshift/cluster-bootstrap                             90a38fd8d9dc0b0a61214f079fd4734b034bae0c
  cluster-config-operator                       https://github.com/openshift/cluster-config-operator                       aa1805e73138deabbfa57772170f310e2f3097cd
  cluster-dns-operator                          https://github.com/openshift/cluster-dns-operator                          e4aa0a50f865e8399aeeccaf8c24f8d891cd67c2
  cluster-image-registry-operator               https://github.com/openshift/cluster-image-registry-operator               689aa65b90644aead5b579acce2725a08bd70f93
  cluster-ingress-operator                      https://github.com/openshift/cluster-ingress-operator                      e53dfea77b35656f105c41d5c1a3bcb2bc6fbcba
  cluster-kube-apiserver-operator               https://github.com/openshift/cluster-kube-apiserver-operator               4c34fbfd2b4382e366d45f5e9acd07fb8da1ee9d
  cluster-kube-controller-manager-operator      https://github.com/openshift/cluster-kube-controller-manager-operator      52a2f710ae90f0624c47040bf6d9b0ad55538de0
  cluster-kube-scheduler-operator               https://github.com/openshift/cluster-kube-scheduler-operator               c68e8b1af27033dec9ca9cd36c831b0796cef798
  cluster-machine-approver                      https://github.com/openshift/cluster-machine-approver                      c4ba3024437a348a03ee1459cdf9823d7c6de4a8
  cluster-monitoring-operator                   https://github.com/openshift/cluster-monitoring-operator                   25fd008f1fb34cc27332fcc59f6821ef01c306a6
  cluster-network-operator                      https://github.com/openshift/cluster-network-operator                      b13c79c1ae6290bbc472c0ac260855e26d71dfd3
  cluster-node-tuned                            https://github.com/openshift/openshift-tuned                               b580cb6f52a0e352aebbe0e368d5ec020230c532
  cluster-node-tuning-operator                  https://github.com/openshift/cluster-node-tuning-operator                  900d59d3aa7a59aa31318bc25efc5df1e994e4b9
  cluster-openshift-apiserver-operator          https://github.com/openshift/cluster-openshift-apiserver-operator          0a65fe40a74cfc6114fdaa30e2b2c24924509cda
  cluster-openshift-controller-manager-operator https://github.com/openshift/cluster-openshift-controller-manager-operator 6656fd894295a9924c6bf5de244586705508e595
  cluster-samples-operator                      https://github.com/openshift/cluster-samples-operator                      204cf2ba6a3a12d2344f69d19f539ebc31f39683
  cluster-storage-operator                      https://github.com/openshift/cluster-storage-operator                      b850242280b7ef2cf7631952229c0a438ec39e64
  cluster-svcat-apiserver-operator              https://github.com/openshift/cluster-svcat-apiserver-operator              547648cb7b3f2a0d8f049f680c18ac66cd339b3f
  cluster-svcat-controller-manager-operator     https://github.com/openshift/cluster-svcat-controller-manager-operator     9261f420a3db9556606c8ee0980a5e02a8f28d89
  cluster-version-operator                      https://github.com/openshift/cluster-version-operator                      bcf8bf290bc7d0090769b4722831dbb157b75d01
  configmap-reloader                            https://github.com/openshift/configmap-reload                              3c2f85724078cbf7ffab56886ff32d677c386afe
  console                                       https://github.com/openshift/console                                       24942e86dd5bef0b17c1e33bfcd386b450c49b19
  console-operator                              https://github.com/openshift/console-operator                              8665600274308fbda0f66e7ed8a0e5cc5c0bb7d9
  container-networking-plugins-supported        https://github.com/openshift/ose-containernetworking-plugins               f6a58dcec62ca740305a58a0a6b008c5e57b8943
  container-networking-plugins-unsupported      https://github.com/openshift/ose-containernetworking-plugins               f6a58dcec62ca740305a58a0a6b008c5e57b8943
  coredns                                       https://github.com/openshift/coredns                                       fbcb8252a1bab3d32ecf2dd3307f798aacd0280e
  deployer                                      https://github.com/openshift/ose                                           e268aada53a27b7cba51e4267d035dad207a1d8a
  docker-builder                                https://github.com/openshift/builder                                       1a77d837d8d74d5dcb6f8afcadb082629b04883e
  docker-registry                               https://github.com/openshift/image-registry                                afcc7daa5eeeb6a77754ae86decefade83314189
  etcd                                          https://github.com/openshift/etcd                                          a0e62b48f8db8572c129fa3d3507c7ce118ab650
  grafana                                       https://github.com/openshift/grafana                                       2ea5517e5d33531ee8b838c70666e484a79cd49d
  haproxy-router                                https://github.com/openshift/router                                        80b8c3d8e67e7549c59957421db2a5d344d8796a
  hyperkube                                     https://github.com/openshift/ose                                           e268aada53a27b7cba51e4267d035dad207a1d8a
  hypershift                                    https://github.com/openshift/ose                                           e268aada53a27b7cba51e4267d035dad207a1d8a
  installer                                     https://github.com/openshift/installer                                     c8b3b5532694c7713efe300a636108174d623c52
  jenkins                                       https://github.com/openshift/jenkins                                       6b596492c09144c37bb484393b977136783d91bd
  jenkins-agent-maven                           https://github.com/openshift/jenkins                                       6b596492c09144c37bb484393b977136783d91bd
  jenkins-agent-nodejs                          https://github.com/openshift/jenkins                                       6b596492c09144c37bb484393b977136783d91bd
  k8s-prometheus-adapter                        https://github.com/openshift/k8s-prometheus-adapter                        815fa76bdbccfd5ee6da8f9fa45d039c4342dcdb
  kube-rbac-proxy                               https://github.com/openshift/kube-rbac-proxy                               3f271e0951f18276ec54e8eac936725d6d68e073
  kube-state-metrics                            https://github.com/openshift/kube-state-metrics                            2ab51c9f341799107ffbf7f373ab55254dc044d0
  libvirt-machine-controllers                   https://github.com/openshift/cluster-api-provider-libvirt                  a06e49585f2cd716ae642c40701c67f17b747553
  machine-api-operator                          https://github.com/openshift/machine-api-operator                          050a65a2bdabcc2c2f17036de967c6bcee6d6a48
  machine-config-controller                     https://github.com/openshift/machine-config-operator                       f5ea7118453804f30b6da859e3a8f7a924e4296d
  machine-config-daemon                         https://github.com/openshift/machine-config-operator                       f5ea7118453804f30b6da859e3a8f7a924e4296d
  machine-config-operator                       https://github.com/openshift/machine-config-operator                       f5ea7118453804f30b6da859e3a8f7a924e4296d
  machine-config-server                         https://github.com/openshift/machine-config-operator                       f5ea7118453804f30b6da859e3a8f7a924e4296d
  machine-os-content
  multus-cni                                    https://github.com/openshift/ose-multus-cni                                61f9e0886370ea5f6093ed61d4cfefc6dadef582
  must-gather                                   https://github.com/openshift/must-gather                                   8286a5dc432e339dc79c75044424cd9c89dc634b
  node                                          https://github.com/openshift/ose                                           e268aada53a27b7cba51e4267d035dad207a1d8a
  oauth-proxy                                   https://github.com/openshift/oauth-proxy                                   40c12481bfdd3e87d133736351c907000d5759b2
  openstack-machine-controllers                 https://github.com/openshift/cluster-api-provider-openstack                9e913e83ca639e7f6e10fdffa8445f504b101f3c
  operator-lifecycle-manager                    https://github.com/operator-framework/operator-lifecycle-manager           04d2513ec9932f20bec57456ba9b4deebd733f71
  operator-marketplace                          https://github.com/operator-framework/operator-marketplace                 aabac93da42773f29c4230bd8b7906facc6c42f9
  operator-registry                             https://github.com/operator-framework/operator-registry                    0531400c661ef7088d71b86ff5f52892f9407a1a
  pod                                           https://github.com/openshift/images                                        2f60da39a9d2e5cc00293b8ec7ad559fcd32446a
  prom-label-proxy                              https://github.com/openshift/prom-label-proxy                              46423f9d573c7d53f5727de1e2db095ae039da06
  prometheus                                    https://github.com/openshift/prometheus                                    6e5fb5dcb6a709bd20ea68cddc1abfcceb8a487d
  prometheus-alertmanager                       https://github.com/openshift/prometheus-alertmanager                       4617d5502332dc41c9c885cc12ecde5069191f73
  prometheus-config-reloader                    https://github.com/openshift/prometheus-operator                           f8a0aa170bf81ef70e16875053573a037461042d
  prometheus-node-exporter                      https://github.com/openshift/node_exporter                                 f248b582878226c8a8cd650223cf981cc556eb44
  prometheus-operator                           https://github.com/openshift/prometheus-operator                           f8a0aa170bf81ef70e16875053573a037461042d
  service-catalog                               https://github.com/openshift/service-catalog                               b24ffd6f826fe094a49afc04a5d62ab65490bb37
  service-serving-cert-signer                   https://github.com/openshift/service-serving-cert-signer                   309242162ed5bcf9398fca0ba9418244ec7c6808
  setup-etcd-environment                        https://github.com/openshift/machine-config-operator                       f5ea7118453804f30b6da859e3a8f7a924e4296d
  telemeter                                     https://github.com/openshift/telemeter                                     0fdf2d009d884ba3f1180d2b5f1531794c80b8d1
  tests                                         https://github.com/openshift/ose                                           e268aada53a27b7cba51e4267d035dad207a1d8a
~~~

You can also `rsh` (remote shell access) into the running Operator and see the
various manifests associated with the installed release of OpenShift:

~~~bash
$ oc rsh -n openshift-cluster-version deployments/cluster-version-operator
~~~

Then to list the available manifests:

~~~bash
sh-4.2# ls -l /release-manifests/
total 836
-r--r--r--. 1 root root   171 Jan 15 04:04 0000_07_cluster-network-operator_00_namespace.yaml
-r--r--r--. 1 root root   381 Jan 15 04:04 0000_07_cluster-network-operator_01_crd.yaml
-r--r--r--. 1 root root   316 Jan 15 04:04 0000_07_cluster-network-operator_02_rbac.yaml
-r--r--r--. 1 root root  1904 Jan 15 04:04 0000_07_cluster-network-operator_03_daemonset.yaml
-r--r--r--. 1 root root   960 Jan 15 04:04 0000_08_cluster-dns-operator_00-cluster-role.yaml
-r--r--r--. 1 root root   298 Jan 15 04:04 0000_08_cluster-dns-operator_00-custom-resource-definition.yaml
-r--r--r--. 1 root root   198 Jan 15 04:04 0000_08_cluster-dns-operator_00-namespace.yaml
(...)
~~~

You will see a number of `.yaml` files in this directory; these are manifests
that describe each of the operators and how they're applied. Feel free to take a
look at some of these to give you an idea of what it's doing.

~~~bash
sh4.2# cat /release-manifests/0000_70_console-operator_00-crd.yaml
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: consoles.console.openshift.io
spec:
  group: console.openshift.io
  names:
    kind: Console
    listKind: ConsoleList
    plural: consoles
    singular: console
  scope: Namespaced
  version: v1alpha1

sh4.2# exit
exit
~~~

> **NOTE**: Don't forget to `exit` from your`rsh` session before continuing...

If you want to look at what the Cluster Operator has done since it was launched,
you can execute the following:

~~~bash
$ oc logs deployments/cluster-version-operator -n openshift-cluster-version > operatorlog.txt
$ ls operatorlog.txt
I0306 10:28:10.548869       1 start.go:71] ClusterVersionOperator v4.0.0-0.139.0.0-dirty
I0306 10:28:10.601159       1 start.go:197] Using in-cluster kube client config
I0306 10:28:10.667401       1 leaderelection.go:185] attempting to acquire leader lease  openshift-cluster-version/version...
(...)
~~~

The operator's log is **extremely** long, so it is recommended that you redirect
it to a file instead of trying to look at it directly with the `logs` command.

# Exploring RHEL CoreOS
*WARNING* this requires advanced knowledge of EC2 and is not a thourough set
*of instructions.

The latest installer does not create any public IP addresses for any of the
EC2 instances that it provisions for your OpenShift cluster. In order to be
able to SSH to your OpenShift 4 hosts:

1. Create a security group that allows SSH access into the VPC created by the 
installer
1. Create an EC2 instance yourself:
    * inside the VPC that the installer created
    * on one of the public subnets the installer created
1. Associate a public IP address with the EC2 instance that you created.

Unlike with the OpenShift installation, you must associate the EC2 instance
you create with an SSH keypair that you already have access to.

It does not matter what OS you choose for this instance, as it will simply
serve as an SSH bastion to bridge the internet into your OCP VPC.

Once you have provisioned your EC2 instance and can SSH into it, you will
then need to add the SSH key that you associated with your OCP installation
(**not the key for the bastion instance**). At that point you can follow the
rest of the instructions.

## Cluster Makeup
The OpenShift 4 cluster is made of hosts that are running RHEL CoreOS.
CoreOS is a container optimized, hardened, minimal footprint operating system
designed specifically to work with OpenShift and to run containers.

## Find a Hostname
First, look at the output of `oc get nodes` and pick one of the nodes that is
a master. Its name is something like `ip-10-0-1-163.ec2.internal`. 

From the bastion SSH host you manually deployed into EC2, you can then SSH
into that master host, making sure to use the same SSH key you specified
during the installation:

    ssh -i /path/to/sshkey core@MASTER_HOSTNAME_FROM_ABOVE

**Note: you *must* use the `core` user**.

If it works, you'll see the CoreOS MOTD/prompt:

    Red Hat CoreOS 400.7.20190301.0 Beta
    WARNING: Direct SSH access to machines is not recommended.
    This node has been annotated with machineconfiguration.openshift.io/ssh=accessed
    
    ---
    [core@ip-10-0-135-32 ~]$ 

## Explore RHEL CoreOS
You can check the kernel information with the following:

    uname -rs

You will see something like:

    Linux 3.10.0-957.5.1.el7.x86_64

The following command will show you a little bit about how `Ignition`
contacts remote servers for information and etc:

    journalctl --no-pager|grep "Ignition finished successfully" -B 100

RHEL CoreOS is an immutable operating system. It is predominantly a
read-only image-based OS. Try to create a file:

    touch /usr/test

You will see that you cannot because the FS is read only. However, there is a
place that is writable, but it is only writable by a user with privileges
(not `core`). As the `core` user, attempt to write to `/var/`:

    touch /var/test

You will be denied because of permissions. However, if you use `sudo`, it
will work:

    sudo touch /var/test && ls -l /var/test*

SELinux is enforcing:

    sestatus

You will see something like:

    SELinux status:                 enabled
    SELinuxfs mount:                /sys/fs/selinux
    SELinux root directory:         /etc/selinux
    Loaded policy name:             targeted
    Current mode:                   enforcing
    Mode from config file:          enforcing
    Policy MLS status:              enabled
    Policy deny_unknown status:     allowed
    Max kernel policy version:      31

The following commands will show you more information about the core of
OpenShift:

    systemctl status kubelet
    systemctl status crio
    sudo crictl pods

During the bootstrapping process, we need to run containers, but OpenShift's
core (eg: kubelet) is still not there yet. To accomplish that, `podman` is
used. You can explore `podman` a little:

    podman version

Next: [Scaling the Cluster](04-scaling-cluster.md)
