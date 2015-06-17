<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Project Administration](#project-administration)
  - [Deleting a Project](#deleting-a-project)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Project Administration
When we created the `demo` project, `joe` was made a project administrator. As
an example of an administrative function, if `joe` now wants to let `alice` look
at his project, with his project administrator rights he can add her using the
`oadm policy` command:

    [joe]$ oadm policy add-role-to-user view alice

**Note:** `oadm` will act, by default, on whatever project the user has
selected. If you recall earlier, when we logged in as `joe` we ended up in the
`demo` project. We'll see how to switch projects later.

Open a new terminal window as the `alice` user:

    su - alice

and login to OpenShift:

    oc login -u alice \
    --certificate-authority=/etc/openshift/master/ca.crt \
    --server=https://ose3-master.example.com:8443

You'll interact with the tool as follows:

    Authentication required for https://ose3-master.example.com:8443 (openshift)
    Password:  <redhat>
    Login successful.

    Using project "demo"
    Welcome to OpenShift! See 'oc help' to get started.

`alice` has no projects of her own yet (she is not an administrator on
anything), so she is automatically configured to look at the `demo` project
since she has access to it. She has "view" access, so `oc status` and `oc get
pods` and so forth should show her the same thing as `joe`:

    [alice]$ oc get pods
    NAME                      READY     REASON    RESTARTS   AGE
    hello-openshift-1-6a4i8   1/1       Running   0          8m

However, she cannot make changes:

    [alice]$ oc delete pod hello-openshift-1-6a4i8
    Error from server: User "alice" cannot delete pods in project "demo"

Also login as `alice` in the web console and confirm that she can view
the `demo` project.

`joe` could also give `alice` the role of `edit`, which gives her access
to do nearly anything in the project except adjust access.

    [joe]$ oadm policy add-role-to-user edit alice

Now she can delete that pod if she wants, but she can not add access for
another user or upgrade her own access. To allow that, `joe` could give
`alice` the role of `admin`, which gives her the same access as himself.

    [joe]$ oadm policy add-role-to-user admin alice

There is no "owner" of a project, and projects can certainly be created
without any administrator. `alice` or `joe` can remove the `admin`
role (or all roles) from each other or themselves at any time without
affecting the existing project.

    [joe]$ oadm policy remove-user joe

Check `oadm policy help` for a list of available commands to modify
project permissions. OpenShift RBAC is extremely flexible. The roles
mentioned here are simply defaults - they can be adjusted (per-project
and per-resource if needed), more can be added, groups can be given
access, etc. Check the documentation for more details:

* http://docs.openshift.org/latest/dev_guide/authorization.html
* https://github.com/openshift/origin/blob/master/docs/proposals/policy.md

Of course, there be dragons. The basic roles should suffice for most uses.

## Deleting a Project
Since we are done with this "demo" project, and since the `alice` user is a
project administrator, let's go ahead and delete the project. This should also
end up deleting all the pods, and other resources, too.

As the `alice` user:

    oc delete project demo

If you *very* quickly go to the web console and return to the top page, you'll
see a warning icon that will pop-up a hover tip saying the project is marked for
deletion.

If you switch to the `root` user and issue `oc get project` you will see that
the demo project's status is "Terminating". If you do an `oc get pod -n demo`
you may see the pods, still. It may take up to 60 seconds for the project
deletion cleanup routine to finish.

Once the project disappears from `oc get project`, doing `oc get pod -n demo`
should return no results.


