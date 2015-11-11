<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Preparing for S2I: the Registry](#preparing-for-s2i-the-registry)
  - [Storage for the registry](#storage-for-the-registry)
    - [Export an NFS Volume](#export-an-nfs-volume)
    - [NFS Firewall](#nfs-firewall)
    - [Allow NFS Access in SELinux Policy](#allow-nfs-access-in-selinux-policy)
  - [Creating the registry](#creating-the-registry)
  - [Attaching Registry Storage](#attaching-registry-storage)
    - [Create a PersistentVolume](#create-a-persistentvolume)
    - [Claim the PersistentVolume](#claim-the-persistentvolume)
    - [Attach the Volume to the Registry](#attach-the-volume-to-the-registry)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Preparing for S2I: the Registry
One of the really interesting things about OpenShift v3 is that it will build
Docker images from your source code, deploy them, and manage their lifecycle.
OpenShift 3 will provide a Docker registry that administrators may run inside
the OpenShift environment that will manage images "locally". Let's take a moment
to set that up.

## Storage for the registry
The registry stores Docker images and metadata. If you simply deploy a pod
with the registry, it will use an ephemeral volume that is destroyed once the
pod exits. Any images anyone has built or pushed into the registry would
disappear. That would be bad.

OpenShift provides a convenient system for mounting external storage to enable
data persistence. It involves a system of `PersistentVolume` objects, and claims
on those volumes, called `PersistentVolumeClaims`. First, we will prepare our
master to provide NFS storage.

### Export an NFS Volume
For the purposes of this training, we will just demonstrate the master
exporting an NFS volume for use as storage by the database. **You would
almost certainly not want to do this in production.** If you happen
to have another host with an NFS export handy, feel free to substitute
that instead of setting the following up on the master, and skip the remainder
of the setup steps.

Ensure that nfs-utils is installed (**on all systems**):

        yum install nfs-utils

Then, as `root` on the master:

1. Create the directory we will export:

        mkdir -p /var/export/regvol
        chown nfsnobody:nfsnobody /var/export/regvol
        chmod 777 /var/export/regvol

1. Edit `/etc/exports` and add the following line:

        /var/export/regvol *(rw,sync,all_squash)

1. Enable and start NFS services:

        systemctl enable rpcbind nfs-server
        systemctl start rpcbind nfs-server nfs-lock 
        systemctl start nfs-idmap

Note that the volume is owned by `nfsnobody` and access by all remote users
is "squashed" to be access by this user. This essentially disables user
permissions for clients mounting the volume. While another configuration
might be preferable, one problem you may run into is that the container
cannot modify the permissions of the actual volume directory when mounted.

### NFS Firewall
We will need to open ports on the firewall on the master to enable the nodes to
communicate with us over NFS. First, let's add rules for NFS to the running
state of the firewall.

On the master as `root`:

    iptables -I OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 111 -j ACCEPT
    iptables -I OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 2049 -j ACCEPT
    iptables -I OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 20048 -j ACCEPT
    iptables -I OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 50825 -j ACCEPT
    iptables -I OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 53248 -j ACCEPT

Next, let's add the rules to `/etc/sysconfig/iptables`. Put them at the top of
the `OS_FIREWALL_ALLOW` set:

    -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 53248 -j ACCEPT
    -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 50825 -j ACCEPT
    -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 20048 -j ACCEPT
    -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 2049 -j ACCEPT
    -A OS_FIREWALL_ALLOW -p tcp -m state --state NEW -m tcp --dport 111 -j ACCEPT

Now, we have to edit NFS' configuration to use these ports. First, let's edit
`/etc/sysconfig/nfs`. Change the RPC option to the following:

    RPCMOUNTDOPTS="-p 20048"

Change the STATD option to the following:

    STATDARG="-p 50825"

Then, edit `/etc/sysctl.conf`:

    fs.nfs.nlm_tcpport=53248
    fs.nfs.nlm_udpport=53248

Then, persist the `sysctl` changes:

    sysctl -p

Lastly, restart NFS:

    systemctl restart nfs

### Allow NFS Access in SELinux Policy
By default policy, containers are not allowed to write to NFS mounted
directories.  We want to do just that with our database, so enable that on
all nodes where the pod could land (i.e. all of them) with:

    setsebool -P virt_use_nfs=true

*Note:* This command may take a while to return. Be patient.

## Creating the registry

`oadm` again comes to our rescue with a handy installer for the
registry. As the `root` user, run the following:

    oadm registry --create \
    --credentials=/etc/origin/master/openshift-registry.kubeconfig 

You'll get output like:

    DeploymentConfig "docker-registry" created
    Service "docker-registry" created

You can use `oc get pods`, `oc get services`, and `oc get deploymentconfig`
to see what happened. This would also be a good time to try out `oc status`
as root:

    oc status
    In project default on server https://ose3-master.example.com:8443
    
    svc/docker-registry - 172.30.20.139:5000
      dc/docker-registry deploys registry.access.redhat.com/openshift3/ose-docker-registry:v3.1.0.2 
        #1 deployed 53 seconds ago - 1 pod
    
    svc/kubernetes - 172.30.0.1 ports 443, 53, 53
    
    svc/router - 172.30.175.206:80
      dc/router deploys registry.access.redhat.com/openshift3/ose-haproxy-router:v3.1.0.2 
        #1 deployed 25 minutes ago - 1 pod
    
    To see more, use 'oc describe <resource>/<name>'.
    You can use 'oc get all' to see a list of other objects.

To see more information about a `Service` or `DeploymentConfig`, use `oc
describe service <name>` or `oc describe dc <name>`.  You can use `oc get all`
to see lists of each of the types described above.

The project we have been working in when using the `root` user is called
"default". This is a special project that always exists (you can delete it, but
OpenShift will re-create it) and that the cluster admin user uses automatically.
One interesting feature of `oc status` is that it lists recent deployments.
When we created the router and registry, each created one deployment. We will
talk more about deployments when we get into builds.

Anyway, you will ultimately have a Docker registry that is being hosted by OpenShift
and that is running on the master (because we edited the default project to use
this region).

To quickly test your Docker registry, you can do the following:

    curl -v $(oc get service docker-registry --template '{{.spec.portalIP}}:{{index .spec.ports 0 "port"}}/healthz')

You'll see something like the following:

    * About to connect() to 172.30.20.139 port 5000 (#0)
    *   Trying 172.30.20.139...
    * Connected to 172.30.20.139 (172.30.20.139) port 5000 (#0)
    > GET /healthz HTTP/1.1
    > User-Agent: curl/7.29.0
    > Host: 172.30.20.139:5000
    > Accept: */*
    > 
    < HTTP/1.1 200 OK
    < Content-Type: application/json; charset=utf-8
    < Docker-Distribution-Api-Version: registry/2.0
    < Date: Wed, 11 Nov 2015 00:50:30 GMT
    < Content-Length: 3
    < 
    {}
    * Connection #0 to host 172.30.20.139 left intact

If you get "connection reset by peer" you may have to wait a few more moments
after the pod is running for the service proxy to update the endpoints necessary
to fulfill your request. You can check if your service has finished updating its
endpoints with:

    oc describe service docker-registry

And you will eventually see something like:

    Name:                   docker-registry
    Labels:                 docker-registry=default
    Selector:               docker-registry=default
    Type:                   ClusterIP
    IP:                     172.30.239.41
    Port:                   <unnamed>       5000/TCP
    Endpoints:              <unnamed>       10.1.0.4:5000
    Session Affinity:       None
    No events.

Once there is an endpoint listed, the curl should work and the registry is
available. **BUT** we still do not have any storage attached.

## Attaching Registry Storage
We've gone through the work of preparing to use external storage, and now we
will actually attach some to our registry.

### Create a PersistentVolume
It is the PaaS administrator's responsibility to define the storage that is
available to users. Storage is represented by a `PersistentVolume` that
encapsulates the details of a particular volume which can be backed by any of
the [supported volume
types](https://docs.openshift.com/enterprise/latest/architecture/additional_concepts/storage.html#types-of-persistent-volumes).

In our case it will be our NFS volume.

Currently PersistentVolume objects must be created "by hand". As `root`, modify
the `~/training/content/registry-volume.json` file as needed if you are using a
different NFS mount:

    {
      "apiVersion": "v1",
      "kind": "PersistentVolume",
      "metadata": {
        "name": "registry-volume"
      },
      "spec": {
        "capacity": {
            "storage": "3Gi"
            },
        "accessModes": [ "ReadWriteMany" ],
        "nfs": {
            "path": "/var/export/regvol",
            "server": "ose3-master.example.com"
        }
      }
    }

Currently, we have no `PersistentVolume`s defined:

    oc get pv
    NAME      LABELS    CAPACITY   ACCESSMODES   STATUS    CLAIM     REASON

Create the `PersistentVolume` as the `root` (administrative) user:

    oc create -f ~/training/content/registry-volume.json
    persistentvolume "registry-volume" created

This defines a volume for OpenShift projects to use in deployments. The storage
should correspond to how much is actually available (make each volume a separate
filesystem).

Take a look at it now:

    oc describe pv/registry-volume                                          
    
    Name:           registry-volume
    Labels:         <none>
    Status:         Bound
    Claim:          default/registry-claim
    Reclaim Policy: Retain
    Access Modes:   RWX
    Capacity:       3Gi
    Message:
    Source:
        Type:       NFS (an NFS mount that lasts the lifetime of a pod)
        Server:     ose3-master.example.com
        Path:       /var/export/regvol
        ReadOnly:   false

### Claim the PersistentVolume
Users "receive" volumes by making claims. Claims are handed out on a
first-come-first-served basis. Now that the administrator has provided a
`PersistentVolume`, any project can make a claim on that storage. We do this by
creating a `PersistentVolumeClaim` that specifies what kind of and how much
storage is desired:

    {
      "apiVersion": "v1",
      "kind": "PersistentVolumeClaim",
      "metadata": {
        "name": "registry-claim"
      },
      "spec": {
        "accessModes": [ "ReadWriteMany" ],
        "resources": {
          "requests": {
            "storage": "3Gi"
          }
        }
      }
    }

Since we want this volume for the registry, and the registry lives in the
*default* project, we perform the following as the `root` system user in the
*default* project:

    oc project default # switch to the default project
    oc create -f ~/training/content/registry-claim.json

You should see something like:

    persistentvolumeclaim "registry-claim" created

This claim will be bound to a suitable `PersistentVolume` (one that is big
enough and allows the requested `accessModes`). The user does not have any
real visibility into `PersistentVolumes`, including whether the backing
storage is NFS or something else. They simply know when their claim has
been filled ("bound" to a PersistentVolume).

    oc get pvc
    NAME             LABELS    STATUS    VOLUME            CAPACITY   ACCESSMODES   AGE
    registry-claim   <none>    Bound     registry-volume   3Gi        RWX           11s

If we now go back and look at our PV, we will also see that it has
been claimed:

    ...
    Claim:          default/registry-claim
    ...

The `PersistentVolume` is now claimed and can't be claimed by any other project.

Although this flow assumes the administrator pre-creates volumes in
anticipation of their use later, it would be possible to create an external
process that watches the API for a `PersistentVolumeClaim` to be created,
dynamically provisions a corresponding volume, and creates the API object
to fulfill the claim.

Some of the storage plugins in OpenShift 3.1 also support dynamic provisioning.
In addition, other storage vendors are working with Red Hat to enable dynamic
provisioning. Stay tuned!

### Attach the Volume to the Registry
Now that the *default* project has a claim on a volume, we can attach it to the
registry. Fortunately, we are provided with a handy tool, `oc volume`, to do
much of the heavy lifting for us. 

Take a quick look at the `DeploymentConfig` for the registry:

    oc get dc docker-registry -o yaml
    ...
        volumeMounts:
        - mountPath: /registry
          name: registry-storage
      dnsPolicy: ClusterFirst
      restartPolicy: Always
      volumes:
      - emptyDir: {}
        name: registry-storage

You can see that the registry is already more or less configured to be ready to
use a volume. We're just going to go through and finish the job.

Do the following as `root`:

    oc volume dc/docker-registry --add --overwrite -t persistentVolumeClaim \
    --claim-name=registry-claim --name=registry-storage

Let's analyze what this command is about to do:

* add a volume
* overwrite any existing volume that matches
* use a `persistentVolumeClaim` named *registry-claim*
* give the volume the name *registry-storage*

Since the registry's `DeploymentConfig` already had a volume with the name
*registry-storage*, we're just going to overwrite that one, and we will end up
switching from `emptyDir` to something else. The registry already had a volume
mount set up to use the *registry-storage* volume and mount it to `/registry`.

When you execute the above `oc volume` command, you'll see the following:

    deploymentconfigs/docker-registry

Now, go ahead and look at the `DeploymentConfig`s:

    oc get dc
    NAME              TRIGGERS       LATEST
    docker-registry   ConfigChange   2
    router            ConfigChange   1

We see that we are on version 2 of the docker-registry `DeploymentConfig`. Take
a look at the `ReplicationController`s:

    oc get rc
    CONTROLLER          CONTAINER(S)   IMAGE(S)                                  SELECTOR                                                                                REPLICAS   AGE
    docker-registry-1   registry       openshift3/ose-docker-registry:v3.1.0.2   deployment=docker-registry-1,deploymentconfig=docker-registry,docker-registry=default   0          14m
    docker-registry-2   registry       openshift3/ose-docker-registry:v3.1.0.2   deployment=docker-registry-2,deploymentconfig=docker-registry,docker-registry=default   1          40s
    router-1            router         openshift3/ose-haproxy-router:v3.1.0.2    deployment=router-1,deploymentconfig=router,router=router    

We see that there is a *docker-registry-2* `ReplicationController` with 1
replica. Now let's look at the pods:

    oc get pod
    NAME                      READY     REASON    RESTARTS   AGE
    docker-registry-2-kqrnj   1/1       Running   0          11m
    router-1-leu8v            1/1       Running   1          5d

And we see that there is a pod that starts with *docker-registry-2*.

When we changed the `DeploymentConfig` for the registry, this caused a new
deployment, which we can see in the naming convention. We'll talk much more
about this process later. Suffice it to say that, now, we have a registry
running with a persistent storage mount. Highly available, actually. You should
be able to delete the registry pod at any point in this training and have it
return shortly after with all data intact.

You can find out more about this storage system of OpenShift here:

    https://docs.openshift.org/latest/architecture/additional_concepts/storage.html

We will revisit storage for user applications again later.
