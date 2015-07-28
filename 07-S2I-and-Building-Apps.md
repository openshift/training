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
- [S2I - What Is It?](#s2i---what-is-it)
  - [Create a New Project](#create-a-new-project)
  - [Switch Projects](#switch-projects)
  - [A Simple Code Example](#a-simple-code-example)
  - [CLI versus Console](#cli-versus-console)
  - [ImageStreams](#imagestreams)
  - [Adding Code Via the Web Console](#adding-code-via-the-web-console)
  - [The Web Console Revisited](#the-web-console-revisited)
  - [Examining the Build](#examining-the-build)
  - [Testing the Application](#testing-the-application)
  - [The Application Route](#the-application-route)
  - [Implications of Quota Enforcement](#implications-of-quota-enforcement)

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
that instead of setting the following up on the master.

Ensure that nfs-utils is installed (**on all systems**):

        yum install nfs-utils

Then, as `root` on the master:

1. Create the directory we will export:

        mkdir -p /var/export/regvol
        chown nfsnobody:nfsnobody /var/export/regvol
        chmod 700 /var/export/regvol

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
    --credentials=/etc/openshift/master/openshift-registry.kubeconfig \
    --images='registry.access.redhat.com/openshift3/ose-${component}:${version}'

You'll get output like:

    deploymentconfigs/docker-registry
    services/docker-registry

You can use `oc get pods`, `oc get services`, and `oc get deploymentconfig`
to see what happened. This would also be a good time to try out `oc status`
as root:

    oc status
    In project default
    
    service docker-registry (172.30.82.255:5000)
      docker-registry deploys registry.access.redhat.com/openshift3/ose-docker-registry:v0.6.1.0 
        #1 deployed 36 seconds ago - 1 pod
    
    service kubernetes (172.30.0.2:443)
    
    service kubernetes-ro (172.30.0.1:80)
    
    service router (172.30.136.52:80)
      router deploys registry.access.redhat.com/openshift3/ose-haproxy-router:v0.6.1.0 
        #1 deployed about an hour ago - 1 pod

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

    curl -v `oc get services | grep registry | awk '{print $4":"$5}/v2/' | sed 's,/[^/]\+$,/v2/,'`

And you should see an "UNAUTHORIZED" response. Your IP addresses will almost
certainly be different. The Docker registry expects us to authenticate, but we
don't do that with our request, hence the error. This at least means our
registry is up and running.

    * About to connect() to 172.30.82.255 port 5000 (#0)
    *   Trying 172.30.82.255...
    * Connected to 172.30.82.255 (172.30.82.255) port 5000 (#0)
    > GET /v2/ HTTP/1.1
    > User-Agent: curl/7.29.0
    > Host: 172.30.82.255:5000
    > Accept: */*
    > 
    < HTTP/1.1 401 Unauthorized
    < Content-Type: application/json; charset=utf-8
    < Docker-Distribution-Api-Version: registry/2.0
    < Www-Authenticate: Basic realm=openshift,error="authorization header with basic token required"
    < Date: Wed, 17 Jun 2015 20:04:23 GMT
    < Content-Length: 114
    < 
    {"errors":[{"code":"UNAUTHORIZED","message":"access to the requested resource is not authorized","detail":null}]}
    * Connection #0 to host 172.30.82.255 left intact

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
encapsulates the details of a particular volume which can be backed by any
of the [volume types available via
Kubernetes](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/docs/volumes.md).
In this case it will be our NFS volume.

Currently PersistentVolume objects must be created "by hand". Modify the
`content/registry-volume.json` file as needed if you are using a different
NFS mount:

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

    oc create -f registry-volume.json
    persistentvolumes/registry-volume

This defines a volume for OpenShift projects to use in deployments. The storage
should correspond to how much is actually available (make each volume a separate
filesystem or use native filesystem quotas if you want to enforce this limit).
Take a look at it now:

    Name:           registry-volume
    Labels:         <none>
    Status:         Available
    Claim:
    Reclaim Policy: %!d(api.PersistentVolumeReclaimPolicy=Retain)
    Message:        %!d(string=)

### Claim the PersistentVolume
Now that the administrator has provided a `PersistentVolume`, any project can
make a claim on that storage. We do this by creating a `PersistentVolumeClaim`
that specifies what kind of and how much storage is desired:

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
*default* project, we perform the following as the `root` system user:

    oc project default
    oc create -f registry-claim.json

You should see something like:

    persistentvolumeclaims/registry-claim

This claim will be bound to a suitable `PersistentVolume` (one that is big
enough and allows the requested `accessModes`). The user does not have any
real visibility into `PersistentVolumes`, including whether the backing
storage is NFS or something else. They simply know when their claim has
been filled ("bound" to a PersistentVolume).

    oc get pvc
    NAME             LABELS    STATUS    VOLUME
    registry-claim   map[]     Bound     registry-volume

If we now go back and look at our PV, we will also see that it has
been claimed:

    oc describe pv/registry-volume
    Name:           registry-volume
    Labels:         <none>
    Status:         Bound
    Claim:          default/registry-claim
    Reclaim Policy: %!d(api.PersistentVolumeReclaimPolicy=Retain)
    Message:        %!d(string=)

The `PersistentVolume` is now claimed and can't be claimed by any other project.

Although this flow assumes the administrator pre-creates volumes in
anticipation of their use later, it would be possible to create an external
process that watches the API for a `PersistentVolumeClaim` to be created,
dynamically provisions a corresponding volume, and creates the API object
to fulfill the claim.

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
    NAME              TRIGGERS       LATEST VERSION
    docker-registry   ConfigChange   2
    router            ConfigChange   1

We see that we are on version 2 of the docker-registry `DeploymentConfig`. Take
a look at the `ReplicationController`s:

    oc get rc
    CONTROLLER          CONTAINER(S)   IMAGE(S)                                                             SELECTOR                                                                                REPLICAS
    docker-registry-1   registry       registry.access.redhat.com/openshift3/ose-docker-registry:v3.0.0.1   deployment=docker-registry-1,deploymentconfig=docker-registry,docker-registry=default   0
    docker-registry-2   registry       registry.access.redhat.com/openshift3/ose-docker-registry:v3.0.0.1   deployment=docker-registry-2,deploymentconfig=docker-registry,docker-registry=default   1
    router-1            router         registry.access.redhat.com/openshift3/ose-haproxy-router:v3.0.0.1    deployment=router-1,deploymentconfig=router,router=router                               1

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

# S2I - What Is It?
S2I stands for *source-to-image* and is the process where OpenShift will take
your application source code and build a Docker image for it. In the real world,
you would need to have a code repository (where OpenShift can introspect an
appropriate Docker image to build and use to support the code) or a code
repository + a Dockerfile (so that OpenShift can pull or build the Docker image
for you).

## Create a New Project
By default, users are allowed to create their own projects. Let's try this now.
As the `joe` user, we will create a new project to put our first S2I example
into:

    oc new-project sinatra --display-name="Sinatra Example" \
    --description="This is your first build on OpenShift 3" 

Logged in as `joe` in the web console, if you click the OpenShift image you
should be returned to the project overview page where you will see the new
project show up. Go ahead and click the *Sinatra* project - you'll see why soon.

## Switch Projects
As the `joe` user, let's switch to the `sinatra` project:

    oc project sinatra

You should see:

    Now using project "sinatra" on server "https://ose3-master.example.com:8443".

## A Simple Code Example
We'll be using a pre-build/configured code repository. This repository is an
extremely simple "Hello World" type application that looks very much like our
previous example, except that it uses a Ruby/Sinatra application instead of a Go
application.

For this example, we will be using the following application's source code:

    https://github.com/openshift/simple-openshift-sinatra-sti

Let's see some JSON:

    oc new-app -o json https://github.com/openshift/simple-openshift-sinatra-sti.git

Take a look at the JSON that was generated. You will see some familiar items at
this point, and some new ones, like `BuildConfig`, `ImageStream` and others.

Essentially, the S2I process is as follows:

1. OpenShift sets up various components such that it can build source code into
a Docker image.

1. OpenShift will then build the Docker image with the source code.

1. OpenShift will then deploy the built Docker image as a `Pod` with an associated
`Service`.

## CLI versus Console
There are currently two ways to get from source code to components on OpenShift.
The CLI has a tool (`new-app`) that can take a source code repository as an
input and will make its best guesses to configure OpenShift to do what we need
to build and run the code. You looked at that already.

You can also just run `oc new-app --help` to see other things that `new-app`
can help you achieve.

The web console also lets you point directly at a source code repository, but
requires a little bit more input from a user to get things running. Let's go
through an example of pointing to code via the web console. Later examples will
use the CLI tools.

## ImageStreams
If you think about one of the important things that OpenShift needs to do, it's
to be able to deploy newer versions of user applications into Docker containers
quickly. But an "application" is really two pieces -- the starting image (the
S2I builder) and the application code. While it's "obvious" that we need to
update the deployed Docker containers when application code changes, it may not
have been so obvious that we also need to update the deployed container if the
**builder** image changes.

For example, what if a security vulnerability in the Ruby runtime is discovered?
It would be nice if we could automatically know this and take action. If you dig
around in the JSON output above from `new-app` you will see some reference to
"triggers". This is where `ImageStream`s come together.

The `ImageStream` resource is, somewhat unsurprisingly, a definition for a
stream of Docker images that might need to be paid attention to. By defining an
`ImageStream` on "ruby-20-rhel7", for example, and then building an application
against it, we have the ability with OpenShift to "know" when that `ImageStream`
changes and take action based on that change. In our example from the previous
paragraph, if the "ruby-20-rhel7" image changed in the Docker repository defined
by the `ImageStream`, we might automatically trigger a new build of our
application code.

An organization will likely choose several supported builders and databases from
Red Hat, but may also create their own builders, DBs, and other images. This
system provides a great deal of flexibility.

The installer pre-populated several `ImageStream`s for you when it was run. As
`root`:

    oc get is -n openshift
    NAME                                 DOCKER REPO                                                      TAGS                   UPDATED
    jboss-amq-6                          registry.access.redhat.com/jboss-amq-6/amq-openshift             6.2,6.2-84,latest      5 days ago
    jboss-eap6-openshift                 registry.access.redhat.com/jboss-eap-6/eap-openshift             6.4,6.4-207,latest     5 days ago
    jboss-webserver3-tomcat7-openshift   registry.access.redhat.com/jboss-webserver-3/tomcat7-openshift   3.0,3.0-135,latest     5 days ago
    jboss-webserver3-tomcat8-openshift   registry.access.redhat.com/jboss-webserver-3/tomcat8-openshift   3.0,3.0-137,latest     5 days ago
    mongodb                              registry.access.redhat.com/openshift3/mongodb-24-rhel7           2.4,latest,v3.0.0.0    5 days ago
    mysql                                registry.access.redhat.com/openshift3/mysql-55-rhel7             5.5,latest,v3.0.0.0    5 days ago
    nodejs                               registry.access.redhat.com/openshift3/nodejs-010-rhel7           0.10,latest,v3.0.0.0   5 days ago
    perl                                 registry.access.redhat.com/openshift3/perl-516-rhel7             5.16,latest,v3.0.0.0   5 days ago
    php                                  registry.access.redhat.com/openshift3/php-55-rhel7               5.5,latest,v3.0.0.0    5 days ago
    postgresql                           registry.access.redhat.com/openshift3/postgresql-92-rhel7        9.2,latest,v3.0.0.0    5 days ago
    python                               registry.access.redhat.com/openshift3/python-33-rhel7            3.3,latest,v3.0.0.0    5 days ago
    ruby                                 registry.access.redhat.com/openshift3/ruby-20-rhel7              2.0,latest,v3.0.0.0    5 days ago

The *openshift* project is another special one. Certain things placed here are
accessible to all users, but may only be modified/manipulated by cluster
administrators.

## Adding Code Via the Web Console
If you go to the web console and then select the "Sinatra Example" project,
you'll see a "Create +" button in the upper right hand corner. Click that
button, and you will see two options. The second option is to create an
application from a template. We will explore that later.

The first option you see is a text area where you can type a URL for source
code. We are going to use the Git repository for the Sinatra application
referenced earlier. Enter this repo in the box:

    https://github.com/openshift/simple-openshift-sinatra-sti

When you hit "Next" you will then be asked which builder image you want to use.
This application uses the Ruby language, so make sure to click `ruby:2.0`.
You'll see a pop-up with some more details asking for confirmation. Click
"Select image..."

The next screen you see lets you begin to customize the information a little
bit. The only default setting we have to change is the name, because it is too
long. Enter something sensible like "*ruby-example*", then scroll to the bottom
and click "Create".

At this point, OpenShift has created several things for you. Use the "Browse"
tab to poke around and find them. You can also use `oc status` as the `joe`
user, too.

If you quickly run (as `joe`):

    oc get pods

You will see that there are currently no pods. That is because we have not
actually gone through a build yet. We told OpenShift about what we wanted to do,
but it takes a little time to think about what should happen. In less than 90
seconds, OpenShift will determine that we wanted an image to be deployed that
was based on a build, but no build had yet happened, so a build should be
started. Be patient. Eventually the web UI will indicate that a build is
running:

     A build of ruby-example is running. A new deployment will be created
     automatically once the build completes.

We can also check on the status of a build (it will switch to "Running" in a few
moments):

    oc get builds
    NAME             TYPE      STATUS     POD
    ruby-example-1   Source    Running   ruby-example-1

Let's go ahead and start "tailing" the build log (substitute the proper UUID for
your environment):

    oc build-logs ruby-example-1

**Note: If the build isn't "Running" yet, or the sti-build container hasn't been
deployed yet, build-logs will give you an error. Just wait a few moments and
retry it.**

## The Web Console Revisited
If you poked around in the web console while the build was running, you probably
noticed a lot of new information - the build status, the deployment status, new
pods, and more.

If you didn't, wait for the build to finish and then go to the web console. The
overview page should show that the application is running and show the
information about the service and route at the top:

    SERVICE: RUBY-EXAMPLE routing traffic on 172.30.78.56 – port 8080 → 8080 (TCP)
    ruby-example.sinatra.cloudapps.example.com

## Examining the Build
If you go back to your console session where you examined the `build-logs`,
you'll see a number of things happened.

What were they?

## Testing the Application
Using the information you found in the web console, try to see if your service
is working (as the `joe` user):

    curl `oc get service | grep example | awk '{print $4":"$5}' | sed -e 's/\/.*//'`
    Hello, Sinatra!

So, from a simple code repository with a few lines of Ruby, we have successfully
built a Docker image and OpenShift has deployed it for us. It also did one other
thing for us -- it made our application externally accessible.

## The Application Route
Remember that routes are associated with services. Let's look at the list of
routes as `joe`:

    oc get route
    NAME           HOST/PORT                                    PATH      SERVICE        LABELS
    ruby-example   ruby-example.sinatra.cloudapps.example.com             ruby-example   generatedby=OpenShiftWebConsole,name=ruby-example

We can see that OpenShift created a route for us, named *ruby-example* (which
matches the name we provided during the creation process), and it created a host
mapping with a specific format:

    ruby-example.sinatra.cloudapps.example.com

That format is:

    <service_name>.<project_name>.<routing_subdomain>

That's the default behavior. You can always edit this later.

At this point, you should be able to verify everything is working right:

    curl http://ruby-example.sinatra.cloudapps.example.com
    Hello, Sinatra!

If you want to be fancy, try it in your browser!

**Note:** HTTPS will *not* work for this route, because we have not specified
any TLS termination.

## Implications of Quota Enforcement
Quotas have implications one may not immediately realize. As `root` assign a
quota and resource limits to the `sinatra` project.

    oc create -f quota.json -n sinatra
    oc create -f limits.json -n sinatra

**Perform the following as `joe`**
As `joe` scale your application up to three instances using the `oc scale`
command:

    oc scale --replicas=3 rc/ruby-example-1

You'll just see:

    scaled

Wait a few seconds and you should see your application scaled up to 3 pods.

    oc get pod
    NAME                   READY     REASON       RESTARTS   AGE
    ruby-example-1-build   0/1       ExitCode:0   0          19m
    ruby-example-1-kqkxr   1/1       Running      0          15s
    ruby-example-1-mqooa   1/1       Running      0          17m
    ruby-example-1-yhjl3   1/1       Running      0          15s

You will see that your build pod is still hanging around, but exited. We are
currently doing this for logging purposes. While there is some log aggregation
happening under the covers (with fluentd), it is not really accessible to a
normal user. The `oc build-logs` command essentially is looking at the Docker
container logs under the covers. If we delete this pod, the build logs are lost.

Also, do the following:

    oc get pod -t '{{range .items}}{{.metadata.name}} {{.spec.host}}{{"\n"}}{{end}}' | grep -v build

And you will see that our pods were equally distributed due to our scheduler
configuration:

    ruby-example-1-kqkxr ose3-node1.example.com
    ruby-example-1-mqooa ose3-node2.example.com
    ruby-example-1-yhjl3 ose3-node2.example.com

*Note:* Your names are probably a little different.

Now start another build, wait a moment or two for your build to start.

    oc start-build ruby-example

    oc get builds
    NAME             TYPE      STATUS     POD
    ruby-example-1   Source    Complete   ruby-example-1
    ruby-example-2   Source    New        ruby-example-2

The build never starts. What happened? The quota limits the number of pods in
this project to three and this includes ephemeral pods like S2I builders. To see
what this looks like, check out the `oc describe` output:

    oc describe build ruby-example-2
    ...
    Tue, 28 Jul 2015 11:04:27 -0400       Tue, 28 Jul 2015 11:04:27 -0400 1       {build-controller }                     failedCreate    Error creating: Pod "ruby-example-2-build" is forbidden: Limited to 3 pods

Resize your application to just one replica and your new build will
automatically start after a minute or two.

**Note:** Once the build is complete a new replication controller is
created and the old one is no longer used.
