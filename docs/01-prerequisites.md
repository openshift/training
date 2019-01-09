There are various software and non-software prerequisites that must be
fulfilled before you can install OpenShift using these documented methods.

# Non-Software Prerequisites

## Amazon Web Services
The current installation process deploys resources on AWS.

### Resource Limits
The new installer will be launching and using at least the following types
and quantity of AWS resources: 7 EC2 instances (m4.large), 7 NAT Gateways, 7
EIPs, 2 IAM roles, 6 EBS Volumes, 2 DNS zone, DNS records in the DNS zone, 4
load balancers, subnets, 13 security groups, S3 buckets, route tables, and a
VPC. It may use other things, too.

If your AWS account doesn't support these limits, please be sure to request
limit increases through the AWS console.

### Supported Regions
Currently the boostrap images that the installer uses are only available in
the following AWS regions:

* us-east-1 (N.Virginia)
* us-east-2 (Ohio)
* us-west-1 (N.California)
* us-west-2 (Oregon)
* sa-east-1 (Sao Paulo)
* eu-west-2 (London)
* eu-west-3 (Paris) 

### Additional AWS Requirements
You will need an AWS account that additionally meets the following
requirements:

* An available IAM role with admin privileges in that account. As an example
  `openshift4-beta-admin`. The installer will be using this IAM role to setup
  the AWS resources for OpenShift. Documentation on creating IAM users can be
  found here:
  https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html

* An available DNS domain (or subdomain) in a zone managed by Route53.
  **Note**: You do not need to purchase the domain through AWS. You simply need
  a Route53-managed zone that the installer can use to create the necessary DNS
  entries for EC2 instances and other items. This can be a base domain (eg: 
  foo.com) or it could be a subdomain (eg: foo.bar.com). The only requirement
  is that the zone authority for the domain lies with the AWS nameservers for
  the DNS zone. If you do not have an available zone please reach out to your 
  Red Hat contact for assistance.
  **Note**: If you purchase a new domain it may take some time for the relevant
  DNS changes to propagate. Information on purchasing domains through AWS can
  be found here:
  https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/registrar.html

## Red Hat Developers
Access to some of the installation web resources requires a Red Hat customer
portal account that is associated with the Red Hat Developer program. Make
sure to visit https://developers.redhat.com and log-in with your customer
portal account and accept the Developer program Ts&Cs.

# Software Prerequisites

## Provisioning Host
You will need a host from which to run the installer, and this host should be
internet connected (can access the AWS APIs). The Red Hat family of OS
(RHEL/Fedora/CentOS) and MacOS have been tested and known to work. A Linux
EC2 instance running in AWS is a convenient option, but your own laptop or a
server in your own environment would suffice.

If you use a (remote/headless) provisioning host, any files downloaded or
other steps performed should be done on the provisioning host itself. As
obtaining the OpenShift installer and tools uses a browser, you may wish to
download locally and then transfer to your provisioning host.

## AWS CLI
The provisioning host you are using must have the AWS command line tools
(CLI) installed. See
https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html

After installing the AWS CLI, it must be configured for the AWS account and
IAM role. This assumes we are using the `openshift4-beta-admin` IAM user
mentioned earlier:

```
$ aws configure --profile=openshift4-beta-admin
AWS Access Key ID [None]: <for the AWS role openshift4-beta-admin >
AWS Secret Access Key [None]: <for the AWS role openshift4-beta-admin>
Default region name [None]: <the AWS region to deploy the beta environment>
Default output format [None]: text
Configure everything to use this new profile
$ export AWS_PROFILE=openshift4-beta-admin
```

## SSH keypair
Your provisioning host will need an SSH keypair in order to access the
OpenShift cluster instances on AWS. If you do not already have an existing
default keypair (id_rsa/id_rsa.pub) then you can use `ssh-keygen` to
create one.

The installer will interactively prompt for an SSH keypair. Use the arrow
keys to select the one you wish to use.

## OpenShift Installer

1. Visit https://try.openshift.com with your web browser
1. Login with the Red Hat Account that is in the Developer Program
1. Following that, you will be re-directed to
    https://cloud.openshift.com/clusters/install Scroll down to the section
    called “Download the installer”
1. Download the installer; You will be re-directed to
    https://github.com/openshift/installer/releases where you can find the
    appropriate binary for your host (openshift-install-linux-amd64 or
    openshift-install-darwin-amd64)
1. Once the download is complete, rename the installer and make it
    executable. For example:
    ```
    mv openshift-install-darwin-amd64 openshift-install
    chmod +x openshift-install
    ```
1. Download the Pull Secret from https://cloud.openshift.com/clusters/install
  and make sure you have its contents available to you

## OpenShift CLI
On https://cloud.openshift.com/clusters/install, scroll down to the section
called “Access your new cluster!” and click the button "Download Command-line
Tools". Download the appropriate CLI for your platform, extract it, make sure
it is executable, and make sure that it is in your `PATH`.

Next: [Installing the Cluster](02-install.md)
