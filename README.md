# OpenShift 4 (beta) on AWS
This tutorial walks you through setting up OpenShift the easy way. This guide
is for people looking for a fully automated command to bring up a
self-managed pre-release (beta) OpenShift 4 cluster on Amazon AWS.

> The results of this tutorial should not be viewed as production ready.

## Target Audience

The target audience for this tutorial is a user looking to install and
operate a pre-release OpenShift 4 cluster for early access, who wants to
understand how everything fits together.

## Cluster Details

This document guides you through creating a highly available OpenShift
cluster on AWS.

## Documentation
With the third beta drop of OpenShift 4, this repository will link you to the work-in-progress official documentation. Currently that documentation is behind a user/password (for anti-search-engine-indexing purposes.

```
Username: stage-user
Password: zc9$!9S%&0N9hsBVSN42
```

## Bugs vs. Cases
As this is pre-release software, it is completely unsupported, and you should
not open support cases for any issues you encounter. However, we very much
wish to collect feedback on documentation and other product issues. Should
you encounter a problem, feel free to [file a
bug](https://bugzilla.redhat.com/enter_bug.cgi?product=OpenShift%20Container%20Platform).

## Exercises

This tutorial assumes you have familiarity with Amazon AWS.

* [Prerequisites](docs/01-prerequisites.md)
* [Installing the Cluster](docs/02-install.md)
* [Exploring the Cluster](docs/03-explore.md)
* [Scaling the Cluster](docs/04-scaling-cluster.md)
* [Infrastructure Nodes](docs/05-infrastructure-nodes.md)
* [Authentication](docs/06-authentication.md)
* [Operator Extensions](docs/07-extensions.md)
* [Tips and tricks](docs/97-tips-and-tricks.md)
* [Cleaning Up](docs/98-cleanup.md)
* [Troubleshooting](docs/99-troubleshooting.md)
