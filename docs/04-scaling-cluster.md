# Scaling an OpenShift 4 Cluster 
OpenShift 4 adds the ability to easily scale cluster size.

## Manual Cluster Scale Up/Down

To manually add worker nodes to the cluster: 

1. Go to the OpenShift web console and login with `kubeadmin`. 
1. Browse to `Administration` in the side-bar, and click `Machine Sets`. 
1. On the `Machine Sets` page, select `openshift-machine-api` from the
  `Project` dropdown.
1. Select a worker set to scale by clicking it.

   Depending on the AWS region you chose, you may have several worker machine
   sets that can be scaled, some of which are at a scale of 0. It does not
   matter which set you choose for this example.
1. In the `Actions` pull down menu, select `Edit Count`.
1. Enter the desired number (for example, 3) and click `Save`

At this point you can click the `Machines` tab in this `Machine Set` display
and see the allocated machines. The `Overview` tab will let you know when the
machines become ready. If you click `Machine Sets` under `Administration`
again, you will also see the status of the machines in the set.

It will take several minutes for the new machines to become ready. In the
background additional EC2 instances are being provisioned and then registered
and configured to participate in the cluster.

Before continuing, scale back down by editing the count to whatever it was
previously for the `Machine Set`.

### Note
The default installation currently creates two routers, but they are on the
same host. This is a known bug. It is possible that when you scale down your
cluster that you may inadvertently end up removing the node where the router
was running, which will temporarily make the console and other resources
unavailable. If you suddenly lose access to the web console, wait a few
moments, and then check to see the status of the router pod with:

    oc get pod -n openshift-ingress

If there is no router pod, or if it is in the `ContainerCreating` state, wait
a little longer.

### Note
You can alter the `Machine Set` count in several ways in the web UI. You can
also perform the same operation via the CLI by using the `oc edit` command on
the `machineset` in the `openshift-machine-api` project.

## Automatic Cluster Scale Up
Automatic scale based on workload is possible provided there is a
configuration specified to do so. From the command line, take a look at the
`machinesets` (they will look the same as in the web UI):

    oc get machinesets -n openshift-machine-api

You will see something like (differing depending on AWS region and `clusterid`):

    NAME                                    DESIRED   CURRENT   READY   AVAILABLE   AGE
    beta-190227-1-7fj4t-worker-us-east-1a   1         1         1       1           64m
    beta-190227-1-7fj4t-worker-us-east-1b   1         1         1       1           64m
    beta-190227-1-7fj4t-worker-us-east-1c   1         1         1       1           64m
    beta-190227-1-7fj4t-worker-us-east-1d   0         0                             64m
    beta-190227-1-7fj4t-worker-us-east-1e   0         0                             64m
    beta-190227-1-7fj4t-worker-us-east-1f   0         0                             64m

### Define a `MachineAutoScaler`
Fetch the following YAML file to the computer with the `oc` client installed:

https://raw.githubusercontent.com/openshift/training/master/assets/machine-autoscale-example.yaml

The file has the following contents:

```YAML
kind: List
metadata: {}
apiVersion: v1
items:
- apiVersion: "autoscaling.openshift.io/v1alpha1"
  kind: "MachineAutoscaler"
  metadata:
    generateName: autoscale-<aws-region-az>-
    namespace: "openshift-machine-api"
  spec:
    minReplicas: 1
    maxReplicas: 4
    scaleTargetRef:
      apiVersion: machine.openshift.io/v1beta1
      kind: MachineSet
      name: <clusterid>-worker-<aws-region-az>
- apiVersion: "autoscaling.openshift.io/v1alpha1"
  kind: "MachineAutoscaler"
  metadata:
    generateName: autoscale-<aws-region-az>-
    namespace: "openshift-machine-api"
  spec:
    minReplicas: 1
    maxReplicas: 4
    scaleTargetRef:
      apiVersion: machine.openshift.io/v1beta1
      kind: MachineSet
      name: <clusterid>-worker-<aws-region-az>
- apiVersion: "autoscaling.openshift.io/v1alpha1"
  kind: "MachineAutoscaler"
  metadata:
    generateName: autoscale-<aws-region-az>-
    namespace: "openshift-machine-api"
  spec:
    minReplicas: 1
    maxReplicas: 4
    scaleTargetRef:
      apiVersion: machine.openshift.io/v1beta1
      kind: MachineSet
      name: <clusterid>-worker-<aws-region-az>
```

When you looked at the `MachineSets` with the CLI, you noticed that they all
had the format of:

    <clusterid>-worker-<aws-region-az>

`MachineAutoscaler`s must be defined for each region-AZ that you want to
autoscale. Using the example output and `MachineSets` above, you would need
to modify the YAML file to look like the following:

```YAML
...
apiVersion: "autoscaling.openshift.io/v1alpha1"
kind: "MachineAutoscaler"
metadata:
  generateName: autoscale-us-east-1a-
  namespace: "openshift-machine-api"
spec:
  minReplicas: 1
  maxReplicas: 4
  scaleTargetRef:
    apiVersion: machine.openshift.io/v1beta1
    kind: MachineSet
    name: 19104-worker-us-east-1a
...
```

