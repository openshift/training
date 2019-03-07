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
* cluster metrics collection ("monitoring")
* cluster aggregated logging
* service brokers

Any node running a container/pod/component not described above is considered
a worker and must be covered by a subscription.

## More MachineSet Details
In [the cluster-scaling excercises](04-scaling-cluster.md) you explored using
`MachineSets` and scaling the cluster by changing their replica count. In the
case of an infrastructure node, we want to create additional `Machines` that
have specific kubernetes labels. Then, we can configure the various
components to run specifically on nodes with those labels.

To accomplish this, you will create additional `MachineSets`. The easiest way
to do this is to `get` the existing `MachineSets` into a file, and then
modify them. This is because the `MachineSet` has some details that are
specific to the AWS region that the cluster is deployed in, like the AWS EC2
AMI ID. For example, given the following output of `oc get machineset -n
openshift-machine-api`:

    NAME                         DESIRED   CURRENT   READY     AVAILABLE   AGE
    190125-3-worker-us-west-1b   2         2         2         2           3h
    190125-3-worker-us-west-1c   1         1         1         1           3 

There are two available EC2 AZs into which we can deposit infrastructure
components (`1b` and `1c`). Take a look at one specifically with `oc get
machineset 190125-3-worker-us-west-1b -n openshift-machine-api -o yaml`.
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
  namespace: openshift-machine-api
  resourceVersion: "9027"
  selfLink: /apis/cluster.k8s.io/v1alpha1/namespaces/openshift-machine-api/machinesets/190125-3-worker-us-west-1b
  uid: 591b4d06-20ba-11e9-a880-068acb199400
```

**NOTE:** You might see some `annotations` on your `MachineSet` if you dumped
*one that had a `MachineAutoScaler` defined.

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

    oc get machineset 190125-3-worker-us-west-1b -o yaml -n openshift-machine-api > infra-machineset.yaml

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
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  labels:
    sigs.k8s.io/cluster-api-cluster: 190125-3
    sigs.k8s.io/cluster-api-machine-role: worker
    sigs.k8s.io/cluster-api-machine-type: worker
  name: infrastructure-us-west-1b
  namespace: openshift-machine-api
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
          - name: kubernetes.io/cluster/190125-3
            value: owned
          userDataSecret:
            name: worker-user-data
      versions:
        kubelet: ""
```

## Create Your Machineset
Now you can create your `MachineSet`:

```sh
oc create -f infra-machineset.yaml -n openshift-machine-api
```

Then go ahead and `oc get machineset -n openshift-machine-api` and you should
see it listed:

```
NAME                         DESIRED   CURRENT   READY     AVAILABLE   AGE
190125-3-worker-us-west-1b   2         2         2         2           4h
190125-3-worker-us-west-1c   1         1         1         1           4h
infrastructure-us-west-1b    1         1                               4s
```

We don't yet have any ready or available machines in the set because the
instance is still coming up and bootstrapping. You can check `oc get machine
-n openshift-machine-api` to see when the instance finally starts running.
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

    oc edit machineset infrastructure-us-west-1b -n openshift-machine-api

Change the `.spec.replicas` from 1 to 3, and then save/exit the editor.

You can issue `oc get machineset` to see the change in the desired number of
instances, and then `oc get machine` and `oc get node` as before. Just don't
forget the `-n openshift-machine-api` or be sure to switch to that namespace
with `oc project openshift-machine-api`.

## Extra Credit
You can use the `oc scale` command to scale a `MachineSet`.

## Extra Credit
In the `openshift-machine-api` project are several `Pods`. One of them has a
name of ` clusterapi-manager-controllers-....`. If you use `oc logs` on the
various containers in that `Pod`, you will see the various operator bits that
actually make the nodes come into existence.

# Moving Infrastructure Components
Now that you have some special nodes, it's time to move various
infrastructure components onto them.

### NOTE
The following assumes you used version `0.14.1` of the installer. This would
give you a `clusterversion` of `4.0.0-0.7`.

