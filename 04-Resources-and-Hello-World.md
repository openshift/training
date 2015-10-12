<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Your First Application](#your-first-application)
  - [Resources](#resources)
  - [Applying Quota to Projects](#applying-quota-to-projects)
  - [Applying Limit Ranges to Projects](#applying-limit-ranges-to-projects)
  - [Login](#login)
  - [Grab the Training Repo Again](#grab-the-training-repo-again)
  - [The Hello World Definition JSON](#the-hello-world-definition-json)
  - [Create the Pod](#create-the-pod)
  - [Examining the Created Pod](#examining-the-created-pod)
  - [Looking at the Pod in the Web Console](#looking-at-the-pod-in-the-web-console)
  - [Quota Usage](#quota-usage)
  - [Delete the Pod](#delete-the-pod)
  - [Quota Enforcement](#quota-enforcement)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Your First Application
At this point you essentially have a sufficiently-functional V3 OpenShift
environment. It is now time to create the classic "Hello World" application
using some sample code.  But, first, some housekeeping.

Also, don't forget, the materials for these examples are in your
`~/training/content` folder.

## Resources
There are a number of different resource types in OpenShift 3, and, essentially,
going through the motions of creating/destroying apps, scaling, building and
etc. all ends up manipulating OpenShift and Kubernetes resources under the
covers. Resources can have quotas enforced against them, so let's take a moment
to look at some example JSON for project resource quota might look like:

    {
      "apiVersion": "v1",
      "kind": "ResourceQuota",
      "metadata": {
        "name": "test-quota"
      },
      "spec": {
        "hard": {
          "memory": "512Mi",
          "cpu": "200m",
          "pods": "3",
          "services": "3",
          "replicationcontrollers": "3",
          "resourcequotas": "1"
        }
      }
    }

The above quota (simply called *test-quota*) defines limits for several
resources. In other words, within a project, users cannot "do stuff" that will
cause these resource limits to be exceeded. Since quota is enforced at the
project level, it is up to the users to allocate resources (more specifically,
memory and CPU) to their pods/containers. OpenShift will soon provide sensible
defaults.

* Memory

    The memory figure is in bytes, but various other suffixes are supported (eg:
    Mi (mebibytes), Gi (gibibytes), etc.

* CPU

    CPU is a little tricky to understand. The unit of measure is actually a
    "Kubernetes Compute Unit" (KCU, or "kookoo"). The KCU is a "normalized" unit
    that should be roughly equivalent to a single hyperthreaded CPU core.
    Fractional assignment is allowed. For fractional assignment, the
    **m**illicore may be used (eg: 200m = 0.2 KCU)

We will get into a description of what pods, services and replication
controllers are over the next few labs. Lastly, we can ignore "resourcequotas",
as it is a bit of a trick so that Kubernetes doesn't accidentally try to apply
two quotas to the same namespace.

## Applying Quota to Projects
At this point we have created our "demo" project, so let's apply the quota above
to it. Still in a `root` terminal in the `training/beta4` folder:

    oc create -f quota.json -n demo

If you want to see that it was created:

    oc get -n demo quota
    NAME
    test-quota

And if you want to verify limits or examine usage:

    oc describe quota test-quota -n demo
    Name:                   test-quota
    Resource                Used    Hard
    --------                ----    ----
    cpu                     0m      200m
    memory                  0       512Mi
    pods                    0       3
    replicationcontrollers  0       3
    resourcequotas          1       1
    services                0       3

If you go back into the web console and click into the "OpenShift 3 Demo"
project, and click on the *Settings* tab, you'll see that the quota information
is displayed.

**Note:** Once creating the quota, it can take a few moments for it to be fully
processed. If you get blank output from the `get` or `describe` commands, wait a
few moments and try again.

## Applying Limit Ranges to Projects
In order for quotas to be effective you need to also create Limit Ranges
which set the maximum, minimum, and default allocations of memory and cpu at
both a pod and container level. Without default values for containers projects
with quotas will fail because the deployer and other infrastructure pods are
unbounded and therefore forbidden.

As `root` in the `training/content` folder:

    oc create -f limits.json -n demo

Review your limit ranges

    oc describe limitranges limits -n demo
    Name:           limits
    Type            Resource        Min     Max     Default
    ----            --------        ---     ---     ---
    Pod             memory          5Mi     750Mi   -
    Pod             cpu             10m     500m    -
    Container       cpu             10m     500m    100m
    Container       memory          5Mi     750Mi   100Mi

## Login
Since we have taken the time to create the *joe* user as well as a project for
him, we can log into a terminal as *joe* and then set up the command line
tooling.

Open a terminal as `joe`:

    # su - joe

Then, execute:

    oc login -u joe \
    --certificate-authority=/etc/openshift/ca.crt \
    --server=https://ose3-master.example.com:8443

OpenShift, by default, is using a self-signed SSL certificate, so we must point
our tool at the CA file.

The `login` process created a file called named `~/.kube/config`
folder. Take a look at it, and you'll see something like the following:

    apiVersion: v1
    clusters:
    - cluster:
        certificate-authority: ../../../etc/openshift/master/ca.crt
        server: https://ose3-master.example.com:8443
      name: ose3-master-example-com:8443
    contexts:
    - context:
        cluster: ose3-master-example-com:8443
        namespace: demo
        user: joe/ose3-master-example-com:8443
      name: demo/ose3-master-example-com:8443/joe
    current-context: demo/ose3-master-example-com:8443/joe
    kind: Config
    preferences: {}
    users:
    - name: joe/ose3-master-example-com:8443
      user:
        token: zXv6pSi0Hw3tT6T7hqlnnyDjypel1BcUBUO2vavHDcE

This configuration file has an authorization token, some information about where
our server lives, our project, etc.

## Grab the Training Repo Again
Since Joe and Alice can't access the training folder in root's home directory,
go ahead and grab it inside Joe's home folder:

    cd
    git clone https://github.com/openshift/training.git
    cd ~/training/content

## The Hello World Definition JSON
In the beta4 training folder, you can see the contents of our pod definition by
using `cat`:

    cat hello-pod.json
    {
      "kind": "Pod",
      "apiVersion": "v1",
      "metadata": {
        "name": "hello-openshift",
        "creationTimestamp": null,
        "labels": {
          "name": "hello-openshift"
        }
      },
      "spec": {
        "containers": [
          {
            "name": "hello-openshift",
            "image": "openshift/hello-openshift",
            "ports": [
              {
                "containerPort": 8080,
                "protocol": "TCP"
              }
            ],
            "resources": {
            },
            "terminationMessagePath": "/dev/termination-log",
            "imagePullPolicy": "IfNotPresent",
            "capabilities": {},
            "securityContext": {
              "capabilities": {},
              "privileged": false
            }
          }
        ],
        "restartPolicy": "Always",
        "dnsPolicy": "ClusterFirst",
        "serviceAccount": ""
      },
      "status": {}
    }

In the simplest sense, a *pod* is an instance of something. If you are familiar
with OpenShift V2 terminology, it is similar to a *gear*.  Reality is more
complex, and we will learn more about the terms as we explore OpenShift further.

## Create the Pod
As `joe`, to create the pod from our JSON file, execute the following:

    oc create -f hello-pod.json

Remember, we've "logged in" to OpenShift and our project, so this will create
the pod inside of it. The command should display the ID of the pod:

    pods/hello-openshift

Issue a `get pods` to see the details of how it was defined:

    oc get pods
    NAME              READY     REASON    RESTARTS   AGE
    hello-openshift   1/1       Running   0          3m

To find out more information about this pod, use `describe`:

    oc describe pod hello-openshift
    Name:                           hello-openshift
    Image(s):                       openshift/hello-openshift
    Host:                           ose3-node2.example.com/192.168.133.4
    Labels:                         name=hello-openshift
    Status:                         Running
    IP:                             10.1.0.3
    Replication Controllers:        <none>
    Containers:
      hello-openshift:
        Image:              openshift/hello-openshift
        State:              Running
          Started:          Wed, 22 Jul 2015 16:42:32 -0400
        Ready:              True
        Restart Count:      0
    Conditions:
      Type          Status
      Ready         True 
    Events:
      FirstSeen                             LastSeen                        Count   From                                    SubobjectPath                           Reason          Message
      Wed, 22 Jul 2015 16:42:30 -0400       Wed, 22 Jul 2015 16:42:30 -0400 1       {scheduler }                                                                    scheduled       Successfully assigned hello-openshift to ose3-node2.example.com
      Wed, 22 Jul 2015 16:42:31 -0400       Wed, 22 Jul 2015 16:42:31 -0400 1       {kubelet ose3-node2.example.com}        implicitly required container POD       pulled          Successfully pulled image "openshift3/ose-pod:v3.0.0.1"
      Wed, 22 Jul 2015 16:42:31 -0400       Wed, 22 Jul 2015 16:42:31 -0400 1       {kubelet ose3-node2.example.com}        implicitly required container POD       created         Created with docker id bd0e34b2310567aa8e05f65cd9c8d3fca6b5b5fdb328b55dd3ff2463d9c2f64d
      Wed, 22 Jul 2015 16:42:31 -0400       Wed, 22 Jul 2015 16:42:31 -0400 1       {kubelet ose3-node2.example.com}        implicitly required container POD       started         Started with docker id bd0e34b2310567aa8e05f65cd9c8d3fca6b5b5fdb328b55dd3ff2463d9c2f64d
      Wed, 22 Jul 2015 16:42:32 -0400       Wed, 22 Jul 2015 16:42:32 -0400 1       {kubelet ose3-node2.example.com}        spec.containers{hello-openshift}        created         Created with docker id 2706a87bd2c04f3ed216b704ee391910556aeea89c00f02ea1e990cd37e266af
      Wed, 22 Jul 2015 16:42:32 -0400       Wed, 22 Jul 2015 16:42:32 -0400 1       {kubelet ose3-node2.example.com}        spec.containers{hello-openshift}        started         Started with docker id 2706a87bd2c04f3ed216b704ee391910556aeea89c00f02ea1e990cd37e266af

On the node where the pod is running (`Host`), look at the list of Docker
containers with `docker ps` (in a `root` terminal) to see the bound ports.  We
should see an `openshift3/ose-pod` container bound to 36061 on the host and
bound to 8080 on the container, along with several other `ose-pod` containers.

    CONTAINER ID        IMAGE                              COMMAND              CREATED             STATUS              PORTS                     NAMES
    4827cf917252        openshift/hello-openshift:latest   "/hello-openshift"   2 minutes ago       Up 2 minutes                                  k8s_hello-openshift.d44dd8de_hello-openshift_demo_8125e12c-146c-11e5-8947-525400b33d1d_911c4fba   
    273ed184353e        openshift3/ose-pod:v0.6.1.0        "/pod"               2 minutes ago       Up 2 minutes        0.0.0.0:36061->8080/tcp   k8s_POD.b5bfe575_hello-openshift_demo_8125e12c-146c-11e5-8947-525400b33d1d_612b6999

The `openshift3/ose-pod` container exists because of the way network namespacing
works in Kubernetes. For the sake of simplicity, think of the container as
nothing more than a way for the host OS to get an interface created for the
corresponding pod to be able to receive traffic. Deeper understanding of
networking in OpenShift is outside the scope of this material.

To verify that the app is working, you can issue a curl to the app's port *on
the node where the pod is running*

    [root@ose3-node1 ~]# curl 10.1.0.3:8080
    Hello OpenShift!

Hooray!

You'll also notice that the pod landed on one of the primary nodes. Why is that?
Becuase we had configured a default `nodeSelector` earlier during the set-up
process.

## Examining the Created Pod
Execute the following:

    oc get pod hello-openshift -o yaml

You should see something like:

    apiVersion: v1                                                                                                                                                                                             [18/554]
    kind: Pod
    metadata:
      annotations:
        openshift.io/scc: restricted
      creationTimestamp: 2015-07-22T20:42:30Z
      labels:
        name: hello-openshift
      name: hello-openshift
      namespace: demo
      resourceVersion: "1399"
      selfLink: /api/v1/namespaces/demo/pods/hello-openshift
      uid: 2c1c7156-30b2-11e5-b6a3-525400b33d1d
    spec:
      containers:
      - image: openshift/hello-openshift
        imagePullPolicy: IfNotPresent
        name: hello-openshift
        ports:
        - containerPort: 8080
          hostPort: 36061
          protocol: TCP
        resources:
          limits:
            cpu: 100m
            memory: 100Mi
        securityContext:
          capabilities: {}
          privileged: false
          runAsUser: 1000030000
          seLinuxOptions:
            level: s0:c6,c0
        terminationMessagePath: /dev/termination-log
        volumeMounts:
        - mountPath: /var/run/secrets/kubernetes.io/serviceaccount
          name: default-token-ahpda
          readOnly: true
      dnsPolicy: ClusterFirst
      host: ose3-node2.example.com
      imagePullSecrets:
      - name: default-dockercfg-5uc2b
      nodeSelector:
        region: primary
      restartPolicy: Always
      serviceAccount: default
      volumes:
      - name: default-token-ahpda
        secret:
          secretName: default-token-ahpda
    status:
      conditions:
      - status: "True"
        type: Ready
      containerStatuses:
      - containerID: docker://2706a87bd2c04f3ed216b704ee391910556aeea89c00f02ea1e990cd37e266af
        image: openshift/hello-openshift
        imageID: docker://4c6802d09a00319e08ed176d9fabe484df9a1bdc575ffe39ce190247f882b391
        lastState: {}
        name: hello-openshift
        ready: true
        restartCount: 0
        state:
          running:
            startedAt: 2015-07-22T20:42:32Z
      hostIP: 192.168.133.4
      phase: Running
      podIP: 10.1.0.3
      startTime: 2015-07-22T20:42:32Z

There are some interesting things in here now. 

* We didn't specify a `nodeSelector` in our pod definition, but it's there now.
  * This is because OpenShift is configured with a default.
* We didn't specify any resource limits in our pod definition, but they're there
    now.
  * This is because our project has default limits set.

Cool, right?

## Looking at the Pod in the Web Console
Go to the web console and go to the *Overview* tab for the *OpenShift 3 Demo*
project. You'll see some interesting things:

* You'll see the pod is running (eventually)
* You'll see the SDN IP address that the pod is associated with (10....)
* You'll see the internal port that the pod's container's "application"/process
    is using
* You'll see the host port that the pod is bound to
* You'll see that there's no service yet - we'll get to services soon.

## Quota Usage
If you click on the *Settings* tab, you'll see our pod usage has increased to 1.

You can also use `osc` to determine the current quota usage of your project. As
`joe`:

    oc describe quota test-quota

## Delete the Pod
As `joe`, go ahead and delete this pod so that you don't get confused in later examples:

    oc delete pod hello-openshift

Take a moment to think about what this pod exercise really did -- it referenced
an arbitrary Docker image, made sure to fetch it (if it wasn't present), and
then ran it. This could have just as easily been an application from an ISV
available in a registry or something already written and built in-house.

This is really powerful. We will explore using "arbitrary" docker images later.

## Quota Enforcement
Since we know we can run a pod directly, we'll go through a simple quota
enforcement exercise. The `hello-quota` JSON will attempt to create four
instances of the "hello-openshift" pod. It will fail when it tries to create the
fourth, because the quota on this project limits us to three total pods.

As `joe`, go ahead and use `oc create` and you will see the following:

    oc create -f ~/training/content/hello-quota.json 
    pods/hello-openshift-1
    pods/hello-openshift-2
    pods/hello-openshift-3
    Error from server: Pod "hello-openshift-4" is forbidden: Limited to 3 pods

Let's delete these pods quickly. As `joe` again:

    oc delete pod --all

**Note:** You can delete most resources using "--all" but there is *no sanity
check*. Be careful.


