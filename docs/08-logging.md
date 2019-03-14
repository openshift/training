# Log Aggregation in OpenShift
Installation of the log aggregation solution is [documented here](https://docs.openshift.com/container-platform/4.0/logging/efk-logging-deploy.html).

## Creating the Logging Project
You can create the required Project with the following command:

```sh
oc create -f https://raw.githubusercontent.com/openshift/training/master/assets/logging-project.yaml
```

While the documentation refers to setting a `NodeSelector` at the namespace
level, there is a [small
bug](https://bugzilla.redhat.com/show_bug.cgi?id=1683819) that would prevent
that from working with the infrastructure node `node-role` label. Instead, we
will set `NodeSelectors` individually on each component.

## Logging Operators
Follow the documentation for installing the required operators.

oc new-project logging
click "show community"
click "do not show again"
click "show community"
click "cluster logging" tile
click "install"
click "show community"

wait

developer catalog
click "logging" project
click "cluster logging" tile
click "create"

if you have infra nodes add nodeselector