## Router
The OpenShift router is managed by an `Operator` called
`openshift-ingress-operator`. Its `Pod` lives in the
`openshift-ingress-operator` project:

```sh
oc get pod -n openshift-ingress-operator
```

The actual default router instance lives in the `openshift-ingress` project:

```sh
oc get pod -n openshift-ingress -o wide
```

Take a look at the `Node` that is listed. You may see something like:

```
NAME                              READY   STATUS    RESTARTS   AGE    IP           NODE                           NOMINATED NODE
router-default-7f9c6678c5-rg8j5   1/1     Running   0          7h1m   10.129.2.3   ip-10-0-128-196.ec2.internal   <none>
router-default-7f9c6678c5-xbmw6   1/1     Running   0          7h1m   10.131.0.3   ip-10-0-149-156.ec2.internal   <none>
```

If you execute `oc get node <your_displayed_node>` you will see that it has
the role of `worker`. The default configuration of the router operator is to
pick nodes with the role of `worker`. But, now that we have created dedicated
infrastructure nodes, we want to tell the operator to put the router
instances on nodes with the role of `infra`.

The OpenShift router operator creates a custom resource definition (`CRD`)
called `clusteringress`:

```sh
oc get clusteringress default -n openshift-ingress-operator -o yaml
```

The `clusteringress` objects are observed by the router operator and tell the
operator how to create and configure routers. Yours likely looks something
like:

```YAML
apiVersion: ingress.openshift.io/v1alpha1
kind: ClusterIngress
metadata:
  creationTimestamp: 2019-02-27T14:07:54Z
  finalizers:
  - ingress.openshift.io/default-cluster-ingress
  generation: 1
  name: default
  namespace: openshift-ingress-operator
  resourceVersion: "11336"
  selfLink: /apis/ingress.openshift.io/v1alpha1/namespaces/openshift-ingress-operator/clusteringresses/default
  uid: 1360a074-3a99-11e9-94cf-0ae9eb6afea2
spec:
  defaultCertificateSecret: null
  highAvailability: null
  ingressDomain: null
  namespaceSelector: null
  nodePlacement:
    nodeSelector:
      matchLabels:
        node-role.kubernetes.io/worker: ""
  replicas: 2
  routeSelector: null
  unsupportedExtensions: null
status:
  highAvailability:
    type: Cloud
  ingressDomain: apps.beta-190227-1.ocp4testing.openshiftdemos.com
  labelSelector: app=router,router=router-default
  replicas: 2
```

As you can see, the `nodeSelector` is configured for the `worker` role. Go
ahead and use `oc edit` to change `node-role.kubernetes.io/worker` to be
`node-role.kubernetes.io/infra`:

```sh
oc edit clusteringress default -n openshift-ingress-operator -o yaml
```

### NOTE
The actual moving of the pod is currently not working. You can track the
progress here: https://jira.coreos.com/browse/NE-72

After saving and exiting the editor, if you're quick enough, you might catch
the router pod being moved to its new home. Run `oc get pod -n
openshift-ingress` and you may see something like:

```
NAME                              READY     STATUS        RESTARTS   AGE       IP           NODE                           NOMINATED NODE
router-default-86798b4b5d-bdlvd   1/1       Running       0          28s       10.130.2.4   ip-10-0-217-226.ec2.internal   <none>
router-default-955d875f4-255g8    0/1       Terminating   0          19h       10.129.2.4   ip-10-0-148-172.ec2.internal   <none>
```

The `Terminating` pod was running on one of the worker nodes. The `Running`
pod is now on one of our nodes with the `infra` role. In our case:

```
oc get node ip-10-0-217-226.ec2.internal
NAME                           STATUS    ROLES          AGE       VERSION
ip-10-0-217-226.ec2.internal   Ready     infra,worker   17h       v1.12.4+4dd65df23d
```

## Registry
The registry uses a similar `CRD` mechanism to configure how the operator
deploys the actual registry pods. That CRD is
`configs.imageregistry.operator.openshift.io`. You will edit the `cluster` CR
object in order to add the `nodeSelector`. First, take a look at it:

