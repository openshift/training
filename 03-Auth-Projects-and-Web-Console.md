<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Auth, Projects, and the Web Console](#auth-projects-and-the-web-console)
  - [Configuring htpasswd Authentication](#configuring-htpasswd-authentication)
  - [A Project for Everything](#a-project-for-everything)
  - [Web Console](#web-console)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Auth, Projects, and the Web Console
## Configuring htpasswd Authentication
** TODO: Does the quick installer do this? **
OpenShift v3 supports a number of mechanisms for authentication. The simplest
use case for our testing purposes is `htpasswd`-based authentication.

To start, we will need the `htpasswd` binary, which is made available by
installing:

    yum -y install httpd-tools

From there, we can create a password for our users, Joe and Alice:

    touch /etc/origin/openshift-passwd
    htpasswd -b /etc/origin/openshift-passwd joe redhat
    htpasswd -b /etc/origin/openshift-passwd alice redhat

Remember, you created these users previously.

The OpenShift configuration is kept in a YAML file which currently lives at
`/etc/openshift/master/master-config.yaml`. Ansible was configured to edit
the `oauthConfig`'s `identityProviders` stanza so that it looks like the following:

    identityProviders:
    - challenge: true
      login: true
      name: htpasswd_auth
      provider:
        apiVersion: v1
        file: /etc/openshift/openshift-passwd
        kind: HTPasswdPasswordIdentityProvider

More information on these configuration settings (and other identity providers) can be found here:

    https://docs.openshift.com/enterprise/3.1/admin_guide/configuring_authentication.html

Restart your master once you have edited the config:

    systemctl restart openshift-master

## A Project for Everything
V3 has a concept of "projects" to contain a number of different resources:
services and their pods, builds and so on. They are somewhat similar to
"namespaces" in OpenShift v2. We'll explore what this means in more details
throughout the rest of the labs. Let's create a project for our first
application.

We also need to understand a little bit about users and administration. The
default configuration for CLI operations currently is to be the `master-admin`
user, which is allowed to create projects. We can use the "admin"
OpenShift command to create a project, and assign an administrative user to it:

    oadm new-project demo --display-name="OpenShift 3 Demo" \
    --description="This is the first demo project with OpenShift v3" \
    --admin=joe

This command creates a project:
* with the id `demo`
* with a display name
* with a description
* with an administrative user `joe` who can login with the password defined by
    htpasswd

Future use of command line statements will have to reference this project in
order for things to land in the right place.

Now that you have a project created, it's time to look at the web console, which
has been completely redesigned for V3.

## Web Console
Open your browser and visit the following URL:

    https://fqdn.of.master:8443

Be aware that it may take up to 90 seconds for the web console to be available
any time you restart the master.

On your first visit your browser will need to accept the self-signed SSL
certificate. You will then be asked for a username and a password. Remembering
that we created a user previously, `joe`, go ahead and enter that and use
the password (`redhat`) you set earlier.

Once you are in, click the *OpenShift 3 Demo* project. There really isn't
anything of interest at the moment, because we haven't put anything into our
project.


