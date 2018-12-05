# Cluster Autoscaler

The cluster autoscaler adds and removes machines from a cluster to match the
workload demand.

## Managing the Cluster Autoscaler

An operator manages the Cluster Autoscaler component.

To view the operator, execute the following:

```sh
oc get deployments -n openshift-cluster-api cluster-autoscaler-operator
NAME                          DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
cluster-autoscaler-operator   1         1         1            1           1h
```

## Autoscaling Limits

The operator watches for a `ClusterAutoscaler` resource to know how to
deploy and configure the autoscaler component.  The resource allows an
administrator to control global autoscaling limits for the cluster.

The administrator may configure the following options:
- max resource limits (nodes, cpu, memory, gpus, etc.)
- min resource limits (nodes, cpu, memory, gpus, etc.)
- pod priority threshold that requires scale up of cluster if pod is pending
- enable scale up, but not scale down

The [file](../assets/cluster-autsocaler.yaml) demonstrates a `ClusterAutoscaler`
object that restricts the cluster from scaling beyond 27 machines.

## Deploy Cluster Autoscaler

To deploy the cluster autoscaler, execute the following:

```sh
oc create -f https://raw.githubusercontent.com/derekwaynecarr/openshift-the-easy-way/master/assets/cluster-autoscaler.yaml
```

To verify the cluster autoscaler is deployed, execute the following:

```sh
oc get deployments cluster-autoscaler-default -n openshift-cluster-api
NAME                         DESIRED   CURRENT   UP-TO-DATE   AVAILABLE   AGE
cluster-autoscaler-default   1         1         1            1           3m
```

Next: [Autoscaling Workers](07-autoscaling-workers.md)