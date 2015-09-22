# EAP Example
This example requires internet access because the Maven configuration uses
public repositories.

If you have a Java application whose Maven configuration uses local
repositories, or has no Maven requirements, you could probably substitute that
code repository for the one below.

## Create a Project
Using the skills you have learned earlier in the training, create a new project
for the EAP example. Call it "eap-example" and make sure to remember which user
you are doing it as.

## Instantiate the Template
Red Hat provides a number of templates that can be used with the JBoss portfolio
builders. Find your EAP project in the web UI and then click "Add to Project".
Click the "Show All Templates" button at the bottom of the screen. Find the
*eap6-basic-sti* template and then click it.

You will come to the template options page and see a large number of parameters
that can be set. The only one we need to worry about is *GIT_CONTEXT_DIR* for
this example. Be sure to set it to `helloworld`.

You will see that there is a field called *GIT_URI*. This field tells the
S2I builder which repository to clone.

You will see that there is a field called *GIT_REF*. This field tells the S2I
builder which branch in the repository to clone.

Changing the *GIT_CONTEXT_DIR* value to `helloworld` will tell the S2I builder
which folder in the repo in the branch to use. If you visit the git repository
and look for the `helloworld` folder you will find our application.

Once you have changed the context dir, hit "Create" at the bottom of the screen.

You will see that two services are created -- one called `eap-app` and one
called `eap-app-ping`. The EAP template sets up a "ping" service that JBoss has
been configured to use to find cluster members for JBoss clustering.

The other service, `eap-app`, has a route created on it and is the one we will
use to visit our application.

## Watch the Build
In a few moments a build will start. You can watch the build if you choose, or
just look at the web console and wait for it to finish. If you do watch the
build, you might notice some Maven errors.  These are non-critical and will not
affect the success or failure of the build.

## Visit Your Application
Once built, you can visit your application using the following URL:

    http://eap-app-http-route-eap-example.cloudapps.example.com/jboss-helloworld

We didn't specify an *APPLICATION_HOSTNAME* when we instantiated the template,
and thus we got a default URL for the route. The reason that we visit
"/jboss-helloworld" and not just "/" is because the helloworld application does
not use a "ROOT.war". If you don't understand this, it's because Java is
confusing. :)
