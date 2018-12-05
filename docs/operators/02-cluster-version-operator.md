# Cluster Version Operator

This tutorial describes the top level operator that manages cluser updates.

## Cluster Version

The `ClusterVersion` resource describes the version of the cluster.

To view the version of the cluster, access the `ClusterVersion` resource.

```sh
oc get clusterversion
NAME      VERSION                           AVAILABLE   PROGRESSING   SINCE     STATUS
version   4.0.0-0.alpha-2018-12-03-184540   True        False         1h        Cluster version is 4.0.0-0.alpha-2018-12-03-184540
```

To see more detail about the cluster version, execute the following:

```sh
oc describe clusterversion
Name:         version
Namespace:    
Labels:       <none>
Annotations:  <none>
API Version:  config.openshift.io/v1
Kind:         ClusterVersion
Metadata:
  Creation Timestamp:  2018-12-03T19:50:53Z
  Generation:          1
  Resource Version:    9509
  Self Link:           /apis/config.openshift.io/v1/clusterversions/version
  UID:                 be183db4-f734-11e8-b511-02ef2cd26b4a
Spec:
  Channel:     fast
  Cluster ID:  44a92329-6124-48b8-be17-a34ab4f4ce70
  Overrides:
    Kind:       APIService
    Name:       v1alpha1.packages.apps.redhat.com
    Unmanaged:  true
  Upstream:     http://localhost:8080/graph
Status:
  Available Updates:  <nil>
  Conditions:
    Last Transition Time:  2018-12-03T19:57:38Z
    Message:               Done applying 4.0.0-0.alpha-2018-12-03-184540
    Status:                True
    Type:                  Available
    Last Transition Time:  2018-12-03T19:57:38Z
    Status:                False
    Type:                  Failing
    Last Transition Time:  2018-12-03T19:57:38Z
    Message:               Cluster version is 4.0.0-0.alpha-2018-12-03-184540
    Status:                False
    Type:                  Progressing
    Last Transition Time:  2018-12-03T19:51:11Z
    Message:               Unable to retrieve available updates: unexpected HTTP status: 404 Not Found
    Reason:                RemoteFailed
    Status:                False
    Type:                  RetrievedUpdates
  Current:
    Payload:     registry.svc.ci.openshift.org/openshift/origin-release:v4.0
    Version:     4.0.0-0.alpha-2018-12-03-184540
  Generation:    1
  Version Hash:  obkgmINz7o8=
Events:          <none>
```

## Release Payload

A `ClusterVersion` maps to a release payload image.  The release payload image
defines the set of operators that should be applied to a cluster in order to
install, upgrade, and reconcile cluster desired state.

To see the list of operators that define the current version, execute the
following:

