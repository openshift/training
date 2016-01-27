<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [S2I - What Is It?](#s2i---what-is-it)
  - [Create a New Project](#create-a-new-project)
  - [A Simple Code Example](#a-simple-code-example)
  - [CLI versus Console](#cli-versus-console)
  - [ImageStreams](#imagestreams)
  - [Adding Code Via the Web Console](#adding-code-via-the-web-console)
  - [Images and ImageStreams](#images-and-imagestreams)
  - [Testing the Application](#testing-the-application)
  - [The Application Route](#the-application-route)
  - [Implications of Quota Enforcement](#implications-of-quota-enforcement)
  - [Registry Storage Revisited](#registry-storage-revisited)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

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

Logged in as `joe` in the web console, if you click the OpenShift logo you
should be returned to the project overview page where you will see the new
project show up. Go ahead and click the *Sinatra* project - you'll see why soon.

## A Simple Code Example
We'll be using a pre-build/configured code repository. This repository is an
extremely simple "Hello World" type application that looks very much like our
previous example, except that it uses a Ruby/Sinatra application instead of a Go
application.

For this example, we will be using the following application's source code:

    https://github.com/openshift/sinatra-example

Let's see some YAML:

    oc new-app -o yaml https://github.com/openshift/sinatra-example

Take a look at the YAML that was generated. You will see some familiar items at
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

You can run `oc new-app --help` to see other things that `new-app` can help you
achieve.

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
around in the YAML output above from `new-app` you will see some reference to
"triggers". This is where `ImageStream`s come together.

The `ImageStream` resource is, somewhat unsurprisingly, a definition for a
stream of Docker images that might need to be paid attention to. By defining an
`ImageStream` on "ruby-22-rhel7", for example, and then building an application
against it, we have the ability with OpenShift to "know" when that `ImageStream`
changes and take action based on that change. In our example from the previous
paragraph, if the "ruby-22-rhel7" image changed in the Docker repository defined
by the `ImageStream`, we might automatically trigger a new build of our
application code.

An organization will likely choose several supported builders and databases from
Red Hat, but may also create their own builders, DBs, and other images. This
system provides a great deal of flexibility.

The installer pre-populated several `ImageStream`s for you when it was run. As
`root`:

    oc get is -n openshift
    NAME                                  DOCKER REPO                                                                  TAGS                            UPDATED
    jboss-amq-62                          registry.access.redhat.com/jboss-amq-6/amq62-openshift                       latest,1.1,1.2-12 + 3 more...   3 weeks ago
    jboss-eap64-openshift                 registry.access.redhat.com/jboss-eap-6/eap64-openshift                       1.1-2,1.1,1.1-6 + 3 more...     3 weeks ago
    jboss-webserver30-tomcat7-openshift   registry.access.redhat.com/jboss-webserver-3/webserver30-tomcat7-openshift   1.2-10,latest,1.1 + 3 more...   3 weeks ago
    jboss-webserver30-tomcat8-openshift   registry.access.redhat.com/jboss-webserver-3/webserver30-tomcat8-openshift   1.1-3,1.1-7,1.2 + 3 more...     3 weeks ago
    jenkins                               172.30.129.155:5000/openshift/jenkins                                        1,latest                        3 weeks ago
    mongodb                               172.30.129.155:5000/openshift/mongodb                                        2.6,latest,2.4                  3 weeks ago
    mysql                                 172.30.129.155:5000/openshift/mysql                                          5.6,latest,5.5                  3 weeks ago
    nodejs                                172.30.129.155:5000/openshift/nodejs                                         0.10,latest                     3 weeks ago
    perl                                  172.30.129.155:5000/openshift/perl                                           5.20,latest,5.16                3 weeks ago
    php                                   172.30.129.155:5000/openshift/php                                            5.6,latest,5.5                  3 weeks ago
    postgresql                            172.30.129.155:5000/openshift/postgresql                                     latest,9.4,9.2                  3 weeks ago
    python                                172.30.129.155:5000/openshift/python                                         3.4,latest,2.7 + 1 more...      3 weeks ago
    ruby                                  172.30.129.155:5000/openshift/ruby                                           2.0,2.2,latest                  10 days ago

The *openshift* project is another special one. Certain things placed here are
accessible to all users, but may only be modified/manipulated by cluster
administrators.

## Adding Code Via the Web Console
If you go to the web console and then select the "Sinatra Example" project,
you'll see a "Add to Project" button in the upper right hand corner. Click that
button. You now see a list of instant apps, and various languages, databases and
runtimes. Since Sinatra is a Ruby framework, go ahead and select the *ruby:2.0*
option.

When you do, you'll be taken to the next page where you can supply a name for
your "application" and its resources, as well as the source code URL. For the
*name* field, enter "example". In the *Git Repository URL* field, put the repo
URL:

    https://github.com/openshift/sinatra-example

We don't need to adjust any of the advanced options at this time, so please
click *Create*. Then click *Continue to overview*. At this point, OpenShift has
created several things for you. Use the "Browse" tab to poke around and find
them. You can also use `oc status` as the `joe` user, too.

If you look at the overview page, you will see the following note:

    Build example #1 is running. A new deployment will be created automatically
    once the build completes. View Log

Go ahead and click the *View Log* button. You will be able to observe the build
log running in real time. How neat is that?

On the command line, if you issue:

    oc get pod

You'll see something like:

    NAME              READY     STATUS    RESTARTS   AGE
    example-1-build   1/1       Running   0          48s

You can view the build logs from the command line with:

    oc build-logs example-1

Why just `example-1`?

Type:

    oc get build

And you will see:

    NAME        TYPE      FROM         STATUS     STARTED         DURATION
    example-1   Source    Git@master   Running    48 seconds ago  48s

Each time OpenShift performs a build, it increments the build number. This lets
you observe the status of past builds relatively easily, as we'll see later.

In the web console, once the build completes and the instance is deployed, the
overview page should show that the application is running and show the
information about the service and route at the top:

    SERVICE: EXAMPLE 8080/TCP → 8080
    example-sinatra.cloudapps.example.com

If you click on the service, in the right-hand *Details* pane you will see the
IP. It will be a 172.b.c.d IP address.

## Images and ImageStreams
**As `root`**, if you do:

    oc get image

You will see something like:

    NAME                                                                      DOCKER REF
    0d9ea62a74e95b2d3772c53ea257983f822945492f9d364e642b57187a7273f6          registry.access.redhat.com/rhscl/postgresql-94-rhel7:latest
    1426af0fc516b8ac50f6d1f127ca25b6275cb3ed86efff12ef1b2a9c912f56c7          registry.access.redhat.com/openshift3/ruby-20-rhel7:v3.0.0.0
    1637dfeeef5ed310ea903ee636fa7c4c0fde51514427010275f38b6a7d43ec4d          registry.access.redhat.com/openshift3/postgresql-92-rhel7:latest
    1ac9fd48694766bf7f17a7f71f29033012769971bd0e95158d9ad8f1501f8d25          registry.access.redhat.com/jboss-amq-6/amq62-openshift:1.1-2
    30bfe842e272328ea965553a7cae2d531abb4994b2830d487cf5536f31f785aa          registry.access.redhat.com/openshift3/perl-516-rhel7:latest
    3634ee8eec8ac268a86133e1ee560bdaa7453dd566e86c08e2402c82145d8d8f          registry.access.redhat.com/openshift3/jenkins-1-rhel7:latest
    39ff592357035637d589367f86bc70eabf09aa454d6db2906da9fc87d45b4d7d          registry.access.redhat.com/openshift3/ruby-20-rhel7:2.0-12
    4052f61aa6b6ff895141eb7d639e33f820376b799bb4d7d9d8e0abfb7a6b2c45          registry.access.redhat.com/rhscl/mongodb-26-rhel7:latest
    45961eb9dde2ce373d36e3ca8605e00cfc102b9f14aa7cd2132b7cadfd3f7f58          registry.access.redhat.com/rhscl/mysql-56-rhel7:latest
    4db71ef8f168097007671047ad9239447217c9e863826623ba7b23018efa8c57          registry.access.redhat.com/rhscl/php-56-rhel7:latest
    5dcbcf875ad6ce1fcb2dfdccef6dab0013be4b3c982597563f8760dfb5246d01          registry.access.redhat.com/jboss-amq-6/amq62-openshift:1.1-6
    611c1ddbf4712ad2ec9d044431aece2ecf8d65724266614c2e29c5ef95245d6c          registry.access.redhat.com/rhscl/perl-520-rhel7:latest
    611e9287c406e06a29eea03fe0c0806576b9b2adb1fc3dda00b45f32622abc1f          registry.access.redhat.com/openshift3/mysql-55-rhel7:latest
    66bbba7cedad2b126e7a8e2ec78b4ddf1a33c3e55179b39895cf7482776dbe92          registry.access.redhat.com/openshift3/python-33-rhel7:latest
    6da66388c3e62b9c956a587b149366b760861d5ed67870723914a2cbdd42a9ee          registry.access.redhat.com/jboss-webserver-3/webserver30-tomcat7-openshift:1.1-2
    6e0858fd4ffc7be3db350ef1adf54b121fab8915972c8ec76db63c83fa17b8e7          registry.access.redhat.com/openshift3/php-55-rhel7:latest
    8b13741374b34b31ada65019c76c213edb20f4dd983f0b3682170150fee3a865          registry.access.redhat.com/jboss-webserver-3/webserver30-tomcat8-openshift:1.1-3
    901b89353cfe7a1c6f6c31d57f89a989b08cf9fd384fcadec6f35a03c95f5ea4          registry.access.redhat.com/openshift3/ruby-20-rhel7:latest
    93d5039ac0fd9c1a9361b3459fdb005cddbdab694afe8d09abf18c064abebf20          registry.access.redhat.com/rhscl/python-27-rhel7:latest
    9416bc460d0c5f962db64dd43ae4a364ff480d883fb50cb0df1bc4808b377217          registry.access.redhat.com/rhscl/ruby-22-rhel7:latest
    bae1743ada780f4f14ba992fb5719ecd8cb2360480546280369050e597f98b3f          registry.access.redhat.com/rhscl/python-34-rhel7:latest
    c12d6b01a2fbd3036df445aa03ae6e9210801bd3245daf4e4fc23af08eb20c21          registry.access.redhat.com/jboss-eap-6/eap64-openshift:1.1-2
    c352faf0612819285212aade561bd0d54ba631df084387bbacb8c398f7ee4e09          registry.access.redhat.com/openshift3/mongodb-24-rhel7:latest
    c887de63ad61eef11824f330c69c081c9afce1d4a263d4ba631630698fb58880          registry.access.redhat.com/jboss-webserver-3/webserver30-tomcat8-openshift:1.1
    c9084bf9a9f5213ceadc38f8cf5aa83b0338c2caa5ceae07efef4b613ef5b496          registry.access.redhat.com/jboss-amq-6/amq62-openshift:1.2
    cd9c11961578733a25875fb51fc94d71135cc52eb270cd58213fe99000b2ce9e          registry.access.redhat.com/jboss-eap-6/eap64-openshift:1.2
    cef5247a4af15d9a0a6458b960412ae4680a04af2967096b1d13f034bda09e8d          registry.access.redhat.com/openshift3/nodejs-010-rhel7:latest
    dfdbff449ef7a289af499cc9e5bbd18f5173f46a674fda6fe6c8d712449c8c53          registry.access.redhat.com/jboss-eap-6/eap64-openshift:1.1-6
    e0f97342ddf6a09972434f98837b5fd8b5bed9390f32f1d63e8a7e4893208af7          registry.access.redhat.com/jboss-webserver-3/webserver30-tomcat7-openshift:1.1-6
    e1df0d20c9b63511e6d5a3681b93e97591400f4918c7a73e0b50e11e1004b379          registry.access.redhat.com/jboss-webserver-3/webserver30-tomcat7-openshift:1.2
    ea16bfe0829377fb1c0191d2953a1e104c9eb05d3691bfe9443bf6a12931fe25          registry.access.redhat.com/openshift3/ruby-20-rhel7:v3.0.2.0
    eea8b5469a20a0917df601856a54cadea77269fd4929c4d2954615b19c7ba8bc          registry.access.redhat.com/jboss-webserver-3/webserver30-tomcat8-openshift:1.2
    fcba2071846ce1f7ed8deb36e346e421d90873b083db3fa4933f4b9c0be72f0e          registry.access.redhat.com/openshift3/ruby-20-rhel7:v3.0.1.0
    sha256:d7ed55225476d23ca16182ee798e94214a9c55a6cdb6f5aa40e7f8330fd8caca   172.30.129.155:5000/sinatra/example@sha256:d7ed55225476d23ca16182ee798e94214a9c55a6cdb6f5aa40e7f8330fd8caca

What you are seeing here is OpenShift's picture of the various images it is
expecting to work with. The last image in the list is the one we just built --
our Sinatra application. `oc describe` can be used to tell us more about it:

    oc describe image sha256:d7ed55225476d23ca16182ee798e94214a9c55a6cdb6f5aa40e7f8330fd8caca
    Name:           sha256:d7ed55225476d23ca16182ee798e94214a9c55a6cdb6f5aa40e7f8330fd8caca
    Created:        14 minutes ago
    Labels:         <none>
    Annotations:    openshift.io/image.managed=true
    Docker Image:   172.30.129.155:5000/sinatra/example@sha256:d7ed55225476d23ca16182ee798e94214a9c55a6cdb6f5aa40e7f8330fd8caca
    Parent Image:   <none>
    Layer Size:     0 B
    Image Created:  292 years ago
    Author:         <none>
    Arch:           <none>

If you ask about the `ImageStream` that was created as part of our application
creation:

    oc get is -n sinatra example -o yaml
    apiVersion: v1
    kind: ImageStream
    metadata:
      annotations:
        openshift.io/generated-by: OpenShiftWebConsole
        openshift.io/image.dockerRepositoryCheck: 2015-11-05T01:31:23Z
      creationTimestamp: 2015-11-05T01:31:23Z
      labels:
        app: example
      name: example
      namespace: sinatra
      resourceVersion: "5713"
      selfLink: /oapi/v1/namespaces/sinatra/imagestreams/example
      uid: ec6c5d1c-835c-11e5-b039-525400b33d1d
    spec: {}
    status:
      dockerImageRepository: 172.30.129.155:5000/sinatra/example
      tags:
      - items:
        - created: 2015-11-05T01:33:18Z
          dockerImageReference: 172.30.129.155:5000/sinatra/example@sha256:d7ed55225476d23ca16182ee798e94214a9c55a6cdb6f5aa40e7f8330fd8caca
          image: sha256:d7ed55225476d23ca16182ee798e94214a9c55a6cdb6f5aa40e7f8330fd8caca
        tag: latest

You see that the stream refers to this particular image, too. And, finally, the
`DeploymentConfig` for our app:

    oc get dc/ruby-example -n sinatra -o yaml
    ...
    spec:
      containers:
      - image: 172.30.129.155:5000/sinatra/example@sha256:d7ed55225476d23ca16182ee798e94214a9c55a6cdb6f5aa40e7f8330fd8caca
        imagePullPolicy: Always
        name: example
    ...
    triggers:
    - imageChangeParams:
        automatic: true
        containerNames:
        - ruby-example
        from:
          kind: ImageStreamTag
          name: example:latest
        lastTriggeredImage: 172.30.129.155:5000/sinatra/example@sha256:d7ed55225476d23ca16182ee798e94214a9c55a6cdb6f5aa40e7f8330fd8caca
      type: ImageChange

The deployment is configured to launch a container based on this image, and
there is a trigger defined to watch for any changes to this image. If the image
associated with the *:latest* tag changes, we will redeploy it.

## Testing the Application
Using the information you found in the web console, try to see if your service
is working (as the `joe` user):

    curl `oc get service -n sinatra example --template \
    '{{.spec.portalIP}}:{{index .spec.ports 0 "port"}}'`

    the time where this server lives is 2015-11-04 20:51:10 -0500
        <br /><br />check out your <a href="/agent">user_agent</a>

So, from a simple code repository with a few lines of Ruby, we have successfully
built a Docker image and OpenShift has deployed it for us. It also did one other
thing for us -- it made our application externally accessible.

## The Application Route
Remember that routes are associated with services. Let's look at the list of
routes as `joe`:

    oc get route
    NAME      HOST/PORT                               PATH      SERVICE   LABELS        INSECURE POLICY   TLS TERMINATION
    example   example-sinatra.cloudapps.example.com             example   app=example                     

We can see that OpenShift created a route for us, named *example* (which matches
the name we provided during the creation process), and it created a host mapping
with a specific format that we've seen before:

    example-sinatra.cloudapps.example.com

That format is:

    <service_name>-<project_name>.<routing_subdomain>

That's the default behavior. You can always edit the route later.

At this point, you should be able to verify everything is working right:

    curl http://example-sinatra.cloudapps.example.com
    the time where this server lives is 2015-11-04 20:53:02 -0500
        <br /><br />check out your <a href="/agent">user_agent</a>

If you want to be fancy, try it in your browser!

**Note:** HTTPS will *not* work for this route, because we have not specified
any TLS termination.

## Implications of Quota Enforcement
Quotas have implications one may not immediately realize. Since we changed the
default project template earlier to include quota and limits, they already exist
for this Sinatra project. For example, as `root`, you can do:

    oc get quota/sinatra-quota limitrange/sinatra-limits -n sinatra

    NAME             AGE
    sinatra-quota    5m
    NAME             AGE
    sinatra-limits   5m

If you look at the UI in the Sinatra project under the `Settings` tab, you'll
also see the quota and limit information there.

If you go back to the overview tab, you will notice there are up and down arrows
next to the circle around the pod indicator. These can be used to scale your
application quickly. Go ahead and click the "up" arrow twice to scale this
application to 3 pods. The circle will change to reflect the status.

Once finished, on the command line as `joe`:

    oc get pod
    NAME              READY     STATUS      RESTARTS   AGE
    example-1-build   0/1       Completed   0          23m
    example-1-kfe86   1/1       Running     0          56s
    example-1-p3rcc   1/1       Running     0          5s
    example-1-watc1   1/1       Running     0          56s

You will see that your build pod is still hanging around, but exited. We are
currently doing this for logging purposes. Configuring log aggregation is
outside the scope of this material, but there are a number of different ways to
do it. Please be sure to check the docs for examples.

The `oc build-logs` command essentially is looking at the Docker
container logs under the covers. If we delete this pod, the build logs are lost.
The same holds true for the logs in the UI.

Also, do the following:

    oc get pod --template '{{range .items}}{{.metadata.name}} {{.spec.host}}{{"\n"}}{{end}}' | grep -v build

And you will see that our pods were equally distributed due to our scheduler
configuration:

    example-1-kfe86 ose3-node2.example.com
    example-1-p3rcc ose3-node1.example.com
    example-1-watc1 ose3-node1.example.com

*Note:* Your names are probably a little different.

Now, start another build, wait a moment or two for your build to start.

    oc start-build example

    oc get builds
    NAME        TYPE      FROM         STATUS                           STARTED          DURATION
    example-1   Source    Git@master   Complete                         25 minutes ago   1m58s
    example-2   Source    Git@master   Pending (CannotCreateBuildPod)  

The build shows *Pending* with an error status. What happened? The quota limits
the number of pods in this project to three and this includes ephemeral pods
like S2I builders. To see what this looks like, check out the `oc describe`
output:

    oc describe build example-2
    ...
    44s           44s             1       {build-controller }                     HandleBuildError        Build has error: failed to create build pod: Pod "example-2-build" is forbidden: limited to 3 pods

When it comes to scaling, there is also a command called `oc scale`. Since we
need to reduce the number of deployed pods in order to allow the build to
continue, do the following:

    oc scale rc/example-1 --replicas=1

You'll see confirmation of your request, and the web console will also show the
pod count decrease. Eventually, your build will restart.

**Note:** Once the build is complete a new replication controller is
created and the old one is no longer used.

**Note:** There is a bug where reducing the number of pods so that the build
*could* run does not result in the *Pending* build switching to *Running*:

    https://bugzilla.redhat.com/show_bug.cgi?id=1278232

## Registry Storage Revisited
At this point, as `root`, if you do:

    find /var/export/regvol/

You will see a large quantity of files and folders. This is the registry's
storage area, and the files and folders are the storage for this first Docker
image that we have built.


