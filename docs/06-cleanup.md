# Deleting the Cluster and Cleaning up
Cleaning up your cluster is trivial. However, on the off chance that the
cleanup fails, you will be left with AWS resources that are undeleted.
Finding them can be tricky, but they have a key:value tag of
`openshiftClusterID:<cluster_uuid>` and then you can carefully delete them by
hand.

Just in case, be sure to grab the UUID before destroying the cluster:

    oc get clusterversion -o jsonpath='{.spec.clusterID}{"\n"}' version

If you are trying to destroy your cluster because of a failed installation,
you may not be able to use `oc`. In that case, you can look for the UUID in
the `metadata.json` asset:

    jq -r .clusterID metadata.json

The following command will read `metadata.json` and remove the
OpenShift 4 cluster and all underlying AWS resources that were created
by the installer:

    ./openshift-install destroy cluster

As for `create`, you can set `--dir` to use an asset directory other
than your current working directory.  You should use the same asset
directory for `destroy` that you used for `create`.
