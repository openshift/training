# Autoscaling Workers

In this tutorial, we will use the cluster autoscaler to scale worker machines
to meet a workload demand.

## Use Case

The administrator wants to maintain a highly available cluster deployed in a
region with 3 availability zones.  The administrator runs a control plane
machine in each region.  The pool of workers should scale between 3 and 24 total
worker machines based on observed demand.  The pool of workers should attempt to
balance across availability zones. An outage of an availability zone should
result in workers scaling up in other zones to handle demand.

## Solution

In the previous tutorial, we deployed the `ClusterAutoscaler` and restricted the
growth of machines to 27.  This enables us to have machine to run the control plane
in each availability zone while still allowing 24 workers across each zone.

In this tutorial, the administrator will autoscale each `MachineSet` to support
scaling between 1 and 12 machines.  Since each `MachineSet` is scoped to a zone,
the loss of a single zone still ensures that across the sets in the remaining zones
the cluster can still scale to meet observed demand.

## Autoscale Machines

To view the machine sets, execute the following:

```sh
oc get machinesets -n openshift-cluster-api
NAME                       AGE
decarr-worker-us-east-2a   1d
decarr-worker-us-east-2b   1d
decarr-worker-us-east-2c   1d
```

To scale each machine set, we must deploy a `MachineAutoscaler` resource.

This resource lets you define a min and max size for a given set.

**NOTE** Depending on your cluster name, you may need to modify these resources to address your machineset appropriately.

```sh
oc create -f https://raw.githubusercontent.com/derekwaynecarr/openshift-the-easy-way/master/assets/machine-autoscale-us-east-2a.yaml
oc create -f https://raw.githubusercontent.com/derekwaynecarr/openshift-the-easy-way/master/assets/machine-autoscale-us-east-2b.yaml
oc create -f https://raw.githubusercontent.com/derekwaynecarr/openshift-the-easy-way/master/assets/machine-autoscale-us-east-2c.yaml
```

The `MachineAutoscaler` controller will detect the desired state and apply annotations
to each set to alert the cluster autoscaler on the min and max boundaries.

To verify the annotations have been applied, execute the following:

```sh
oc get machinesets -n openshift-cluster-api -o yaml | grep -A 2 annotations
    annotations:
      sigs.k8s.io/cluster-api-autoscaler-node-group-max-size: "12"
      sigs.k8s.io/cluster-api-autoscaler-node-group-min-size: "1"
--
    annotations:
      sigs.k8s.io/cluster-api-autoscaler-node-group-max-size: "12"
      sigs.k8s.io/cluster-api-autoscaler-node-group-min-size: "1"
--
    annotations:
      sigs.k8s.io/cluster-api-autoscaler-node-group-max-size: "12"
      sigs.k8s.io/cluster-api-autoscaler-node-group-min-size: "1"
```

## Introduce a workload

To demonstrate autoscaling, let's introduce a workload to the cluster.  This workload will create a large number of pods
concurrently that will require a scale up event for the cluster to satisfy.  Each pod runs for 10m.

```sh
oc new-project work-queue
oc create -f https://raw.githubusercontent.com/derekwaynecarr/openshift-the-easy-way/master/assets/job-work-queue.yaml
```

This will create a large number of pods that need scheduling.

To see the new machines coming up:

```sh
oc get machines -n openshift-cluster-api
```

Each machine will take ~3m to join the cluster pending image pull time.

After ~3m, you should see the new nodes go ready:

```sh
oc get nodes
```

Each job in the work queue will run for ~5m.

As jobs complete, the cluster shrinks in size and machines are removed.

Next: [Health Checks](08-health-checks.md)