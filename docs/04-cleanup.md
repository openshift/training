# Cleanup

In this lab, we will delete the compute resources created during this tutorial.

### Linux

Delete the cluster and its associated compute resources.

The command will print out all changes made to the target platform.

For example, if running on AWS, you will see output describing each deleted resource.

```
./openshift-install-linux-amd64 destroy cluster
```

### Mac

Delete the cluster and its associated compute resources.

The command will print out all changes made to the target platform.

For example, if running on AWS, you will see output describing each deleted resource.

```
./openshift-install-darwin-amd64 destroy cluster
```
