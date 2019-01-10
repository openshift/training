# Highly Available Control Plane

The install creates a highly available control plane by default for the target
platform.

## AWS

Each cluster is associated with a region.

Each master is placed in a separate availability zone in that region.

To see the region for each control plane machine, execute the following:

```sh
oc get machines -l sigs.k8s.io/cluster-api-machine-type=master -n openshift-cluster-api -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.providerConfig.value.placement.region}{"\n"}{end}'
decarr-master-0 us-east-2
decarr-master-1 us-east-2
decarr-master-2 us-east-2
```

To see the availability zone for each control plane machine, execute the
following:

```sh
oc get machines -l sigs.k8s.io/cluster-api-machine-type=master -n openshift-cluster-api -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.providerConfig.value.placement.availabilityZone}{"\n"}{end}'
decarr-master-0 us-east-2a
decarr-master-1 us-east-2b
decarr-master-2 us-east-2c
```

## OpenStack

coming soon

Next: [Workers](04-workers.md)
