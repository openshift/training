# OpenShift Infrastructure Nodes

In this section we're going to look at the OpenShift infrastructure nodes, and
more specifically how to scale them once they've been deployed. To understand
what we mean by "infrastructure node", the nodes running the following services
would fall into that description, although this is not necessarily an exhaustive
list:

* Kubernetes and OpenShift control plane services ("masters")
* Router(s)
* Container Image Registry
* Cluster metrics collection ("monitoring")
* Cluster aggregated logging
* Service Brokers

> **NOTE**: The OpenShift subscription model allows customers to run various
core infrastructure components at no additional charge. In other words, a node
that is only running core OpenShift infrastructure components is not counted
in terms of the total number of subscriptions required to cover the
environment. Any node running a container, pod, or component not described above
is considered a worker and must be covered by a subscription.

If we wanted to see what different types of nodes we have in our cluster we need
to do a bit of digging. We can list all of the machines as part of our cluster
in a couple of different ways, firstly with the simple `oc get nodes` which
queries Kubernetes specifically for the nodes that are reporting in:

~~~bash
$ oc get nodes --show-labels
NAME                                              STATUS    ROLES     AGE       VERSION              LABELS
ip-10-0-129-153.ap-southeast-1.compute.internal   Ready     master    12h       v1.12.4+4dd65df23d   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.xlarge,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=ap-southeast-1,failure-domain.beta.kubernetes.io/zone=ap-southeast-1a,kubernetes.io/hostname=ip-10-0-129-153,node-role.kubernetes.io/master=
ip-10-0-135-227.ap-southeast-1.compute.internal   Ready     worker    12h       v1.12.4+4dd65df23d   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.large,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=ap-southeast-1,failure-domain.beta.kubernetes.io/zone=ap-southeast-1a,kubernetes.io/hostname=ip-10-0-135-227,node-role.kubernetes.io/worker=
ip-10-0-148-44.ap-southeast-1.compute.internal    Ready     worker    12h       v1.12.4+4dd65df23d   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.large,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=ap-southeast-1,failure-domain.beta.kubernetes.io/zone=ap-southeast-1b,kubernetes.io/hostname=ip-10-0-148-44,node-role.kubernetes.io/worker=
ip-10-0-157-229.ap-southeast-1.compute.internal   Ready     master    12h       v1.12.4+4dd65df23d   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.xlarge,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=ap-southeast-1,failure-domain.beta.kubernetes.io/zone=ap-southeast-1b,kubernetes.io/hostname=ip-10-0-157-229,node-role.kubernetes.io/master=
ip-10-0-164-113.ap-southeast-1.compute.internal   Ready     master    12h       v1.12.4+4dd65df23d   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.xlarge,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=ap-southeast-1,failure-domain.beta.kubernetes.io/zone=ap-southeast-1c,kubernetes.io/hostname=ip-10-0-164-113,node-role.kubernetes.io/master=
ip-10-0-168-95.ap-southeast-1.compute.internal    Ready     worker    12h       v1.12.4+4dd65df23d   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.large,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=ap-southeast-1,failure-domain.beta.kubernetes.io/zone=ap-southeast-1c,kubernetes.io/hostname=ip-10-0-168-95,node-role.kubernetes.io/worker=
~~~

And also asking via the `Machine` extension which uses a Kubernetes operator to
manage the nodes themselves through the cluster itself; this can give us a
little more information about the nodes and the underlying infrastructure,
noting that this environment is running on-top of AWS:

