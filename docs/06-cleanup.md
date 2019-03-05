# Deleting the Cluster and Cleaning up

Cleaning up your cluster is straightforward *if* you preserved the
`metadata.json` file from cluster creation.  It is usually possible to
reconstruct the file if you lose it, but that depends on still having
a functioning cluster or poking around in AWS, so it's better to just
hang on to the file.

The following command will read `metadata.json` and remove the
OpenShift 4 cluster and all underlying AWS resources that were created
by the installer:

    ./openshift-install destroy cluster

As for `create`, you can set `--dir` to use an asset directory other
than your current working directory.  You should use the same asset
directory for `destroy` that you used for `create`.
