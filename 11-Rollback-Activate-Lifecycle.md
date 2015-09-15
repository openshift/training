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

The next few labs require that you have a Github account. We will take Alice's
"wiring" application and modify its front-end and then rebuild. We'll roll-back
to the original version, and then go forward to our re-built version.

## Fork the Repository
Our wiring example's frontend service uses the following Github repository:

    https://github.com/openshift/ruby-hello-world

Go ahead and fork this into your own account by clicking the *Fork* Button at
the upper right.

## Update the BuildConfig
Remember that a `BuildConfig`(uration) tells OpenShift how to do a build.
Still as the `alice` user, take a look at the current `BuildConfig` for our
frontend:

    oc get buildconfig ruby-example -o yaml
    apiVersion: v1beta1
    kind: BuildConfig
    metadata:
      creationTimestamp: 2015-03-10T15:40:26-04:00
      labels:
        template: application-template-stibuild
      name: ruby-example
      namespace: wiring
      resourceVersion: "831"
      selfLink: /osapi/v1beta1/buildConfigs/ruby-example?namespace=wiring
      uid: 4cff2e5e-c75d-11e4-806e-525400b33d1d
    parameters:
      output:
        to:
          kind: ImageStream
          name: origin-ruby-sample
      source:
        git:
          uri: git://github.com/openshift/ruby-hello-world.git
          ref: beta4
        type: Git
      strategy:
        stiStrategy:
          builderImage: openshift/ruby-20-rhel7
          image: openshift/ruby-20-rhel7
        type: STI
    triggers:
    - github:
        secret: secret101
      type: github
    - generic:
        secret: secret101
      type: generic
    - imageChange:
        from:
          name: ruby-20-rhel7
        image: openshift/ruby-20-rhel7
        imageRepositoryRef:
          name: ruby-20-rhel7
        tag: latest
      type: imageChange

As you can see, the current configuration points at the
`openshift/ruby-hello-world` repository. Since you've forked this repo, let's go
ahead and re-point our configuration. Our friend `oc edit` comes to the rescue
again:

    oc edit bc ruby-example

Change the "uri" reference to match the name of your Github
repository. Assuming your github user is `alice`, you would point it
to `git://github.com/alice/ruby-hello-world.git`. Save and exit
the editor.

If you again run `oc get buildconfig ruby-example -o yaml` you should see
that the `uri` has been updated.

## Change the Code
Github's web interface will let you make edits to files. Go to your forked
repository (eg: https://github.com/alice/ruby-hello-world), select the `beta3`
branch, and find the file `main.erb` in the `views` folder.

Change the following HTML:

    <div class="page-header" align=center>
      <h1> Welcome to an OpenShift v3 Demo App! </h1>
    </div>

To read (with the typo):

    <div class="page-header" align=center>
      <h1> This is my crustom demo! </h1>
    </div>

You can edit code on Github by clicking the pencil icon which is next to the
"History" button. Provide some nifty commit message like "Personalizing the
application."

If you know how to use Git/Github, you can just do this "normally".

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
project, click on *Browse* and then on *Builds*. You'll see two webhook
URLs. Copy the *Generic* one. It should look like:

    https://ose3-master.example.com:8443/osapi/v1beta3/namespaces/wiring/buildconfigs/ruby-hello-world/webhooks/ZmUo4U1BaE0PnJz9QNnY/generic

If you look at the `frontend-config.json` file that you created earlier,
you'll notice the same "secret101" entries in triggers. These are
basically passwords so that just anyone on the web can't trigger the
build with knowledge of the name only. You could of course have adjusted
the passwords or had the template generate randomized ones.

This time, in order to run a build for the frontend, we'll use `curl` to hit our
webhook URL.

First, look at the list of builds:

    oc get build

You should see that the first build had completed. Then, `curl`:

    curl -i -H "Accept: application/json" \
    -H "X-HTTP-Method-Override: PUT" -X POST -k \
    https://ose3-master.example.com:8443/osapi/v1beta3/namespaces/wiring/buildconfigs/ruby-hello-world/webhooks/ZmUo4U1BaE0PnJz9QNnY/generic

And now `get build` again:

    oc get build
    NAME                  TYPE      STATUS     POD
    ruby-example-1   Source    Complete   ruby-example-1
    ruby-example-2   Source    Pending    ruby-example-2

You can see that this could have been part of some CI/CD workflow that
automatically called our webhook once the code was tested.

You can also check the web interface (logged in as `alice`) and see
that the build is running. Once it is complete, point your web browser
at the application:

    http://ruby-hello-world.wiring.cloudapps.example.com/

You should see your big fat typo.

**Note: Remember that it can take a minute for your service endpoint to get
updated. You might get a `503` error if you try to access the application before
this happens.**

Since we failed to properly test our application, and our ugly typo has made it
into production, a nastygram from corporate marketing has told us that we need
to revert to the previous version, ASAP.

If you log into the web console as `alice` and find the `Deployments` section of
the `Browse` menu, you'll see that there are two deployments of our frontend: 1
and 2.

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

## Activate
Corporate marketing called again. They think the typo makes us look hip and
cool. Let's now roll forward (activate) the typo-enabled application:

    oc rollback ruby-hello-world-2