~~~bash
oc get machines --all-namespaces --show-labels
NAMESPACE               NAME                                              INSTANCE              STATE     TYPE        REGION           ZONE              AGE       LABELS
openshift-machine-api   cluster-8145-5nvqd-master-0                       i-0e1fe3f94d986c3aa   running   m4.xlarge   ap-southeast-1   ap-southeast-1a   12h       machine.openshift.io/cluster-api-cluster=cluster-8145-5nvqd,machine.openshift.io/cluster-api-machine-role=master,machine.openshift.io/cluster-api-machine-type=master
openshift-machine-api   cluster-8145-5nvqd-master-1                       i-04f521b255b75f1ad   running   m4.xlarge   ap-southeast-1   ap-southeast-1b   12h       machine.openshift.io/cluster-api-cluster=cluster-8145-5nvqd,machine.openshift.io/cluster-api-machine-role=master,machine.openshift.io/cluster-api-machine-type=master
openshift-machine-api   cluster-8145-5nvqd-master-2                       i-05a8f9a53803647bd   running   m4.xlarge   ap-southeast-1   ap-southeast-1c   12h       machine.openshift.io/cluster-api-cluster=cluster-8145-5nvqd,machine.openshift.io/cluster-api-machine-role=master,machine.openshift.io/cluster-api-machine-type=master
openshift-machine-api   cluster-8145-5nvqd-worker-ap-southeast-1a-s9xjj   i-0c77428c3366349ea   running   m4.large    ap-southeast-1   ap-southeast-1a   12h       machine.openshift.io/cluster-api-cluster=cluster-8145-5nvqd,machine.openshift.io/cluster-api-machine-role=worker,machine.openshift.io/cluster-api-machine-type=worker,machine.openshift.io/cluster-api-machineset=cluster-8145-5nvqd-worker-ap-southeast-1a
openshift-machine-api   cluster-8145-5nvqd-worker-ap-southeast-1b-2hmrd   i-05332b2cf3998783e   running   m4.large    ap-southeast-1   ap-southeast-1b   12h       machine.openshift.io/cluster-api-cluster=cluster-8145-5nvqd,machine.openshift.io/cluster-api-machine-role=worker,machine.openshift.io/cluster-api-machine-type=worker,machine.openshift.io/cluster-api-machineset=cluster-8145-5nvqd-worker-ap-southeast-1b
openshift-machine-api   cluster-8145-5nvqd-worker-ap-southeast-1c-s9tr5   i-0380527907d3a5a82   running   m4.large    ap-southeast-1   ap-southeast-1c   12h       machine.openshift.io/cluster-api-cluster=cluster-8145-5nvqd,machine.openshift.io/cluster-api-machine-role=worker,machine.openshift.io/cluster-api-machine-type=worker,machine.openshift.io/cluster-api-machineset=cluster-8145-5nvqd-worker-ap-southeast-1c
~~~

In both of these outputs you'll note that both of the outputs have roles listed,
and these are associated to **kubernetes labels** for scheduling purposes; we
have two types of role defined, **master**, and **worker**. With the exception
of **master** nodes (due to specific scheduling and deployment limitations), all
other node types are deployed as part of a `MachineSet`, and can therefore be
scaled as one.

## More MachineSet Details
In [the previous section](04-scaling-cluster.md) you explored the
`MachineSets` resource and scaled the cluster by changing its replica count,
adding additional workers, we also configured an auto scaler to ensure that the
cluster would have the required capacity to accommodate the workload demand.
You'll note that right now we only have **worker** type machine sets configured:

~~~bash
$ oc get machinesets -n openshift-machine-api
NAME                                        DESIRED   CURRENT   READY     AVAILABLE   AGE
cluster-8145-5nvqd-worker-ap-southeast-1a   1         1         1         1           12h
cluster-8145-5nvqd-worker-ap-southeast-1b   1         1         1         1           12h
cluster-8145-5nvqd-worker-ap-southeast-1c   1         1         1         1           12h
~~~

Here we have three distinct machine sets deployed, each with a **single**
machine running. Each machine set is aligned with a given AWS EC2 availability
zone, and we could easily deploy additional machines (or nodes) into one of the
three listed (`1a`, `1b` and `1c`). If we wanted to add additional capacity to
our cluster we could adjust the replica count like we did in the previous lab,
remembering that we randomly selected one of the machine sets in the overall
configuration, but that's just for worker nodes, i.e. where our user
applications run, and where **some** of the key infrastructure components run by
default, e.g. our routers, etc.

If we wanted to create a dedicated infrastructure role where we could run
specific infrastructure services, components, and pods on (and move them away
from the **worker** nodes like they are by default), we would need to create an
additional set of nodes, define a `MachineSet` to deploy and scale them into,
and then label them with specific **kubernetes labels**. We can then configure
the various components to run specifically on nodes with those labels.

To accomplish this, you will create additional `MachineSets`. The easiest way
to do this is to `get` the existing `MachineSets` by downloading it into a file,
and then modifying them. This is because the `MachineSet` has some details that
are specific to the AWS region that the cluster is deployed in, like the AWS EC2
AMI ID, so crafting it by hand would be very difficult.

Let's take a look at one of our `MachineSets` in detail to understand how the
configuration is set, and how we can look to adapt it to create a new one for
specifically for our infrastructure services. Use the following command, noting
that you'll have to adjust the command to suit the name of your machine set:

~~~bash
$ oc get machineset cluster-8145-5nvqd-worker-ap-southeast-1a -n openshift-machine-api -o yaml
~~~

Which will give you the following output:

```YAML
apiVersion: machine.openshift.io/v1beta1
kind: MachineSet
metadata:
  creationTimestamp: 2019-03-18T00:55:29Z
  generation: 1
  labels:
    machine.openshift.io/cluster-api-cluster: cluster-8145-5nvqd
    machine.openshift.io/cluster-api-machine-role: worker
    machine.openshift.io/cluster-api-machine-type: worker
  name: cluster-8145-5nvqd-worker-ap-southeast-1a
  namespace: openshift-machine-api
  resourceVersion: "16167"
  selfLink: /apis/machine.openshift.io/v1beta1/namespaces/openshift-machine-api/machinesets/cluster-8145-5nvqd-worker-ap-southeast-1a
  uid: 8677e204-4918-11e9-85ca-02fb9875b46a
spec:
  replicas: 1
(...)
```

