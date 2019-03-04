# Extensions to OpenShift using OperatorHub

OpenShift 4 has a slimmer base, with the ability to easily extend it with
Operators for both cluster services (networking, storage, logging) and
applications (databases, message queues, source control) for your developers
to build applications with.

OperatorHub is a feature built into your cluster to discover and install
Operators on your cluster. OperatorHub is only available for cluster
administrators. Once installed, these services are made available to users of
the cluster through the Developer Catalog.

Within OperatorHub, you will find three sets of Operators available to you:

* Red Hat Products - licensed software that is tested extensively on OpenShift 4.
* Certified Partners - partners that have certified their applications for 
  OpenShift and have established a mutual support SLA with Red Hat, in order to 
  provide you with the best experience.
* Community - a set of curated Operators built by the Kubernetes community and 
  work well with the Operator Lifecycle Management software already installed
  on your cluster.

## Create a Project
Before you get started, create a project for what you're about to do with
Couchbase. You can either do it from the command line:

```sh
oc new-project mycouchbase
```

or from the web console.

## Installing an Extension

Installing your first Operator is best done through the user interface, but
can also be driven by the command line. Open the OpenShift web console, click
to "Catalog", then "OperatorHub". Only users with cluster admin privileges
can see the Operator Hub interface. At the top of the page, in the Project
selector, choose `mycouchbase`.

Couchbase is a powerful NoSQL database. Search or browse to the Couchbase
Operator and click it. The description lays out the notable features of the
Operator. Go ahead and click "Install" to deploy the Operator on to the
cluster. It may take several moments after clicking "Install" before the
Subscription page shows up.

The installation process involves "subscribing" to an Operator from the hub.
This subscription mechanism is how OpenShift learns about updates to the
operator. Operator creators may roll updates for their operators to handle
things like updates, enhancements, bug fixes, and other changes to the
solution that the operator deploys.

### Installation Mode

Operators can be enabled for all Projects across the cluster or only within
specific namespaces. Not all Operators support each of these installation
methods. The Couchbase operator only supports installation for a specific
namespace. Make sure `mycouchbase` is selected to match the project you
created earlier.

### Update Channel

Each Operator publisher can create channels for their software, to give
adminsitrators more control over the versions that are installed. In this
case, Couchbase only has a "preview" channel.

### Update Approval Strategy

If Operator creators enable their operators to update the deployed solutions,
Operator Lifecycle Manager is able to automatically apply those updates.
Cluster administrators can decide whether or not OLM should or should not
automatically apply updates. In the future, when Couchbase releases an
updated operator to the "preview" channel, you can decide whether you want to
approve each update, or have it happen automatically. Choose "Automatic" for
now.

After clicking "Subscribe", the Couchbase entry will now show that it is
"Installed".

**Note:** While the Operator Hub page indicates that the operator is
"installed", really it is indicating that the operator is configured to be
installed. It may take several minutes for OpenShift to pull in the operator
to the cluster. You can check on the status of this operator with the
following command:

```sh
oc get pod -all-namespaces | grep couch
```

You will likely see the Couchbase operator pod in `ContainerCreating` status
if you look very soon after finishing the installation/subscription process.

