# OpenShift Infrastructure Nodes
The OpenShift subscription model allows customers to run various core
infrastructure components at no additional charge. In other words, a node
that is only running core OpenShift infrastructure components is not counted
in terms of the total number of subscriptions required to cover the
environment.

OpenShift components that fall into the infrastructure categorization
include:

* kubernetes and OpenShift control plane services ("masters")
* router
* container image registry
* cluster metrics collection
* cluster aggregated logging
* service brokers

Any node running a container/pod/component not described above is considered
a worker and must be covered by a subscription.

## More MachineSet Details
In [the cluster-scaling excercises](04-scaling-cluster.md) you explored the
use of `MachineSets` and adding replicas within them. In the case of an
infrastructure node, we want to create additional `Machines` that have
specific kubernetes labels. Then, we can configure the various components to
run specifically on nodes with those labels.

To accomplish this, you will create additional `MachineSets`. The easiest way
to do this is to `get` the existing `MachineSets` into a file, and then
modify them. This is because the `MachineSet` has some details that are
specific to the AWS region that the cluster is deployed in, like the AWS EC2
AMI ID. For example, given the following output of `oc get machineset -n
openshift-cluster-api`:

    NAME                         DESIRED   CURRENT   READY     AVAILABLE   AGE
    190125-3-worker-us-west-1b   2         2         2         2           3h
    190125-3-worker-us-west-1c   1         1         1         1           3 

There are two available EC2 AZs into which we can deposit infrastructure
components (`1b` and `1c`). Take a look at one specifically with `oc get
machineset 190125-3-worker-us-west-1b -n openshift-cluster-api -o yaml`.
There are a few very important sections.

### Metadata
The `metadata` on the `MachineSet` itself includes information like the name
of the `MachineSet` and various labels:

```YAML
metadata:
  creationTimestamp: 2019-01-25T16:00:34Z
  generation: 1
  labels:
    sigs.k8s.io/cluster-api-cluster: 190125-3
    sigs.k8s.io/cluster-api-machine-role: worker
    sigs.k8s.io/cluster-api-machine-type: worker
  name: 190125-3-worker-us-west-1b
  namespace: openshift-cluster-api
  resourceVersion: "9027"
  selfLink: /apis/cluster.k8s.io/v1alpha1/namespaces/openshift-cluster-api/machinesets/190125-3-worker-us-west-1b
  uid: 591b4d06-20ba-11e9-a880-068acb199400
```

### Selector
The `MachineSet` defines how to create `Machines`, and the `Selector` tells
the operator which machines are associated with the set:

```YAML
spec:
  replicas: 2
  selector:
    matchLabels:
      sigs.k8s.io/cluster-api-cluster: 190125-3
      sigs.k8s.io/cluster-api-machineset: 190125-3-worker-us-west-1b
```

In this case, the cluster name is `190125-3` and there is an additional
label for the whole set.

### Template Metadata
The `template` is the part of the `MachineSet` that templates out the
`Machine`. The `template` itself can have metadata associated, and we need to
make sure that things match here when we make changes:

```YAML
  template:
    metadata:
      creationTimestamp: null
      labels:
        sigs.k8s.io/cluster-api-cluster: 190125-3
        sigs.k8s.io/cluster-api-machine-role: worker
        sigs.k8s.io/cluster-api-machine-type: worker
        sigs.k8s.io/cluster-api-machineset: 190125-3-worker-us-west-1b
```

### Template Spec
The `template` needs to `spec`ify how the `Machine`/node should be created.
You will notice that the `spec` and, more specifically, the `providerSpec`
contains all of the important AWS data to help get the `Machine` created
correctly and bootstrapped.

In our case, we want to ensure that the resulting node inherits one or more
specific labels. As you've seen in the examples above, labels go in
`metadata` sections:

```YAML
  spec:
      metadata:
        creationTimestamp: null
      providerSpec:
        value:
          ami:
            id: ami-08871aee06d13e584
....
```

By default the `MachineSets` that the installer creates do not apply any
additional labels to the node.

## Defining a Custom MachineSet
Now that you've analyzed an existing `MachineSet` it's time to go over the
rules for creating one, at least for a simple change like we're making:

1. Don't change anything in the `providerSpec`
1. Don't change any instances of `sigs.k8s.io/cluster-api-cluster: <clusterid>`
1. Give your `MachineSet` a unique `name`
1. Make sure any instances of `sigs.k8s.io/cluster-api-machineset` match the `name`
1. Add labels you want on the nodes to `.spec.template.spec.metadata.labels`
1. Even though you're changing `MachineSet` `name` references, be sure not to change the `subnet`.

This sounds complicated, so let's go through an example. Go ahead and dump
one of your existing `MachineSets` to a file, and then open it with your
favorite text editor. For example:

    oc get machineset 190125-3-worker-us-west-1b -o yaml -n openshift-cluster-api > infra-machineset.yaml

### Clean It
Since we asked OpenShift to tell us about an _existing_ `MachineSet`, there's a
lot of extra data that we can immediately remove from the file. At the
`.metadata` top level, delete:

1. `generation`
1. `resourceVersion`
1. `selfLink`
1. `uid`

Then, delete the entire `.status` block.

You can also delete all instances of `creationTimestamp`.

### Name It
Go ahead and change the top-level `.metadata.name` to something indicative of
the purpose of this set, for example:

    name: infrastructure-us-west-1b

By looking at this `MachineSet` we can tell that it houses
infrastructure-focused `Machines` (nodes) in `us-west-1` in the `b`
availability zone. Of course, you will want to change this to something that
makes sense for your cluster.

### Match It
Change any instance of `sigs.k8s.io/cluster-api-machineset` to match your new
name of `infrastructure-us-west-1b`. This appears in both
`.spec.selector.matchLabels` as well as `.spec.template.metadata.labels`.