There are a few very important sections in the output, we'll discuss them in
depth below...

### Metadata
The `metadata` on the `MachineSet` itself includes information like the name
of the `MachineSet` and various labels:

```YAML
metadata:
  creationTimestamp: 2019-03-18T00:55:29Z
  generation: 1
  labels:
    machine.openshift.io/cluster-api-cluster: cluster-8145-5nvqd
    machine.openshift.io/cluster-api-machine-role: worker
    machine.openshift.io/cluster-api-machine-type: worker
  name: cluster-8145-5nvqd-worker-ap-southeast-1a
  namespace: openshift-machine-api
  resourceVersion: "16167"
  selfLink: /apis/machine.openshift.io/v1beta1/namespaces/openshift-machine-api/machinesets/cluster-8145-5nvqd-worker-ap-southeast-1a
  uid: 8677e204-4918-11e9-85ca-02fb9875b46a
```

> **NOTE**: You might see some `annotations` on your `MachineSet` if you use the `MachineSet` that you defined a `MachineAutoScaler` on in the previous lab section.

### Selector
The `MachineSet` defines how to create `Machines`, and the `Selector` tells
the operator which machines are associated with the set, note that `replicas: 1`
is set here, hence we only have one machine in this set running:

```YAML
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: cluster-8145-5nvqd
      machine.openshift.io/cluster-api-machineset: cluster-8145-5nvqd-worker-ap-southeast-1a
```

In this case, the cluster name is `8145-5nvqd` and there is an additional
label for the whole set.

### Template Metadata
The `template` section is the part of the `MachineSet` that specifically
templates out the `Machine`. The `template` itself can have metadata associated,
and we need to make sure that things match here when we make changes:

```YAML
  template:
    metadata:
      creationTimestamp: null
      labels:
        machine.openshift.io/cluster-api-cluster: cluster-8145-5nvqd
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: cluster-8145-5nvqd-worker-ap-southeast-1a
```

### Template Spec
The `template` needs to `spec`ify how the `Machine`/node should be created, i.e.
"use this configuration for all machines in this set"; this configuration will
be used when provisioning new systems when scaling is required. You will notice
that the `spec` and, more specifically, the `providerSpec` contains all of the
important AWS data to help get the `Machine` created correctly and bootstrapped.

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
            id: ami-08b086f355b2ad409
          apiVersion: awsproviderconfig.openshift.io/v1beta1
          blockDevices:
          - ebs:
              iops: 0
              volumeSize: 120
              volumeType: gp2
          deviceIndex: 0
          iamInstanceProfile:
            id: cluster-8145-5nvqd-worker-profile
          instanceType: m4.large
          kind: AWSMachineProviderConfig
          metadata:
            creationTimestamp: null
          placement:
            availabilityZone: ap-southeast-1a
            region: ap-southeast-1
          publicIp: null
          securityGroups:
          - filters:
            - name: tag:Name
              values:
              - cluster-8145-5nvqd-worker-sg
          subnet:
            filters:
            - name: tag:Name
              values:
              - cluster-8145-5nvqd-private-ap-southeast-1a