```sh
oc adm release info registry.svc.ci.openshift.org/openshift/origin-release:v4.0
Name:      4.0.0-0.alpha-2018-12-04-003938
Digest:    sha256:c954d27201756060e26595a2861e5fde5ed3012743502f75277fe6735197b5f1
Created:   2018-12-03 19:40:39 -0500 EST
OS/Arch:   linux/amd64
Manifests: 146

Images:
  NAME                                          DIGEST
  aws-machine-controllers                       sha256:8610e4e111db2b7d368ba511ec4de76288a097689f7fa8c712276d5cf2d9a575
  cli                                           sha256:c7a9e466ad5aba366e026de18e576cc575d53904419ca84fde6267bb4025b076
  cluster-autoscaler-operator                   sha256:4f636ff8d9668f4fbba2d953d1017ca3df9707629cabd8164982231ffa0abe36
  cluster-bootstrap                             sha256:58b79dec7b54b6ade89615e2afc9cfdefb2f03bd612f6f27a4eff2763a342443
  cluster-dns-operator                          sha256:f0fdd4a07d31dde67ef7c35848c486dea3e2d42990b67fea8e80861175e1076b
  cluster-image-registry-operator               sha256:6e415d8224fcdadaf08fed0e6791f2ecac1c1ae59d1ba8734531f18d4417220f
  cluster-ingress-operator                      sha256:2a2613fef6622c4d39f6e7f67fc021250206c59231503c08bb54af8280f1f567
  cluster-kube-apiserver-operator               sha256:4330660366da1f97fff2b4895d5dbd20b47e291afabef1f442e21fff48e15cb1
  cluster-kube-controller-manager-operator      sha256:1398f6fdc3b4869e7dfac1e5b3097398b65d6d868ca24b2aee8cb0594a633fc5
  cluster-kube-scheduler-operator               sha256:b30682fc6cf4886bd66c9f28fe091ded9f811a93a22ab480c7a2ae79450b6e17
  cluster-machine-approver                      sha256:581af93fda80257651d621dade879e438f846a5bf39040dd0259006fc3b73820
  cluster-monitoring-operator                   sha256:20393c3ce270834bfe261c1eaabea8947732240f6f1235c39eecb5ffa05d1835
  cluster-network-operator                      sha256:a8aa3e53cbaeae806210878f0c7b499b636a963b2a52f4d1eea6db3dfa2fdc98
  cluster-node-tuned                            sha256:6667ac4aecae183dfd4e6ae4277dd86ca977e0a3b9feefee653043105503c6d6
  cluster-node-tuning-operator                  sha256:9a3d67b76bbcfc180ba1eadf9be125c7e0cde35834eac733fbf81fc0711f52d0
  cluster-openshift-apiserver-operator          sha256:e2f045f8a08006ed3e328ed37be28978900945a33fa3a7d33b32cad1470bc130
  cluster-openshift-controller-manager-operator sha256:b19f518cb41dce7e3fe134d06b8e837073794a4680b5f943346643229c227a46
  cluster-samples-operator                      sha256:8268004eb08e52d9be3e77827edc21d3c9a6c310de3484783032625ac025703f
  cluster-version-operator                      sha256:9e0185ed0c984b66c5db71a9c50cd4f1cb844abf4b3a514825b2dfe59e03ab3b
  console                                       sha256:61afcc92eee49931ce7879ff628daf8efdf604e65e9720625e8bc0b7cda7a26f
  console-operator                              sha256:bf6d6915622fb5e527dd4ffb083e5e134240ff245ecc5a2686286470b37dc9cd
  coredns                                       sha256:e4936a702d7d466a64a6a9359f35c7ad528bba7c35fe5c582a90e46f9051d8b8
  csi-driver-registrar                          sha256:c4b8e70eaeec2959060085a8aa2b9203cc4add34842728c7ea807e144722832e
  csi-external-attacher                         sha256:01285eabf22efcbfdea78f6ffc65eed1010f9f082dde4b00b4e4266fdebc971f
  csi-external-provisioner                      sha256:094ec3ead253b09022b43a08802dae6497d37be3872e8895c39dbfc1359a5f6d
  csi-livenessprobe                             sha256:3efa20f6d5b55e3082a5ae0d6980cc9bfc6dc8565407a4aa46b67216a3a7cc8b
  csi-operator                                  sha256:042a5490b2c7e05eb14b9e248bfd3470388c456c959136b995a3b3a063060c75
  deployer                                      sha256:58be72cea031b887706b8ba088dd18c661df7f3eddc339b99a25b48f4c006241
  docker-builder                                sha256:636a90a1edda24ceafd6f6917c3f6d3427eb43422b02c18dd3eeeb0109b58b68
  docker-registry                               sha256:c8c110b8733d0d352ddc5fe35ba9eeac913b7609c2c9c778586f2bb74f281681
  haproxy-router                                sha256:f39dece70c9adc7f251c1f2275e90266f35ac47bb42772de9bca01bdb2d51ad6
  hyperkube                                     sha256:e6bd189adf849a2e7b9510c1fe82c5f7b8dc1fe0c2a4316b3f6773962e3ff5d2
  hypershift                                    sha256:7d848e4f6ab1d426b4b9fd958247b74251a59247ec602a7eff085926e4ea10d4
  libvirt-machine-controllers                   sha256:16060d1a461ef9d4fbe2d7ba14b7378ae07b59af1150e7720b4e0b98b8633d7a
  machine-api-operator                          sha256:166628c841e80c65128e421557a44885d74450c0df041cab57e045e75fcf00d9
  machine-config-controller                     sha256:deedb04093f4a36c879a16d3c81f9d60d13e243334734bd7020de82e5a5a90dd
  machine-config-daemon                         sha256:0931aa0525e5cbfadd72b625f981cd40251e44f5a8e3c61aa85f62ffb7d6eca1
  machine-config-operator                       sha256:7b9a2f04d58bdcbf5833ee56e81fd5fe78f5292594609f73ab45a7c3af075300
  machine-config-server                         sha256:ad5bdf5faedcc906e5110f0b3a12c97f20782de5486201e16bb7b61296fdef7f
  node                                          sha256:0d600cc530e0304f1ce6ea791d2891e92be3621b410866a0a733f47c500a7f01
  olm                                           sha256:c444c811cb2366bf67fa95e46f6cb3820ecb064539862173499a878029a20b0d
  openstack-machine-controllers                 sha256:d81704f479e263ae6da7a918200788cd10e91e3a83e43c2451b27181e690a384
  service-serving-cert-signer                   sha256:b532d9351b803b5a03cf6777f12d725b4973851957497ea3e2b37313aadd6750
```

