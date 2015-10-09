<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [S2I - What Is It?](#s2i---what-is-it)
  - [Create a New Project](#create-a-new-project)
  - [Switch Projects](#switch-projects)
  - [A Simple Code Example](#a-simple-code-example)
  - [CLI versus Console](#cli-versus-console)
  - [ImageStreams](#imagestreams)
  - [Adding Code Via the Web Console](#adding-code-via-the-web-console)
  - [The Web Console Revisited](#the-web-console-revisited)
  - [Examining the Build](#examining-the-build)
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

    oc new-app -o json --strategy=source https://github.com/openshift/simple-openshift-sinatra-sti.git

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
you'll see a "Add to Project" button in the upper right hand corner. Click that
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

## Images and ImageStreams
**As `root`**, if you do:

    oc get image

You will see something like:

    NAME                                                                      DOCKER REF
    02d394ee667a865baf5d99f4f5d6d7146ef5900a58f3aab70b095316058e05cb          registry.access.redhat.com/jboss-amq-6/amq-openshift:6.2
    114ca2aa4e7deae983e19702015546a6be564f79aaabd1997c65ee8564323039          registry.access.redhat.com/openshift3/mongodb-24-rhel7:latest
    1426af0fc516b8ac50f6d1f127ca25b6275cb3ed86efff12ef1b2a9c912f56c7          registry.access.redhat.com/openshift3/ruby-20-rhel7:latest
    21f6d385fc0f16a1e4d05c16b2947eae8e576ae6d6c56ef3a151ec61e30f10d0          registry.access.redhat.com/openshift3/perl-516-rhel7:latest
    23f62abc77f1c7a5f42909363b097a756fa8e427fc19ffd1f11fe7adb63ecae8          registry.access.redhat.com/openshift3/python-33-rhel7:v3.0.0.0
    2b8583f742ac6c759a342033dceedf360f5e4d7a1c3eef4d073f3ecbb9f492e2          registry.access.redhat.com/openshift3/php-55-rhel7:latest
    57d5749e02a3d6d2a1af45305b573a30add5e4259d9c5cc0fba49bae43f105cc          registry.access.redhat.com/jboss-webserver-3/tomcat7-openshift:3.0
    66d92cebc0e48e4e4be3a93d0f9bd54f21af7928ceaa384d20800f6e6fcf669f          registry.access.redhat.com/openshift3/nodejs-010-rhel7:latest
    6b851f2a44a51713c877d486f5ec724f2aabd7b18e9b176e6cf8cf285fce8908          registry.access.redhat.com/jboss-webserver-3/tomcat8-openshift:3.0-137
    72039de9ffde99926f8056cefe90c9061d633c1b46e05599b9e42ee01c7fe6a6          registry.access.redhat.com/openshift3/postgresql-92-rhel7:latest
    85765d60ad4647183e37a5c63449e754c931e1de84200413577fcb124ae5907c          registry.access.redhat.com/jboss-eap-6/eap-openshift:6.4
    bb8bf2124de9cdb13e96087298d75538dddaacb93ccdd1c124c0a8889e670fdb          registry.access.redhat.com/openshift3/mysql-55-rhel7:latest
    sha256:c02e7822e7c4ae7929e1f8fe102649332fb27f418d1c4bf8e348e7a658fb34b7   172.30.101.126:5000/sinatra/ruby-example@sha256:c02e7822e7c4ae7929e1f8fe102649332fb27f418d1c4bf8e348e7a658fb34b7

What you are seeing here is OpenShift's picture of the various images it is
expecting to work with. The last image in the list is the one we just built --
our Sinatra application. `oc describe` can be used to tell us more about it:

    oc describe image sha256:c02e7822e7c4ae7929e1f8fe102649332fb27f418d1c4bf8e348e7a658fb34b7
    Name:           sha256:c02e7822e7c4ae7929e1f8fe102649332fb27f418d1c4bf8e348e7a658fb34b7
    Created:        25 minutes ago
    Labels:         <none>
    Annotations:    openshift.io/image.managed=true
    Docker Image:   172.30.101.126:5000/sinatra/ruby-example@sha256:c02e7822e7c4ae7929e1f8fe102649332fb27f418d1c4bf8e348e7a658fb34b7
    Parent Image:   <none>
    Layer Size:     0 B
    Image Created:  292.471209 years ago
    Author:         <none>
    Arch:           <none>

If you ask about the `ImageStream` that was created as part of our application
creation:

    oc get is -n sinatra ruby-example -o yaml
    apiVersion: v1
    kind: ImageStream
    metadata:
      creationTimestamp: 2015-07-28T14:39:51Z
      labels:
        generatedby: OpenShiftWebConsole
        name: ruby-example
      name: ruby-example
      namespace: sinatra
      resourceVersion: "13090"
      selfLink: /osapi/v1beta3/namespaces/sinatra/imagestreams/ruby-example
      uid: 80d62f34-3536-11e5-9e7e-525400b33d1d
    spec: {}
    status:
      dockerImageRepository: 172.30.101.126:5000/sinatra/ruby-example
      tags:
      - items:
        - created: 2015-07-28T14:42:42Z
          dockerImageReference: 172.30.101.126:5000/sinatra/ruby-example@sha256:c02e7822e7c4ae7929e1f8fe102649332fb27f418d1c4bf8e348e7a658fb34b7
          image: sha256:c02e7822e7c4ae7929e1f8fe102649332fb27f418d1c4bf8e348e7a658fb34b7
        tag: latest

You see that the stream refers to this particular image, too. And, finally, the
`DeploymentConfig` for our app:

    oc get dc/ruby-example -n sinatra -o yaml
    ...
    spec:
      containers:
      - image: 172.30.101.126:5000/sinatra/ruby-example@sha256:c02e7822e7c4ae7929e1f8fe102649332fb27f418d1c4bf8e348e7a658fb34b7
        imagePullPolicy: Always
        name: ruby-example
    ...
    triggers:
    - imageChangeParams:
        automatic: true
        containerNames:
        - ruby-example
        from:
          kind: ImageStreamTag
          name: ruby-example:latest
        lastTriggeredImage: 172.30.101.126:5000/sinatra/ruby-example@sha256:c02e7822e7c4ae7929e1f8fe102649332fb27f418d1c4bf8e348e7a658fb34b7
      type: ImageChange

The deployment is configured to launch a container based on this image, and
there is a trigger defined to watch for any changes to this image. If the image
associated with the *:latest* tag changes, we will redeploy it.

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

## Registry Storage Revisited
At this point, as `root`, if you do:

    find /var/export/regvol/

You will see a large quantity of files and folders. This is the registry's
storage area, and the files and folders are the storage for this first Docker
image that we have built.