```
By default the `MachineSets` that the installer creates do not apply any
additional labels to the node.

> **NOTE**: As you can probably see, there's plenty of AWS-specific provider
configuration here, in future versions of OpenShift, there will be similar
respective parameters for other infrastructure providers that can be used.

## Defining a Custom MachineSet
In this section we're going to be defining a custom `MachineSet` for
infrastructure services. Now that you've inspected an existing `MachineSet`
it's time to go over the rules for creating one, at least for a simple change
like we're making:

1. Don't change anything in the `providerSpec`
1. Don't change any instances of `sigs.k8s.io/cluster-api-cluster: <clusterid>`
1. Give your `MachineSet` a unique `name`
1. Make sure any instances of `sigs.k8s.io/cluster-api-machineset` match the
`name`
1. Add labels you want on the nodes to `.spec.template.spec.metadata.labels`
1. Even though you're changing `MachineSet` `name` references, be sure not to
change the `subnet`.

This sounds complicated, so let's go through an example. Go ahead and dump one
of your existing `MachineSets` to a file, remembering to adjust this command to
match one of yours:

~~~bash
$ oc get machineset cluster-8145-5nvqd-worker-ap-southeast-1a -o yaml -n openshift-machine-api > infra-machineset.yaml
(No output)
~~~

Now open it with a text editor of your choice:

~~~bash
$ vi infra-machineset.yaml
~~~

Let's now take some steps to adapt this `MachineSet` to suit our required new **infrastructure** node type...

### Clean It
Since we asked OpenShift to tell us about an _existing_ `MachineSet`, there's a
lot of extra data that we can immediately remove from the file. Remove the
following:

1. Within the `.metadata` top level, remove:

	* `generation`
	* `resourceVersion`
	* `selfLink`
	* `uid`

2. The entire `.status` block.

3. All instances of `creationTimestamp`.

### Name It
Go ahead and change the top-level `.metadata.name` to something indicative of
the purpose of this set, for example:

    name: infrastructure-ap-southeast-1a

By looking at this `MachineSet` we can tell that it houses
infrastructure-focused `Machines` (nodes) in `ap-southeast-1` region in the `a`
availability zone. Ultimately, you can call this anything you like, but we
should change this to something that makes sense for your cluster.

### Match It
Change any instance of `sigs.k8s.io/cluster-api-machineset` to match your new
name of `infrastructure-ap-southeast-1a` (or whatever you're using). This
appears in both `.spec.selector.matchLabels` as well as
`.spec.template.metadata.labels`.

### Add Your Node Label
Add a `labels` section to `.spec.template.spec.metadata` with the label
`node-role.kubernetes.io/infra: ""`. Why this particular label?
Because `oc get node` looks at the `node-role.kubernetes.io/xxx` label and
shows that in the output. This will make it easy to identify which workers
are also infrastructure nodes (the quotes are because of the boolean).

Your resulting section should look somewhat like the following, albeit with
slightly different names as per your unique cluster name:

```YAML
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: cluster-8145-5nvqd
      machine.openshift.io/cluster-api-machineset: infrastructure-ap-southeast-1a
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: cluster-8145-5nvqd
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: infrastructure-ap-southeast-1a
    spec:
      metadata:
        labels:
          node-role.kubernetes.io/infra: ""
```

### Set the replica count
For now, make the replica count 1, which it should be already, unless you didn't
change it from a previous lab instruction:

```YAML
spec:
  replicas: 1
```

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
    machine.openshift.io/cluster-api-cluster: cluster-8145-5nvqd
    machine.openshift.io/cluster-api-machine-role: worker
    machine.openshift.io/cluster-api-machine-type: worker
  name: infrastructure-ap-southeast-1a
  namespace: openshift-machine-api
spec:
  replicas: 1
  selector:
    matchLabels:
      machine.openshift.io/cluster-api-cluster: cluster-8145-5nvqd
      machine.openshift.io/cluster-api-machineset: infrastructure-ap-southeast-1a
  template:
    metadata:
      labels:
        machine.openshift.io/cluster-api-cluster: cluster-8145-5nvqd
        machine.openshift.io/cluster-api-machine-role: worker
        machine.openshift.io/cluster-api-machine-type: worker
        machine.openshift.io/cluster-api-machineset: infrastructure-ap-southeast-1a
    spec:
      metadata:
        labels:
          node-role.kubernetes.io/infra: ""
      providerSpec:
        value:
          ami:
            id: ami-08b086f355b2ad409
          apiVersion: awsproviderconfig.openshift.io/v1beta1
          blockDevices:
          - ebs:
              iops: 0
              volumeSize: 120
              volumeType: gp2
          deviceIndex: 0
          iamInstanceProfile:
            id: cluster-8145-5nvqd-worker-profile
          instanceType: m4.large
          kind: AWSMachineProviderConfig
          metadata:
          placement:
            availabilityZone: ap-southeast-1a
            region: ap-southeast-1
          publicIp: null
          securityGroups:
          - filters:
            - name: tag:Name
              values:
              - cluster-8145-5nvqd-worker-sg
          subnet:
            filters:
            - name: tag:Name
              values:
              - cluster-8145-5nvqd-private-ap-southeast-1a
          tags:
          - name: kubernetes.io/cluster/cluster-8145-5nvqd
            value: owned
          - name: Stack
            value: project ocp4-coreos-deployer-8145
          - name: owner
            value: noreply@opentlc.com
          userDataSecret:
            name: worker-user-data
      versions:
        kubelet: ""
```

## Create Your Machineset
Now you can create your `MachineSet` from the definition that we created:

```bash
$ oc create -f infra-machineset.yaml -n openshift-machine-api
machineset.machine.openshift.io/infrastructure-ap-southeast-1a created
```

Then go ahead and check to see if this new `MachineSet` is listed:

```bash
$ oc get machineset -n openshift-machine-api
NAME                                        DESIRED   CURRENT   READY     AVAILABLE   AGE
cluster-8145-5nvqd-worker-ap-southeast-1a   1         1         1         1           15h
cluster-8145-5nvqd-worker-ap-southeast-1b   1         1         1         1           15h
cluster-8145-5nvqd-worker-ap-southeast-1c   1         1         1         1           15h
infrastructure-ap-southeast-1a              1         1                               46s
```

