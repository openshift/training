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
    NAME                                 DOCKER REPO                                                      TAGS                                     UPDATED
    jboss-amq-6                          registry.access.redhat.com/jboss-amq-6/amq-openshift             6.2-140,6.2-123,latest + 2 more...       3 hours ago
    jboss-eap6-openshift                 registry.access.redhat.com/jboss-eap-6/eap-openshift             6.4-260,6.4-207,6.4-239 + 2 more...      3 hours ago
    jboss-webserver3-tomcat7-openshift   registry.access.redhat.com/jboss-webserver-3/tomcat7-openshift   3.0-135,3.0-190,latest + 2 more...       3 hours ago
    jboss-webserver3-tomcat8-openshift   registry.access.redhat.com/jboss-webserver-3/tomcat8-openshift   3.0-137,3.0-163,3.0-190 + 2 more...      3 hours ago
    jenkins                              registry.access.redhat.com/openshift3/jenkins-1-rhel7            1,1.6-3,latest                           3 hours ago
    mongodb                              registry.access.redhat.com/openshift3/mongodb-24-rhel7           v3.0.0.0,v3.0.1.0,2.4 + 2 more...        3 hours ago
    mysql                                registry.access.redhat.com/openshift3/mysql-55-rhel7             5.5,latest,v3.0.2.0 + 2 more...          3 hours ago
    nodejs                               registry.access.redhat.com/openshift3/nodejs-010-rhel7           v3.0.0.0,v3.0.2.0,0.10 + 2 more...       3 hours ago
    perl                                 registry.access.redhat.com/openshift3/perl-516-rhel7             v3.0.1.0,5.16,latest + 2 more...         3 hours ago
    php                                  registry.access.redhat.com/openshift3/php-55-rhel7               v3.0.1.0,v3.0.2.0,v3.0.0.0 + 2 more...   3 hours ago
    postgresql                           registry.access.redhat.com/openshift3/postgresql-92-rhel7        v3.0.2.0,9.2,latest + 2 more...          3 hours ago
    python                               registry.access.redhat.com/openshift3/python-33-rhel7            v3.0.1.0,v3.0.2.0,3.3 + 2 more...        3 hours ago
    ruby                                 registry.access.redhat.com/openshift3/ruby-22-rhel7              v3.0.0.0,2.2,latest + 2 more...          3 hours ago

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
    02d394ee667a865baf5d99f4f5d6d7146ef5900a58f3aab70b095316058e05cb          registry.access.redhat.com/jboss-amq-6/amq-openshift:6.2-84
    0fb368c42851b39784c1ba2896b23049289136bba120e39fdb4210fc8b240cef          registry.access.redhat.com/openshift3/python-33-rhel7:latest
    114ca2aa4e7deae983e19702015546a6be564f79aaabd1997c65ee8564323039          registry.access.redhat.com/openshift3/mongodb-24-rhel7:v3.0.0.0
    1426af0fc516b8ac50f6d1f127ca25b6275cb3ed86efff12ef1b2a9c912f56c7          registry.access.redhat.com/openshift3/ruby-22-rhel7:v3.0.0.0
    18a614c1ed41987b8bd941d4b2f241df4340060bc755429d35b7dcbfaf753b41          registry.access.redhat.com/openshift3/python-33-rhel7:v3.0.1.0
    1a6b324077cdd0259a87adaae7a09edd3f3050b8472ea9cb913b7e60e476b483          registry.access.redhat.com/jboss-webserver-3/tomcat7-openshift:3.0-190
    21f6d385fc0f16a1e4d05c16b2947eae8e576ae6d6c56ef3a151ec61e30f10d0          registry.access.redhat.com/openshift3/perl-516-rhel7:v3.0.0.0
    225d177d917d87ac71f252e7027d2388c70bed899023de047e7c1ea3008e3169          registry.access.redhat.com/openshift3/jenkins-1-rhel7:1.6-3
    23f62abc77f1c7a5f42909363b097a756fa8e427fc19ffd1f11fe7adb63ecae8          registry.access.redhat.com/openshift3/python-33-rhel7:v3.0.0.0
    2b8583f742ac6c759a342033dceedf360f5e4d7a1c3eef4d073f3ecbb9f492e2          registry.access.redhat.com/openshift3/php-55-rhel7:v3.0.0.0
    2cf41faf81c11bbcf730a3e8a3609ec557b35dde97a3906900461497c34c30ea          registry.access.redhat.com/jboss-amq-6/amq-openshift:latest
    38ce0de2eb32bedac80605a83ab5fd6ebc96dc3c040702549ef6ded9a445f6c3          registry.access.redhat.com/openshift3/nodejs-010-rhel7:v3.0.2.0
    3c7c6d0b04516295ae6f699bfb8b3562eb3acd60b95a3bc4d013a9496de49a54          registry.access.redhat.com/openshift3/php-55-rhel7:v3.0.1.0
    4cc25684d3228fd08ed00f9220db04301a3995d49641fb00488abc0da76da0e6          registry.access.redhat.com/openshift3/postgresql-92-rhel7:v3.0.1.0
    57d5749e02a3d6d2a1af45305b573a30add5e4259d9c5cc0fba49bae43f105cc          registry.access.redhat.com/jboss-webserver-3/tomcat7-openshift:3.0-135
    583fb8a0657511291efe6da5c78c639ba2937c1bee60e403fd806379adb1d481          registry.access.redhat.com/jboss-eap-6/eap-openshift:6.4-239
    5c93a30f18d087bd04653342ebf712faa6eb0b3cc4fd5384a9d2fcd7cad73dd6          registry.access.redhat.com/jboss-eap-6/eap-openshift:latest
    6504ce77e8bc29ac624df2d27481a9b0f058913c1b9ab18a8841f8c049e78982          registry.access.redhat.com/openshift3/perl-516-rhel7:v3.0.1.0
    66d92cebc0e48e4e4be3a93d0f9bd54f21af7928ceaa384d20800f6e6fcf669f          registry.access.redhat.com/openshift3/nodejs-010-rhel7:v3.0.0.0
    6b851f2a44a51713c877d486f5ec724f2aabd7b18e9b176e6cf8cf285fce8908          registry.access.redhat.com/jboss-webserver-3/tomcat8-openshift:3.0-137
    72039de9ffde99926f8056cefe90c9061d633c1b46e05599b9e42ee01c7fe6a6          registry.access.redhat.com/openshift3/postgresql-92-rhel7:v3.0.0.0
    7c3547ea8e83faab8818e66b9a239e61ea04ba6e921801b59031e1a8849e58f4          registry.access.redhat.com/openshift3/mysql-55-rhel7:v3.0.1.0
    82e9d56236e2c9803b4e456046a003c4c75d79fb2237b78210a07a57631fed2e          registry.access.redhat.com/openshift3/php-55-rhel7:latest
    85765d60ad4647183e37a5c63449e754c931e1de84200413577fcb124ae5907c          registry.access.redhat.com/jboss-eap-6/eap-openshift:6.4-207
    b80076acb2e748879d770cc1b8ba40c7df8c690301d68b668dcc10935973ae03          registry.access.redhat.com/openshift3/mongodb-24-rhel7:v3.0.1.0
    bb8bf2124de9cdb13e96087298d75538dddaacb93ccdd1c124c0a8889e670fdb          registry.access.redhat.com/openshift3/mysql-55-rhel7:v3.0.0.0
    bdaffa30e8c12b53104b1c47a29c3292d1f5945ebf72c6c2cf53778cea2bbd72          registry.access.redhat.com/openshift3/nodejs-010-rhel7:v3.0.1.0
    be57a13e50bb0bb348fa3af5852421660b24dc7a4620ec58644aff332ccf497b          registry.access.redhat.com/jboss-webserver-3/tomcat7-openshift:3.0-160
    c10e6b2e643e30eaa93d8c47e6d6c545ba28494cbb6e2e2862a4cb1895f07f6e          registry.access.redhat.com/openshift3/postgresql-92-rhel7:v3.0.2.0
    c3d990247510bcd3e1dbc3093a97bad5cfad753ea7bba9d74457515aa5d62406          registry.access.redhat.com/openshift3/mysql-55-rhel7:v3.0.2.0
    cb8815d8f7156545b189c32276f8d638c87ba913c126c66d79aac9f744d5a979          registry.access.redhat.com/openshift3/perl-516-rhel7:v3.0.2.0
    d17602c1d6644dc614b57fb895f06b5b564679e40ee09fc374008799c984fe89          registry.access.redhat.com/openshift3/mongodb-24-rhel7:v3.0.2.0
    df03c0820b69bae34b414be401227fddba1a72189d4575b0be3bddc1b979e04a          registry.access.redhat.com/jboss-amq-6/amq-openshift:6.2-123
    ea16bfe0829377fb1c0191d2953a1e104c9eb05d3691bfe9443bf6a12931fe25          registry.access.redhat.com/openshift3/ruby-22-rhel7:v3.0.2.0
    fb24d497b1aeb499a07e5ac4996893ecf5dfc0a7369399e2f40120b58a077462          registry.access.redhat.com/jboss-webserver-3/tomcat8-openshift:3.0-163
    fc44453d1eca9eb9d07407b612cf72f7362789ca08c982c1495903cc861c7dab          registry.access.redhat.com/jboss-webserver-3/tomcat8-openshift:latest
    fcba2071846ce1f7ed8deb36e346e421d90873b083db3fa4933f4b9c0be72f0e          registry.access.redhat.com/openshift3/ruby-22-rhel7:v3.0.1.0
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


