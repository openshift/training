# OpenShift V3 Beta Documentation
- Basic Installation via go binary.  No docker-ized framework components (ie
    OpenShift router, master, etcd, and other internal components of OpenShift)
    - Be able to add multiple nodes to the master. 
- All features found in the Alpha drops the Ben has been demo'ing around STI and
    then basically adding routing/dns/users/auth/console
- Limited console and command line
- Basic HTTP/S only routing for application protocols.  No non-HTTP application
    traffic.
- DNS alias assignments for application urls via the REST API only
- Non-SSL HTTP routing integration example for F5
- Work with supplied docker example applications
- No application docker image auto-binding.  Need to hardwire multi-tier
    application components to each other post deployment
- Users can form projects
- Multi-user protection
    - roles, AUTH, identity