### Add Your Node Label
Add a `labels` section to `.spec.template.spec.metadata` with the label
`node-role.kubernetes.io/infra: ""`. Why this particular label?
Because `oc get node` looks at the `node-role.kubernetes.io/xxx` label and
shows that in the output. This will make it easy to identify which workers
are also infrastructure nodes.(the quotes are because of the boolean). 

Your resulting section should look like the following:

```YAML
    spec:
      metadata:
        labels:
          node-role.kubernetes.io/infra: ""
```

### Change the Replica Count
For now, make the replica count 1.

### Change the Instance Type
If you want a different EC2 instance type, you can change that. It is one of
the few things in the `providerSpec` block you can realistically change. You
can also change volumes if you want a different storage size or need
additional volumes on your instances.

Save your file and exit.

### Double Check
Your cluster will have a different ID and you are likely operating in a
different version, however, your file should more or less look like the
following:

```YAML
apiVersion: cluster.k8s.io/v1alpha1
kind: MachineSet
metadata:
  labels:
    sigs.k8s.io/cluster-api-cluster: 190125-3
    sigs.k8s.io/cluster-api-machine-role: worker
    sigs.k8s.io/cluster-api-machine-type: worker
  name: infrastructure-us-west-1b
  namespace: openshift-cluster-api
spec:
  replicas: 1
  selector:
    matchLabels:
      sigs.k8s.io/cluster-api-cluster: 190125-3
      sigs.k8s.io/cluster-api-machineset: infrastructure-us-west-1b
  template:
    metadata:
      labels:
        sigs.k8s.io/cluster-api-cluster: 190125-3
        sigs.k8s.io/cluster-api-machine-role: worker
        sigs.k8s.io/cluster-api-machine-type: worker
        sigs.k8s.io/cluster-api-machineset: infrastructure-us-west-1b
    spec:
      metadata:
        labels:
          node-role.kubernetes.io/infra: ""
      providerSpec:
        value:
          ami:
            id: ami-08871aee06d13e584
          apiVersion: awsproviderconfig.k8s.io/v1alpha1
          blockDevices:
          - ebs:
              iops: 0
              volumeSize: 32
              volumeType: gp2
          deviceIndex: 0
          iamInstanceProfile:
            id: 190125-3-worker-profile
          instanceType: m4.large
          kind: AWSMachineProviderConfig
          metadata:
          placement:
            availabilityZone: us-west-1b
            region: us-west-1
          publicIp: null
          securityGroups:
          - filters:
            - name: tag:Name
              values:
              - 190125-3_worker_sg
          subnet:
            filters:
            - name: tag:Name
              values:
              - 190125-3-worker-us-west-1b
          tags:
          - name: openshiftClusterID
            value: 45d08e94-6bf6-4fd3-988f-54a616d04252
          - name: kubernetes.io/cluster/190125-3
            value: owned
          userDataSecret:
            name: worker-user-data
      versions:
        kubelet: ""
```

## Create Your Machineset
Now you can create your `MachineSet`:

```bash
oc create -f infra-machineset.yaml
```

Then go ahead and `oc get machineset -n openshift-cluster-api` and you should
see it listed:

```
NAME                         DESIRED   CURRENT   READY     AVAILABLE   AGE
190125-3-worker-us-west-1b   2         2         2         2           4h
190125-3-worker-us-west-1c   1         1         1         1           4h
infrastructure-us-west-1b    1         1                               4s
```

We don't yet have any ready or available machines in the set because the
instance is still coming up and bootstrapping. You can check `oc get machine
-n openshift-cluster-api` to see when the instance finally starts running.
Then, you can use `oc get node` to see when the actual node is joined and
ready. If you're having trouble figuring out which node is the new one, take
a look at the `AGE` column. It will be the youngest!

## Check the Labels
In our case, the youngest node was named
`ip-10-0-128-138.us-west-1.compute.internal`, so we can ask what its labels
are:

    oc get node ip-10-0-128-138.us-west-1.compute.internal --show-labels

And, in the `LABELS` column we see:

    beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.large,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=us-west-1,failure-domain.beta.kubernetes.io/zone=us-west-1b,kubernetes.io/hostname=ip-10-0-128-138,node-role.kubernetes.io/infra=,node-role.kubernetes.io/worker=

It's hard to see, but our `node-role.kubernetes.io/infra` label is there. You
will also see `infra,worker` in the output of `oc get node` in the `ROLES`
column. Success!

## Add More Machinesets (or scale, or both)
In a realistic production deployment, you would want at least 3 `MachineSets`
to hold infrastructure components. Both the logging aggregation solution and
the service mesh will deploy ElasticSearch, and ElasticSearch really needs 3
instances spread across 3 discrete nodes. Why 3 `MachineSets`? Well, in
theory, having a `MachineSet` in different AZs ensures that you don't go
completely dark if AWS loses an AZ.

For the purposes of this exercise, though, we'll just scale up our single
set:

    oc edit machineset infrastructure-us-west-1b -n openshift-cluster-api

Change the `.spec.replicas` from 1 to 3, and then save/exit the editor.

You can issue `oc get machineset` to see the change in the desired number of
instances, and then `oc get machine` and `oc get node` as before. Just don't
forget the `-n openshift-cluster-api` or be sure to switch to that namespace
with `oc project openshift-cluster-api`.

## Extra Credit
In the `openshift-cluster-api` project are several `Pods`. One of them has a
name of ` clusterapi-manager-controllers-....`. If you use `oc logs` on the
various containers in that `Pod`, you will see the various operator bits that
actually make the nodes come into existence.

## Move Infrastructure Components
Now that you have some special nodes, it's time to move various
infrastructure components onto them.