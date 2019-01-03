There are various software and non-software prerequisites that must be
fulfilled before you can install OpenShift using these documented methods.

# Non-Software Prerequisites

## Amazon Web Services
The new installer will be launching and using at least the following types
and quantity of AWS resources: 7 EC2 instances (m4.large), 7 NAT Gateways, 7
EIPs, 2 IAM roles, 6 EBS Volumes, 2 DNS zone, DNS records in the DNS zone, 4
load balancers, subnets, 13 security groups, S3 buckets, route tables, and a
VPC. It may use other things, too.

If your AWS account doesn't support these limits, please be sure to request
limit increases through the AWS console.

You will need an AWS account that additionally meets the following
requirements:

* An available IAM role with admin privileges in that account. As an example
  `openshift4-beta-admin`. The installer will be using this IAM role to setup
  the AWS resources for OpenShift. Documentation on creating IAM users can be
  found here:
  https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html

* An availble DNS domain (or subdomain) in a zone managed by Route53.
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

## Provisioning Host
You will need a host from which to run the installer, and this host should be
internet connected (can access the AWS APIs). The Red Hat family of OS
(RHEL/Fedora/CentOS) and MacOS have been tested and known to work. A Linux
EC2 instance running in AWS is a convenient option, but your own laptop or a
server in your own environment would suffice.

# Software Prerequisites

## AWS CLI
The installation host you are using must have the AWS command line tools
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

## OpenShift Installer

1. You will be redirected to https://cloud.openshift.com/clusters/install -
  Download the Installer release for your platform
1. Download Terraform
1. Download OpenShift client tools


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
1. Download the Pull Secret and make sure you have its contents available to you

Next: [Installing the Cluster](02-install.md)