To see the list of operators, their source repos, and the associated commit,
execute the following:

```sh
oc adm release info registry.svc.ci.openshift.org/openshift/origin-release:v4.0 --commits
Name:      4.0.0-0.alpha-2018-12-04-003938
Digest:    sha256:c954d27201756060e26595a2861e5fde5ed3012743502f75277fe6735197b5f1
Created:   2018-12-03 19:40:39 -0500 EST
OS/Arch:   linux/amd64
Manifests: 146

Images:
  NAME                                          REPO                                                                       COMMIT 
  aws-machine-controllers                       https://github.com/openshift/cluster-api-provider-aws                      ae50317a3b56c849cc200e9c72dd06854cbe5471
  cli                                           https://github.com/openshift/origin                                        6fe98a2fceeb4c3a21bb76e36748cde4c45c4ecb
  cluster-autoscaler-operator                   https://github.com/openshift/cluster-autoscaler-operator                   388fd680bbf3455fed52b2434d395e38dfe2170e
  cluster-bootstrap                             https://github.com/openshift/cluster-bootstrap                             b2958a5ad08dccb95fc26b82a36a71ef94e8860a
  cluster-dns-operator                          https://github.com/openshift/cluster-dns-operator                          aaa7289694484574930c5c2e5f36ed19a32ab3ae
  cluster-image-registry-operator               https://github.com/openshift/cluster-image-registry-operator               83f0b8d3eddf2175496f915b7c095baa1d7f57a9
  cluster-ingress-operator                      https://github.com/openshift/cluster-ingress-operator                      085416486c403ebf55ae2e95e6623b90f80b04e3
  cluster-kube-apiserver-operator               https://github.com/openshift/cluster-kube-apiserver-operator               776687d68b37428f0f1f0c6f74c64c099933d72c
  cluster-kube-controller-manager-operator      https://github.com/openshift/cluster-kube-controller-manager-operator      7af4237e42a7134827840cf6af6bc6bf5e9757b6
  cluster-kube-scheduler-operator               https://github.com/openshift/cluster-kube-scheduler-operator               8ea47ff86c24aeb3453fe94807c76a3c99f5929b
  cluster-machine-approver                      https://github.com/openshift/cluster-machine-approver                      17a9b3eb1da3b5db69dbb2ce6528c59bc2df5aa1
  cluster-monitoring-operator                   https://github.com/openshift/cluster-monitoring-operator                   09edf1338d895592f25352ce4a85168fa53c92d7
  cluster-network-operator                      https://github.com/openshift/cluster-network-operator                      ab9e329892bbf7b800bd9f479aed2df7f4eb3059
  cluster-node-tuned                            https://github.com/openshift/openshift-tuned                               3d80914d2c32e22aa7ba1db2bfa8f704fb55f613
  cluster-node-tuning-operator                  https://github.com/openshift/cluster-node-tuning-operator                  cd26ebdb4a90790aafa44c2afb2679b2b4f9a589
  cluster-openshift-apiserver-operator          https://github.com/openshift/cluster-openshift-apiserver-operator          84673c60b9dc339c093bda9eed98f994127d3344
  cluster-openshift-controller-manager-operator https://github.com/openshift/cluster-openshift-controller-manager-operator 0bcba116b5530c0775d5683a590b9f5da30af7bb
  cluster-samples-operator                      https://github.com/openshift/cluster-samples-operator                      3269e28d1ea9c24a617f19f092fff64f0809a58d
  cluster-version-operator                      https://github.com/openshift/cluster-version-operator                      6a7afb861e2865a4269efeebed6e9872f8529d5d
  console                                       https://github.com/openshift/console                                       bd0beeb577d0b2d862e60239e4376557e1e2a5b5
  console-operator                              https://github.com/openshift/console-operator                              f1578c0be0264168ff2eb16b05337456620940b2
  coredns                                       https://github.com/openshift/coredns                                       4fbb9ba6d2abd35c97d0485d7fa9ac8f039477cf
  csi-driver-registrar                          https://github.com/openshift/csi-driver-registrar                          de895ba5e4cb83be2148a2c7a379eff99dbafb26
  csi-external-attacher                         https://github.com/openshift/csi-external-attacher                         9b0da06f677300a5a1be47a338a3cf5f3b49c9e9
  csi-external-provisioner                      https://github.com/openshift/csi-external-provisioner                      cf12791992cbebd04f314678fb1bc7ebd54c2aa1
  csi-livenessprobe                             https://github.com/openshift/csi-livenessprobe                             7d4112c2fab27913db99bd7ab60251a822e2fb49
  csi-operator                                  https://github.com/openshift/csi-operator                                  45ebe2c6fba413d3a79018c9f11d27fb12cf4cb1
  deployer                                      https://github.com/openshift/origin                                        6fe98a2fceeb4c3a21bb76e36748cde4c45c4ecb
  docker-builder                                https://github.com/openshift/builder                                       c6a4315f96e7af1777dee8178c5c372e08fd97c6
  docker-registry                               https://github.com/openshift/image-registry                                38aca248d1405b901f28ff472b413b682040616d
  haproxy-router                                https://github.com/openshift/origin                                        6fe98a2fceeb4c3a21bb76e36748cde4c45c4ecb
  hyperkube                                     https://github.com/openshift/origin                                        6fe98a2fceeb4c3a21bb76e36748cde4c45c4ecb
  hypershift                                    https://github.com/openshift/origin                                        6fe98a2fceeb4c3a21bb76e36748cde4c45c4ecb
  libvirt-machine-controllers                   https://github.com/openshift/cluster-api-provider-libvirt                  d82d0107b90324aa38ea23b132bae8b8da67b3bb
  machine-api-operator                          https://github.com/openshift/machine-api-operator                          b875f572f693a29b7a9e514cbad4e1b5ff5a026a
  machine-config-controller                     https://github.com/openshift/machine-config-operator                       84bf7d6940e480325944c959e8b599d949490120
  machine-config-daemon                         https://github.com/openshift/machine-config-operator                       84bf7d6940e480325944c959e8b599d949490120
  machine-config-operator                       https://github.com/openshift/machine-config-operator                       84bf7d6940e480325944c959e8b599d949490120
  machine-config-server                         https://github.com/openshift/machine-config-operator                       84bf7d6940e480325944c959e8b599d949490120
  node                                          https://github.com/openshift/origin                                        6fe98a2fceeb4c3a21bb76e36748cde4c45c4ecb
  olm                                           https://github.com/operator-framework/operator-lifecycle-manager           7f2129d16372668d3512e3119786d952483360d7
  openstack-machine-controllers                 https://github.com/openshift/cluster-api-provider-openstack                43aff4a43667d4c788da186074c4a50ed69f0f5c
  service-serving-cert-signer                   https://github.com/openshift/service-serving-cert-signer                   726b188efdb8c52c72e543ffee182753751a9623
```

