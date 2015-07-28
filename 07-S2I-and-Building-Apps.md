<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Preparing for S2I: the Registry](#preparing-for-s2i-the-registry)
  - [Storage for the registry](#storage-for-the-registry)
  - [Service Account for the Registry](#service-account-for-the-registry)
  - [Creating the registry](#creating-the-registry)
- [S2I - What Is It?](#s2i---what-is-it)
  - [Create a New Project](#create-a-new-project)
  - [Switch Projects](#switch-projects)
  - [A Simple Code Example](#a-simple-code-example)
  - [CLI versus Console](#cli-versus-console)
  - [Adding the Builder ImageStreams](#adding-the-builder-imagestreams)
  - [Wait, What's an ImageStream?](#wait-whats-an-imagestream)
  - [Adding Code Via the Web Console](#adding-code-via-the-web-console)
  - [The Web Console Revisited](#the-web-console-revisited)
  - [Examining the Build](#examining-the-build)
  - [Testing the Application](#testing-the-application)
  - [Adding a Route to Our Application](#adding-a-route-to-our-application)
  - [Implications of Quota Enforcement on Scaling](#implications-of-quota-enforcement-on-scaling)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Preparing for S2I: the Registry
One of the really interesting things about OpenShift v3 is that it will build
Docker images from your source code, deploy them, and manage their lifecycle.
OpenShift 3 will provide a Docker registry that administrators may run inside
the OpenShift environment that will manage images "locally". Let's take a moment
to set that up.

## Storage for the registry
The registry stores docker images and metadata. If you simply deploy a pod
with the registry, it will use an ephemeral volume that is destroyed once the
pod exits. Any images anyone has built or pushed into the registry would
disappear. That would be bad.

What we will do for this demo is use a directory on the master host for
persistent storage. In production, you would actually want to use OpenShift's
system for creating and managing persistent volumes. We will use that system
later in these examples.

The following instructions are not to be considered production-usable. They're
barely supportable. Please don't do this "in the real world".

On the master, as `root`, create the storage directory with:

    mkdir -p /mnt/registry

## Service Account for the Registry
The topic of service accounts will also be addressed later. For now, just copy
and paste, please.

Again, as `root`:

    echo '{"kind":"ServiceAccount","apiVersion":"v1","metadata":{"name":"registry"}}' \
    | oc create -f -

Now we need to give the service account for the registry special permission to
host-mount the folder. Run the following:

    oc edit scc privileged

This will bring up your default text editor (likely `vim`). Find the section
that looks like:

    users:
    - system:serviceaccount:openshift-infra:build-controller

Make it look like:

    users:
    - system:serviceaccount:openshift-infra:build-controller
    - system:serviceaccount:default:registry

Save and exit.

## Creating the registry

`oadm` again comes to our rescue with a handy installer for the
registry. As the `root` user, run the following:

    oadm registry --create \
    --credentials=/etc/openshift/master/openshift-registry.kubeconfig \
    --images='registry.access.redhat.com/openshift3/ose-${component}:${version}' \
    --selector="region=infra" --mount-host=/mnt/registry \
    --service-account=registry

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

To see more information about a Service or DeploymentConfig, use 'oc describe service <name>' or 'oc describe dc <name>'.
You can use 'oc get all' to see lists of each of the types described above.

The project we have been working in when using the `root` user is called
"default". This is a special project that always exists (you can delete it, but
OpenShift will re-create it) and that the administrative user uses by default.
One interesting features of `oc status` is that it lists recent deployments.
When we created the router and registry, each created one deployment. We will
talk more about deployments when we get into builds.

Anyway, you will ultimately have a Docker registry that is being hosted by OpenShift
and that is running on the master (because we specified "region=infra" as the
registry's node selector).

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

Once there is an endpoint listed, the curl should work and the registry is available.

Highly available, actually. You should be able to delete the registry pod at any
point in this training and have it return shortly after with all data intact.

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

1. OpenShift will then (on command) build the Docker image with the source code.

1. OpenShift will then deploy the built Docker image as a Pod with an associated
Service.

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

## Adding the Builder ImageStreams
While `new-app` has some built-in logic to help automatically determine the
correct builder ImageStream, the web console currently does not have that
capability. The user will have to first target the code repository, and then
select the appropriate builder image.

Perform the following command as `root` in the `beta4`folder in order to add all
of the builder images:

    oc create -f image-streams-rhel7.json -f jboss-image-streams.json \
    -n openshift

You will see the following:

    imageStreams/ruby
    imageStreams/nodejs
    imageStreams/perl
    imageStreams/php
    imageStreams/python
    imageStreams/mysql
    imageStreams/postgresql
    imageStreams/mongodb
    imageStreams/jboss-webserver3-tomcat7-openshift
    imageStreams/jboss-webserver3-tomcat8-openshift
    imageStreams/jboss-eap6-openshift
    imageStreams/jboss-amq-62
    imageStreams/jboss-mysql-55
    imageStreams/jboss-postgresql-92
    imageStreams/jboss-mongodb-24

What is the `openshift` project where we added these builders? This is a
special project that can contain various elements that should be available to
all users of the OpenShift environment.

## Wait, What's an ImageStream?
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

Feel free to look around `image-streams.json` for more details.  As you can see,
we have provided definitions for EAP and Tomcat builders as well as other DBs
and etc. Please feel free to experiment with these - we will attempt to provide
sample apps as time progresses.

When finished, let's go move over to the web console to create our
"application".

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
This application uses the Ruby language, so make sure to click
`ruby:latest`. You'll see a pop-up with some more details asking for
confirmation. Click "Select image..."

The next screen you see lets you begin to customize the information a little
bit. The only default setting we have to change is the name, because it is too
long. Enter something sensible like "*ruby-example*", then scroll to the bottom
and click "Create".

At this point, OpenShift has created several things for you. Use the "Browse"
tab to poke around and find them. You can also use `oc status` as the `joe`
user, too.

If you run (as `joe`):

    oc get pods

You will see that there are currently no pods. That is because we have not
actually gone through a build yet. While OpenShift has the capability of
automatically triggering builds based on source control pushes (eg: Git(hub)
webhooks, etc), we will have to trigger our build manually in this example.

By the way, most of these things can (SHOULD!) also be verified in the web
console. If anything, it looks prettier!

To start our build, as `joe`, execute the following:

    oc start-build ruby-example

You'll see some output to indicate the build:

    ruby-example-1

We can check on the status of a build (it will switch to "Running" in a few
moments):

    oc get builds
    NAME             TYPE      STATUS     POD
    ruby-example-1   Source    Running   ruby-example-1

The web console would've updated the *Overview* tab for the *Sinatra* project to
say:

    A build of ruby-example is running. A new deployment will be
    created automatically once the build completes.

Let's go ahead and start "tailing" the build log (substitute the proper UUID for
your environment):

    oc build-logs ruby-example-1

**Note: If the build isn't "Running" yet, or the sti-build container hasn't been
deployed yet, build-logs will give you an error. Just wait a few moments and
retry it.**

## The Web Console Revisited
If you peeked at the web console while the build was running, you probably
noticed a lot of new information in the web console - the build status, the
deployment status, new pods, and more.

If you didn't, go to the web console now. The overview page should show that the
application is running and show the information about the service at the top:

    SERVICE: RUBY-EXAMPLE routing traffic on 172.30.17.20 port 8080 - 8080 (tcp)

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
built a Docker image and OpenShift has deployed it for us.

The last step will be to add a route to make it publicly accessible. You might
have noticed that adding the application code via the web console resulted in a
route being created. Currently that route doesn't have a corresponding DNS
entry, so it is unusable. The default domain is also not currently configurable,
so it's not very useful at the moment.

## Adding a Route to Our Application
Remember that routes are associated with services, so, determine the id of your
services from the service output you looked at above.

**Hint:** You will need to use `oc get services` to find it.

**Hint:** Do this as `joe`.

**Hint:** It is `ruby-example`.

When you are done, create your route:

    oc create -f sinatra-route.json

Check to make sure it was created:

    oc get route
    NAME                 HOST/PORT                                   PATH      SERVICE        LABELS
    ruby-example         ruby-example.sinatra.router.default.local             ruby-example   generatedby=OpenShiftWebConsole,name=ruby-example
    ruby-example-route   hello-sinatra.cloudapps.example.com                   ruby-example

And now, you should be able to verify everything is working right:

    curl http://hello-sinatra.cloudapps.example.com
    Hello, Sinatra!

If you want to be fancy, try it in your browser!

You'll note above that there is a route involving "router.default.local". If you
remember, when creating the application from the web console, there was a
section for "route". In the future the router will provide more configuration
options for default domains and etc. Currently, the "default" domain for
applications is "router.default.local", which is most likely unusable in your
environment.

**Note:** HTTPS will *not* work for this route, because we have not specified
any TLS termination.

## Implications of Quota Enforcement on Scaling
**THIS SECTION IS BROKEN**

There is currently a bug with quota enforcement. Do **NOT** apply the quota to
this project. Skip ahead to the scaling part.

    https://github.com/openshift/origin/issues/2821

** SKIP THIS**

`*
Quotas have implications one may not immediately realize. As `root` assign a
quota to the `sinatra` project.

    oc create -f quota.json -n sinatra

There is currently no default "size" for applications that are created with the
web console. This means that, whether you think it's a good idea or not, the
application is actually unbounded -- it can consume as much of a node's
resources as it wants.

Before we can try to scale our application, we'll need to update the deployment
to put a memory and CPU limit on the pods. Go ahead and edit the
`deploymentConfig`, as `joe`:

    oc edit dc/ruby-example-1 -o json

You'll need to find "spec", "containers" and then the "resources" block in
there. It's after a bunch of `env`ironment variables. Update that "resources"
block to look like this:

        "resources": {
          "limits": {
            "cpu": "10m",
            "memory": "16Mi"
          }
        },

`*

As `joe` scale your application up to three instances using the `oc resize`
command:

    oc resize --replicas=3 rc/ruby-example-1

Wait a few seconds and you should see your application scaled up to 3 pods.

    oc get pods | grep -v "example"
    POD                    IP          CONTAINER(S) ... STATUS  CREATED
    ruby-example-3-6n19x   10.1.0.27   ruby-example ... Running 2 minutes
    ruby-example-3-pfga3   10.1.0.26   ruby-example ... Running 18 minutes
    ruby-example-3-tzt0z   10.1.0.28   ruby-example ... Running About a minute

You will also notice that these pods were distributed across our two nodes
"east" and "west". You can also see this in the web console. Cool!

**SKIP THIS**

*`
Now start another build, wait a moment or two for your build to start.

    oc start-build ruby-example

    oc get builds
    NAME             TYPE      STATUS     POD
    ruby-example-1   Source    Complete   ruby-example-1
    ruby-example-2   Source    New        ruby-example-2

The build never starts, what happened? The quota limits the number of pods in
this project to three and this includes ephemeral pods like S2I builders.
Resize your application to just one replica and your new build will
automatically start after a minute or two.

**Note:** Once the build is complete a new replication controller is
created and the old one is no longer used.
`*


