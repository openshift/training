# Troubleshooting
This section helps troubleshoot various issues that you might encounter
during your exploration of OpenShift 4.

## Installation
There are a number of problems that commonly occur that we have documented in
the [installer's GitHub
repository](https://github.com/openshift/installer/blob/master/docs/user/troubleshooting.md).
If you don't find your particular issue, as of the time of this writing, you
will need to do a fresh install.

If you used the `--dir` option when you installed, you already have a
separate folder somewhere that contains the artifacts. If you did **NOT** use
the `--dir` option during the installation, you will want to capture and
retain installer log.

        mv .openshift_install.log openshift_install_fail_logs

In either case, please try to capture any console output from the installer
to a separate file.

Then, [clean up your cluster](08-cleanup.md).

Finally, re-start the install process

        ./openshift-install create cluster

