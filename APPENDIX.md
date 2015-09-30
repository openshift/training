# APPENDIX - DNSMasq setup
In this training repository is a sample
[dnsmasq.conf](./content/dnsmasq.conf) file and a sample [hosts](./content/hosts)
file. If you do not have the ability to manipulate DNS in your
environment, or just want a quick and dirty way to set up DNS, you can
install dnsmasq on one of your nodes. Do **not** install DNSMasq on
your master. OpenShift now has an internal DNS service provided by
Go's "SkyDNS" that is used for internal service communication.

    yum -y install dnsmasq

Replace `/etc/dnsmasq.conf` with the one from this repository, and replace
`/etc/hosts` with the `hosts` file from this repository.

Copy your current `/etc/resolv.conf` to a new file such as
`/etc/resolv.conf.upstream`.  Ensure you *only* have an upstream
resolver there (eg: Google DNS @ `8.8.8.8`), not the address of your
dnsmasq server.

Enable and start the dnsmasq service:

    systemctl enable dnsmasq; systemctl start dnsmasq

You will need to ensure the following, or fix the following:

* Your IP addresses match the entries in `/etc/hosts`
* Your hostnames for your machines match the entries in `/etc/hosts`
* Your `cloudapps` domain points to the correct node ip in `dnsmasq.conf`
* Each of your systems has the same `/etc/hosts` file
* Your master and nodes `/etc/resolv.conf` points to the IP address of the node
  running DNSMasq as the first nameserver
* Your dnsmasq instance uses the `resolv-file` option to point to `/etc/resolv.conf.upstream` only.
* That you also open port 53 (TCP and UDP) to allow DNS queries to hit the node

Following this setup for dnsmasq will ensure that your wildcard domain works,
that your hosts in the `example.com` domain resolve, that any other DNS requests
resolve via your configured local/remote nameservers, and that DNS resolution
works inside of all of your containers. Don't forget to start and enable the
`dnsmasq` service.

### Verifying DNSMasq

You can query the local DNS on the master using `dig` (provided by the
`bind-utils` package) to make sure it returns the correct records:

    dig ose3-master.example.com

    ...
    ;; ANSWER SECTION:
    ose3-master.example.com. 0  IN  A 192.168.133.2
    ...

The returned IP should be the public interface's IP on the master. Repeat for
your nodes. To verify the wildcard entry, simply dig an arbitrary domain in the
wildcard space:

    dig foo.cloudapps.example.com

    ...
    ;; ANSWER SECTION:
    foo.cloudapps.example.com 0 IN A 192.168.133.2
    ...

