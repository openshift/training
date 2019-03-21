# Istio Service Mesh
While Istio is still in Tech Preview state, it is installable on top of OCP4
with some small caveats.

## Installing Istio
Take a look at the [OpenShift 3-based Istio Installation
Overview](https://docs.openshift.com/container-platform/3.11/servicemesh-install/servicemesh-install.html)
documentation.

### Skip Node Configuration
Do not perform the [node
configuration](https://docs.openshift.com/container-platform/3.11/servicemesh-install/servicemesh-install.html#updating-node-configuration)
steps. There is a tuned Operator running in OpenShift 4 that will take care
of this for you.

### Build Your Istio Configuration CR
The [custom resource
parameters](https://docs.openshift.com/container-platform/3.11/servicemesh-install/servicemesh-install.html#custom-resource-parameters)
documentation describes the various options you can put into the CR that tell
the Operator how to configure Istio. You can also just use the minimal CR to
start. You can actually find that CR here:

https://raw.githubusercontent.com/Maistra/openshift-ansible/maistra-0.10/istio/istio-installation-minimal.yaml

### Istio Operator
You can follow the [Istio operator
installation](https://docs.openshift.com/container-platform/3.11/servicemesh-install/servicemesh-install.html#installing-operator)
steps as written.

### Deploy the Control Plane
If you want to use the minimal CR, you can simply execute the following:

```
oc create -f https://raw.githubusercontent.com/Maistra/openshift-ansible/maistra-0.10/istio/istio-installation-minimal.yaml -n istio-operator
```

Otherwise, use whatever CR you designed.

### Add StatefulSet Label
ElasticSearch requires a specific `sysctl` setting be set. The OpenShift
3-based instructions tell you to directly modify the Nodes. But, in OCP4, the
Nodes are immutable and should not be directly modified. There is a `tuned`
Operator that can set these `sysctls` for you, and it actually already knows
specifically about the ones for ES.

Once the Istio installation Pod/Job is completed, all you need to do is edit
the Elasticsearch `StatefulSet`:

```
oc edit statefulset elasticsearch -n istio-system
```

Make a change to `.spec.template.metadata.labels` so that it looks like the following:

```yaml
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: elasticsearch
        tuned.openshift.io/elasticsearch: ""
```

The `tuned` Operator will see the ElasticSearch label and appropriately set
the sysctl on any Node that is running the Pod.

Once you save and quit the editor, you should delete any existing
ElasticSearch Pods in the `istio-system` Project, which will cause them to be
recreated with the new Label.

## Application Requirements
The various instructions for using Istio with your applications are found in
the [application
requirements](https://docs.openshift.com/container-platform/3.11/servicemesh-install/servicemesh-install.html#install_chapter_5)
documentation.

## Other Examples
There are various tutorials that you can try with Istio [here](http://bit.ly/istio-tutorial).