# Deleting the Cluster and Cleaning up
Cleaning up your cluster is trivial. However, on the off chance that the
cleanup fails, you will be left with AWS resources that are undeleted.
Finding them can be tricky, but they all have a key:value tag of
`openshiftClusterID:<cluster_uuid>` and then you can carefully delete them by
hand.

Just in case, be sure to grab the UUID before destroying the cluster:

    oc get clusterversion -o jsonpath='{.spec.clusterID}{"\n"}' version

If you are trying to destroy your cluster because of a failed installation,
you may not be able to use `oc`. In that case, you can look for the UUID in
one of the state files:

    grep '"clusterID"' .openshift_install_state.json

The following command will then remove the OpenShift 4 cluster and all the
underlying AWS resources that were created by the installer:

    ./openshift-install destroy cluster
