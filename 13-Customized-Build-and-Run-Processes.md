<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Customized Build and Run Processes](#customized-build-and-run-processes)
  - [Add a Script](#add-a-script)
  - [Kick Off a Build](#kick-off-a-build)
  - [Watch the Build Logs](#watch-the-build-logs)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Customized Build and Run Processes
OpenShift v3 supports customization of both the build and run processes.
Generally speaking, this involves modifying the various S2I scripts from the
builder image. When OpenShift builds your code, it checks to see if any of the
scripts in the `.sti/bin` folder of your repository override/supercede the
builder image's scripts. If so, it will execute the repository script instead.

More information on the scripts, their execution during the process, and
customization can be found here:

    https://docs.openshift.com/enterprise/3.0/creating_images/s2i.html#s2i-scripts

## Add a Script
We will be performing these actions as `alice` in the *wiring* project that we
created earlier. In Chapter 11 we forked the Github repository and edited our
`buildConfig` to point at it. So we'll keep using it.

You will find a script called `assemble` in the `content` folder of the training
materials. Go to your forked Github repository for `ruby-hello-world`, and find
the `.sti/bin` folder.

* Click the "+" button at the top (to the right of `bin` in the
    breadcrumbs).
* Name your file `assemble`.
* Paste the contents of `assemble` into the text area.
* Provide a nifty commit message.
* Click the "commit" button.

**Note:** If you know how to Git(hub), you can do this via your shell.

Once the file is added, we can now do another build. The "custom" assemble
script will log some extra data.

## Kick Off a Build
Our old friend `curl` is back:

    curl -i -H "Accept: application/json" \
    -H "X-HTTP-Method-Override: PUT" -X POST -k \
    https://ose3-master.example.com:8443/osapi/v1beta3/namespaces/wiring/buildconfigs/ruby-example/webhooks/secret101/generic

## Watch the Build Logs
Using the skills you have learned, watch the build logs for this build. If you
miss them, remember that you can find the Docker container that ran the build
and look at its Docker logs.

Did You See It?

    2015-03-11T14:57:00.022957957Z I0311 10:57:00.022913       1 sti.go:357]
    ---> CUSTOM S2I ASSEMBLE COMPLETE

But where's the output from the custom `run` script? The `assemble` script is
run inside of your builder pod. That's what you see by using `build-logs` - the
output of the assemble script. The
`run` script actually is what is executed to "start" your application's pod. In
other words, the `run` script is what starts the Ruby process for an image that
was built based on the `ruby-20-rhel7` S2I builder. 

To look inside the builder pod, as `alice`:

    oc logs `oc get pod | grep -e "[0-9]-build" | tail -1 | awk {'print $1'}` | grep CUSTOM

You should see something similar to:

    2015-04-27T22:23:24.110630393Z ---> CUSTOM S2I ASSEMBLE COMPLETE
