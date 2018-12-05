# Second Level Operators

This tutorial describes second level operators that manage the core control plane.

## Second Level Operators

Any operator that is deployed by the cluster version operator directly via the
release payload is refered to as a `Second Level Operator`.  This operator
manages the artifacts needed to drive a minimal OpenShift distribution.

Each operator handles install and upgrade of its component.  It also exposes
mechanisms to enable administrators to configure the component.  The operator
watches for the configuration change and applies it out to each manage component.
Each operator reconciles to ensure it always converges to desired state.  As a
result, the entire system is level-based rather than edge-based.  It acts on
observed state rather than past actions.

Each operator publishes it status to a `ClusterOperator` custom resource definition
that is read by the `ClusterVersionOperator` to ensure the desired state has converged.

To view the list of cluster operators and their status, execute the following:

```sh
oc get clusteroperators
NAME                                                      VERSION                         AVAILABLE   PROGRESSING   SINCE
machine-api-operator                                      v0.0.0-was-not-built-properly   True                      1m
machine-config-operator                                   3.11.0-294-g77b0e7bc-dirty      True        False         16s
openshift-cluster-kube-scheduler-operator                                                                           
openshift-cluster-openshift-controller-manager-operator   3.11.0                          True        False         
openshift-cluster-samples-operator                                                        True        False         1h
```

**TODO** UPDATE THIS SECTION WITH FULL LIST AS COMPONENTS MERGE THIS WEEK

To view more detail about an operator, you can describe it.

To view information about the operator that manages the , execute the following:

```sh
oc describe clusteroperator openshift-cluster-openshift-controller-manager-operator
Name:         openshift-cluster-openshift-controller-manager-operator
Namespace:    
Labels:       <none>
Annotations:  <none>
API Version:  config.openshift.io/v1
Kind:         ClusterOperator
Metadata:
  Creation Timestamp:  2018-12-03T19:53:48Z
  Generation:          1
  Resource Version:    276100
  Self Link:           /apis/config.openshift.io/v1/clusteroperators/openshift-cluster-openshift-controller-manager-operator
  UID:                 265fc834-f735-11e8-b511-02ef2cd26b4a
Status:
  Conditions:
    Last Transition Time:  <nil>
    Message:               replicas ready
    Status:                True
    Type:                  Available
    Last Transition Time:  2018-12-03T19:53:51Z
    Message:               no errors found
    Status:                False
    Type:                  Failing
    Last Transition Time:  <nil>
    Message:               available and not waiting for a change
    Status:                False
    Type:                  Progressing
  Version:                 3.11.0
Events:                    <none>
```

# Next steps

Optional components that administrators can install in the distribution are
managed by Operator Lifecycle Manager.

Next: [Operator Lifecycle Management](04-operator-lifecycle-manager.md)