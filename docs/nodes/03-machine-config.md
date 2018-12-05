# Machine Configuration

This tutorial explains how files and operating system updates are delivered.

## Machine Config Operator

The machine config operator is responsible for coordinated rollout of
configuration to machines in the cluster.

To view the operator, execute the following:

```sh
oc get deployments -n openshift-machine-config-operator machine-config-operator
NAME                      DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
machine-config-operator   1         1         1            1           2h
```

This operator deploys resources to manage configuration on the hosts.

## Machine Config

The `MachineConfig` is a custom resource definition that describes a set of
files that should be applied to a host.

To view the list of machine configs, execute the following:

```sh
oc get machineconfigs
NAME                               AGE
00-master                          2h
00-worker                          2h
830eef02a7bc439c3057486f00224d40   2h
ff43b88a861697ce6c7d9cb0e5b3215a   2h
```

Each `MachineConfig` includes an ignition stub that has the filesytem, path, and
contents of a resource that should be deployed to a host in the cluster on first
boot, and over its life-cycle as changes are rolled out.

To view this information, execute the following:

```sh
oc get machineconfigs -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.config.storage.files[*]}{"\t"}{.filesystem}{"\t"}{.path}{"\n"}{end}{"\n"}{end}{"\n"}'
00-master
    root    /etc/containers/registries.conf
    root    /etc/hosts
    root    /etc/kubernetes/manifests/etcd-member.yaml
    root    /etc/sysconfig/crio-network
    root    /etc/kubernetes/static-pod-resources/etcd-member/ca.crt
    root    /etc/kubernetes/static-pod-resources/etcd-member/root-ca.crt
    root    /etc/kubernetes/kubelet.conf
    root    /var/lib/kubelet/config.json
    root    /etc/docker/certs.d/docker-registry.default.svc:5000/ca.crt
    root    /etc/kubernetes/ca.crt
    root    /etc/sysctl.d/forward.conf
00-worker
    root    /etc/containers/registries.conf
    root    /etc/hosts
    root    /etc/sysconfig/crio-network
    root    /etc/kubernetes/kubelet.conf
    root    /var/lib/kubelet/config.json
    root    /etc/docker/certs.d/docker-registry.default.svc:5000/ca.crt
    root    /etc/kubernetes/ca.crt
    root    /etc/sysctl.d/forward.conf
830eef02a7bc439c3057486f00224d40
    root    /etc/containers/registries.conf
    root    /etc/hosts
    root    /etc/sysconfig/crio-network
    root    /etc/kubernetes/kubelet.conf
    root    /var/lib/kubelet/config.json
    root    /etc/docker/certs.d/docker-registry.default.svc:5000/ca.crt
    root    /etc/kubernetes/ca.crt
    root    /etc/sysctl.d/forward.conf
ff43b88a861697ce6c7d9cb0e5b3215a
    root    /etc/containers/registries.conf
    root    /etc/hosts
    root    /etc/kubernetes/manifests/etcd-member.yaml
    root    /etc/sysconfig/crio-network
    root    /etc/kubernetes/static-pod-resources/etcd-member/ca.crt
    root    /etc/kubernetes/static-pod-resources/etcd-member/root-ca.crt
    root    /etc/kubernetes/kubelet.conf
    root    /var/lib/kubelet/config.json
    root    /etc/docker/certs.d/docker-registry.default.svc:5000/ca.crt
    root    /etc/kubernetes/ca.crt
    root    /etc/sysctl.d/forward.conf
```

## Machine Config Pools

The `MachineConfigPool` is a custom resource definition that matches a set of
`MachineConfig` definitions with a set of hosts via label selector.  It exposes
options for how configuration is rolled out to each host in the cluster in a
coordinated matter to reduce the blast radius of a change in the cluster.

To view the list of machine config pools, execute the following:

```sh
oc get machineconfigpools 
NAME      AGE
master    2h
worker    2h
```

