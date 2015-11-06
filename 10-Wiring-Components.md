<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Creating and Wiring Disparate Components](#creating-and-wiring-disparate-components)
  - [Create a New Project](#create-a-new-project)
  - [Stand Up the Frontend](#stand-up-the-frontend)
  - [Test the Frontend](#test-the-frontend)
    - [(It looks like the database isn't running.  This isn't going to be much fun.)](#it-looks-like-the-database-isnt-running--this-isnt-going-to-be-much-fun)
  - [Expose the Service](#expose-the-service)
  - [Create the Database From the Web Console](#create-the-database-from-the-web-console)
  - [Visit Your Application Again](#visit-your-application-again)
  - [Replication Controllers](#replication-controllers)
  - [Revisit the Webpage](#revisit-the-webpage)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Creating and Wiring Disparate Components
Quickstarts are great, but sometimes a developer wants to build up the various
components manually. Let's take our quickstart example and treat it like two
separate "applications" that we want to wire together.

## Create a New Project
Open a terminal as `alice`:

    # su - alice

Then, create a project for this example:

    oc new-project wiring --display-name="Exploring Parameters" \
    --description='An exploration of wiring using parameters'

Log into the web console as `alice`. Can you see `joe`'s projects and content?

Before continuing, `alice` will also need the training repository:

    cd
    git clone https://github.com/openshift/training.git
    cd ~/training/content

## Stand Up the Frontend
The first step will be to stand up the frontend of our application. For
argument's sake, this could have just as easily been brand new vanilla code.
However, to make things faster, we'll start with an application that already is
looking for a DB, but won't fail spectacularly if one isn't found.

The frontend application comes from the following code repository:

    https://github.com/openshift/ruby-hello-world

We can use the `new-app` command to help get this started for us. As `alice` go
ahead and do the following:

    oc new-app -i openshift/ruby https://github.com/openshift/ruby-hello-world

You should see something like the following:

    I1105 14:11:59.060593   83892 newapp.go:522] Using "https://github.com/openshift/ruby-hello-world" as the source for build
    --> Found image ea16bfe (8 weeks old) in image stream "ruby in project openshift" under tag :latest for "openshift/ruby"
        * The source repository appears to match: ruby
        * A source build using source code from https://github.com/openshift/ruby-hello-world will be created
          * The resulting image will be pushed to image stream "ruby-hello-world:latest"
        * This image will be deployed in deployment config "ruby-hello-world"
        * Port 8080/tcp will be load balanced by service "ruby-hello-world"
    --> Creating resources with label app=ruby-hello-world ...
        ImageStream "ruby-hello-world" created
        BuildConfig "ruby-hello-world" created
        DeploymentConfig "ruby-hello-world" created
        Service "ruby-hello-world" created
    --> Success
        Build scheduled for "ruby-hello-world" - use the logs command to track its progress.
        Run 'oc status' to view your app.

The syntax of the command tells us:

* I want to create a new application
* using the *ruby* builder imagestream defined in the *openshift* project
* based off of the code in a git repository

Since we know that we want to talk to a database eventually, let's take a moment
to add the environment variables for it. Conveniently, there is an `env`
subcommand to `oc`. As `alice`, we can use it like so:

    oc env dc/ruby-hello-world MYSQL_USER=redhat MYSQL_PASSWORD=redhat MYSQL_DATABASE=mydb

If you want to double-check, you can verify using the following:

    oc env dc/ruby-hello-world --list
    # deploymentconfigs ruby-hello-world, container ruby-hello-world
    MYSQL_USER=redhat
    MYSQL_PASSWORD=redhat
    MYSQL_DATABASE=mydb

At this point, you probably have a build running and a second deployment. The
`deploymentConfig` has a trigger defined on it called *ConfigChange*. Becuase we
*changed* the environment variables, that constituted a *ConfigChange*, which
*triggers* a new deployment. In this case, the 2nd deployment.

For example, `oc get pod` might look like:

    NAME                       READY     REASON                                                   RESTARTS   AGE
    ruby-hello-world-1-build   1/1       Running                                                  0          1m
    ruby-hello-world-2-3jby9   0/1       Error: image library/ruby-hello-world:latest not found   0          32s

Wait for the build to complete, and you should end up with a running front-end
in a few moments. You'll probably end up with something like this:

    oc get pod
    NAME                       READY     REASON       RESTARTS   AGE
    ruby-hello-world-1-build   0/1       ExitCode:0   0          7m
    ruby-hello-world-3-eq9w3   1/1       Running      0          5m

## Test the Frontend
While it won't look great using `curl`, we can validate the frontend is running
with it. The previous steps should have resulted in a service being created:

    oc get service
    NAME               LABELS    SELECTOR                            IP(S)            PORT(S)
    ruby-hello-world   <none>    deploymentconfig=ruby-hello-world   172.30.103.182   8080/TCP

We can hit that with `curl`:

    curl -s `oc get service -n wiring ruby-hello-world --template \
    '{{.spec.portalIP}}:{{index .spec.ports 0 "port"}}'` | grep database
        <h3>(It looks like the database isn't running.  This isn't going to be much fun.)</h3>

This is good so far!

## Expose the Service
The `oc` command has a nifty subcommand called `expose` that will take a service
and automatically create a route for us. It will do this in the defined cloud
domain and in the current project as an additional "namespace" of sorts.  For
example, the steps above resulted in a service called "ruby-hello-world". We can
use `expose` against it:

    oc expose service ruby-hello-world

After a few moments:

    oc get route
    NAME               HOST/PORT                                       PATH      SERVICE            LABELS                 INSECURE POLICY   TLS TERMINATION
    ruby-hello-world   ruby-hello-world-wiring.cloudapps.example.com             ruby-hello-world   app=ruby-hello-world  

Remember, the `host` was automatically generated from the service name and the
project name. `oc expose` also takes a `--hostname` argument if you need to use
something specific.

Now you should be able to access your application with your browser! Go ahead
and do that now. You'll notice that the frontend is happy to run without a
database, but is not all that exciting. We'll fix that in a moment.

## Create the Database From the Web Console
During the installation, several templates were added for us, including some
database templates. Go to the web console and make sure you are logged in as
`alice` and using the `Exploring Parameters` project. You should see your
front-end already there. Click the "Add to Project" button. In the bottom
right-hand corner is a *Databases* section. Click "See all", and you should see
the `mysql-ephemeral` template. Click it.

You will need to edit the parameters of this template, because the defaults will
not work for us. Change the `DATABASE_SERVICE_NAME` to be "database", because
that is what service the frontend expects to connect to. Make sure that the
MySQL user, password and database match whatever values you specified in the
previous labs.

Click the "Create" button when you are ready. Then click "Continue to overview".

It may take a little while for the MySQL container to download (if you didn't
pre-fetch it). It's a good idea to verify that the database is running before
continuing.  If you don't happen to have a MySQL client installed you can still
verify MySQL is running with curl:

    curl $(oc get service database --template '{{.spec.portalIP}}:{{index .spec.ports 0 "targetPort"}}')

MySQL doesn't speak HTTP so you will see garbled output like this (however,
you'll know your database is running!):

    5.5.45}(Iw>n2J��\rJZeloiBM:{mysql_native_password!��#08S01Got packets out of order

## Visit Your Application Again
Visit your application again with your web browser. Why does it still say that
there is no database?

When the frontend was first built and created, there was no service called
"database", so the environment variable `DATABASE_SERVICE_HOST` did not get
populated with any values. Our database does exist now, and there is a service
for it, but OpenShift could not "inject" those values into the running frontend
container.

## Replication Controllers
The easiest way to get this going? Just nuke the existing pod. There is a
replication controller running for both the frontend and backend:

    oc get replicationcontroller

The replication controller is configured to ensure that we always have the
desired number of replicas (instances) running. We can look at how many that
should be:

    oc describe rc ruby-hello-world-3

*Note:* Depending on how fast you went through previous examples, you may have
only 2 replication controllers listed.

So, if we kill the pod, the RC will detect that, and fire it back up. When it
gets fired up this time, it will then have the `DATABASE_SERVICE_HOST` value,
which means it will be able to connect to the DB, which means that we should no
longer see the database error!

As `alice`, go ahead and find your frontend pod, and then kill it:

    oc delete pod `oc get pod | grep -e "hello-world-[0-9]" | grep -v build | awk '{print $1}'`

You'll see something like:

    pods/ruby-hello-world-3-wcxiw

That was the generated name of the pod when the replication controller stood it
up the first time.

After a few moments, we can look at the list of pods again:

    oc get pod | grep -v build | grep -v database

And we should see a different name for the pod this time:

    ruby-hello-world-3-xbs3o

This shows that, underneath the covers, the RC started a new pod. Since it is a
new pod, it should have a value for the `DATABASE_SERVICE_HOST` environment
variable. 

As `root` on the master, the following hideous command will bash-fu its way to
show you specific output from inspecting the Docker container running on the
right node:

    ssh $(oc get pod $(oc get pod -n wiring | grep -v build | grep world \
    | awk {'print $1'}) -n wiring --template '{{.spec.host}}') \
    'docker inspect $(docker ps | grep wiring/ruby-hello-world | \
    awk '"'"'{print $1}'"'"')' | grep -E "DATABASE|MYSQL"

The output will look something like:

    "MYSQL_USER=redhat",
    "MYSQL_PASSWORD=redhat",
    "MYSQL_DATABASE=mydb",
    "DATABASE_PORT_3306_TCP_ADDR=172.30.212.48",
    "DATABASE_PORT=tcp://172.30.212.48:3306",
    "DATABASE_PORT_3306_TCP_PROTO=tcp",
    "DATABASE_SERVICE_PORT=3306",
    "DATABASE_SERVICE_PORT_MYSQL=3306",
    "DATABASE_PORT_3306_TCP=tcp://172.30.212.48:3306",
    "DATABASE_SERVICE_HOST=172.30.212.48",
    "DATABASE_PORT_3306_TCP_PORT=3306",

## Revisit the Webpage
Go ahead and revisit
[http://ruby-hello-world.wiring.cloudapps.example.com](http://ruby-hello-world.wiring.cloudapps.example.com)
(or your appropriate FQDN) in your browser, and you should see that the
application is now fully functional!
