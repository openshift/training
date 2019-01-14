# Troubleshooting
This section helps troubleshoot various issues that you might encounter
during your exploration of OpenShift 4.

## Installation
There are a number of problems that commonly occur that we have documented in
the
[https://github.com/openshift/installer/blob/master/docs/user/troubleshooting.md](installer's
GitHub repository). If you don't find your particular issue, as of the time
of this writing, you will need to do a fresh install.

Please capture the console output and the installer log. 

        mv .openshift_install.log openshift_install_fail_logs

Then, [clean up your cluster](05-cleanup.md).

Finally, re-start the install process

        ./openshift-install create cluster

