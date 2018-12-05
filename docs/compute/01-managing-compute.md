# Managing Compute

This tutorial will walk you through managing compute instances.

# Machine API

OpenShift uses the machine API types introduced by the [Kubernetes Cluster
API](https://github.com/kubernetes-sigs/cluster-api).

This enables administrators to introspect and manage machines in the cluster
using a Kubernetes native approach.

## Machine

The `Machine` object represents a "Kubernetes machine" that can run workloads in
the cluster.

To see the machines in the cluster, you can run the following command:

```sh
oc get machines -n openshift-cluster-api
NAME                             AGE
decarr-master-0                  3h
decarr-master-1                  3h
decarr-master-2                  3h
decarr-worker-us-east-2a-gdbnm   3h
decarr-worker-us-east-2b-bj9dz   3h
decarr-worker-us-east-2c-w2pfs   3h
```

The specification for each machine is specific to each target cloud platform.

### Amazon Web Services

If you are using the machine API on Amazon Web Services, the
`.spec.providerConfig` section of a `Machine` resource describes how a machine
should be provisioned on Amazon.

To list machines and their associated instance type, you can run the following
command:

```sh
oc get machines -n openshift-cluster-api -o jsonpath='{range .items[*]}{"\n"}{.metadata.name}{"\t"}{.spec.providerConfig.value.instanceType}{end}{"\n"}'
decarr-master-0 m4.large
decarr-master-1 m4.large
decarr-master-2 m4.large
decarr-worker-us-east-2a-9vcvt  m4.large
decarr-worker-us-east-2b-b4hfj  m4.large
decarr-worker-us-east-2c-q5pdm  m4.large
```

## MachineSets

The `MachineSet` object allows an admin to request a desire for a specific
number of machines replicated from a common `Machine` template.

To see the machine sets in the cluster, you can run the following command:

```sh
oc get machinesets -n openshift-cluster-api
NAME                       AGE
decarr-worker-us-east-2a   23m
decarr-worker-us-east-2b   23m
decarr-worker-us-east-2c   23m
```

# Machine Lifecycle

## Provisioning

To provision a new machine, the user can create a new `Machine`.

An easy way to create a new machine is to scale up a `MachineSet`.

To scale a `MachineSet` to 5 replicas, you can run the following command:

```sh
oc patch -n openshift-cluster-api machineset/decarr-worker-us-east-2a -p '{"spec":{"replicas":5}}'
TODO add machine listing showing new machine
TODO add node listing showing new node
```

## Deprovisioning

To deprovision a machine, the user can delete a `Machine` resource.

An easy way to delete a machine is to scale down a `MachineSet`.

```sh
TODO
```

Prior to deleting the machine, the node is cordoned and drained of its pods.

# Next steps

The machine API provides a powerful primitive to manage compute in the cluster.

In the following sections, we will see how it is used to lifecycle compute for
the cluster.

Next: [Control Plane](02-control-plane.md)