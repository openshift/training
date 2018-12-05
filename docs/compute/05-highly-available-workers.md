
# Highly Avaiable Workers

The install creates a highly available pool of worker machines by default for
the target platform.

## AWS

Each cluster is associated with a region.

The install creates a `MachineSet` for each availability zone in that region.

If the region supports 3 availability zones, and the user requests 3 machines,
then a `MachineSet` is created for each availability zone with a replica size of
1.

To view all machinesets and their replica count, execute the following:

```sh
oc get machinesets -n openshift-cluster-api -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.replicas}{"\n"}{end}'
decarr-worker-us-east-2a	1
decarr-worker-us-east-2b	1
decarr-worker-us-east-2c	1
```

Next: [Cluster Autoscaler](06-cluster-autoscaler.md) 
