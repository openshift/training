# Worker Machines

This tutorial will walk you through managing worker machines.

## Bootstrapping

Once the cluster control plane is bootstrapped, all worker machines are
provisioned by the machine API.

The install creates a `MachineSet` with the desired number of replicas for the
cluster.

## Identifying worker machines

The worker nodes run end-user workloads on the cluster.

They execute on machines that have the
`sigs.k8s.io/cluster-api-machine-type=worker` label.

To find all worker machines, execute the following:

```sh
oc get machines -l sigs.k8s.io/cluster-api-machine-type=worker -n openshift-cluster-api
NAME                             AGE
decarr-worker-us-east-2a-gdbnm   4h
decarr-worker-us-east-2b-bj9dz   4h
decarr-worker-us-east-2c-w2pfs   4h
```

Worker nodes are backed by the `MachineSet` machine controller.

To view all machine sets, execute the following:

```sh
oc get machinesets -n openshift-cluster-api
NAME                       AGE
decarr-worker-us-east-2a   5h
decarr-worker-us-east-2b   5h
decarr-worker-us-east-2c   5h
```

Next: [Highly Available Workers](05-highly-available-workers.md)