```sh
oc get configs.imageregistry.operator.openshift.io/cluster -o yaml
```

You will see something like:

```YAML
apiVersion: imageregistry.operator.openshift.io/v1
kind: Config
metadata:
  creationTimestamp: 2019-02-27T14:08:32Z
  finalizers:
  - imageregistry.operator.openshift.io/finalizer
  generation: 1
  name: cluster
  resourceVersion: "106372"
  selfLink: /apis/imageregistry.operator.openshift.io/v1/configs/cluster
  uid: 2a5609e5-3a99-11e9-bf3b-02319b2b6c5a
spec:
  httpSecret: ec7df887545c5e6a5dadf049a6c7a3e9102ecb92b57876fde1f658303038e192479a251a9f2f80d968c3a59a749526e724c632e2f0b85a83de9d2c3bbe04339a
  logging: 2
  managementState: Managed
  proxy: {}
  replicas: 1
  requests:
    read: {}
    write: {}
  storage:
    s3:
      bucket: image-registry-us-east-1-dac0065618f84094b8e8faf4de2fd3f9-2a66
      encrypt: true
      region: us-east-1
status:
...
```

If you `oc edit configs.imageregistry.operator.openshift.io/cluster` and then
modify the `.spec` section to add the following:

```YAML
  nodeSelector:
    node-role.kubernetes.io/infra: ""
```  
The `nodeSelector` stanza may be added anywhere inside the `.spec` block.

### NOTE
At this time the image registry is not using a separate project for its
operator. Both the operator and the operand are housed in the
`openshift-image-registry` project.

When you save and exit you should see the registry pod being moved to the
infra node. The registry is in the `openshift-image-registry` project. If you
execute the following quickly enough:

```sh
oc get pod -n openshift-image-registry
```

You might see the old registry pod terminating and the new one starting.
Since the registry is being backed by an S3 bucket, it doesn't matter what
node the new registry pod instance lands on. It's talking to an object store
via an API, so any existing images stored there will remain accessible.

Also note that the default replica count is 1. In a real-world environment
you might wish to scale that up for better availability, network throughput,
or other reasons.

If you look at the node on which the registry landed (see the section on the
router), you'll note that it is now running on an infra worker.

Lastly, notice that the CRD for the image registry's configuration is not
namespaced -- it is cluster scoped. There is only one internal/integrated
registry per OpenShift cluster.

## Monitoring
The Cluster Monitoring operator is responsible for deploying and managing the
state of the Prometheus+Grafana+AlertManager cluster monitoring stack. It is
installed by default during the initial cluster installation. Its operator
uses a `ConfigMap` in the `openshift-monitoring` project to set various
tunables and settings for the behavior of the monitoring stack.

Take a look at the following file:

https://github.com/openshift/training/blob/master/assets/cluster-monitoring-configmap.yaml

It contains the definition for a `ConfigMap` that will cause the monitoring
solution to be redeployed onto infrastructure nodes. There is no `ConfigMap`
created as part of the installation. Without one, the operator will assume
default settings:

```sh
oc get configmap cluster-monitoring-config -n openshift-monitoring
```

The operator will, in turn, create several `ConfigMap` objects for the
various monitoring stack components, and you can see them, too:

```sh
oc get configmap -n openshift-monitoring
```

You can create the new monitoring config with the following command:

```sh
oc create -f https://raw.githubusercontent.com/openshift/training/master/assets/cluster-monitoring-configmap.yaml
```

Then, you can do something like `watch 'oc get pod -n openshift-monitoring'`
or `oc get pod -w -n openshift-monitoring` to watch the operator cause the
various pods to be redeployed.

## Logging
OpenShift's log aggregation solution is not installed by default. There are
also a few minor bugs that prevent Logging from being easily installed via
the Operator UI in the web console. It is skipped for now.

## Configuring Authentication
The [configuring authentication](06-authentication.md) section describes how
to configure htpasswd-based auth for your cluster.
