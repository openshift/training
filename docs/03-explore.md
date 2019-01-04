# Exploring the Cluster

Now that your cluster is installed, you have access to the web console, and you can use the CLI, here are some command-line exercises to explore the cluster:

## Cluster Nodes

The default installation behavior creates 6 nodes: 3 masters and 3 "worker"
application/compute nodes. You can view them with:

    oc get nodes

If you want to see the various applied labels, you can also do:

    oc get nodes --show-labels

## The Cluster Operator
The Cluster Operator is heavily responsible for
installation/management/maintenance/automated operations on the OpenShift
cluster. 

    oc get deployments -n openshift-cluster-version 

You can `rsh` into the running Operator and see the various manifests
associated with the installed release of OpenShift:

    oc rsh -n openshift-cluster-version deployments/cluster-version-operator 

Then:

    ls /release-manifests

You will see a number of `.yaml` files. Don't forget to `exit` from your
`rsh` session before continuing

If you want to look at what the Cluster Operator has done since it was
launched, you can execute the following (**Generates quite a lot of output -
you may wish to redirect to a text file**):

    oc logs deployments/cluster-version-operator -n openshift-cluster-version

# WARNING
The below exercises/steps have not been validated.

## Understanding OpenShift

Depending on your interest, explore the following:

- [Using the CLI](cli/01-accessing.md)
- [Accessing the console](console/01-accessing.md)
- [Understanding operators](operators/01-understanding-operators.md)
- [Managing Compute](compute/01-managing-compute.md)
- [Managing Nodes](nodes/01-managing-nodes.md)
- [Monitoring](monitoring/01-understanding-monitoring.md)
- [Developer Experience](developer-experience/01-developer-experience.md)

Next: [Cleanup the Cluster](04-cleanup.md)