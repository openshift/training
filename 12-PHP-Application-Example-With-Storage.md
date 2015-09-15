<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [A Simple PHP Example](#a-simple-php-example)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# A Simple PHP Example
Let's take some time to build a simple PHP example. Using PHP will make it easy
for us to demonstrate persistent storage.

## Create a PHP Project
As `alice`, create a project called `php-upload`.

## Build the App
The source code for the application is here:

    https://github.com/thoraxe/openshift-php-upload-demo

Using the skills you've learned so far, get this code running in your new
project. Remember that you'll have to select the PHP builder (if you use the
WebUI). Call this new application/service "demo".

## Create a Route
Using the skills you've learned so far, use the `expose` subcommand to create a
route for your app. If you used the WebUI, make sure you created a default
route.

## Visit the Application
Once your code is built, visit your application. Your URL probably looks
something like:

    http://demo-php-upload.cloudapps.example.com/

There should be a file picker and an upload button. Try to upload something and
see what happens.

## Error!
You are not allowed to upload a file. This is because the area of the Docker
image where the applicaion content lives (`/opt/app-root/src/`) is not writeable
by the user that is running the PHP process.

You can see this by doing something like the following:

    oc exec demo-1-kly7h -- sh -c 'whoami; ls -al'
    whoami: cannot find name for user ID 1000100000
    total 24
    drwxr-xr-x. 3 default default 4096 Sep 15 14:36 .
    drwxr-xr-x. 4 default default 4096 Sep  8 12:41 ..
    -rw-r--r--. 1 default default  365 Sep 15 14:36 index.html
    -rw-r--r--. 1 default default   20 Sep 15 14:36 info.php
    -rw-r--r--. 1 default default  700 Sep 15 14:36 upload.php
    drwxr-xr-x. 2 default default 4096 Sep 15 14:36 uploaded

You can see that the user you are (1000100000) is not who owns the `uploaded`
folder (`default`). And the `uploaded` folder does not have world-writeable
permissions.

But, that's OK, because we're going to add storage to our application
containers.

## Export Another NFS Export
Earlier in the labs you created an NFS export to store your Docker registry
data. We're going to add another one for use with this PHP application. On your
*master* and as *root*:

1. Create the directory we will export:

        mkdir -p /var/export/vol1
        chown nobody:nobody /var/export/vol1
        chmod 777 /var/export/vol1

1. Edit `/etc/exports` and add the following line:

        /var/export/vol1 *(rw,sync,all_squash)

1. Execute `exportfs -r` to tell NFS to refresh its exports.

You can validate that your new export is there with the following:

    showmount -e
    Export list for ose3-master.example.com:
    /var/export/vol1   *
    /var/export/regvol *

## Create a PersistentVolume
Much like with the registry, it's up to an administrator to create a
PersistentVolume. The following JSON definition can be found in
`content/php-volume.json`:

    {
      "apiVersion": "v1",
      "kind": "PersistentVolume",
      "metadata": {
        "name": "php-volume"
      },
      "spec": {
        "capacity": {
            "storage": "3Gi"
            },
        "accessModes": [ "ReadWriteMany" ],
        "nfs": {
            "path": "/var/export/vol1",
            "server": "ose3-master.example.com"
        }
      }
    }

As the *root* user, go ahead and create this volume:

    oc create ~/training/content/php-volume.json