To view the set of machines and configuration that are matched by a
`MachineConfig`, execute the following:

```sh
oc get machineconfigpools -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.machineConfigSelector.matchLabels}{"\t"}{.spec.machineSelector.matchLabels}{"\n"}{end}{"\n"}'
master  map[machineconfiguration.openshift.io/role:master]  map[node-role.kubernetes.io/master:]
worker  map[machineconfiguration.openshift.io/role:worker]  map[node-role.kubernetes.io/worker:]
```

## Machine Config Controller

This controller coordinates how machines reach their desired host configuration.

To view the operator, execute the following:

```sh
oc get deployments -n openshift-machine-config-operator machine-config-controller
NAME                        DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
machine-config-controller   1         1         1            1           2h
```

It observes changes to `MachineConfigPool` and annotates each node with its
desired machine configuration by applying the annotation
`machineconfiguration.openshift.io/desiredConfig`.  To minimize the blast radius
of a change, it makes the change on a subset of machines at a time.

## Machine Config Daemon

This daemon runs on each machine, and applies the desired machine configuration
to each host by watching the `machineconfiguration.openshift.io/desiredConfig`
annotation. If the `machineconfiguration.openshift.io/currentConfig` does not
match, the daemon attempts an update.

To see the list of nodes with their desired and current configuration, execute the following:

```sh
oc get nodes -o yaml | grep annotations -A 3
    annotations:
      machine: openshift-cluster-api/decarr-worker-us-east-2a-2dv5d
      machineconfiguration.openshift.io/currentConfig: 830eef02a7bc439c3057486f00224d40
      machineconfiguration.openshift.io/desiredConfig: 830eef02a7bc439c3057486f00224d40
--
    annotations:
      machine: openshift-cluster-api/decarr-worker-us-east-2b-k9tc9
      machineconfiguration.openshift.io/currentConfig: 830eef02a7bc439c3057486f00224d40
      machineconfiguration.openshift.io/desiredConfig: 830eef02a7bc439c3057486f00224d40
--
    annotations:
      machine: openshift-cluster-api/decarr-worker-us-east-2c-pqb9j
      machineconfiguration.openshift.io/currentConfig: 830eef02a7bc439c3057486f00224d40
      machineconfiguration.openshift.io/desiredConfig: 830eef02a7bc439c3057486f00224d40
--
    annotations:
      machine: openshift-cluster-api/decarr-master-1
      machineconfiguration.openshift.io/currentConfig: ff43b88a861697ce6c7d9cb0e5b3215a
      machineconfiguration.openshift.io/desiredConfig: ff43b88a861697ce6c7d9cb0e5b3215a
--
    annotations:
      machine: openshift-cluster-api/decarr-master-2
      machineconfiguration.openshift.io/currentConfig: ff43b88a861697ce6c7d9cb0e5b3215a
      machineconfiguration.openshift.io/desiredConfig: ff43b88a861697ce6c7d9cb0e5b3215a
--
    annotations:
      machine: openshift-cluster-api/decarr-master-0
      machineconfiguration.openshift.io/currentConfig: ff43b88a861697ce6c7d9cb0e5b3215a
      machineconfiguration.openshift.io/desiredConfig: ff43b88a861697ce6c7d9cb0e5b3215a
```

During each update, it cordons, drains, and updates the host.  If an operating
system image update is required, it is applied.  Finally, once all updates are
completed, it reboots the host.

To view the daemon, execute the following:

```sh
oc get ds -n openshift-machine-config-operator machine-config-daemon
NAME                    DESIRED   CURRENT   READY     UP-TO-DATE   AVAILABLE   NODE SELECTOR   AGE
machine-config-daemon   6         6         6         6            6           <none>          3h
```

### Machine Config Server

The machine config server is used to serve an ignition configuration for new
machines that join the cluster.  This ensures that new machines always
have the latest desired configuration applied prior to accepting workloads.

Next: [Explore More](../03-explore.md)