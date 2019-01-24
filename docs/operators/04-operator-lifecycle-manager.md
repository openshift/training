# Operator Lifecycle Manager

The
[Operator Lifecycle Manager](https://github.com/operator-framework/operator-lifecycle-manager)
is an operator that manages the installation and upgrade of Kubernetes-native
applications.

Optional components that administrators can install in the distribution are
managed by Operator Lifecycle Manager.

Users consume applications in their namespaces by creating **Subscriptions**:

```yaml
apiVersion: operators.coreos.com/v1alpha1
  kind: Subscription
  metadata:
    name: federationv2
    namespace: my-project
  spec:
    channel: alpha
    name: federationv2
    source: rh-operators
```

Subscriptions drive OLM to install components into namespaces.

Next: [Configuration](05-configuration.md)
