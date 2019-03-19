# Configuring Authentication
OpenShift 4 installs with two effective superusers out of the box:

* `kubeadmin` (technically an alias for `kube:admin`)
* `system:admin`

Why two? Because `system:admin` is a user that uses a certificate to login
and has no password. Therefore this superuser cannot log-in to the web
console (which requires a password).

If you want additional users to be able to authenticate to and use the
cluster, you must configure an authentication provider. In this example we will
configure a basic `htpasswd` implementation that relies on a specific
authentication file that's hashed for security. Production environments would
rely on something much more comprehensive and scalable.

## Create the htpasswd file
You can create an `htpasswd` file in whatever way suits you. You can use the
`htpasswd` utility, you can do something like:

~~~bash
$ printf "USER:$(openssl passwd -apr1 openshift4)\n" >> /path/to/htpasswd"
~~~

...or any number of other mechanisms. If you don't want to create a file, you
can use the following sample file:

https://github.com/openshift/training/blob/master/assets/htpasswd

Note that all users have the password `openshift4`.

Make sure you know what your file is called. We use a file called `htpasswd`
in the rest of the examples.

## Create the htpasswd secret
The authentication operator will read the `htpasswd` file from a secret in
the `openshift-config` project. Go ahead and create that secret using the
following command:

~~~bash
$ oc create secret generic htpass-secret --from-file=htpasswd=</path/to/htpasswd> -n openshift-config
~~~

## Create the identity provider Custom Resource
The operator that configures authentication is looking for a `CustomResource`
object. In our case, we want one that tells it to configure htpasswd
authentication using the provided secret. Here's what that definition looks
like:

```YAML
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
  - name: my_htpasswd_provider 
    challenge: true 
    login: true 
    mappingMethod: claim 
    type: HTPasswd
    htpasswd:
      fileData:
        name: htpass-secret 
```

If you are interested, the CRD that defines `OAuth` is
`oauths.config.openshift.io`. It is a cluster-scoped object. Go ahead and
create the CR for auth with the following command:

~~~bash
$ oc apply -f https://raw.githubusercontent.com/openshift/training/master/assets/htpasswd-cr.yaml
~~~

You might be wondering why `apply` was used here. It is because there is an
existing `OAuth` called `cluster`. The `apply` command will overwrite
existing objects.

## Test Authentication
When you created the CR, the authentication operator reconfigured the cluster
to use htpasswd authentication. After a few moments, you should be able to
`oc login` as one of the users you created. If you used our example file, we
have a user called `susan`:

~~~bash
oc login -u susan -p openshift4
~~~

You should see something like the following:

```
Login successful.

You don't have any projects. You can try to create a new project, by running

    oc new-project <projectname>
```

## Return to the Admin User

Before proceeding with the rest of the instructions, log back in as the
administrator using the administrator credentials you were provided with
when you installed OpenShift.

~~~bash
$ oc login
Authentication required for https://... (openshift)
Username: <your username>
Password: <your password>

Login successful.
(...)
~~~

# Extensions with Operators
You can extend your cluster to do many more exciting things using Operators.
Take a look at the [extensions](07-extensions.md) section for an example of
using Couchbase.