## Cluster Version Operator

This operator ensures that specified release payload associated with a
`ClusterVersion` is applied to the cluster.  It reconciles the manifests in the
update payload with the Kubernetes API server to ensure the desired cluster
version converges with the observed version.

To view the operator, execute the following:

```sh
oc get deployments -n openshift-cluster-version
NAME                       DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
cluster-version-operator   1         1         1            1           1h
```

The manifests in the update payload are standard Kubernetes API resources and
custom resource definitions that drive operator behavior.  Earlier, we could see
there were 146 manifests in this release version.  These manfiests include
namespaces, custom resource definitions, rbac rules, service accounts, and
deployments or daemonsets that drive individual operator behavior.

To view the release update manifests, execute the following:

```sh
oc rsh -n openshift-cluster-version deployments/cluster-version-operator
sh-4.2# ls release-manifests
0000_07_cluster-network-operator_00_namespace.yaml                     0000_50_machine-api-operator_00_namespace.yaml
0000_07_cluster-network-operator_01_crd.yaml                           0000_50_machine-api-operator_01_images.configmap.yaml
0000_07_cluster-network-operator_02_rbac.yaml                          0000_50_machine-api-operator_02_machine.crd.yaml
0000_07_cluster-network-operator_03_daemonset.yaml                     0000_50_machine-api-operator_03_machineset.crd.yaml
0000_08_cluster-dns-operator_00-cluster-role.yaml                      0000_50_machine-api-operator_04_machinedeployment.crd.yaml
0000_08_cluster-dns-operator_00-custom-resource-definition.yaml                0000_50_machine-api-operator_05_cluster.crd.yaml
0000_08_cluster-dns-operator_00-namespace.yaml                         0000_50_machine-api-operator_06_machineclass.crd.yaml
0000_08_cluster-dns-operator_01-cluster-role-binding.yaml                  0000_50_machine-api-operator_07_machinehealthcheck.crd.yaml
0000_08_cluster-dns-operator_01-role-binding.yaml                      0000_50_machine-api-operator_08_rbac.yaml
0000_08_cluster-dns-operator_01-role.yaml                          0000_50_machine-api-operator_09_deployment.yaml
0000_08_cluster-dns-operator_01-service-account.yaml                       0000_50_machine-config-operator_00_namespace.yaml
0000_08_cluster-dns-operator_02-deployment.yaml                        0000_50_machine-config-operator_01_mcoconfig.crd.yaml
0000_09_service-serving-cert-signer_00_roles.yaml                      0000_50_machine-config-operator_02_images.configmap.yaml
0000_09_service-serving-cert-signer_01_namespace.yaml                      0000_50_machine-config-operator_03_rbac.yaml
0000_09_service-serving-cert-signer_02_crd.yaml                        0000_50_machine-config-operator_04_deployment.yaml
0000_09_service-serving-cert-signer_03_cm.yaml                         0000_51_machine-approver-00-ns.yaml
0000_09_service-serving-cert-signer_04_sa.yaml                         0000_51_machine-approver-01-sa.yaml
0000_09_service-serving-cert-signer_05_deploy.yaml                     0000_51_machine-approver-02-clusterrole.yaml
0000_09_service-serving-cert-signer_06_config.yaml                     0000_51_machine-approver-03-clusterrolebinding.yaml
0000_10_cluster-kube-apiserver-operator_00_namespace.yaml                  0000_51_machine-approver-04-deployment.yaml
0000_10_cluster-kube-apiserver-operator_01_config.crd.yaml                 0000_70_cluster-image-registry-operator_00-crd.yaml
0000_10_cluster-kube-apiserver-operator_02_service.yaml                    0000_70_cluster-image-registry-operator_01-namespace.yaml
0000_10_cluster-kube-apiserver-operator_03_configmap.yaml                  0000_70_cluster-image-registry-operator_01-openshift-config-managed-namespace.yaml
0000_10_cluster-kube-apiserver-operator_04_clusterrolebinding.yaml             0000_70_cluster-image-registry-operator_01-openshift-config-namespace.yaml
0000_10_cluster-kube-apiserver-operator_05_serviceaccount.yaml                 0000_70_cluster-image-registry-operator_02-rbac.yaml
0000_10_cluster-kube-apiserver-operator_06_deployment.yaml                 0000_70_cluster-image-registry-operator_03-sa.yaml
0000_11_cluster-kube-scheduler-operator_00_namespace.yaml                  0000_70_cluster-image-registry-operator_04-operator.yaml
0000_11_cluster-kube-scheduler-operator_01_config.crd.yaml                 0000_70_cluster-image-registry-operator_05-ca-config.yaml
0000_11_cluster-kube-scheduler-operator_03_configmap.yaml                  0000_70_cluster-image-registry-operator_06-ca-rbac.yaml
0000_11_cluster-kube-scheduler-operator_04_clusterrolebinding.yaml             0000_70_cluster-image-registry-operator_07-ca-serviceaccount.yaml
0000_11_cluster-kube-scheduler-operator_05_serviceaccount.yaml                 0000_70_cluster-image-registry-operator_08-ca-daemonset.yaml
0000_11_cluster-kube-scheduler-operator_06_deployment.yaml                 0000_70_cluster-ingress-operator_00-cluster-role.yaml
0000_12_cluster-kube-controller-manager-operator_00_namespace.yaml             0000_70_cluster-ingress-operator_00-custom-resource-definition.yaml
0000_12_cluster-kube-controller-manager-operator_01_config.crd.yaml            0000_70_cluster-ingress-operator_00-namespace.yaml
0000_12_cluster-kube-controller-manager-operator_02_service.yaml               0000_70_cluster-ingress-operator_01-cluster-role-binding.yaml
0000_12_cluster-kube-controller-manager-operator_03_configmap.yaml             0000_70_cluster-ingress-operator_01-kube-system-aws-creds-role-binding.yaml
0000_12_cluster-kube-controller-manager-operator_04_clusterrolebinding.yaml        0000_70_cluster-ingress-operator_01-role-binding.yaml
0000_12_cluster-kube-controller-manager-operator_05_serviceaccount.yaml            0000_70_cluster-ingress-operator_01-role.yaml
0000_12_cluster-kube-controller-manager-operator_06_deployment.yaml            0000_70_cluster-ingress-operator_01-service-account.yaml
0000_20_cluster-openshift-apiserver-operator_00_namespace.yaml                 0000_70_cluster-ingress-operator_02-deployment.yaml
0000_20_cluster-openshift-apiserver-operator_01_config.crd.yaml                0000_70_cluster-monitoring-operator_01-namespace.yaml
0000_20_cluster-openshift-apiserver-operator_03_configmap.yaml                 0000_70_cluster-monitoring-operator_02-role-binding.yaml
0000_20_cluster-openshift-apiserver-operator_04_roles.yaml                 0000_70_cluster-monitoring-operator_02-role.yaml
0000_20_cluster-openshift-apiserver-operator_05_serviceaccount.yaml            0000_70_cluster-monitoring-operator_03-config.yaml
0000_20_cluster-openshift-apiserver-operator_06_service.yaml                   0000_70_cluster-monitoring-operator_03-etcd-secret.yaml
0000_20_cluster-openshift-apiserver-operator_07_deployment.yaml                0000_70_cluster-monitoring-operator_04-deployment.yaml
0000_21_cluster-openshift-controller-manager-operator_00_namespace.yaml            0000_70_cluster-node-tuning-operator_01-namespace.yaml
0000_21_cluster-openshift-controller-manager-operator_01_config.crd.yaml           0000_70_cluster-node-tuning-operator_02-crd.yaml
0000_21_cluster-openshift-controller-manager-operator_02_configmap.yaml            0000_70_cluster-node-tuning-operator_03-rbac.yaml
0000_21_cluster-openshift-controller-manager-operator_03_builder-deployer-config.yaml  0000_70_cluster-node-tuning-operator_04-operator.yaml
0000_21_cluster-openshift-controller-manager-operator_04_roles.yaml            0000_70_cluster-samples-operator_00-crd.yaml
0000_21_cluster-openshift-controller-manager-operator_05_serviceaccount.yaml           0000_70_cluster-samples-operator_01-namespace.yaml
0000_21_cluster-openshift-controller-manager-operator_06_build.crd.yaml            0000_70_cluster-samples-operator_02-sa.yaml
0000_21_cluster-openshift-controller-manager-operator_07_deployment.yaml           0000_70_cluster-samples-operator_03-rbac.yaml
0000_30_00-namespace.yaml                                  0000_70_cluster-samples-operator_04-openshift-rbac.yaml
0000_30_01-olm-operator.serviceaccount.yaml                        0000_70_cluster-samples-operator_05-operator.yaml
0000_30_02-clusterserviceversion.crd.yaml                          0000_70_console-operator_00-crd.yaml
0000_30_03-installplan.crd.yaml                                0000_70_console-operator_00-oauth.yaml
0000_30_04-subscription.crd.yaml                               0000_70_console-operator_01-namespace.yaml
0000_30_05-catalogsource.crd.yaml                              0000_70_console-operator_02-rbac-role.yaml
0000_30_06-rh-operators.configmap.yaml                             0000_70_console-operator_03-rbac-rolebinding.yaml
0000_30_07-certified-operators.configmap.yaml                          0000_70_console-operator_04-config.yaml
0000_30_08-certified-operators.catalogsource.yaml                      0000_70_console-operator_04-sa.yaml
0000_30_09-rh-operators.catalogsource.yaml                         0000_70_console-operator_05-operator.yaml
0000_30_10-olm-operator.deployment.yaml                            0000_70_csi-operator_01_crd.yaml
0000_30_11-catalog-operator.deployment.yaml                        0000_70_csi-operator_02_csi_roles.yaml
0000_30_12-aggregated.clusterrole.yaml                             0000_70_csi-operator_03_csi_operator_role.yaml
0000_30_13-packageserver.yaml                                  0000_70_csi-operator_04_namespace.yaml
0000_30_14-operatorgroup.crd.yaml                              0000_70_csi-operator_05_sa.yaml
0000_50_cluster-autoscaler-operator_00_namespace.yaml                      0000_70_csi-operator_06_role_binding.yaml
0000_50_cluster-autoscaler-operator_01_clusterautoscaler.crd.yaml              0000_70_csi-operator_07_config.yaml
0000_50_cluster-autoscaler-operator_02_machineautoscaler.crd.yaml              0000_70_csi-operator_99_operator.yaml
0000_50_cluster-autoscaler-operator_03_rbac.yaml                       image-references
0000_50_cluster-autoscaler-operator_04_deployment.yaml
```

If you view the logs of the cluster version operator, you can see
its continously applying the desired state to avoid configuration drift.

To see the logs, execute the following:

```sh
oc logs deployments/cluster-version-operator -n openshift-cluster-version
```

## Understanding Upgrades

In order to upgrade the cluster, one must update the version of the cluster
version operator to a new release image.

The manifests are read from the release image, and applied to the cluster.  This
will update each operator, and each operator in turn is responsible for
observing existing state on the cluster and driving to the upgraded desired
state for the resources it manages.  This simplifies cluster upgrades into a
series of `kubectl apply` statements. Since the cluster version operator
reconciles the desired state of the cluster with observed state, drift of the
underlying cluster configuration which may have been applied manually is undone.

As a result, upgrading the cluster is equivalent to deploying a new version of
an application that runs on the platform.

# Next steps

The set of operators deployed by the cluster version operator are called
second level operators, learn more in the next tutorial.

Next: [Second Level Operators](03-second-level-operators.md)