We don't yet have any ready or available machines in the set because the
instance is still coming up and bootstrapping. We can check every minute or to
see see whether the machine has been created or not, noting that in the output
below the new node is now running:

~~~bash
$ oc get machine -n openshift-machine-api
NAME                                              INSTANCE              STATE     TYPE        REGION           ZONE              AGE
cluster-8145-5nvqd-master-0                       i-0e1fe3f94d986c3aa   running   m4.xlarge   ap-southeast-1   ap-southeast-1a   15h
cluster-8145-5nvqd-master-1                       i-04f521b255b75f1ad   running   m4.xlarge   ap-southeast-1   ap-southeast-1b   15h
cluster-8145-5nvqd-master-2                       i-05a8f9a53803647bd   running   m4.xlarge   ap-southeast-1   ap-southeast-1c   15h
cluster-8145-5nvqd-worker-ap-southeast-1a-s9xjj   i-0c77428c3366349ea   running   m4.large    ap-southeast-1   ap-southeast-1a   15h
cluster-8145-5nvqd-worker-ap-southeast-1b-2hmrd   i-05332b2cf3998783e   running   m4.large    ap-southeast-1   ap-southeast-1b   15h
cluster-8145-5nvqd-worker-ap-southeast-1c-s9tr5   i-0380527907d3a5a82   running   m4.large    ap-southeast-1   ap-southeast-1c   15h
infrastructure-ap-southeast-1a-wkj4c              i-069189c06f38ee9a3   running   m4.large    ap-southeast-1   ap-southeast-1a   114s
~~~

Now we can use `oc get nodes` to see when the actual node is joined and ready.
If you're having trouble figuring out which node is the new one, take a look at
the `AGE` column. It will be the youngest! Again, this node may show up as a
`Machine` in the previous API call, but may not have joined the cluster yet,
so give it some time to bootstrap properly.

~~~bash
$ oc get nodes
NAME                                              STATUS    ROLES          AGE       VERSION
ip-10-0-129-153.ap-southeast-1.compute.internal   Ready     master         15h       v1.12.4+4dd65df23d
ip-10-0-131-124.ap-southeast-1.compute.internal   Ready     infra,worker   6m7s      v1.12.4+4dd65df23d
ip-10-0-135-227.ap-southeast-1.compute.internal   Ready     worker         15h       v1.12.4+4dd65df23d
ip-10-0-148-44.ap-southeast-1.compute.internal    Ready     worker         15h       v1.12.4+4dd65df23d
ip-10-0-157-229.ap-southeast-1.compute.internal   Ready     master         15h       v1.12.4+4dd65df23d
ip-10-0-164-113.ap-southeast-1.compute.internal   Ready     master         15h       v1.12.4+4dd65df23d
ip-10-0-168-95.ap-southeast-1.compute.internal    Ready     worker         15h       v1.12.4+4dd65df23d
~~~

## Check the Labels
In our case, the youngest node was named
`ip-10-0-131-124.ap-southeast-1.compute.internal`, so we can ask what its labels
are:

~~~bash
$ oc get node ip-10-0-131-124.ap-southeast-1.compute.internal --show-labels
NAME                                              STATUS    ROLES          AGE       VERSION              LABELS
ip-10-0-131-124.ap-southeast-1.compute.internal   Ready     infra,worker   7m5s      v1.12.4+4dd65df23d   beta.kubernetes.io/arch=amd64,beta.kubernetes.io/instance-type=m4.large,beta.kubernetes.io/os=linux,failure-domain.beta.kubernetes.io/region=ap-southeast-1,failure-domain.beta.kubernetes.io/zone=ap-southeast-1a,kubernetes.io/hostname=ip-10-0-131-124,node-role.kubernetes.io/infra=,node-role.kubernetes.io/worker=
~~~

It's hard to see, but our `node-role.kubernetes.io/infra` label is the `LABELS`
column. You will also see `infra,worker` in the output of `oc get node` in the
`ROLES` column. Success!

## Add More Machinesets (or scale, or both)
In a realistic production deployment, you would want at least 3 `MachineSets`
to hold infrastructure components. Both the logging aggregation solution and
the service mesh will deploy ElasticSearch, and ElasticSearch really needs 3
instances spread across 3 discrete nodes. Why 3 `MachineSets`? Well, in
theory, having a `MachineSet` in different AZs ensures that you don't go
completely dark if AWS loses an AZ.

For the purposes of this exercise, though, we'll just scale up our single
set:

~~~bash
$ oc edit machineset infrastructure-ap-southeast-1a -n openshift-machine-api
(Opens in vi)
~~~

> **NOTE**: If you're uncomfortable with vi(m) you can use your favourite editor
by specifying `EDITOR=<your choice>` before the `oc` command.

