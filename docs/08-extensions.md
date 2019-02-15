# Extensions to OpenShift using OperatorHub

OpenShift 4 has a slimmer base, with the ability to easily extend it with Operators for both cluster services (networking, storage, logging) and applications (databases, message queues, source control) for your developers to build applications with.

OperatorHub is a feature built into your cluster to discover and install Operators on your cluster. OperatorHub is only available for cluster administrators. Once installed, these services are made available to users of the cluster through the Developer Catalog.

Within OperatorHub, you will find three sets of Operators available to you:

* Red Hat Products - licensed software that is tested extensively on OpenShift 4.
* Certified Partners - partners that have certified their applications for OpenShift and have established a mutual support SLA with Red Hat, in order to provide you with the best experience.
* Community - a set of curated Operators built by the Kubernetes community and work well with the Operator Lifecycle Management software already installed on your cluster.

## Installing an Extension

Installing your first Operator is best done through the user interface, but can also be driven by the command line. Navigate to "Catalog", then "OperatorHub".

Search or browse to the Couchbase Operator, which is a powerful NoSQL database. The description lays out the notable features of the Operator. Go ahead and click "Install" to deploy the Operator on to the cluster.

### Installation Method

Operators can be installed for all Projects across the cluster or within specific namespaces. Not all Operators support each of these installation methods, but Couchbase does. Choose to install it for all Projects, so all users of the cluster can make Couchbase databases.

### Update Channel

Each Operator publisher can create channels for their software, to give adminsitrators more control over the versions that are installed. In this case, Couchbase only has a "preview" channel.

### Update Approval Strategy

In the future, when Couchbase releases a new version to the "preview" channel, the Operator Lifecycle Manager is able to execute a smooth rolling update of the Operator. As an admin, you have control over this process, and can indicate if you want to approve each update, or have it happen automatically. Choose "Automatic" for now.

After clicking "Subscribe", the Couchbase entry will show that it is "Installed" within the box.

## Using an Installed Operator

Now let's switch our persona into developer mode. Navigate to the "Developer Catalog" to check that the Operator installed successfully. After a minutes, the container image should be pulled and running.

Click on the Couchbase Cluster tile, which is a capability that the Operator has extended our cluster to support. Operators can expose more than one capability, such as the MongoDB Operator, which exposes three common configurations of it's database.

Deploy an instance of Couchbase by clicking the "Create" button in the top left. The YAML editor has been pre-filled with a set of minimal defaults for our instance.

Operators may require certain input from the developer, in this case a Secret containing the default set of credentials for the database. First, [follow the instructrions](https://docs.couchbase.com/operator/1.1/couchbase-cluster-config.html#authsecret) to generate a Secret or use the OpenShift UI to create a "key/value" Secret with both `username` and `password`. Here's an example secret with username `couchbase` and password `password`.

```
kind: Secret
apiVersion: v1
metadata:
  name: cb-example-auth
  namespace: default
data:
  password: cGFzc3dvcmQ=
  username: Y291Y2hiYXNl
type: Opaque
```

### Changing Couchbase Parameters

After your Secret is created, refer to it's name with the `authSecret` parameter:

```
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

Set the `replicas` field set to `3`, so our Operator sets up a highly available cluster for us.

Click "Create". Afterwards, you will be taken to a list of all Couchbase instances running with this Project.

### View the Deployed Resources

Navigate to the Couchbase Cluster that was deployed, and click on the "Resources" tab. This collects all of the objects deployed and managed by the Operator. From here you can view Pod logs to check on the Couchbase Cluster instances.

We are going to use the Service `<insert me>` to access the Couchbase dashboard. Use the OpenShift Console or the CLI to create a Route that points to this Service. Be aware that we are temporarily exposing this dashboard to the Internet for ease of use.

```
kind: Route
apiVersion: route.openshift.io/v1
metadata:
  name: couchbase-public
  namespace: default
  labels:
    <insert these>
spec:
  to:
    kind: Service
    name: <service-name>
    weight: 100
  port:
    targetPort: http
```

The Couchbase dashboard is now available at `couchbase-public-default.apps.<cluster-name>.<base-domain>`.

### Re-Configure the Cluster with the Operator

Keep the dashboard up as we re-configure the cluster. As the Operator scales up more Pods, they will automatically join and appear in the dashboard.

Edit your `cb-example` Couchbase instance to have `4` replicas instead of `3`. A few things will happen:

* The Operator will detect the difference between the desired state and the current state
* A new Pod will be created and show up under "Resources"
* The Couchbase dashboard will show 4 instances once the Pod is created

After the cluster is scaled up to `4`, try scaling back down to `3`. If you watch the dashboard closely, you will see that Couchbase as automatically triggered a re-balance of the data within the cluster to reflect the new topology of the cluster. This is one of many advanced feautres embedded within applications in OperatorHub to save you time when administering your workloads.

### Delete the Couchbase Instance

After you are done, delete the `cb-example` Couchbase instance and the Opeator will clean up all of the resources that were deployed. Remember to delete the Route that we manually created as well.

## Try Out More Operators

Operators are a powerful way for cluster administrators to extend the cluster, so that developers can build their apps and services in a self-service way. With the expertise baked into an Operator, running high quality, production instructure has never been easier.

OperatorHub will be continually updated with more great Operators from Red Hat, certified partners and the Kubernetes community.