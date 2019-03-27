# Configuring Authentication
OpenShift 4 installs with two effective superusers:

* `kubeadmin` (technically an alias for `kube:admin`)
* `system:admin`

Why two? Because `system:admin` is a user that uses a certificate to login
and has no password. Therefore this superuser cannot log-in to the web
console (which requires a password).

If you want additional users to be able to authenticate to and use the
cluster, you must configure an authentication provider. The documentation
provides some [background on authentication in
OpenShift](https://docs.openshift.com/container-platform/4.0/authentication/understanding-authentication.html).

# htpasswd Authentication
The documentation covers [configuring htpasswd as an identity
provider](https://docs.openshift.com/container-platform/4.0/authentication/identity_providers/configuring-htpasswd-identity-provider.html).

## The htpasswd File
You can create an `htpasswd` file in whatever way suits you. You can use the
`htpasswd` utility provided by `httpd-tools`, or you can do something like:

```sh
printf "USER:$(openssl passwd -apr1 PASSWORD)\n >> /path/to/htpasswd"
```

or any number of other mechanisms. If you don't want to create a file, you
can use the following sample file:

https://github.com/openshift/training/blob/master/assets/htpasswd

Note that all users have the password `openshift4`.

Make sure you know what your file is called. We use a file called `htpasswd`
in the rest of the examples.

## The CustomResource
You might be wondering why `apply` was used here. It is because there is an
existing `OAuth` called `cluster`. The CRD that defines `OAuth` is
`oauths.config.openshift.io`. It is a cluster-scoped object. The `apply`
command will overwrite existing objects.

## Test Authentication
When you created the CR, the authentication operator reconfigured the cluster
to use htpasswd authentication. After a few moments, you should be able to
`oc login` as one of the users you created. If you used our example file, we
have a user called `susan`:

```sh
oc login -u susan -p openshift4
```

You should see something like the following:

```
Login successful.

You don't have any projects. You can try to create a new project, by running

    oc new-project <projectname>
```

# Extensions with Operators
You can extend your cluster to do many more exciting things using Operators.
Take a look at the [extensions](07-extensions.md) section for an example of
using Couchbase.
