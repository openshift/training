# Configuring Authentication
OpenShift 4 installs with only a single cluster superuser, `kubeadmin`. If
you want additional users to be able to authenticate to and use the cluster,
you must configure an authentication provider. We will configure `htpasswd`
authentication as an example.

## Create the htpasswd file
You can create an `htpasswd` file in whatever way suits you. You can use the
`htpasswd` utility, you can do something like:

```sh
printf "USER:$(openssl passwd -crypt PASSWORD)\n"
```

or any number of other mechanisms. If you don't want to create a file, you
can use the following sample file:

hhhhh

Note that all users have the password `openshift4`.

Make sure you know what your file is called. We use a file called `htpasswd`
in the rest of the examples.

## Create the htpasswd secret
The authentication operator will read the `htpasswd` file from a secret in
the `openshift-config` project. Go ahead and create that secret using the
following command:

```sh
oc create secret generic htpass-secret --from-file=htpasswd=</path/to/htpasswd> -n openshift-config
```
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

```sh
oc apply -f lkajdsf
```

You might be wondering why `apply` was used here. It is because there is an
existing `OAuth` called `cluster`. The `apply` command will overwrite
existing objects.

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

# End of Materials
Congratulations. You have reached the end of the materials. Feel free to
explore this repository as there are some other examples that have not been
tested. And, of course, explore your cluster.

If you are done, you can proceed to [cleanup your cluster](08-cleanup.md)
