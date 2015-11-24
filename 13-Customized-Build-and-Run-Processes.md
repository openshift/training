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

    https://docs.openshift.com/enterprise/latest/creating_images/s2i.html#s2i-scripts

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

**Note:** If you know how to Git(Hub), you can do this via your shell.

There is also a `run` script in the `content` folder. Upload that to the
`.sti/bin` folder as well.

Once the file is added, we can now do another build. The "custom" assemble
script will log some extra data.

## Kick Off a Build
Our old friend `curl` is back:

    curl -i -H "Accept: application/json" \
    -H "X-HTTP-Method-Override: PUT" -X POST -k \
    https://ose3-master.example.com:8443/oapi/v1/namespaces/wiring/buildconfigs/ruby-hello-world/webhooks/1B-cP1NWmH2U0U247ob2/generic

You could also use `oc start-build` or use the web console. Whatever suits your
fancy.

## Watch the Build Logs
Using the skills you have learned, watch the build logs for this build. Did You See It?

    ---> CUSTOM S2I ASSEMBLE COMPLETE

But where is the output from our custom run? The `run` script actually is what
is executed to "start" your application's pod.  In other words, the `run` script
is what starts the Ruby process for an image that was built based on the
`ruby-20-rhel7` S2I builder. So where would you find this output? In the pod's
log. Use the web console or "oc logs" to check out the pod that was deployed as
a result of this build.

