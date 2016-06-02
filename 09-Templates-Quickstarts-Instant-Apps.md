<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Templates, Instant Apps, and "Quickstarts"](#templates-instant-apps-and-quickstarts)
  - [Increase Pod Quota](#increase-pod-quota)
  - [A Project for the Quickstart](#a-project-for-the-quickstart)
  - [A Quick Aside on Templates](#a-quick-aside-on-templates)
  - [Adding the Template](#adding-the-template)
  - [Create an Instance of the Template](#create-an-instance-of-the-template)
  - [Using Your App](#using-your-app)
  - [Topology View](#topology-view)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Templates, Instant Apps, and "Quickstarts"
The next example will involve a build of another application, but also a service
that has two pods -- a "front-end" web tier and a "back-end" database tier. This
application also makes use of auto-generated parameters and other neat features
of OpenShift. One thing of note is that this project already has the
wiring/plumbing between the front- and back-end components pre-defined as part
of its JSON and embedded in the source code. Adding resources "after the fact"
will come in a later lab.

This example is effectively a "quickstart", or, in OpenShift 3 terms, an
"instant app" -- a pre-defined application that comes in a template that you can
just fire up and start using or hacking on.

## Increase Pod Quota
For the next few labs we will end up needing a higher pod quota. This requires
editing the project request template that we created earlier. Here we can use
`oc edit` as `root`:

    oc edit template/default-project-request

In the `ResourceQuota` section under `spec` change:

    pods: 3

to:

    pods: 5

Save and quit the editor.

## A Project for the Quickstart
As `joe`, create a new project:

    oc new-project quickstart --display-name="Quickstart" \
    --description='A demonstration of a "quickstart/template"'

This also changes you to use that project:

    Now using project "quickstart" on server "https://ose3-master.example.com:8443".

## A Quick Aside on Templates
From the [OpenShift
documentation](https://docs.openshift.com/enterprise/latest/dev_guide/templates.html):

    A template describes a set of objects that can be parameterized and
    processed to produce a list of objects for creation by OpenShift. A template
    can be processed to create anything you have permission to create within a
    project, for example services, build configurations, and deployment
    configurations. A template may also define a set of labels to apply to every
    object defined in the template.

As we mentioned previously, this template has some auto-generated parameters.
For example, take a look at the following JSON:

    "parameters": [
      {
        "name": "MYSQL_USER",
        "description": "database username",
        "generate": "expression",
        "from": "user[A-Z0-9]{3}"
      },

This portion of the template's JSON tells OpenShift to generate an expression
using a regex-like string that will be available as `MYSQL_USER` when the
template is processed/instantiated.

## Adding the Template
Go ahead and do the following as `root`:

    oc create -f ~/training/content/quickstart-template.json -n openshift

What did you just do? The `quickstart-template.json` file defined a template. By
"creating" it, you have added it to the *openshift* project. Remember that the
*openshift* project is special in that any users can see templates and other
content in it.

## Create an Instance of the Template
In the web console, logged in as `joe`, find the "Quickstart" project, and then
hit the "Add to Project" button. We've seen this page before. This time, we're
going to use the  "Instant Apps" section.

An instant app is a "special" kind of template (really, it just has the
"instant-app" tag). The idea behind an "Instant App" is that, when creating an
instance of the template, you will have a fully functional application. In this
example, our "instant" app is just a simple key-value storage and retrieval
webapp. You may have noticed that there were already several instant apps
loaded. The installer set these up.

Next to "Instant Apps" click "See all" and then click
"quickstart-keyvalue-application".

The next page that you will see is the template "configuration" page. This is
where you can specify certain options for how the application components will be
insantiated.

* It will show you what Docker images are used
* It will let you add label:value pairs that can be used for other things
* It will let you set specific values for any parameters, if you so choose

Leave all of the defaults and simply click "Create". Then click "Continue to
overview".

When you hit the "Create" button, the services and pods and
replicationcontrollers and etc. will be instantiated.

Much like before, the build will start automatically after creating an instance
of the template, so you can wait for it to finish. Feel free to check the build
logs.

Once the build finishes and the pods come up, it can take a little while for the
application to be ready. This is due to the database setup that this application
is performing on first start.

## Using Your App
Once the build is complete and the application instance is ready, you should be
able to visit the routed URL and actually use the application!

    http://keyvalue-route-quickstart.cloudapps.example.com

If you get 503 errors, wait a minute and then try again -- this is a
sign that the application is not "ready" yet. We will talk about checking
"liveness" and "readiness" in later labs.

The dev guide linked previously has a lot of information on how to use
templates. 

## Topology View
If you look at the *Overview* tab in the project page in the web console, you
will notice a little icon that looks like a "<", or kind of like the Steam logo.
To its left is what looks like a grid button. If you click the "<" button, this
will switch the overview to what is called the *Topology View*. You will see
various bubbles that represent the various resources in the project -
DeploymentConfigs, Pods, BuildConfigs, and more.

Play around with scaling the frontend application up and down and see how the
topology view is affected.