**Make sure** that you properly modify both `generateName` and `name`. Note
which one has the `<clusterid>` and which one does not. Note that
`generateName` has a trailing hyphen. You can specify the minimum and maximum
quantity of nodes that are allowed to be created by adjusting the
`minReplicas` and `maxReplicas`.

You do not have to define a `MachineAutoScaler` for each `MachineSet`. But
remember that each `MachineSet` corresponds to an AWS region/AZ. So, without
having multiple `MachineAutoScalers`, you could end up with a cluster fully
scaled out in a single AZ. If that's what you're after, it's fine. However if
AWS has a problem in that AZ, you run the risk of losing a large portion of
your cluster.

**Note: You should probably choose a small-ish number for `maxReplicas`. The
next lab will autoscale the cluster up to that maximum. You're paying for the
EC2 instances.**

Once the file has been modified appropriately, you can now create the
autoscaler:

    oc create -f machine-autoscale-example.yaml -n openshift-machine-api

You will see a note that the objects were created.

### Define a `ClusterAutoscaler`
The following file contains the definition for a `ClusterAutoscaler`:

https://raw.githubusercontent.com/openshift/training/master/assets/cluster-autoscaler.yaml

The `ClusterAutoscaler` configures some boundaries and behaviors for how the
cluster will autoscale. It is set for a maximum of 10 workers, but you can
change that limit if you desire. Remember, **you are paying for the EC2
instances**.

If you don't wish to make any changes, you can simply `create` the
`ClusterAutoscaler` with the following command:

    oc create -f https://raw.githubusercontent.com/openshift/training/master/assets/cluster-autoscaler.yaml

You will see a note that the autoscaler has been created.

**Note:** The `ClusterAutoscaler` is not a namespaced resource -- it exists at
the cluster scope.

### Define a `Job`
The following YAML file defines a `Job`:

https://raw.githubusercontent.com/openshift/training/master/assets/job-work-queue.yaml

It will produce a massive load that the cluster cannot handle, and will force
the autoscaler to take action (up to the `maxReplicas` defined in your YAML).

**Note: If you did not scale down your machines earlier, you may have too much
capacity to trigger an autoscaling event. Make sure you have no more than 3
workers before continuing.**

Create a project to hold the resources for the `Job`:

    oc adm new-project autoscale-example && oc project autoscale-example

### Open Grafana
In the OpenShift web console, click `Monitoring` and then click `Dashboards`.
This will open a new browser tab for Grafana. You will also get a certificate
error similar to the first time you logged in. This is because Grafana has
its own SSL certificate. You will then see a login screen. Use the same
`kubeadmin` user and password. Grafana is configured to use an OpenShift user
and inherits permissions of that user for accessing cluster information.

Finally, allow the permissions, and then you will see the Grafana homepage.

Click the dropdown on `Home` and choose `K8s / Compute Resources / Cluster`.
Leave this browser window open while you start the `Job` so that you can
observe the CPU utilization of the cluster rise.

### Force an Autoscaling Event
Create the `Job`:

    oc create -n autoscale-example -f https://raw.githubusercontent.com/openshift/training/master/assets/job-work-queue.yaml

You will see a note that the `Job` was created. It will create a *lot* of `Pods`:

    oc get pod -n autoscale-example

After a few moments, look at the list of `Machines`:

    oc get machines -n openshift-machine-api

You should see a scaled-up cluster that looks similar to the following:

    NAME                               INSTANCE              STATE     TYPE       REGION      ZONE         AGE
    190115-2-master-0                  i-0a9b96c9f4297e544   running   m4.large   us-west-2   us-west-2a   22m
    190115-2-master-1                  i-08b90823542c5d00d   running   m4.large   us-west-2   us-west-2b   22m
    190115-2-master-2                  i-0d1d68894ca3b72ca   running   m4.large   us-west-2   us-west-2c   22m
    190115-2-worker-us-west-2a-27dcq   i-0663c5e9e90c27c05   pending   m4.large   us-west-2   us-west-2a   4s
    190115-2-worker-us-west-2a-tgs85   i-08cab36b6f80ea9af   running   m4.large   us-west-2   us-west-2a   21m
    190115-2-worker-us-west-2b-n7xcx   i-0e34b19ba10ee297d   running   m4.large   us-west-2   us-west-2b   21m
    190115-2-worker-us-west-2c-49snd   i-028c0f01f6cd2bc04   running   m4.large   us-west-2   us-west-2c   21m
    190115-2-worker-us-west-2c-88gqb   i-00f89b1065e8e3aa0   pending   m4.large   us-west-2   us-west-2c   14s
    190115-2-worker-us-west-2c-nx46d   i-00d49c1f3de9b1997   pending   m4.large   us-west-2   us-west-2c   14s
    190115-2-worker-us-west-2c-p97ml   i-0fac6e06a978f028e   pending   m4.large   us-west-2   us-west-2c   14s
    ....

Depending on when you run the command, your list may show all running
workers, or some pending.

After the `Job` completes, which could take anywhere from a few minutes to
ten or more (depending on your `ClusterAutoscaler` size and your
`MachineAutoScaler` sizes), the cluster should scale down to the original
count of worker nodes.

In Grafana, be sure to click the `autoscale-example` project in the graphs,
otherwise the interesting things happening might get drowned out by the rest
of the baseline.

# Infrastructure Nodes
Continue on to the section that details [infrastructure nodes](05-infrastructure-nodes.md).
