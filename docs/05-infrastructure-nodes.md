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

## Infrastructure MachineSets
The documentation covers [creating infrastructure
machinesets](https://docs.openshift.com/container-platform/4.0/machine_management/creating-infrastructure-machinesets.html).
It also goes into detail on moving various OpenShift infrastructure
components. Take a look at all of the documentation and then come back here
to look at the various notes and suggestions before you try anything.

## Docs Notes and Omissions

### Automagic

The following scriptlet assumes you have an AWS region called `us-east-1e`
and will build and create a `MachineSet` for you. It requires the `jq`
program be installed.

```bash
export REGION=us-east-1e
export NAME="infra-$REGION"
oc get machineset -o json\
| jq '.items[0]'\
| jq '.metadata.name=env["NAME"]'\
| jq '.spec.selector.matchLabels."machine.openshift.io/cluster-api-machineset"=env["NAME"]'\
| jq '.spec.template.metadata.labels."machine.openshift.io/cluster-api-machineset"=env["NAME"]'\
| jq '.spec.template.spec.metadata.labels."node-role.kubernetes.io/infra"=""'\
| oc create -f -
```

### Add More Machinesets (or scale, or both)
In a realistic production deployment, you would want at least 3 `MachineSets`
to hold infrastructure components. Both the logging aggregation solution and
the service mesh will deploy ElasticSearch, and ElasticSearch really needs 3
instances spread across 3 discrete nodes. Why 3 `MachineSets`? Well, in
theory, having a `MachineSet` in different AZs ensures that you don't go
completely dark if AWS loses an AZ.

For testing purposes, you could just scale a single infra `MachineSet` to 3
replicas.

If you do want to create multiple `MachineSets` you can simply modify the
scriptlet above for whichever regions you want.

### Extra Credit
In the `openshift-machine-api` project are several `Pods`. One of them has a
name of ` clusterapi-manager-controllers-....`. If you use `oc logs` on the
various containers in that `Pod`, you will see the various operator bits that
actually make the nodes come into existence.

### Router moving not working
The actual moving of the pod is currently not working. You can track the
progress here: https://jira.coreos.com/browse/NE-72

### Monitoring
The docs incorrectly say that the Monitoring solution cannot be modified.
This is tracked in https://bugzilla.redhat.com/show_bug.cgi?id=1688487

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
Logging is handled in its own document, [installing and configuring log
aggregation](08-logging.md). The installation and configuration of logging
uses the Operator Lifecycle Manager, so you may want to go through the
section on [extensions to your cluster](07-extensions.md) first.

## Configuring Authentication
The [configuring authentication](06-authentication.md) section describes how
to configure htpasswd-based auth for your cluster.