## Using Secrets
The Couchbase operator is capable of installing and managing a Couchbase
cluster for you. But, before it can do that, it has a [prerequisite for a
Kubernetes
secret](https://docs.couchbase.com/operator/1.1/couchbase-cluster-config.html#authsecret)
that it can use to configure the username and password for the cluster. You
have a few ways to create this secret.

1. You can create a key/value secret with a `username` and `password` key in
the OpenShift web console by navigating to "Workloads" and then "Secrets".
Make sure the Project selector is set to `mycouchbase`. Finally, you can
click "Create" and choose "Key/Value Secret".

1. You can make sure the Project selector is set to `mycouchbase` and then
click "+ Add" at the upper right-hand area of the web console, and then
choose "Import YAML". Paste the following YAML into the form (the username is
"couchbase" and the password is "securepassword"):

    ```YAML
    apiVersion: v1
    data:
      password: c2VjdXJlcGFzc3dvcmQ=
      username: Y291Y2hiYXNl
    kind: Secret
    metadata:
      name: cb-example-auth
      namespace: mycouchbase
    type: Opaque
    ```

1. You can create the secret directly using the following command:

    ```sh
    oc create -f https://raw.githubusercontent.com/openshift/training/master/assets/cb-example-auth.yaml
    ```

Ultimately, you want a secret with the username `couchbase` and the password
`securepassword` (both example #2/#3 above use that).

## Using an Installed Operator

Regular users will use the "Developer Catalog" menu to add shared apps,
services, or source-to-image builders to projects. Navigate to the "Developer
Catalog" and, at the top of the page, again make sure you select
`mycouchbase` from the Project dropdown. You should see that the Couchbase
operator is available. If you choose a different Project, you should also
notice that the Couchbase operator is **not** available in other Projects.

Click on the Couchbase Cluster tile, which is a capability that the Operator
has extended our OpenShift cluster to support. Operators can expose more than
one capability. For example, the MongoDB Operator exposes three common
configurations of its database (and you would see three _different_ MongoDB
tiles).

Deploy an instance of Couchbase by clicking the "Create" button in the top
left. The YAML editor has been pre-filled with a set of defaults for the
resulting Couchbase cluster. One of those defaults is a reference to the
Secret you created earlier.

### Changing Couchbase Parameters

Set the `replicas` field set to `3`, so our Operator sets up a highly
available cluster for us. Your YAML should look like the following:

```YAML
apiVersion: couchbase.com/v1
kind: CouchbaseCluster
metadata:
  name: cb-example
  namespace: default
spec:
  authSecret: cb-example-auth
  baseImage: registry.connect.redhat.com/couchbase/server
  buckets:
    - conflictResolution: seqno
      enableFlush: true
      evictionPolicy: fullEviction
      ioPriority: high
      memoryQuota: 128
      name: default
      replicas: 3
      type: couchbase
  ...
```

Click "Create". Afterwards, you will be taken to a list of all Couchbase
instances running with this Project and should see the one you just created
has a status of "Creating".

### View the Deployed Resources

Navigate to the Couchbase Cluster that was deployed by clicking `cb-example`,
and then click on the "Resources" tab. This collects all of the objects
deployed and managed by the Operator. From here you can ultimately view Pod
logs to check on the Couchbase Cluster instances.

If for some reason you had navigated away from the page after creating your
Couchbase cluster, you can get back here by clicking "Catalog" -> "Installed
Operators" -> "Couchbase Cluster" -> `cb-example`.

We are going to use the Service `cb-example` to access the Couchbase
dashboard via a Route:

```sh
oc expose service cb-example -n mycouchbase
```

You should now have a route:

```sh
oc get route -n mycouchbase
```

Which will show something like:

```
NAME         HOST/PORT                                                                  PATH   SERVICES     PORT        TERMINATION   WILDCARD
cb-example   cb-example-mycouchbase.apps.beta-190304-2.ocp4testing.openshiftdemos.com          cb-example   couchbase                 None
```

Your Couchbase installation is now exposed directly to the internet and is
not using HTTPS. Go ahead and copy/paste the URL into your browser. Login
with the user `couchbase` and the password `securepassword` (these were in
your secret). If you used different credentials, make sure you put in the
right ones.

### Re-Configure the Cluster with the Operator

Keep the Couchbase dashboard up as we re-configure the cluster. As the Operator scales
up more Pods, they will automatically join and appear in the dashboard.

Edit your `cb-example` Couchbase instance to have a server size of `4`
instead of `3`. You can navigate back to the installed instances of Couchbase
via the web console, or you can use:

```sh
oc edit couchbaseclusters.couchbase.com/cb-example -n mycouchbase
```

A few things will happen:

* The Operator will detect the difference between the desired state and the 
  current state
* A new Pod will be created and show up under "Resources"
* The Couchbase dashboard will show 4 instances once the Pod is created
* The Couchbase dashboard will show that the cluster is being rebalanced

After the cluster is scaled up to `4`, try scaling back down to `3`. If you
watch the dashboard closely, you will see that Couchbase as automatically
triggered a re-balance of the data within the cluster to reflect the new
topology of the cluster. This is one of many advanced feautres embedded
within applications in OperatorHub to save you time when administering your
workloads.

### Delete the Couchbase Instance

After you are done, delete the `cb-example` Couchbase instance and the
Opeator will clean up all of the resources that were deployed. Remember to
delete the Route that we manually created as well. Remember to delete the
Operator instance and not to delete the Pods or other resources directly --
the operator will immediately try to fix that thinking that there's a
problem!

After you delete the `cb-example` instance, if you look at the Project
quickly you'll see the Pods terminating:

```sh
oc get pod -n mycouchbase
```

But you'll also see that the Operator Pod remains. That's because there's
still a Subscription for the Couchbase operator in this Project. You can
delete the Subscription (and, thus, the Pod) by going to "Operator
Management" -> "Operator Subscriptions". There you can click the 3 dots and
remove the Subscription for the Couchbase Operator in the `mycouchbase`
Project. Now there should be no Pods, and you can also delete the Project if
you want.

## Try Out More Operators

Operators are a powerful way for cluster administrators to extend the
cluster, so that developers can build their apps and services in a
self-service way. With the expertise baked into an Operator, running high
quality, production instructure has never been easier.

OperatorHub will be continually updated with more great Operators from Red
Hat, certified partners and the Kubernetes community.

# End of Materials
Congratulations. You have reached the end of the materials. Feel free to
explore your cluster further.

If you are done, you can proceed to [cleanup your cluster](08-cleanup.md)