Change the `.spec.replicas` from 1 to 3, and then save/exit the editor.

~~~bash
machineset.machine.openshift.io/infrastructure-ap-southeast-1a edited
~~~

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
Now that we have provisioned some infrastructure specific nodes, it's time to
move various infrastructure components onto them, i.e. move them away from the
worker nodes, and onto the fresh systems. Let's go through some of them
individually to see how they can be moved, and how to monitor the progress.

> **NOTE**: The following assumes that you used at least version `0.14.1` of the
installer. Which would result in a minimum `clusterversion` of `4.0.0-0.7`.

## Router
The OpenShift router is deployed, maintained, and scaled by an `Operator` called
`openshift-ingress-operator`. Its `Pod` lives in the
`openshift-ingress-operator` project:

```bash
$ oc get pod -n openshift-ingress-operator
NAME                                READY     STATUS    RESTARTS   AGE
ingress-operator-7d74fdfc5f-zhngh   1/1       Running   0          15h
```

The actual default router instance lives in the `openshift-ingress` project:

```bash
$ oc get pod -n openshift-ingress -o wide
NAME                              READY     STATUS    RESTARTS   AGE       IP           NODE                                              NOMINATED NODE
router-default-5fc6c9ffbb-9x9l8   1/1       Running   0          15h       10.131.0.7   ip-10-0-135-227.ap-southeast-1.compute.internal   <none>
router-default-5fc6c9ffbb-p5x6d   1/1       Running   0          15h       10.131.0.8   ip-10-0-135-227.ap-southeast-1.compute.internal   <none>
```

The cluster deploys two routers for availability and fault tolerance, and you
can see that the pods are deployed across two nodes. Right now, these will be
deployed on nodes with the `worker` label, and not on the `infrastructure` nodes
that were recently deployed, as the default configuration of the router operator
is to pick nodes with the role of `worker`.

Pick one of the nodes (from `NODE`) where a router pod is running and see the
`ROLES` column:

~~~bash
$ oc get node ip-10-0-135-227.ap-southeast-1.compute.internal
NAME                                              STATUS    ROLES     AGE       VERSION
ip-10-0-135-227.ap-southeast-1.compute.internal   Ready     worker    15h       v1.12.4+4dd65df23d
~~~

ut, now that we have created dedicated infrastructure nodes, we want to tell the
operator to put the router instances on nodes with the new role of `infra`.

The OpenShift router operator creates a custom resource definition (`CRD`)
called `clusteringress`. The `clusteringress` objects are observed by the router
operator and tell the operator how to create and configure routers. Let's take
a look:

~~~bash
$ oc get clusteringress default -n openshift-ingress-operator -o yaml
~~~

Which will give you the following output:

```YAML
apiVersion: ingress.openshift.io/v1alpha1
kind: ClusterIngress
metadata:
  creationTimestamp: 2019-03-18T00:59:59Z
  finalizers:
  - ingress.openshift.io/default-cluster-ingress
  generation: 1
  name: default
  namespace: openshift-ingress-operator
  resourceVersion: "17987"
  selfLink: /apis/ingress.openshift.io/v1alpha1/namespaces/openshift-ingress-operator/clusteringresses/default
  uid: 2763923f-4919-11e9-85ca-02fb9875b46a
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
  ingressDomain: apps.cluster-8145.8145.sandbox389.opentlc.com
  labelSelector: app=router,router=router-default
  replicas: 2
```

As you can see, the `nodeSelector` is configured for the `worker` role. Go
ahead and use `oc edit` to change `node-role.kubernetes.io/worker` to be
`node-role.kubernetes.io/infra`:

```bash
$ oc edit clusteringress default -n openshift-ingress-operator -o yaml
(Opens in vi)
```

The relevant section should look like the following:

~~~YAML
spec:
  defaultCertificateSecret: null
  highAvailability: null
  ingressDomain: null
  namespaceSelector: null
  nodePlacement:
    nodeSelector:
      matchLabels:
        node-role.kubernetes.io/infra: ""
~~~

After saving and exiting the editor, if you're quick enough, you might catch the
router pod being moved to its new home. Run the following command and you may
see something like:

```bash
$ oc get pod -n openshift-ingress -o wide
NAME                              READY     STATUS        RESTARTS   AGE       IP           NODE                                              NOMINATED NODE
router-default-5fc6c9ffbb-9x9l8   1/1       Running       0          15h       10.131.0.7   ip-10-0-131-124.ap-southeast-1.compute.internal   <none>
router-default-5fc6c9ffbb-p5x6d   0/1       Terminating   0          15h       10.131.0.8   ip-10-0-135-227.ap-southeast-1.compute.internal   <none>
```

In the above output, the `Terminating` pod was running on one of the worker
nodes. The `Running` pod is now on one of our nodes with the `infra` role.

