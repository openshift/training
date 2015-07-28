<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Templates, Instant Apps, and "Quickstarts"](#templates-instant-apps-and-quickstarts)
  - [A Project for the Quickstart](#a-project-for-the-quickstart)
  - [A Quick Aside on Templates](#a-quick-aside-on-templates)
  - [Adding the Template](#adding-the-template)
  - [Create an Instance of the Template](#create-an-instance-of-the-template)
  - [Using Your App](#using-your-app)

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

## A Project for the Quickstart
As `joe`, create a new project:

    oc new-project quickstart --display-name="Quickstart" \
    --description='A demonstration of a "quickstart/template"'

This also changes you to use that project:

    Now using project "quickstart" on server "https://ose3-master.example.com:8443".

## A Quick Aside on Templates
From the [OpenShift
documentation](https://docs.openshift.com/enterprise/3.0/dev_guide/templates.html):

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
Go ahead and do the following as `root` in the `~/training/content` folder:

    oc create -f quickstart-template.json -n openshift

What did you just do? The `quickstart-template.json` file defined a template. By
"creating" it, you have added it to the *openshift* project. Remember that the
*openshift* project is special in that any users can see templates and other
content in it.

## Create an Instance of the Template
In the web console, logged in as `joe`, find the "Quickstart" project, and then
hit the "Create +" button. We've seen this page before, but now it contains
something new -- an additional "instant app(lication)". An instant app is a
"special" kind of template (relaly, it just has the "instant-app" tag). The idea
behind an "instant app" is that, when creating an instance of the template, you
will have a fully functional application. In this example, our "instant" app is
just a simple key-value storage and retrieval webapp. You may have noticed that
there were already several instant apps loaded. The installer set these up.

Click "quickstart-keyvalue-application", and you'll see a modal pop-up that
provides more information about the template.

Click "Select template..."

The next page that you will see is the template "configuration" page. This is
where you can specify certain options for how the application components will be
insantiated.

* It will show you what Docker images are used
* It will let you add label:value pairs that can be used for other things
* It will let you set specific values for any parameters, if you so choose

The only parameter you may need to edit is the `APPLICATION_DOMAIN` if it does
not match what you have used for your environment. Leave all of the other
defaults and simply click "Create".

Once you hit the "Create" button, the services and pods and
replicationcontrollers and etc. will be instantiated.

Much like before, the build will start automatically after creating an instance
of the template, so you can wait for it to finish. Feel free to check the build
logs.

## Using Your App
Once the build is complete, you should be able to visit the routed URL and
actually use the application!

    http://quickstart.cloudapps.example.com
