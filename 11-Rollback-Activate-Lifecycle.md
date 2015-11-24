<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Rollback/Activate and Code Lifecycle](#rollbackactivate-and-code-lifecycle)
  - [Fork the Repository](#fork-the-repository)
  - [Update the BuildConfig](#update-the-buildconfig)
  - [Change the Code](#change-the-code)
- [ Welcome to an OpenShift v3 Demo App! ](#welcome-to-an-openshift-v3-demo-app)
- [ This is my crustom demo! ](#this-is-my-crustom-demo)
  - [Start a Build with a Webhook](#start-a-build-with-a-webhook)
  - [Rollback](#rollback)
  - [Activate](#activate)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Rollback/Activate and Code Lifecycle
Not every coder is perfect, and sometimes you want to rollback to a previous
incarnation of your application. Sometimes you then want to go forward to a
newer version, too.

The next few labs require that you have a GitHub account, or that you are using
code that is in a repository that you can change. We will take Alice's "wiring"
application and modify its front-end and then rebuild. We'll roll-back to the
original version, and then go forward to our re-built version.

## Fork the Repository
Our wiring example's frontend service uses the following GitHub repository:

    https://github.com/openshift/ruby-hello-world

Go ahead and fork this into your own account by clicking the *Fork* Button at
the upper right.

## Update the BuildConfig
Remember that a `BuildConfig`(uration) tells OpenShift how to do a build.
Still as the `alice` user, take a look at the current `BuildConfig` for our
frontend:

    oc get buildconfig ruby-hello-world -o yaml
    apiVersion: v1
    kind: BuildConfig
    metadata:
      annotations:
        openshift.io/generated-by: OpenShiftNewApp
      creationTimestamp: 2015-11-06T02:18:19Z
      labels:
        app: ruby-hello-world
      name: ruby-hello-world
      namespace: wiring
      resourceVersion: "3081"
      selfLink: /oapi/v1/namespaces/wiring/buildconfigs/ruby-hello-world
      uid: a57f07c5-842c-11e5-af5d-525400b33d1d
    spec:
      output:
        to:
          kind: ImageStreamTag
          name: ruby-hello-world:latest
      resources: {}
      source:
        git:
          uri: https://github.com/openshift/ruby-hello-world
        type: Git
      strategy:
        sourceStrategy:
          from:
            kind: ImageStreamTag
            name: ruby:latest
            namespace: openshift
        type: Source
      triggers:
      - github:
          secret: r-_UtC9CchVBq-7JUHmE
        type: GitHub
      - generic:
          secret: UfU-eyd3BOKGDArWkb7T
        type: Generic
      - type: ConfigChange
      - imageChange:
          lastTriggeredImageID: registry.access.redhat.com/openshift3/ruby-20-rhel7:latest
        type: ImageChange
    status:
      lastVersion: 2

As you can see, the current configuration points at the
`openshift/ruby-hello-world` repository. Since you've forked this repo, let's go
ahead and re-point our configuration. Our friend `oc edit` comes to the rescue
again:

    oc edit bc ruby-hello-world

Change the "uri" reference to match the name of your GitHub
repository. Assuming your github user is `alice`, you would point it
to `git://github.com/alice/ruby-hello-world.git`. Save and exit
the editor.

If you again run `oc get buildconfig ruby-example -o yaml` you should see
that the `uri` has been updated.

## Change the Code
GitHub's web interface will let you make edits to files. Go to your forked
repository (eg: https://github.com/alice/ruby-hello-world) and find the file
`main.erb` in the `views` folder.

Change the following HTML:

    <div class="page-header" align=center>
      <h1> Welcome to an OpenShift v3 Demo App! </h1>
    </div>

To read (with the typo):

    <div class="page-header" align=center>
      <h1> This is my crustom demo! </h1>
    </div>

You can edit code on GitHub by clicking the pencil icon which is next to the
"History" button. Provide some nifty commit message like "Personalizing the
application."

If you know how to use Git/GitHub, you can just do this "normally".

## Start a Build with a Webhook
Webhooks are a way to integrate external systems into your OpenShift
environment so that they can fire off OpenShift builds. Generally
speaking, one would make code changes, update the code repository, and
then some process would hit OpenShift's webhook URL in order to start
a build with the new code.

Your GitHub account has the capability to configure a webhook to request
whenever a commit is pushed to a specific branch; however, it would only
be able to make a request against your OpenShift master if that master
is exposed on the Internet, so you will probably need to simulate the
request manually for now.

To find the webhook URL, you can visit the web console, click into the
project, click on *Browse* and then on *Builds*. Find the `ruby-hello-world`
build and click that.

You'll see two webhook URL types listed: *GitHub* and *Generic*. Click the copy
button for the *Generic* one. If you click *Show URL* you will see something
that looks like:

    https://ose3-master.example.com:8443/oapi/v1/namespaces/wiring/buildconfigs/ruby-hello-world/webhooks/UfU-eyd3BOKGDArWkb7T/generic

If you look at the `buildConfiguration` YAML output from earlier, you'll notice
the secrets entries in triggers. These are basically passwords so that just
anyone on the web can't trigger the build with knowledge of the name only.

This time, in order to run a build for the frontend, we'll use `curl` to hit our
webhook URL.

First, look at the list of builds:

    oc get build

You should see that the first build had completed. Then, `curl`:

    curl -i -H "Accept: application/json" \
    -H "X-HTTP-Method-Override: PUT" -X POST -k \
    https://ose3-master.example.com:8443/oapi/v1/namespaces/wiring/buildconfigs/ruby-hello-world/webhooks/UfU-eyd3BOKGDArWkb7T/generic

And now `get build` again:

    oc get build
    NAME                 TYPE      FROM      STATUS     STARTED          DURATION
    ruby-hello-world-1   Source    Git       Complete   3 minutes ago    28s
    ruby-hello-world-2   Source    Git       Running    10 seconds ago   10s

You can see that this could have been part of some CI/CD workflow that
automatically called our webhook once the code was tested.

You can also check the web interface (logged in as `alice`) and see
that the build is running. Once it is complete, point your web browser
at the application:

    http://ruby-hello-world.wiring.cloudapps.example.com/

You should see your big fat typo.

**Note: Remember that it can take a few moments for your service endpoint to get
updated. You might get a `503` error if you try to access the application before
this happens.**

Since we failed to properly test our application, and our ugly typo has made it
into production, a nastygram from corporate marketing has told us that we need
to revert to the previous version, ASAP.

If you log into the web console as `alice` and find the *Deployments* section of
the *Browse* menu, and click on `ruby-hello-world`, you'll see that there are
two deployments of our frontend: 1 and 2.

You can also see this information from the cli by doing:

    oc get replicationcontroller

The semantics of this are that a `DeploymentConfig` ensures a
`ReplicationController` is created to manage the deployment of the built `Image`
from the `ImageStream`.

Simple, right?

## Rollback
You can rollback a deployment using the CLI. Let's go and checkout what a rollback to
`frontend-1` would look like:

    oc rollback ruby-hello-world-1 --dry-run

Since it looks OK, let's go ahead and do it:

    oc rollback ruby-hello-world-1

If you look at the `Browse` tab of your project, you'll see that in the `Pods`
section there is a `frontend-3...` pod now. After a few moments, revisit the
application in your web browser, and you should see the old "Welcome..." text.

You may be wondering "Why did I get a -3 instead of going 'back' to -1?". The
answer is that, while it is called "rollback", OpenShift only ever goes forward.
The 3rd deployment that results from this "rollback" is technically a new
deployment with its own, new `ReplicationController`. The YAML that describes
this new `ReplicationController` (-3) looks identical to the older one (-1).
That's just the way it works.

## Activate
Corporate marketing called again. They think the typo makes us look hip and
cool. Let's now roll forward (activate) the typo-enabled application. You can
actually do this from the web console as well as from the command line.

In the web console, go back to *Browse* and then *Deployments* and then click on
`ruby-hello-world`. Find the *#2* deployment and click it. In the *Status* line
you will notice that there is a *Roll Back* button. Go ahead and click it. Check
all of the boxes, and then click *Roll Back* again. Wait a bit and you should
see that you "roll back" to the newer (#2) deployment.
