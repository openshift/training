<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Lifecycle Pre and Post Deployment Hooks](#lifecycle-pre-and-post-deployment-hooks)
  - [Add a Database Migration File](#add-a-database-migration-file)
  - [Examining Deployment Hooks](#examining-deployment-hooks)
  - [Modifying the Hooks](#modifying-the-hooks)
  - [Quickly Clean Up](#quickly-clean-up)
  - [Build Again](#build-again)
  - [Verify the Migration](#verify-the-migration)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Lifecycle Pre and Post Deployment Hooks
Like in OpenShift 2, we have the capability of "hooks" - performing actions both
before and after the **deployment**. In other words, once an S2I build is
complete, the resulting Docker image is pushed into the registry. Once the push
is complete, OpenShift detects an `ImageChange` and, if so configured, triggers
a **deployment**.

The *pre*-deployment hook is executed just *before* the new image is deployed.

The *post*-deployment hook is executed just *after* the new image is deployed.

How is this accomplished? OpenShift will actually spin-up an *extra* instance of
your built image, execute your hook script(s), and then shut the instance down.
Neat, huh?

## Add a Database Migration File
Since we already have our `wiring` app pointing at our forked code repository,
let's go ahead and add a database migration file. In the `content` folder you will
find a file called `1_sample_table.rb`. 

Add this file to the `db/migrate` folder of the `ruby-hello-world` repository
that you forked. If you don't add this file to the right folder, the rest of the
steps will fail.

## Examining Deployment Hooks
Take a look at the following JSON:

    "strategy": {
        "type": "Rolling",
        "rollingParams": {
            "pre": {
                "failurePolicy": "Abort",
                "execNewPod": {
                    "containerName": "ruby-helloworld",
                    "command": [
                        "/bin/true"
                    ],
                    "env": [
                        {
                            "name": "CUSTOM_VAR1",
                            "value": "custom_value1"
                        }
                    ]
                }
            },
            "post": {
                "failurePolicy": "Ignore",
                "execNewPod": {
                    "containerName": "ruby-helloworld",
                    "command": [
                        "/bin/false"
                    ],
                    "env": [
                        {
                            "name": "CUSTOM_VAR2",
                            "value": "custom_value2"
                        }
                    ]
                }
            }
        }
    },

You can see that both a *pre* and *post* deployment hook are defined. They don't
actually do anything useful. But they are good examples.

The pre-deployment hook executes "/bin/true" whose exit code is always 0 --
success. If for some reason this failed (non-zero exit), our policy would be to
`Abort` -- consider the entire deployment a failure and stop.

The post-deployment hook executes "/bin/false" whose exit code is always 1 --
failure. The policy is to `Ignore`, or do nothing. For non-essential tasks that
might rely on an external service, this might be a good policy.

More information on these strategies, the various policies, and other
information can be found in the documentation:

    https://docs.openshift.com/enterprise/latest/dev_guide/deployments.html

## Modifying the Hooks
Since we are talking about **deployments**, let's look at our
`DeploymentConfig`s. As the `alice` user in the `wiring` project:

    oc get dc

You should see something like:

    NAME               TRIGGERS                    LATEST VERSION
    database           ConfigChange, ImageChange   1
    ruby-hello-world   ConfigChange, ImageChange   4

Since we are trying to associate a Rails database migration hook with our
application, we are ultimately talking about a deployment of the frontend. If
you edit the frontend's `DeploymentConfig` as `alice`:

    oc edit dc ruby-hello-world -o json

Yes, the default for `oc edit` is to use YAML. For this exercise, JSON will be
easier as it is indentation-insensitive. Find the section that looks like the
following before continuing:

    "spec": {
        "strategy": {
            "type": "Rolling",
            "rollingParams": {
                "updatePeriodSeconds": 1,
                "intervalSeconds": 1,
                "timeoutSeconds": 600,
                "maxUnavailable": "25%",
                "maxSurge": "25%"
            },
            "resources": {}
        },

A Rails database migration is commonly performed when we have added/modified the
database as part of our code change. In the case of a pre- or post-deployment
hook, it would make sense to:

* Attempt to migrate the database
* Abort the new deployment if the database migration fails

Otherwise we could end up with our new code deployed but our database schema
would not match. This could be a *Real Bad Thing (TM)*.

In the case of the `ruby-20` builder image, we are actually using RHEL7 and the
Red Hat Software Collections (SCL) to get our Ruby 2.0 support. So, the command
we want to run looks like:

    /usr/bin/scl enable ruby200 ror40 'cd /opt/app-root/src ; bundle exec rake db:migrate'

This command:

* executes inside an SCL "shell"
* enables the Ruby 2.0.0 and Ruby On Rails 4.0 environments
* changes to the `/opt/openshift/src` directory (where our applications' code is
    located)
* executes `bundle exec rake db:migrate`

If you're not familiar with the SCL, Ruby, Rails, or Bundler, that's OK. Just
trust us.  Would we lie to you?

The `command` directive inside the hook's definition tells us which command to
actually execute. It is required that this is an array of individual strings.
Represented in JSON, our desired command above represented as a string array
looks like:

    "command": [
        "/usr/bin/scl",
        "enable",
        "ruby200",
        "ror40",
        "cd /opt/app-root/src ; bundle exec rake db:migrate"
    ]

This is great, but actually manipulating the database requires that we talk
**to** the database. Talking to the database requires a user and a password.
Smartly, our hook pods inherit the same environment variables as the main
deployed pods, so we'll have access to the same datbase information.

Looking at the original hook example in the previous section, and our command
reference above, in the end, you will have something that looks like:

    "strategy": {
        "type": "Rolling",
        "rollingParams": {
            "pre": {
                "failurePolicy": "Abort",
                "execNewPod": {
                    "command": [
                        "/usr/bin/scl",
                        "enable",
                        "ruby200",
                        "ror40",
                        "cd /opt/app-root/src ; bundle exec rake db:migrate"
                    ],
                    "containerName": "ruby-hello-world"
                }
            },
            "updatePeriodSeconds": 1,
            "intervalSeconds": 1,
            "timeoutSeconds": 600,
            "maxUnavailable": "25%",
            "maxSurge": "25%"
        },
        "resources": {}
    },

Remember, indentation isn't critical in JSON, but closing brackets and braces
are. When you are done editing the deployment config, save and quit your editor.

## Quickly Clean Up
When we did our previous builds and rollbacks and etc, we ended up with a lot of
stale pods that are not running (`Succeeded`). Currently we do not auto-delete
these pods because we have no log store -- once they are deleted, you can't view
their logs any longer.

For now, we can clean up by doing the following as `alice`:

    oc get pod |\
    grep -E "[0-9]-build" |\
    awk {'print $1'} |\
    xargs -r oc delete pod

This will get rid of all of our old build pods.

## Build Again
Now that we have modified the deployment configuration and cleaned up a bit, we
need to trigger another deployment. While killing the frontend pod would trigger
another deployment, our current Docker image doesn't have the database migration
file in it. Nothing really useful would happen.

In order to get the database migration file into the Docker image, we actually
need to do another build. Remember, the S2I process starts with the builder
image, fetches the source code, executes the (customized) assemble script, and
then pushes the resulting Docker image into the registry. **Then** the
deployment happens.

Before we start the next build, we will have to remove the quota on the wiring
project. Since there is already a database, and an existing frontend, when the
deployment pod is launched, we will run out of quota.

As `root`, perform the following:

    oc delete quota/wiring-quota -n wiring

As `alice`:

    oc start-build ruby-hello-world

Or go into the web console and click the "Build" button in the Builds
area.

## Verify the Migration
If you run `oc get pod -w` as `alice` after starting the build, you might catch
the `prehook` pod show up and then disappear. This is the pod where our hook is
actually running. If the hook completes successfully, the pod goes away. In the
end, if you do `oc get pod` as `alice` again,y ou'll probably see:

    NAME                        READY     STATUS      RESTARTS   AGE
    database-1-edgvy            1/1       Running     0          1h
    ruby-hello-world-4-build    0/1       Completed   0          6m
    ruby-hello-world-4-8v0ui    1/1       Running     0          24s

** NOTE **
Lifecycle pods are currently deleted. Without centralized logging, it's not
really easy to see the log of what happened. 

While the Advanced section of this material does talk about how you can
implement centralized logging, you can see the upstream work on deployer/hook
pods here:

    https://trello.com/c/5Pt8kGwT/506-support-cleanup-policy-for-deployer-pods

Since we know that we are on the "4th" deployment, we can look for the pod.
You'll have to do the following as `root` on the master:

    for node in ose3-master ose3-node1 ose3-node2; do echo -e "\n$node";\
    ssh $node.example.com "docker ps -a | grep hello-world-4-prehook |\
    grep -v pod | awk {'print \$1'}"; done

You might see some output like:

    ose3-master
    
    ose3-node1
    695f891aca39
    
    ose3-node2

This tells us the pod was apparently on node 1. Then, we can do the following,
again, as `root`:

    ssh ose3-node1.example.com "docker logs 695f891aca39"

The output should show something like:

    == 1 SampleTable: migrating ===================================================
    -- create_table(:sample_table)
       -> 0.1075s
    == 1 SampleTable: migrated (0.1078s) ==========================================

If you have no output, you may have forgotten to actually put the migration file
in your repo. Without that file, the migration does nothing, which produces no
output.

Another way to validate the migration is to talk directly to the database on its
service IP/port using the `mysql` client and the environment variables (you
would need the `mysql` package installed on your master, for example).

As `alice`, find your database:

    [alice@ose3-master beta4]$ oc get service
    NAME               CLUSTER_IP       EXTERNAL_IP   PORT(S)    SELECTOR                                                 AGE
    database           172.30.223.253   <none>        3306/TCP   name=database                                            2h
    ruby-hello-world   172.30.234.149   <none>        8080/TCP   app=ruby-hello-world,deploymentconfig=ruby-hello-world   2h

You can double check your environment variables from the web UI or from the CLI,
as `alice`, using:

    oc env dc/database --list
    # deploymentconfigs database, container mysql
    MYSQL_USER=redhat
    MYSQL_PASSWORD=redhat
    MYSQL_DATABASE=mydb

Then, somewhere inside your OpenShift environment, use the `mysql` client to
connect to this service and dump the table that we created:

    mysql -uredhat -predhat \
    -h 172.30.223.253 \
    -e 'show tables; describe sample_table;' mydb
    +-------------------+
    | Tables_in_root    |
    +-------------------+
    | sample_table      |
    | key_pairs         |
    | schema_migrations |
    +-------------------+
    +-------+--------------+------+-----+---------+----------------+
    | Field | Type         | Null | Key | Default | Extra          |
    +-------+--------------+------+-----+---------+----------------+
    | id    | int(11)      | NO   | PRI | NULL    | auto_increment |
    | name  | varchar(255) | NO   |     | NULL    |                |
    +-------+--------------+------+-----+---------+----------------+


