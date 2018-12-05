# Control Plane

This tutorial will walk you through managing control plane machines.

## Bootstrapping

The install provisions the required compute to run the control plane.

Once the API server is running, the install creates a `Machine` resource for
each control plane machine using the machine API.  The machine API adopts the
existing machines.  Once machines are adopted, the machine API is responsible
for ensuring the continued existence of master machines.

## Identifying control plane machines

The control plane is executed on machines that have the
`sigs.k8s.io/cluter-api-machine-type=master` label.

To find all machines that run the control plane, execute the following:

```sh
oc get machines -l sigs.k8s.io/cluster-api-machine-type=master -n openshift-cluster-api
NAME              AGE
decarr-master-0   3h
decarr-master-1   3h
decarr-master-2   3h
```

Next: [Highly Available Control Plane](03-highly-available-control-plane.md)