**NOTE**: The actual moving of the pod is currently not working (you can track
the progress [here](https://jira.coreos.com/browse/NE-72)), so as a temporary
workaround we can force the router pods to be rebuilt on other nodes by running:

~~~bash
$ for i in $(oc get pod -n openshift-ingress | awk 'NR>1{print $1;}'); do oc delete pod $i -n openshift-ingress; done
pod "router-default-5fc6c9ffbb-9x9l8" deleted
pod "router-default-5fc6c9ffbb-p5x6d" deleted
~~~

If we wait a minute or so, we should see that the pods are rebuilt:

~~~bash
$ oc get pod -n openshift-ingress -o wide
NAME                              READY     STATUS    RESTARTS   AGE       IP           NODE                                              NOMINATED NODE
router-default-5fc6c9ffbb-2jtrx   1/1       Running   0          70s       10.131.2.5   ip-10-0-142-239.ap-southeast-1.compute.internal   <none>
router-default-5fc6c9ffbb-jplph   1/1       Running   0          83s       10.128.4.6   ip-10-0-133-204.ap-southeast-1.compute.internal   <none>
~~~

If we check one of the nodes for the `ROLE` that it's labeled with:

~~~bash
$ oc get node ip-10-0-142-239.ap-southeast-1.compute.internal
NAME                                              STATUS    ROLES          AGE       VERSION
ip-10-0-142-239.ap-southeast-1.compute.internal   Ready     infra,worker   19m       v1.12.4+4dd65df23d
~~~

Success! Our pods have been automatically redeployed onto the infrastructure
nodes.

## Container Image Registry
The registry uses a similar `CRD` (Custom Resource Definition) mechanism to
configure how the operator deploys the actual registry pods. That CRD is
`configs.imageregistry.operator.openshift.io`. You will need to edit the
`cluster` CR object in order to add the `nodeSelector`. First, take a look at
it:

~~~bash
$ oc get configs.imageregistry.operator.openshift.io/cluster -o yaml
~~~

Which will give you the following output:

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

Next, let's modify the custom resource by live-patching the configuration.
For this we can use `oc edit`, and you'll need to modify the `.spec` section:

~~~bash
$ oc edit configs.imageregistry.operator.openshift.io/cluster
~~~

The `.spec` section will need to look like the following:

```YAML
  nodeSelector:
    node-role.kubernetes.io/infra: ""
```

Once you're done, save and exit the editor, and it should confirm the change:

~~~bash
config.imageregistry.operator.openshift.io/cluster edited
~~~

> **NOTE**: The `nodeSelector` stanza may be added **anywhere** inside the `.spec` block.

When you save and exit you should see the registry pod being moved to the infra
node. The registry is in the `openshift-image-registry` project. If you execute
the following quickly enough, you may see the old registry pods terminating and
the new ones starting.:

~~~bash
$ oc get pod -n openshift-image-registry
NAME                                               READY     STATUS        RESTARTS   AGE
cluster-image-registry-operator-8548dcf5b8-rlrhg   1/1       Running       0          16h
image-registry-559d48d7fc-zw8fr                    1/1       Terminating   0          16h
node-ca-5wq4z                                      1/1       Running       0          16h
node-ca-622n2                                      1/1       Running       0          16h
node-ca-7x5l4                                      1/1       Running       0          62m
node-ca-956sf                                      1/1       Running       0          28m
node-ca-kwllr                                      1/1       Running       0          16h
node-ca-twz85                                      1/1       Running       0          28m
node-ca-vgkt4                                      1/1       Running       0          16h
node-ca-xjkfd                                      1/1       Running       0          16h
node-ca-xnct7                                      1/1       Running       0          16h
~~~

> **NOTE**: At this time the image registry is not using a separate project for its
operator. Both the operator and the operand are housed in the
`openshift-image-registry` project.

Since the registry is being backed by an S3 bucket, it doesn't matter what
node the new registry pod instance lands on. It's talking to an object store
via an API, so any existing images stored there will remain accessible.

Also note that the default replica count is 1. In a real-world environment
you might wish to scale that up for better availability, network throughput,
or other reasons.

If you look at the node on which the registry landed (noting that you'll likely
have to refresh your list of pods by using the previous commands to get its new
name):

~~~bash
$ oc get pod image-registry-6dd97df674-v77m2 -n openshift-image-registry -o wide
NAME                              READY     STATUS    RESTARTS   AGE       IP           NODE                                              NOMINATED NODE
image-registry-6dd97df674-v77m2   1/1       Running   0          4m45s     10.130.2.6   ip-10-0-131-124.ap-southeast-1.compute.internal   <none>
~~~

...you'll note that it is now running on an infra worker:

~~~bash
$ oc get node ip-10-0-131-124.ap-southeast-1.compute.internal
NAME                                              STATUS    ROLES          AGE       VERSION
ip-10-0-131-124.ap-southeast-1.compute.internal   Ready     infra,worker   67m       v1.12.4+4dd65df23d
~~~

Lastly, notice that the CRD for the image registry's configuration is not
namespaced -- it is cluster scoped. There is only one internal/integrated
registry per OpenShift cluster that serves all projects.

## Monitoring
The Cluster Monitoring operator is responsible for deploying and managing the
state of the Prometheus+Grafana+AlertManager cluster monitoring stack. It is
installed by default during the initial cluster installation. Its **operator**
uses a `ConfigMap` in the `openshift-monitoring` project to set various
tunables and settings for the behavior of the monitoring stack.

There is no `ConfigMap` created as part of the installation. Without one,
the operator will assume default settings, as we can see, this is not defined:

```bash
$ oc get configmap cluster-monitoring-config -n openshift-monitoring
```

Even with the default settings, The operator will create several `ConfigMap`
objects for the various monitoring stack components, and you can see them, too:

```bash
$ oc get configmap -n openshift-monitoring
NAME                                        DATA      AGE
adapter-config                              1         16h
grafana-dashboard-k8s-cluster-rsrc-use      1         16h
grafana-dashboard-k8s-node-rsrc-use         1         16h
grafana-dashboard-k8s-resources-cluster     1         16h
grafana-dashboard-k8s-resources-namespace   1         16h
grafana-dashboard-k8s-resources-pod         1         16h
grafana-dashboards                          1         16h
kubelet-serving-ca-bundle                   1         16h
prometheus-adapter-prometheus-config        1         16h
prometheus-k8s-rulefiles-0                  1         16h
serving-certs-ca-bundle                     1         16h
sharing-config                              3         16h
telemeter-client-serving-certs-ca-bundle    1         16h
```


Take a look at the following file, it contains the definition for a `ConfigMap`
that will cause the monitoring solution to be redeployed onto infrastructure
nodes:

https://github.com/openshift/training/blob/master/assets/cluster-monitoring-configmap.yaml

Let's use this as our new configuration; you can create the new monitoring
config with the following command:

```bash
$ oc create -f https://raw.githubusercontent.com/openshift/training/master/assets/cluster-monitoring-configmap.yaml
configmap/cluster-monitoring-config created
```

We can now watch the various monitoring pods be redeployed onto our
`infrastructure` nodes with the following command:

~~~bash
$ oc get pod -w -n openshift-monitoring
NAME                                           READY     STATUS              RESTARTS   AGE
alertmanager-main-0                            3/3       Running             0          16h
alertmanager-main-1                            3/3       Running             0          16h
alertmanager-main-2                            0/3       ContainerCreating   0          3s
cluster-monitoring-operator-6fc8c9bc75-6pfpw   1/1       Running             0          16h
grafana-574679769d-7f9mf                       2/2       Running             0          16h
kube-state-metrics-55f8d66c77-sbbbc            3/3       Running             0          16h
kube-state-metrics-578dbdf85d-85vm7            0/3       ContainerCreating   0          9s
node-exporter-2x7b7                            2/2       Running             0          16h
node-exporter-d4vq9                            2/2       Running             0          45m
node-exporter-dx5kz                            2/2       Running             0          16h
node-exporter-f9g4h                            2/2       Running             0          16h
node-exporter-kvd5x                            2/2       Running             0          45m
node-exporter-ntzbp                            2/2       Running             0          16h
node-exporter-prsj9                            2/2       Running             0          1h
node-exporter-qx9lf                            2/2       Running             0          16h
node-exporter-wh9qs                            2/2       Running             0          16h
prometheus-adapter-7fb8c8b544-jn8q2            1/1       Running             0          32m
prometheus-adapter-7fb8c8b544-v5rfs            1/1       Running             0          33m
prometheus-k8s-0                               6/6       Running             1          16h
prometheus-k8s-1                               6/6       Running             1          16h
prometheus-operator-7787679668-nxc6s           0/1       ContainerCreating   0          8s
prometheus-operator-954644495-m64hd            1/1       Running             0          16h
telemeter-client-79f99d7bc6-4p8zv              3/3       Running             0          16h
telemeter-client-7f48f48dd7-dvblb              0/3       ContainerCreating   0          4s
grafana-5fc5979587-bdkcd                       0/2       Pending             0          3s

(Ctrl+C to exit)
~~~

> **NOTE**: You can also run `watch 'oc get pod -n openshift-monitoring'` as an
alternative.

## Logging
OpenShift's log aggregation solution is not installed by default. There are
also a few minor bugs that prevent Logging from being easily installed via
the Operator UI in the web console. It is skipped for now.

## Configuring Authentication
The [configuring authentication](06-authentication.md) section describes how
to configure htpasswd-based auth for your cluster.
