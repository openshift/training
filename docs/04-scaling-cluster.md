# Scaling an OpenShift 4 Cluster
With OpenShift 4.0+, we now have the ability to dynamically scale the cluster
size through OpenShift itself.

Refer to the [Manually scaling a
MachineSet](https://docs.openshift.com/container-platform/4.0/machine_management/manually-scaling-machineset.html)
documentation for details on how to do this from the command line.

# Cluster Scaling From the Web Console

You can also scale the cluster from the Web Console.

1. Go to the OpenShift web console and login with `kubeadmin` (or your admin
username if different)
1. Browse to `Machines` on the left-hand side-bar, and click `Machine Sets`.
1. On the `Machine Sets` page, select `openshift-machine-api` from the `Project`
dropdown and you should see the machine sets:

     <center><img src="../img/machine-set.png"/></center>

1. Select one of the machine sets in the list by clicking on the name, e.g.
"**beta-190305-1-79tf5-worker-us-east-1a**" (yours will be slightly different)
1. Go to the OpenShift web console and login with `kubeadmin`.
1. Browse to `Machines` in the side-bar, and click `Machine Sets`.
1. On the `Machine Sets` page, select `openshift-machine-api` from the
  `Project` dropdown.
1. Select a worker set to scale by clicking it.

   Depending on the AWS region you chose, you may have several worker machine
   sets that can be scaled, some of which are at a scale of 0. It does not
   matter which set you choose for this example.
1. In the `Actions` pull down menu (on the right hand side), select `Edit Count`

1. Enter '3' and click `Save`

  <center><img src="../img/scale-nodes.png"/></center>

At this point you can click the `Machines` tab in this `Machine Set` display
and see the allocated machines. The `Overview` tab will let you know when the
machines become ready. If you click `Machine Sets` under `Machines` on the
left-hand side again, you will also see the status of the machines in the set:

  <center><img src="../img/all-systems.png"/></center>

machines become ready. If you click `Machine Sets` under `Machines`
again, you will also see the status of the machines in the set.

It will take several minutes for the new machines to become ready. In the
background additional EC2 instances are being provisioned and then registered
and configured to participate in the cluster, so yours may still show 1/3.

You can also view this in the CLI:

~~~bash
$ oc get machinesets -n openshift-machine-api
NAME                                    DESIRED   CURRENT   READY     AVAILABLE   AGE
beta-190305-1-79tf5-worker-us-east-1a   3         3         3         3           23h
beta-190305-1-79tf5-worker-us-east-1b   1         1         1         1           23h
beta-190305-1-79tf5-worker-us-east-1c   1         1         1         1           23h
beta-190305-1-79tf5-worker-us-east-1d   0         0                               23h
beta-190305-1-79tf5-worker-us-east-1e   0         0                               23h
beta-190305-1-79tf5-worker-us-east-1f   0         0                               23h

$ oc get nodes
NAME                           STATUS    ROLES     AGE       VERSION
ip-10-0-132-138.ec2.internal   Ready     worker    2m6s      v1.12.4+5dc94f3fda
ip-10-0-137-104.ec2.internal   Ready     worker    23h       v1.12.4+5dc94f3fda
ip-10-0-140-138.ec2.internal   Ready     master    24h       v1.12.4+5dc94f3fda
ip-10-0-140-67.ec2.internal    Ready     worker    2m6s      v1.12.4+5dc94f3fda
ip-10-0-158-222.ec2.internal   Ready     master    24h       v1.12.4+5dc94f3fda
ip-10-0-159-179.ec2.internal   Ready     worker    23h       v1.12.4+5dc94f3fda
ip-10-0-168-43.ec2.internal    Ready     master    24h       v1.12.4+5dc94f3fda
ip-10-0-171-135.ec2.internal   Ready     worker    23h       v1.12.4+5dc94f3fda
~~~

You'll note that some of these systems 'age' will be much newer than some of the
others, these are the ones that will have just been added in. Before continuing,
scale back down by editing the count to whatever it was previously for the
`Machine Set`, i.e. return it to '1' node.

## Note
The default installation currently creates two routers, but they are on the
same host. This is a known bug. It is possible that when you scale down your
cluster that you may inadvertently end up removing the node where the router
was running, which will temporarily make the console and other resources
unavailable. If you suddenly lose access to the web console, wait a few
moments, and then check to see the status of the router pod with:

~~~bash
$ oc get pod -n openshift-ingress
NAME                            READY     STATUS    RESTARTS   AGE
router-default-dffd8548-6g4hz   1/1       Running   0          23h
router-default-dffd8548-vxtt8   1/1       Running   0          23h
~~~

If there is no router pod, or if it is in the `ContainerCreating` state, wait
a little longer.

# Automatic Cluster Scale Up

OpenShift can automatically scale the infrastructure based on workload provided
there is a configuration specified to do so.  Before we begin, ensure that your
cluster is back to having three nodes running:

~~~bash
$ oc get machinesets -n openshift-machine-api
NAME                                    DESIRED   CURRENT   READY     AVAILABLE   AGE
beta-190305-1-79tf5-worker-us-east-1a   1         1         1         1           24h
beta-190305-1-79tf5-worker-us-east-1b   1         1         1         1           24h
beta-190305-1-79tf5-worker-us-east-1c   1         1         1         1           24h
beta-190305-1-79tf5-worker-us-east-1d   0         0                               24h
beta-190305-1-79tf5-worker-us-east-1e   0         0                               24h
beta-190305-1-79tf5-worker-us-east-1f   0         0                               24h
~~~

## Auto Scaling Configuration

Refer to the [Applying
autoscaling](https://docs.openshift.com/container-platform/4.0/machine_management/applying-autoscaling.html)
documentation for details on how to configure the cluster for autoscaling.

### NOTE
You can find an example cluster autoscaler config here:

https://raw.githubusercontent.com/openshift/training/master/assets/cluster-autoscaler.yaml

Feel free to adjust the maximum number of nodes as desired.

### NOTE
You can also use this script to automagically create one cluster autoscaler
for EVERY `MachineSet` you currently have:

https://raw.githubusercontent.com/openshift/training/master/assets/create-autoscalers.sh

It requires the `jq` program.

# Causing a Scaling Event
This next section walks through causing the cluster to auto scale.

## Define a `Job`

The following example YAML file defines a `Job`:

https://raw.githubusercontent.com/openshift/training/master/assets/job-work-queue.yaml

It will produce a massive load that the cluster cannot handle, and will force
the autoscaler to take action (up to the `maxReplicas` defined in your
ClusterAutoscaler YAML).

> **NOTE**: If you did not scale down your machines earlier, you may have too
much capacity to trigger an autoscaling event. Make sure you have no more than
3 total workers before continuing.

Create a project to hold the resources for the `Job`, and switch into it:

~~~bash
oc adm new-project autoscale-example && oc project autoscale-example
~~~

## Open Grafana
In the OpenShift web console, click `Monitoring` and then click `Dashboards`.
This will open a new browser tab for Grafana. You will also get a certificate
error similar to the first time you logged in. This is because Grafana has
its own SSL certificate. You will then see a login button. Grafana is
configured to use an OpenShift user and inherits permissions of that user for
accessing cluster information. This happens to be the user you're already
logged into the web console with.

Finally, allow the permissions, and then you will see the Grafana homepage.

Click the dropdown on `Home` and choose `Kubernetes / Compute Resources /
Cluster`. Leave this browser window open while you start the `Job` so that
you can observe the CPU utilization of the cluster rise:

  <center><img src="../img/grafana.png"/></center>

## Force an Autoscaling Event

Now we're ready to create the `Job`:

~~~bash
oc create -n autoscale-example -f https://raw.githubusercontent.com/openshift/training/master/assets/job-work-queue.yaml
~~~

You will see a note that the `Job` was created. It will create a *lot* of `Pods`. You can look at the list of pods with:

```
oc get pod -n autoscale-example
```

After a few moments, look at the list of `Machines`:

```sh
oc get machines -n openshift-machine-api
```

You will see something like:

```
NAME                                          INSTANCE              STATE     TYPE        REGION      ZONE         AGE
beta-190305-1-79tf5-master-0                  i-080dea906d9750737   running   m4.xlarge   us-east-1   us-east-1a   26h
beta-190305-1-79tf5-master-1                  i-0bf5ad242be0e2ea1   running   m4.xlarge   us-east-1   us-east-1b   26h
beta-190305-1-79tf5-master-2                  i-00f13148743c13144   running   m4.xlarge   us-east-1   us-east-1c   26h
beta-190305-1-79tf5-worker-us-east-1a-8dvwq   i-06ea8662cf76c7591   running   m4.large    us-east-1   us-east-1a   2m7s
beta-190305-1-79tf5-worker-us-east-1a-9pzvg   i-0bf01b89256e7f39f   running   m4.large    us-east-1   us-east-1a   2m7s
beta-190305-1-79tf5-worker-us-east-1a-vvddp   i-0e649089d42751521   running   m4.large    us-east-1   us-east-1a   2m7s
beta-190305-1-79tf5-worker-us-east-1a-xx282   i-07b2111dff3c7bbdb   running   m4.large    us-east-1   us-east-1a   26h
beta-190305-1-79tf5-worker-us-east-1b-hjv9c   i-0562517168aadffe7   running   m4.large    us-east-1   us-east-1b   26h
beta-190305-1-79tf5-worker-us-east-1c-cdhth   i-09fbcd1c536f2a218   running   m4.large    us-east-1   us-east-1c   26h
```

You should see a scaled-up cluster with three new additions as worker nodes
in the region where you defined a `MachineAutoScaler`. You can see the ones
that have been auto-scaled from their age.

Depending on when you run the command, your list may show all running
workers, or some pending. After the `Job` completes, which could take anywhere
from a few minutes to ten or more (depending on your `ClusterAutoscaler` size
and your `MachineAutoScaler` sizes), the cluster should scale down to the
original count of worker nodes. You can watch the output with the following
(runs every 10s)-

```sh
watch -n10 'oc get machines -n openshift-machine-api'
```

Press Ctrl-C to break out of the watch.

In Grafana, be sure to click the `autoscale-example` project in the graphs,
otherwise the interesting things happening might get drowned out by the rest
of the baseline.

# Infrastructure Nodes
Continue on to the section that details [infrastructure nodes](05-infrastructure-nodes.md).
