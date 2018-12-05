# Access Cluster

<!-- TODO: replace with the oc login command with the user/pass provided during install? -->
If you haven't already, set your `KUBECONFIG` environment variable to provide the CLI with the cluster admin credentials.

```
# In the same directory you ran the installer. If you used the --dir flag when running create cluster,
# the auth directory will be there instead.
export KUBECONFIG=./auth/kubeconfig
```
Now you can run any command against the cluster. If you are already familiar with the commands available in `kubectl`, the `oc` tool contains the same set of commands plus additional ones that add to the experience of using and administering OpenShift.

WARNING: While authenticated as the cluster administrator you can perform highly destructive commands against the cluster.

```
# Get all the nodes in the cluster to see if the status of your worker nodes is now Ready
oc get nodes

# Get pods across all namespaces to watch the rest of the infrastructure components come online
oc get pods --all-namespaces
```

To see the full set of commands run `oc help`

Next: [Explore More](../03-explore.md)