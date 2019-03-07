# Deleting the Cluster and Cleaning up

Cleaning up your cluster is straightforward *if* you preserved the
`metadata.json` file from cluster creation.  It is usually possible to
reconstruct the file if you lose it, but that depends on still having
a functioning cluster or poking around in AWS, so it's better to just
hang on to the file.

Also, if you added an EC2 instance to your VPC in order to be able to SSH
into the cluster, make sure that you manually delete it first before
attempting to delete your cluster. Our instructions did not provide
sufficient detail to ensure that the installer could "find" the EC2 instance
in order to delete it. Failing to manually delete the EC2 instance you
manually created will result in the deletion of your cluster hanging and
never completing.

The following command will read `metadata.json` and remove the
OpenShift 4 cluster and all underlying AWS resources that were created
by the installer:

    ./openshift-install destroy cluster

As with `create`, you can set `--dir` to use an asset directory other
than your current working directory.  You should use the same asset
directory for `destroy` that you used for `create`.
