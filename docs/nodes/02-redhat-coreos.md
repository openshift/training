# Red Hat CoreOS

This tutorial will guide you through the basics of Red Hat CoreOS.

Red Hat CoreOS is the immutable, container-optimized operating system for
OpenShift.

## Accessing the host

To access the host, we will `ssh` into a master.

```
oc get nodes -l node-role.kubernetes.io/master -o wide
```

Select a machine, and `export EXTERNAL_IP=<EXTERNAL IP>`

To access the host:

```sh
ssh -i $PEM_FILE core@$EXTERNAL_IP
Red Hat CoreOS 4.0
 Information: https://url.corp.redhat.com/redhat-coreos
 Bugs: https://github.com/openshift/os

---
```

**NOTE** In the future, accessing a host via `ssh` will taint the node.

## RHEL Kernel and Content

Red Hat CoreOS runs a RHEL kernel and uses RHEL content.

To view the RHEL kernel, execute the following command:

```sh
uname -rs
Linux 3.10.0-957.1.3.el7.x86_64
```

## Ignition

Executes during early boot and writes files (regular files, systemd units, etc.)
required to configure the host.

The configuration is served from the control plane.

## Kubelet

The `kubelet` is packaged with the operating system.  It is not run in a
container.  It is configured to use `cri-o` as the runtime.

To view status for `kubelet`, execute the following:

```sh
systemctl status kubelet -l
● kubelet.service - Kubernetes Kubelet
   Loaded: loaded (/etc/systemd/system/kubelet.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2018-12-03 19:49:15 UTC; 49min ago
  Process: 4104 ExecStartPre=/bin/mkdir --parents /etc/kubernetes/manifests (code=exited, status=0/SUCCESS)
 Main PID: 4124 (hyperkube)
   Memory: 161.9M
   CGroup: /system.slice/kubelet.service
           └─4124 /usr/bin/hyperkube kubelet --config=/etc/kubernetes/kubelet.conf --bootstrap-kubeconfig=/etc/kubernetes/kubeconfig --rotate-certificates --kubeconfig=/var/lib/kubelet/kubeconfig --container-runtime=remote --container-runtime-endpoint=/var/run/crio/crio.sock --allow-privileged --node-labels=node-role.kubernetes.io/master --minimum-container-ttl-duration=6m0s --client-ca-file=/etc/kubernetes/ca.crt --cloud-provider=aws --anonymous-auth=false --register-with-taints=node-role.kubernetes.io/master=:NoSchedule
```

## CRI-O
Container runtime for Kubernetes. To view status for `cri-o`, execute the
following:

```sh
systemctl status crio
● crio.service - Open Container Initiative Daemon
   Loaded: loaded (/usr/lib/systemd/system/crio.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2018-12-03 19:48:28 UTC; 49min ago
     Docs: https://github.com/kubernetes-sigs/cri-o
 Main PID: 4268 (crio)
   Memory: 3.4G
   CGroup: /system.slice/crio.service
           └─4268 /usr/bin/crio --cni-config-dir=/etc/kubernetes/cni/net.d --cni-plugin-dir=/var/lib/cni/bin
```

Inspected and debugged via `crictl`

To view running pods via `crictl`, execute the following:

```sh
 sudo crictl pods
```

## Podman

Executes containers required to bring up a cluster on bootstrap machine.

To view containers, execute the following command:

```sh
sudo podman ps
```

# Next

In the next step, we will explore how OpenShift nodes are configured via an
operator.

Next: [Maching Config](03-machine-config.md)