# APPENDIX - LDAP Authentication
OpenShift currently supports several authentication methods for obtaining API
tokens.  While OpenID or one of the supported Oauth providers are preferred,
support for services such as LDAP is possible today using either the [Basic Auth
Remote](http://docs.openshift.org/latest/admin_guide/configuring_authentication.html#BasicAuthPasswordIdentityProvider)
identity provider or the [Request
Header](http://docs.openshift.org/latest/admin_guide/configuring_authentication.html#RequestHeaderIdentityProvider)
Identity provider.  This example while demonstrate the ease of running a
`BasicAuthPasswordIdentityProvider` on OpenShift.

For full documentation on the other authentication options please refer to the
[Official
Documentation](http://docs.openshift.org/latest/admin_guide/configuring_authentication.html)

### Prerequirements:

* A working Router with a wildcard DNS entry pointed to it
* A working Registry

### Setting up an example LDAP server:

For purposes of this training it is possible to use a preexisting LDAP server
or the example ldap server that comes preconfigured with the users referenced
in this document.  The decision does not need to be made up front.  It is
possible to change the ldap server that is used at any time.

For convenience the example LDAP server can be deployed on OpenShift as
follows:

    osc create -f openldap-example.json

That will create a pod from an OpenLDAP image hosted externally on the Docker
Hub.  You can find the source for it [here](beta4/images/openldap-example/).

To test the example LDAP service you can run the following:

    yum -y install openldap-clients
    ldapsearch -D 'cn=Manager,dc=example,dc=com' -b "dc=example,dc=com" \
               -s sub "(objectclass=*)" -w redhat \
               -h `osc get services | grep openldap-example-service | awk '{print $4}'`

You should see ldif output that shows the example.com users.

# APPENDIX - Import/Export of Docker Images (Disconnected Use)
Docker supports import/save of Images via tarball. These instructions are
general and may not be 100% accurate for the current release. You can do
something like the following on your connected machine:

    docker pull registry.access.redhat.com/openshift3_beta/ose-haproxy-router
    docker pull registry.access.redhat.com/openshift3_beta/ose-deployer
    docker pull registry.access.redhat.com/openshift3_beta/ose-sti-builder
    docker pull registry.access.redhat.com/openshift3_beta/ose-docker-builder
    docker pull registry.access.redhat.com/openshift3_beta/ose-pod
    docker pull registry.access.redhat.com/openshift3_beta/ose-docker-registry
    docker pull openshift/ruby-20-centos7
    docker pull openshift/mysql-55-centos7
    docker pull openshift/hello-openshift
    docker pull centos:centos7

This will fetch all of the images. You can then save them to a tarball:

    docker save -o beta1-images.tar \
    registry.access.redhat.com/openshift3_beta/ose-haproxy-router \
    registry.access.redhat.com/openshift3_beta/ose-deployer \
    registry.access.redhat.com/openshift3_beta/ose-sti-builder \
    registry.access.redhat.com/openshift3_beta/ose-docker-builder \
    registry.access.redhat.com/openshift3_beta/ose-pod \
    registry.access.redhat.com/openshift3_beta/ose-docker-registry \
    openshift/ruby-20-centos7 \
    openshift/mysql-55-centos7 \
    openshift/hello-openshift \
    centos:centos7

**Note: On an SSD-equipped system this took ~2 min and uses 1.8GB of disk
space**

Sneakernet that tarball to your disconnected machines, and then simply load the
tarball:

    docker load -i beta1-images.tar

**Note: On an SSD-equipped system this took ~4 min**

# APPENDIX - Cleaning Up
Figuring out everything that you have deployed is a little bit of a bear right
now. The following command will show you just about everything you might need to
delete. Be sure to change your context across all the namespaces and the
master-admin to find everything:

    for resource in build buildconfig images imagestream deploymentconfig \
    route replicationcontroller service pod; do echo -e "Resource: $resource"; \
    osc get $resource; echo -e "\n\n"; done

Deleting a project with `osc delete project` should delete all of its resources,
but you may need help finding things in the default project (where
infrastructure items are). Deleting the default project is not recommended.

# APPENDIX - Pretty Output
If the output of `osc get pods` is a little too busy, you can use the following
to limit some of what it returns:

    osc get pods | awk '{print $1"\t"$3"\t"$5"\t"$7"\n"}' | column -t

# APPENDIX - Troubleshooting

(STUB)

An experimental diagnostics command is in progress for OpenShift v3.
Once merged it should be available as `openshift ex diagnostics`. There may
be out-of-band updated versions of diagnostics under
[Luke Meyer's release page](https://github.com/sosiouxme/origin/releases).
Running this may save you some time by pointing you in the right direction
for common issues. This is very much still under development however.

**Common problems**

* All of a sudden authentication seems broken for non-admin users.  Whenever I run osc commands I see output such as:

        F0310 14:59:59.219087   30319 get.go:164] request
        [&{Method:GET URL:https://ose3-master.example.com:8443/api/v1beta1/pods?namespace=demo
        Proto:HTTP/1.1 ProtoMajor:1 ProtoMinor:1 Header:map[] Body:<nil> ContentLength:0 TransferEncoding:[]
        Close:false Host:ose3-master.example.com:8443 Form:map[] PostForm:map[]
        MultipartForm:<nil> Trailer:map[] RemoteAddr: RequestURI: TLS:<nil>}]
        failed (401) 401 Unauthorized: Unauthorized

    In most cases if admin (certificate) auth is still working this means the token is invalid.  Soon there will be more polish in the osc tooling to handle this edge case automatically but for now the simplist thing to do is to recreate the .kubeconfig.

        # The login command creates a .kubeconfig file in the CWD.
        # But we need it to exist in ~/.kube
        cd ~/.kube

        # If a stale token exists it will prevent the beta4 login command from working
        rm .kubeconfig

        osc login \
        --certificate-authority=/etc/openshift/master/ca.crt \
        --cluster=master --server=https://ose3-master.example.com:8443 \
        --namespace=[INSERT NAMESPACE HERE]

* When using an "osc" command like "osc get pods" I see a "certificate signed by
    unknown authority error":

        F0212 16:15:52.195372   13995 create.go:79] Post
        https://ose3-master.example.net:8443/api/v1beta1/pods?namespace=default:
        x509: certificate signed by unknown authority

    Check the value of $KUBECONFIG:

        echo $kubeconfig

    If you don't see anything, you may have changed your `.bash_profile` but
    have not yet sourced it. Make sure that you followed the step of adding
    `$KUBECONFIG`'s export to your `.bash_profile` and then source it:

        source ~/.bash_profile

* When issuing a `curl` to my service, I see `curl: (56) Recv failure:
    Connection reset by peer`

    It can take as long as 90 seconds for the service URL to start working.
    There is some internal house cleaning that occurs inside Kubernetes
    regarding the endpoint maps.

    If you look at the log for the node, you might see some messages about
    looking at endpoint maps and not finding an endpoint for the service.

    To find out if the endpoints have been updated you can run:

    `osc describe service $name_of_service` and check the value of `Endpoints:`

# APPENDIX - Infrastructure Log Aggregation
Given the distributed nature of OpenShift you may find it beneficial to
aggregate logs from your OpenShift infastructure services. By default, openshift
services log to the systemd journal and rsyslog persists those log messages to
`/var/log/messages`. We''ll reconfigure rsyslog to write these entries to
`/var/log/openshift` and configure the master host to accept log data from the
other hosts.

## Enable Remote Logging on Master
Uncomment the following lines in your master's `/etc/rsyslog.conf` to enable
remote logging services.

    $ModLoad imtcp
    $InputTCPServerRun 514

Restart rsyslog

    systemctl restart rsyslog



## Enable logging to /var/log/openshift
On your master update the filters in `/etc/rsyslog.conf` to divert openshift logs to `/var/log/openshift`

    # Log openshift processes to /var/log/openshift
    :programname, contains, "openshift"                     /var/log/openshift

    # Log anything (except mail) of level info or higher.
    # Don't log private authentication messages!
    # Don't log openshift processes to /var/log/messages either
    :programname, contains, "openshift" ~
    *.info;mail.none;authpriv.none;cron.none                /var/log/messages

Restart rsyslog

    systemctl restart rsyslog

## Configure nodes to send openshift logs to your master
On your other hosts send openshift logs to your master by adding this line to
`/etc/rsyslog.conf`

    :programname, contains, "openshift" @@ose3-master.example.com

Restart rsyslog

    systemctl restart rsyslog

Now all your openshift related logs will end up in `/var/log/openshift` on your
master.

## Optionally Log Each Node to a unique directory
You can also configure rsyslog to store logs in a different location
based on the source host. On your master, add these lines immediately prior to
`$InputTCPServerRun 514`

    $template TmplMsg, "/var/log/remote/%HOSTNAME%/%PROGRAMNAME:::secpath-replace%.log"
    $RuleSet remote1
    authpriv.*   ?TmplAuth
    *.info;mail.none;authpriv.none;cron.none   ?TmplMsg
    $RuleSet RSYSLOG_DefaultRuleset   #End the rule set by switching back to the default rule set
    $InputTCPServerBindRuleset remote1  #Define a new input and bind it to the "remote1" rule set

Restart rsyslog

    systemctl restart rsyslog


Now logs from remote hosts will go to `/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log`

See these documentation sources for additional rsyslog configuration information

    https://access.redhat.com/documentation/en-US/Red_Hat_Enterprise_Linux/7/html/System_Administrators_Guide/s1-basic_configuration_of_rsyslog.html
    http://www.rsyslog.com/doc/v7-stable/configuration/filters.html

# APPENDIX - JBoss Tools for Eclipse
Support for OpenShift development using Eclipse is provided through the JBoss Tools plugin.  The plugin is available
from the Jboss Tools nightly build of the Eclipse Mars.

Development is ongoing but current features include:

- Connecting to an OpenShift server using Oauth
    - Connections to multiple servers using multiple user names
- OpenShift Explorer
    - Browsing user projects
    - Browsing project resources
- Display of resource properties

## Installation
1. Install the Mars release of Eclipse from the [Eclipse Download site](http://www.eclipse.org/downloads/)
1. Add the update site
  1. Click from the toolbar 'Help > Install New Sofware'
  1. Click the 'Add' button and a dialog appears
  1. Enter a value for the name
  1. Enter 'http://download.jboss.org/jbosstools/updates/nightly/mars/' for the location.  **Note:** Alternative updates are available from
     the [JBoss Tools Downloads](http://tools.jboss.org/downloads/jbosstools/mars/index.html).  The various releases and code
     freeze dates are listed on the [JBoss JIRA site](https://issues.jboss.org/browse/JBIDE/?selectedTab=com.atlassian.jira.jira-projects-plugin:versions-panel)
  1. Click 'OK' to add the update site
1. Type 'OpenShift' in the text input box to filter the choices
1. Check 'JBoss OpenShift v3 Tools' and click 'Next'
1. Click 'Next' again, accept the license agreement, and click 'Finish'

After installation, open the OpenShift explorer view by clicking from the toolbar 'Window > Show View > Other' and typing 'OpenShift'
in the dialog box that appears.

## Connecting to the Server
1. Click 'New Connection Wizard' and a dialog appears
1. Select a v3 connection type
1. Uncheck default server
1. Enter the URL to the OpenShift server instance
1. Enter the username and password for the connection

A successful connection will allow you to expand the OpenShift explorer tree and browse the projects associated with the account
and the resources associated with each project.

# APPENDIX - Working with HTTP Proxies

In many production environments direct access to the web is not allowed.  In
these situations there is typically an HTTP(S) proxy available.  Configuring
OpenShift builds and deployments to use these proxies is as simple as setting
standard environment variables.  The trick is knowing where to place them.

## Importing ImageStreams

Since the importer is on the Master we need to make the configuration change
there.  The easiest way to do that is to add environment variables `NO_PROXY`,
`HTTP_PROXY`, and `HTTPS_PROXY` to `/etc/sysconfig/openshift-master` then restart
your master.

~~~
HTTP_PROXY=http://USERNAME:PASSWORD@10.0.1.1:8080/
HTTPS_PROXY=https://USERNAME:PASSWORD@10.0.0.1:8080/
NO_PROXY=master.example.com
~~~

It's important that the Master doesn't use the proxy to access itself so make
sure it's listed in the `NO_PROXY` value.

Now restart the Service:
~~~
systemctl restart openshift-master
~~~

If you had previously imported ImageStreams without the proxy configuration to can re-run the process as follows:

~~~
osc delete imagestreams -n openshift --all
osc create -f image-streams.json -n openshift
~~~

## S2I Builds

Let's take the sinatra example.  That build uses fetches gems from
rubygems.org.  The first thing we'll want to do is fork that codebase and
create a file called `.sti/environment`.  The contents of the file are simple
shell variables.  Most libraries will look for `NO_PROXY`, `HTTP_PROXY`, and
`HTTPS_PROXY` variables and react accordingly.

    NO_PROXY=mycompany.com
    HTTP_PROXY=http://USER:PASSWORD@IPADDR:PORT
    HTTPS_PROXY=https://USER:PASSWORD@IPADDR:PORT

## Setting Environment Variables in Pods

It's not only at build time that proxies are required.  Many applications will
need them too.  In previous examples we used environment variables in
`DeploymentConfig`s to pass in database connection information.  The same can
be done for configuring a `Pod`'s proxy at runtime:

    {
      "apiVersion": "v1beta1",
      "kind": "DeploymentConfig",
      "metadata": {
        "name": "frontend"
      },
      "template": {
        "controllerTemplate": {
          "podTemplate": {
            "desiredState": {
              "manifest": {
                "containers": [
                  {
                    "env": [
                      {
                        "name": "HTTP_PROXY",
                        "value": "http://USER:PASSWORD@IPADDR:PORT"
                      },
    ...

## Git Repository Access

In most of the beta examples code has been hosted on GitHub.  This is strictly
for convenience and in the near future documentation will be published to show
how best to integrate with GitLab as well as corporate git servers.  For now if
you wish to use GitHub behind a proxy you can set an environment variable on
the `stiStrategy`:

    {
      "stiStrategy": {
        ...
        "env": [
          {
            "Name": "HTTP_PROXY",
            "Value": "http://USER:PASSWORD@IPADDR:PORT"
          }
        ]
      }
    }

It's worth noting that if the variable is set on the `stiStrategy` it's not
necessary to use the `.sti/environment` file.

## Proxying Docker Pull

This is yet another case where it may be necessary to tunnel traffic through a
proxy.  In this case you can edit `/etc/sysconfig/docker` and add the variables
in shell format:

    NO_PROXY=mycompany.com
    HTTP_PROXY=http://USER:PASSWORD@IPADDR:PORT
    HTTPS_PROXY=https://USER:PASSWORD@IPADDR:PORT


## Future Considerations

We're working to have a single place that administrators can set proxies for
all network traffic.

# APPENDIX - Installing in IaaS Clouds
This appendix contains two "versions" of installation instructions. One is for
"generic" clouds, where the installer does not provision any resources on the
actual cloud (eg: it does not stand up VMs or configure security groups).
Another is specifically for AWS, which can take your API credentials and
configure the entire AWS environment, too.

## Generic Cloud Install

**An Example Hosts File (/etc/ansible/hosts):**

    [OSEv3:children]
    masters
    nodes

    [OSEv3:vars]
    deployment_type=enterprise

    # The default user for the image used
    ansible_ssh_user=ec2-user

    # host group for masters
    # The entries should be either the publicly accessible dns name for the host
    # or the publicly accessible IP address of the host.
    [masters]
    ec2-52-6-179-239.compute-1.amazonaws.com

    # host group for nodes
    [nodes]
    ec2-52-6-179-239.compute-1.amazonaws.com openshift_node_labels="{'region': 'infra', 'zone': 'default'}" #The master
    ec2-52-4-251-128.compute-1.amazonaws.com openshift_node_labels="{'region': 'primary', 'zone': 'default'}"
    ... <additional node hosts go here> ...

**Testing the Auto-detected Values:**
Run the openshift_facts playbook:

    cd ~/openshift-ansible
    ansible-playbook playbooks/byo/openshift_facts.yml

The output will be similar to:

    ok: [10.3.9.45] => {
        "result": {
            "ansible_facts": {
                "openshift": {
                    "common": {
                        "hostname": "ip-172-31-8-89.ec2.internal",
                        "ip": "172.31.8.89",
                        "public_hostname": "ec2-52-6-179-239.compute-1.amazonaws.com",
                        "public_ip": "52.6.179.239",
                        "use_openshift_sdn": true
                    },
                    "provider": {
                      ... <snip> ...
                    }
                }
            },
            "changed": false,
            "invocation": {
                "module_args": "",
                "module_name": "openshift_facts"
            }
        }
    }
    ...

Next, we'll need to override the detected defaults if they are not what we expect them to be
- hostname
  * Should resolve to the internal ip from the instances themselves.
  * openshift_hostname will override.
* ip
  * Should be the internal ip of the instance.
  * openshift_ip will override.
* public hostname
  * Should resolve to the external ip from hosts outside of the cloud
  * provider openshift_public_hostname will override.
* public_ip
  * Should be the externally accessible ip associated with the instance
  * openshift_public_ip will override

To override the the defaults, you can set the variables in your inventory. For example, if using AWS and managing dns externally, you can override the host public hostname as follows:

    [masters]
    ec2-52-6-179-239.compute-1.amazonaws.com openshift_node_labels="{'region': 'infra', 'zone': 'default'}" openshift_public_hostname=ose3-master.public.example.com

**Running ansible:**

    ansible ~/openshift-ansible/playbooks/byo/config.yml

## Automated AWS Install With Ansible

**Requirements:**
- ansible-1.8.x
- python-boto

**Assumptions Made:**
- The user's ec2 credentials have the following permissions:
  - Create instances
  - Create EBS volumes
  - Create and modify security groups
    - The following security groups will be created:
      - openshift-v3-training-master
      - openshift-v3-training-node
  - Create and update route53 record sets
- The ec2 region selected is using ec2 classic or has a default vpc and subnets configured.
  - When using a vpc, the default subnets are expected to be configured for auto-assigning a public ip as well.
- If providing a different ami id using the EC2_AMI_ID, it is a cloud-init enabled RHEL-7 image.

**Setup (Modifying the Values Appropriately):**

    export AWS_ACCESS_KEY_ID=MY_ACCESS_KEY
    export AWS_SECRET_ACCESS_KEY=MY_SECRET_ACCESS_KEY
    export EC2_REGION=us-east-1
    export EC2_AMI_ID=ami-12663b7a
    export EC2_KEYPAIR=MY_KEYPAIR_NAME
    export RHN_USERNAME=MY_RHN_USERNAME
    export RHN_PASSWORD=MY_RHN_PASSWORD
    export ROUTE_53_WILDCARD_ZONE=cloudapps.example.com
    export ROUTE_53_HOST_ZONE=example.com

**Clone the openshift-ansible repo and configure helpful symlinks:**
    ansible-playbook clone_and_setup_repo.yml

**Configuring the Hosts:**

    ansible-playbook -i inventory/aws/hosts openshift_setup.yml

**Accessing the Hosts:**
Each host will be created with an 'openshift' user that has passwordless sudo configured.

# APPENDIX - Linux, Mac, and Windows clients

The OpenShift client `osc` is available for Linux, Mac OSX, and Windows. You
can use these clients to perform all tasks in this documentation that make use
of the `osc` command.

## Downloading The Clients

Visit [Download Red Hat OpenShift Enterprise Beta](https://access.redhat.com/downloads/content/289/ver=/rhel---7/0.5.2.2/x86_64/product-downloads)
to download the Beta4 clients. You will need to sign into Customer Portal using
an account that includes the OpenShift Enterprise High Touch Beta entitlements.

## Log In To Your OpenShift Environment

You will need to log into your environment using `osc login` as you have
elsewhere. If you have access to the CA certificate you can pass it to osc with
the --certificate-authority flag or otherwise import the CA into your host's
certificate authority. If you do not import or specify the CA you will be
prompted to accept an untrusted certificate which is not recommended.

The CA is created on your master in `/etc/openshift/master/ca.crt`

    C:\Users\test\Downloads> osc --certificate-authority="ca.crt"
    OpenShift server [[https://localhost:8443]]: https://ose3-master.example.com:8443
    Authentication required for https://ose3-master.example.com:8443 (openshift)
    Username: joe
    Password:
    Login successful.

    Using project "sinatra"

On Mac OSX and Linux you will need to make the file executable

    chmod +x osc

In the future users will be able to download clients directly from the OpenShift
console rather than needing to visit Customer Portal.
