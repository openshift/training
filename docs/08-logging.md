# Log Aggregation in OpenShift
The log aggregation solution in OpenShift 4 is not changed from the
ElasticSearch, Kibana and FluentD stack. The installation process, though,
has changed.

Take a moment to familiarize yourself with the [logging
overview](https://docs.openshift.com/container-platform/4.0/logging/efk-logging.html).

# Deploying Logging
Deploying the logging solution requires only a few steps. Take a look at the
[deploying cluster
logging](https://docs.openshift.com/container-platform/4.0/logging/efk-logging-deploy.html#efk-logging-deploy-subscription-efk-logging-deploy)
documentation. There are some additional notes on the process here.

## Create the Logging Project
You can create the required Project with the following command:

```sh
oc create -f https://raw.githubusercontent.com/openshift/training/master/assets/logging-project.yaml
```

This YAML already has the annotations and appropriate details.

## Logging CR
If you had followed the instructions for [creating infrastructure
nodes](docs/05-infrastructure-nodes.md), you already have some special nodes
with special labels. When you get to the section on "Create a cluster logging
instance", if you want to deploy the logging solution onto your
infrastructure nodes, we have an existing CR that you can use.

https://raw.githubusercontent.com/openshift/training/master/assets/logging-cr.yaml

You can paste the contents of the CR into the web console.

## Set Default Index Pattern
When the Logging solution is finished installing, find the route for Kibana,
click through to it, accept all certificates and login as `kubeadmin`. You
will find that Kibana wants you to set a default index pattern.

Click `.all` on the left and then click the star icon on the right to set
this as the default index. You will notice that a star icon appears on the
left next to `.all`. At this point you can click "Discover" to perform your
searches.