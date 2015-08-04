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
        "type": "Recreate",
        "resource": {},
        "recreateParams": {
            "pre": {
                "failurePolicy": "Abort",
                "execNewPod": {
                    "command": [
                        "/bin/true"
                    ],
                    "env": [
                        {
                            "name": "CUSTOM_VAR1",
                            "value": "custom_value1"
                        }
                    ],
                    "containerName": "ruby-helloworld"
                }
            },
            "post": {
                "failurePolicy": "Ignore",
                "execNewPod": {
                    "command": [
                        "/bin/false"
                    ],
                    "env": [
                        {
                            "name": "CUSTOM_VAR2",
                            "value": "custom_value2"
                        }
                    ],
                    "containerName": "ruby-helloworld"
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

    https://docs.openshift.com/enterprise/3.0/dev_guide/deployments.html

## Modifying the Hooks
Since we are talking about **deployments**, let's look at our
`DeploymentConfig`s. As the `alice` user in the `wiring` project:

    osc get dc

You should see something like:

    NAME               TRIGGERS                    LATEST VERSION
    database           ConfigChange, ImageChange   1
    ruby-hello-world   ConfigChange, ImageChange   4

Since we are trying to associate a Rails database migration hook with our
application, we are ultimately talking about a deployment of the frontend. If
you edit the frontend's `DeploymentConfig` as `alice`:

    osc edit dc ruby-hello-world -ojson

Yes, the default for `osc edit` is to use YAML. For this exercise, JSON will be
easier as it is indentation-insensitive. Find the section that looks like the
following before continuing:

    "spec": {
        "strategy": {
            "type": "Recreate",
            "resources": {}
        },

A Rails migration is commonly performed when we have added/modified the database
as part of our code change. In the case of a pre- or post-deployment hook, it
would make sense to:

* Attempt to migrate the database
* Abort the new deployment if the migration fails

Otherwise we could end up with our new code deployed but our database schema
would not match. This could be a *Real Bad Thing (TM)*.

In the case of the `ruby-20` builder image, we are actually using RHEL7 and the
Red Hat Software Collections (SCL) to get our Ruby 2.0 support. So, the command
we want to run looks like:

    /usr/bin/scl enable ruby200 ror40 'cd /opt/openshift/src ; bundle exec rake db:migrate'

This command:

* executes inside an SCL "shell"
* enables the Ruby 2.0.0 and Ruby On Rails 4.0 environments
* changes to the `/opt/openshift/src` directory (where our applications' code is
    located)
* executes `bundle exec rake db:migrate`

If you're not familiar with Ruby, Rails, or Bundler, that's OK. Just trust us.
Would we lie to you?

The `command` directive inside the hook's definition tells us which command to
actually execute. It is required that this is an array of individual strings.
Represented in JSON, our desired command above represented as a string array
looks like:

    "command": [
        "/usr/bin/scl",
        "enable",
        "ruby200",
        "ror40",
        "cd /opt/openshift/src ; bundle exec rake db:migrate"
    ]

This is great, but actually manipulating the database requires that we talk
**to** the database. Talking to the database requires a user and a password.
Smartly, our hook pods inherit the same environment variables as the main
deployed pods, so we'll have access to the same datbase information.

Looking at the original hook example in the previous section, and our command
reference above, in the end, you will have something that looks like:

    "strategy": {
        "type": "Recreate",
        "resources": {},
        "recreateParams": {
            "pre": {
                "failurePolicy": "Abort",
                "execNewPod": {
                    "command": [
                        "/usr/bin/scl",
                        "enable",
                        "ruby200",
                        "ror40",
                        "cd /opt/openshift/src ; bundle exec rake db:migrate"
                    ],
                    "containerName": "ruby-hello-world"
                }
            },
        }
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

This will get rid of all of our old build and lifecycle pods. The lifecycle pods
are the pre- and post-deployment hook pods, and the sti-build pods are the pods
in which our previous builds occurred.

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

As `alice`:

    oc start-build ruby-hello-world

Or go into the web console and click the "Start Build" button in the Builds
area.

## Verify the Migration
About a minute after the build completes, you should see something like the following output
of `oc get pod` as `alice`:

    NAME                         READY     REASON    RESTARTS   AGE
    database-1-817tj             1/1       Running   1          3d
    ruby-hello-world-3-build     1/1       Running   0          37s
    ruby-hello-world-4-pab66     1/1       Running   1          2h
    ruby-hello-world-5-deploy    1/1       Running   0          4s
    ruby-hello-world-5-prehook   0/1       Pending   0          1s

** NOTE **
You might see that there is a single `prehook` pod -- this corresponds
with the pod that ran our pre-deployment hook. If you don't see it, that's OK,
too, because right now there's a bug where the hook pods get deleted after
exiting:

(https://bugzilla.redhat.com/show_bug.cgi?id=1247735)

Since we know that we are on the "5th" deployment, we can look for the pod.
You'll have to do the following as `root`:

    for node in ose3-master ose3-node1 ose3-node2; do echo -e "\n$node";\
    ssh $node "docker ps -a | grep hello-world-5-prehook |\
    grep -v pod | awk {'print \$1'}"; done

You might see some output like:

    ose3-master
    
    ose3-node1
    695f891aca39
    
    ose3-node2

This tells us the pod is apparently on node 1. Then, we can do the following,
again, as `root`:

    ssh ose3-node1 "docker logs 695f891aca39"

The output should show something like:

    == 1 SampleTable: migrating ===================================================
    -- create_table(:sample_table)
       -> 0.1075s
    == 1 SampleTable: migrated (0.1078s) ==========================================

If you have no output, you may have forgotten to actually put the migration file
in your repo. Without that file, the migration does nothing, which produces no
output.

For giggles, you can even talk directly to the database on its service IP/port
using the `mysql` client and the environment variables (you would need the
`mysql` package installed on your master, for example).

As `alice`, find your database:

    [alice@ose3-master beta4]$ osc get service
    NAME       LABELS    SELECTOR        IP(S)            PORT(S)
    database   <none>    name=database   172.30.108.133   5434/TCP
    frontend   <none>    name=frontend   172.30.229.16    5432/TCP

Then, somewhere inside your OpenShift environment, use the `mysql` client to
connect to this service and dump the table that we created:

    mysql -u userJKL \
      -p 5678efgh \
      -h 172.30.108.133 \
      -P 5434 \
      -e 'show tables; describe sample_table;' \
      root
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


