# Deleting the Cluster and Cleaning up
The following command will remove the OpenShift 4 cluster and all the underlying
AWS resources that were created by the installer:

    ./openshift-install destroy cluster

The installer also created various dot files (`.openshift...`) that you may
also wish to delete. If you do not delete them, the next time you `install
cluster` you may find that you are not prompted for any input and the
installer will use the input you provided on the last run.

On the off chance that you experience a failure during the `destroy`
operation, you will need to very carefully delete the resources that were
created, by hand, from your AWS account. Fortunately they are all tagged with
a `key:value` pair of `clusterid:whatever_you_specified_during_install`.