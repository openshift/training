<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Services](#services)
- [Routing](#routing)
  - [Creating a Wildcard Certificate](#creating-a-wildcard-certificate)
  - [Creating the Router](#creating-the-router)
  - [Router Placement By Region](#router-placement-by-region)
  - [Viewing Router Stats](#viewing-router-stats)
- [The Complete Pod-Service-Route](#the-complete-pod-service-route)
  - [Creating the Definition](#creating-the-definition)
  - [Project Status](#project-status)
  - [Verifying the Service](#verifying-the-service)
  - [Verifying the Routing](#verifying-the-routing)
  - [The Web Console](#the-web-console)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Services
From the [Kubernetes
documentation](https://github.com/GoogleCloudPlatform/kubernetes/blob/master/docs/services.md):

    A Kubernetes service is an abstraction which defines a logical set of pods and a
    policy by which to access them - sometimes called a micro-service. The goal of
    services is to provide a bridge for non-Kubernetes-native applications to access
    backends without the need to write code that is specific to Kubernetes. A
    service offers clients an IP and port pair which, when accessed, redirects to
    the appropriate backends. The set of pods targetted is determined by a label
    selector.

If you think back to the simple pod we created earlier, there was a "label":

      "labels": {
        "name": "hello-openshift"
      },

Now, let's look at a *service* definition:

    {
      "kind": "Service",
      "apiVersion": "v1",
      "metadata": {
        "name": "hello-service"
      },
      "spec": {
        "selector": {
          "name":"hello-openshift"
        },
        "ports": [
          {
            "protocol": "TCP",
            "port": 80,
            "targetPort": 9376
          }
        ]
      }
    }

The *service* has a `selector` element. In this case, it is a key:value pair of
`name:hello-openshift`. If you looked at the output of `oc get pods` on your
master, you saw that the `hello-openshift` pod has a label:

    name=hello-openshift

The definition of the *service* tells Kubernetes that any pods with the label
"name=hello-openshift" are associated, and should have traffic distributed
amongst them. In other words, the service itself is the "connection to the
network", so to speak, or the input point to reach all of the pods. Generally
speaking, pod containers should not bind directly to ports on the host. We'll
see more about this later.

But, to really be useful, we want to make our application accessible via a FQDN,
and that is where the routing tier comes in.

# Routing
The OpenShift routing tier is how FQDN-destined traffic enters the OpenShift
environment so that it can ultimately reach pods. In a simplification of the
process, the `openshift3/ose-haproxy-router` container we will create below
is a pre-configured instance of HAProxy as well as some of the OpenShift
framework. The OpenShift instance running in this container watches for route
resources on the OpenShift master.

Here is an example route resource JSON definition:

    {
      "kind": "Route",
      "apiVersion": "v1",
      "metadata": {
        "name": "hello-openshift-route"
      },
      "spec": {
        "host": "hello-openshift.cloudapps.example.com",
        "to": {
          "name": "hello-openshift-service"
        },
        "tls": {
          "termination": "edge"
        }
      }
    }

When the `oc` command is used to create this route, a new instance of a route
*resource* is created inside OpenShift's data store. This route resource is
affiliated with a service.

The HAProxy/Router is watching for changes in route resources. When a new route
is detected, an HAProxy pool is created. When a change in a route is detected,
the pool is updated.

This HAProxy pool ultimately contains all pods that are in a service. Which
service? The service that corresponds to the `to` directive that you
see above.

You'll notice that the definition above specifies TLS edge termination. This
means that the router should provide this route via HTTPS. Because we provided
no certificate info, the router will provide its default SSL certificate when
the user connects. Because this is edge termination, user connections to the
router will be SSL encrypted but the connection between the router and the pods
is unencrypted.

It is possible to utilize various TLS termination mechanisms, and more details
is provided in the router documentation:

    http://docs.openshift.org/latest/architecture/core_objects/routing.html#securing-routes

We'll see this edge termination in action shortly.

## Creating a Wildcard Certificate
In order to serve a valid certificate for secure access to applications in our
cloud domain, we will need to create a key and wildcard certificate that the
router will use by default for any routes that do not specify a key/cert of their
own. OpenShift supplies a command for creating a key/cert signed by the OpenShift
CA which we will use.

On the master, as `root`:

    CA=/etc/openshift/master
    oadm create-server-cert --signer-cert=$CA/ca.crt \
          --signer-key=$CA/ca.key --signer-serial=$CA/ca.serial.txt \
          --hostnames='*.cloudapps.example.com' \
          --cert=cloudapps.crt --key=cloudapps.key

Now we need to combine `cloudapps.crt` and `cloudapps.key` with the CA into
a single PEM format file that the router needs in the next step.

    cat cloudapps.crt cloudapps.key $CA/ca.crt > cloudapps.router.pem

Make sure you remember where you put this PEM file.

## Creating the Router
The router is the ingress point for all traffic destined for OpenShift
v3 services. It currently supports only HTTP(S) traffic (and "any"
TLS-enabled traffic via SNI). While it is called a "router", it is essentially a
proxy.

The `openshift3/ose-haproxy-router` container listens on the host network
interface, unlike most containers that listen only on private IPs. The router
proxies external requests for route names to the IPs of actual pods identified
by the service associated with the route.

OpenShift's admin command set enables you to deploy router pods automatically.
Perform the following comands as `root`.

Let's try to create a router:

    oadm router
    error: router could not be created; you must specify a .kubeconfig file path containing credentials for connecting the router to the master with --credentials

Just about every form of communication with OpenShift components is secured by
SSL and uses various certificates and authentication methods. Even though we set
up our `.kubeconfig` for the root user, `oadm router` is asking us what
credentials the *router* should use to communicate. We also need to specify the
router image, since the tooling defaults to upstream/origin:

    oadm router --dry-run \
    --credentials=/etc/openshift/master/openshift-router.kubeconfig

Adding that would be enough to allow the command to proceed, but if we want
this router to work for our environment, we also need to specify the 
router image (the tooling defaults to upstream/origin otherwise) and we need
to supply the wildcard cert/key that we created for the cloud domain.

    oadm router --default-cert=cloudapps.router.pem \
    --credentials=/etc/openshift/master/openshift-router.kubeconfig \
    --selector='region=infra' \
    --images='registry.access.redhat.com/openshift3/ose-${component}:${version}'

If this works, you'll see some output:

    password for stats user admin has been set to Cwwk96Huso
    deploymentconfigs/router
    services/router
    
**Note:** You will have to reference the absolute path of the PEM file if you
did not run this command in the folder where you created it.

**Note:** You will want to keep that password handy. But you can get it by
looking at the DeploymentConfiguration later. Don't worry.

Let's check the pods:

    oc get pods 

In the output, you should see the router pod status change to "running" after a
few moments (it may take up to a few minutes):

    NAME             READY     REASON    RESTARTS   AGE
    router-1-rt6qk   1/1       Running   0          20s

In the above router creation command (`oadm router...`) we also specified
`--selector`. This flag causes a `nodeSelector` to be placed on all of the pods
created. If you think back to our "regions" and "zones" conversation, the
OpenShift environment is currently configured with an *infra*structure region
called "infra". This `--selector` argument asks OpenShift:

*Please place all of these router pods in the infra region*.

If you `describe` the router pod, you will see that it is running on the master:

    oc describe pod router-1-rt6qk
    Name:                           router-1-rt6qk
    Image(s):                       registry.access.redhat.com/openshift3/ose-haproxy-router:v0.6.1.0
    Host:                           ose3-master.example.com/192.168.133.2
    Labels:                         deployment=router-1,deploymentconfig=router,router=router
    Status:                         Running
    IP:                             10.1.0.4
    Replication Controllers:        router-1 (1/1 replicas created)
    Containers:
      router:
        Image:              registry.access.redhat.com/openshift3/ose-haproxy-router:v0.6.1.0
        State:              Running
          Started:          Wed, 17 Jun 2015 14:49:42 -0400
        Ready:              True
        Restart Count:      0
    Conditions:
      Type          Status
      Ready         True 
    Events:
      FirstSeen                             LastSeen                        Count   From                                    SubobjectPath                           Reason          Message
      Wed, 17 Jun 2015 14:49:40 -0400       Wed, 17 Jun 2015 14:49:40 -0400 1       {scheduler }                                                                    scheduled       Successfully assigned router-1-rt6qk to ose3-master.example.com
      Wed, 17 Jun 2015 14:49:40 -0400       Wed, 17 Jun 2015 14:49:40 -0400 1       {kubelet ose3-master.example.com}       implicitly required container POD       pulled          Successfully pulled image "openshift3/ose-pod:v0.6.1.0"
      Wed, 17 Jun 2015 14:49:41 -0400       Wed, 17 Jun 2015 14:49:41 -0400 1       {kubelet ose3-master.example.com}       implicitly required container POD       created         Created with docker id 9e3c20ad9e356e9495004004b81b19d3eaaa721f42ee07073380efaa9047b45a
      Wed, 17 Jun 2015 14:49:41 -0400       Wed, 17 Jun 2015 14:49:41 -0400 1       {kubelet ose3-master.example.com}       implicitly required container POD       started         Started with docker id 9e3c20ad9e356e9495004004b81b19d3eaaa721f42ee07073380efaa9047b45a
      Wed, 17 Jun 2015 14:49:42 -0400       Wed, 17 Jun 2015 14:49:42 -0400 1       {kubelet ose3-master.example.com}       spec.containers{router}                 created         Created with docker id f891a779c18ed960ae27d630e7df2061531533ead6df4b262d642c2d0a3902ef
      Wed, 17 Jun 2015 14:49:42 -0400       Wed, 17 Jun 2015 14:49:42 -0400 1       {kubelet ose3-master.example.com}       spec.containers{router}                 started         Started with docker id f891a779c18ed960ae27d630e7df2061531533ead6df4b262d642c2d0a3902ef

In the very beginning of the documentation, we indicated that a wildcard DNS
entry is required and should point at the master. When the router receives a
request for an FQDN that it knows about, it will proxy the request to a pod for
a service. But, for that FQDN request to actually reach the router, the FQDN has
to resolve to whatever the host is where the router is running. Remember, the
router is bound to ports 80 and 443 on the *host* interface. Since our wildcard
DNS entry points to the public IP address of the master, the `--selector` flag
used above ensures that the router is placed on our master as it's the only node
with the label `region=infra`.

For a true HA implementation, one would want multiple "infra" nodes and
multiple, clustered router instances. Please see the "high availability"
documentation for more information on how tihs can be achieved:

    http://docs.openshift.org/latest/admin_guide/high_availability.html

## Viewing Router Stats
Haproxy provides a stats page that's visible on port 1936 of your router host.
The username is `admin` and the password was displayed to you when you created
the router. If you forgot it, you can find it by `describe`ing the deployment
configuration of the router:

    oc describe dc router

To make the stats port acessible publicly, you will need to open it on your
master:

    iptables -I OS_FIREWALL_ALLOW -p tcp -m tcp --dport 1936 -j ACCEPT

You will also want to add this rule to `/etc/sysconfig/iptables` as well to keep
it across reboots. However, don't restart the iptables service, as this would
destroy the rules that had already been created by Openshift. Use the `iptables`
command to change rules on a live system.

Feel free to not open this port if you don't want to make this accessible, or if
you only want it accessible via port fowarding, etc.

**Note**: Unlike OpenShift v2 this router is not specific to a given project, as
such it's really intended to be viewed by cluster admins rather than project
admins.

Ensure that port 1936 is accessible and visit:

    http://admin:$YOURPASSWORDHERE@ose3-master.example.com:1936 

to view your router stats.

# The Complete Pod-Service-Route
With a router now available, let's take a look at an entire
Pod-Service-Route definition template and put all the pieces together.

Don't forget -- the materials are in `~/training/content`.

## Creating the Definition
The following is a complete definition for a pod with a corresponding service
and a corresponding route. It also includes a deployment configuration.

    {
      "kind": "List",
      "apiVersion": "v1",
      "metadata": {
        "name": "hello-service-complete-example"
      },
      "items": [
        {
          "kind": "Service",
          "apiVersion": "v1",
          "metadata": {
            "name": "hello-openshift-service"
          },
          "spec": {
            "selector": {
              "name": "hello-openshift"
            },
            "ports": [
              {
                "protocol": "TCP",
                "port": 27017,
                "targetPort": 8080
              }
            ]
          }
        },
        {
          "kind": "Route",
          "apiVersion": "v1",
          "metadata": {
            "name": "hello-openshift-route"
          },
          "spec": {
            "host": "hello-openshift.cloudapps.example.com",
            "to": {
              "name": "hello-openshift-service"
            },
            "tls": {
              "termination": "edge"
            }
          }
        },
        {
          "kind": "DeploymentConfig",
          "apiVersion": "v1",
          "metadata": {
            "name": "hello-openshift"
          },
          "spec": {
            "strategy": {
              "type": "Recreate",
              "resources": {}
            },
            "replicas": 1,
            "selector": {
              "name": "hello-openshift"
            },
            "template": {
              "metadata": {
                "creationTimestamp": null,
                "labels": {
                  "name": "hello-openshift"
                }
              },
              "spec": {
                "containers": [
                  {
                    "name": "hello-openshift",
                    "image": "openshift/hello-openshift:v0.4.3",
                    "ports": [
                      {
                        "name": "hello-openshift-tcp-8080",
                        "containerPort": 8080,
                        "protocol": "TCP"
                      }
                    ],
                    "resources": {},
                    "terminationMessagePath": "/dev/termination-log",
                    "imagePullPolicy": "PullIfNotPresent",
                    "capabilities": {},
                    "securityContext": {
                      "capabilities": {},
                      "privileged": false
                    },
                    "livenessProbe": {
                      "tcpSocket": {
                        "port": 8080
                      },
                      "timeoutSeconds": 1,
                      "initialDelaySeconds": 10
                    }
                  }
                ],
                "restartPolicy": "Always",
                "dnsPolicy": "ClusterFirst",
                "serviceAccount": "",
                "nodeSelector": {
                  "region": "primary"
                }
              }
            }
          },
          "status": {
            "latestVersion": 1
          }
        }
      ]
    }

In the JSON above:

* There is a pod whose containers have the label `name=hello-openshift-label` and the nodeSelector `region=primary`
* There is a service:
  * with the id `hello-openshift-service`
  * with the selector `name=hello-openshift`
* There is a route:
  * with the FQDN `hello-openshift.cloudapps.example.com`
  * with the `spec` `to` `name=hello-openshift-service`

If we work from the route down to the pod:

* The route for `hello-openshift.cloudapps.example.com` has an HAProxy pool
* The pool is for any pods in the service whose ID is `hello-openshift-service`,
    via the `serviceName` directive of the route.
* The service `hello-openshift-service` includes every pod who has a label
    `name=hello-openshift-label`
* There is a single pod with a single container that has the label
    `name=hello-openshift-label`

If you are not using the `example.com` domain you will need to edit the route
portion of `test-complete.json` to match your DNS environment.

**Logged in as `joe`,** go ahead and use `oc` to create everything:

    oc create -f test-complete.json

You should see something like the following:

    services/hello-openshift-service
    routes/hello-openshift-route
    deploymentconfigs/hello-openshift

You can verify this with other `oc` commands:

    oc get pods

    oc get services

    oc get routes

    oc get rc

    oc get dc

## Project Status
OpenShift provides a handy tool, `oc status`, to give you a summary of
common resources existing in the current project:

    oc status
    In project OpenShift 3 Demo (demo)
    
    service hello-openshift-service (172.30.252.29:27017 -> 8080)
      hello-openshift deploys docker.io/openshift/hello-openshift:v0.4.3 
        #1 deployed about a minute ago - 1 pod
    
    To see more information about a Service or DeploymentConfig, use 'oc describe service <name>' or 'oc describe dc <name>'.
    You can use 'oc get all' to see lists of each of the types described above.

`oc status` does not yet show bare pods or routes. The output will be
more interesting when we get to builds and deployments.

## Verifying the Service
Services are not externally accessible without a route being defined, because
they always listen on "local" IP addresses (eg: 172.x.x.x). However, if you have
access to the OpenShift environment, you can still test a service.

    oc get services
    NAME                      LABELS    SELECTOR                     IP              PORT(S)
    hello-openshift-service   <none>    name=hello-openshift-label   172.30.17.229   27017/TCP

We can see that the service has been defined based on the JSON we used earlier.
If the output of `oc get pods` shows that our pod is running, we can try to
access the service:

    curl `oc get services | grep hello-openshift | awk '{print $4":"$5}' | sed -e 's/\/.*//'`
    Hello OpenShift!

This is a good sign! It means that, if the router is working, we should be able
to access the service via the route.

## Verifying the Routing
Verifying the routing is a little complicated, but not terribly so. Since we
specified that the router should land in the "infra" region, we know that its
Docker container is on the master. Log in there as `root`.

We can use `oc exec` to get a bash interactive shell inside the running
router container. The following command will do that for us:

    oc exec -it -p $(oc get pods | grep router | awk '{print $1}' | head -n 1) /bin/bash

You are now in a bash session *inside* the container running the router.

Since we are using HAProxy as the router, we can cat the `routes.json` file:

    cat /var/lib/containers/router/routes.json

If you see some content that looks like:

    "demo/hello-openshift-service": {
      "Name": "demo/hello-openshift-service",
      "EndpointTable": [
        {
          "ID": "10.1.2.2:8080",
          "IP": "10.1.2.2",
          "Port": "8080",
          "TargetName": "hello-openshift-1-6a4i8"
        }
      ],
      "ServiceAliasConfigs": {
        "demo-hello-openshift-route": {
          "Host": "hello-openshift.cloudapps.example.com",
          "Path": "",
          "TLSTermination": "edge",
          "Certificates": {
            "hello-openshift.cloudapps.example.com": {
              "ID": "demo-hello-openshift-route",
              "Contents": "",
              "PrivateKey": ""
            }
          },
          "Status": ""
        }
      }

You know that "it" worked -- the router watcher detected the creation of the
route in OpenShift and added the corresponding configuration to HAProxy.

Go ahead and `exit` from the container.

    bash-4.2$ exit

As `joe`, you can reach the route securely and check that it is using the right
certificate:

    curl --cacert /etc/openshift/master/ca.crt \
             https://hello-openshift.cloudapps.example.com
    Hello OpenShift!

And:

    openssl s_client -connect hello.cloudapps.example.com:443 \
                       -CAfile /etc/openshift/master/ca.crt
    CONNECTED(00000003)
    depth=1 CN = openshift-signer@1430768237
    verify return:1
    depth=0 CN = *.cloudapps.example.com
    verify return:1
    [...]

Since we used OpenShift's CA to create the wildcard SSL certificate, and since
that CA is not "installed" in our system, we need to point our tools at that CA
certificate in order to validate the SSL certificate presented to us by the
router. With a CA or all certificates signed by a trusted authority, it would
not be necessary to specify the CA everywhere.

## The Web Console
Take a moment to look in the web console to see if you can find everything that
was just created.


