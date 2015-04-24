#!/bin/bash

ROUTE="basicauthurl.example.com"
GIT_REPO="git://github.com/brenton/basicauthurl-example.git"
FORCE=

function usage
{
    echo "This tool will output a json service, route, build and deployment
config suitable for hosting LDAP authentication on OpenShift."
    echo ""
    echo "usage: basicauthurl.sh [[[-r <route> ] [-g <git repository>]] | [-h]]"
    echo ""
    echo "-r | --route       The hostname used to reach the LDAP authentication service."
    echo "                   This script will generated certificates that match this name."
    echo "                   The default is basicauthurl.example.com"
    echo ""
    echo "-g | --git-repo    The repository hosting basicauthurl.conf.  If you are OK"
    echo "                   with the beta3 defaults you can leave this blank to use"
    echo "                   git://github.com/brenton/basicauthurl-example.git."
    echo ""
    echo "                   NOTE: For now this repository must be available to OpenShift"
    echo "                   unauthenticated."
    echo ""
    echo "-f | --force       Force certificate regeneration."

}

while [ "$1" != "" ]; do
    case $1 in
        -r | --route )          shift
                                ROUTE=$1
                                ;;
        -g | --git-repo )       shift
                                GIT_REPO=$1
                                ;;
        -f | --force )          FORCE=1
                                ;;
        -h | --help )           usage
                                exit
                                ;;
        * )                     usage
                                exit 1
    esac
    shift
done

rm -f basicauthurl.json
cp basicauthurl.template basicauthurl.json

# --hostnames need to match route
sed -i "s@%%ROUTE%%@${ROUTE}@" basicauthurl.json

# need a way to inject their own git url
sed -i "s@%%GIT_REPO%%@${GIT_REPO}@" basicauthurl.json

pushd /var/lib/openshift > /dev/null
  if [ "$FORCE" = "1" ]; then
    rm -rf openshift.local.certificates/basicauthurl
  fi

  if [ ! -d "openshift.local.certificates/basicauthurl" ]; then
    echo "Creating server certificate for $ROUTE"
    openshift admin create-server-cert --cert='openshift.local.certificates/basicauthurl/cert.crt' --hostnames="${ROUTE}" --key='openshift.local.certificates/basicauthurl/key.key'
  else
    echo "Found preexiting certificates.  Use --force to force regeneration."
  fi
popd > /dev/null


echo "Generating basicauthurl.json..."
CERT=`cat /var/lib/openshift/openshift.local.certificates/ca/cert.crt | sed ':a;N;$!ba;s/\n/%%NEWLINE%%/g'`
sed -i "s@%%OPENSHIFT_CA_DATA%%@${CERT}@" basicauthurl.json

CERT=`cat /var/lib/openshift/openshift.local.certificates/basicauthurl/cert.crt | sed ':a;N;$!ba;s/\n/%%NEWLINE%%/g'`
sed -i "s@%%OPENSHIFT_CERT_DATA%%@${CERT}@" basicauthurl.json

CERT=`cat /var/lib/openshift/openshift.local.certificates/basicauthurl/key.key | sed ':a;N;$!ba;s/\n/%%NEWLINE%%/g'`
sed -i "s@%%OPENSHIFT_KEY_DATA%%@${CERT}@" basicauthurl.json

# It was horrible to deal with escaping newlines in bash and sed so I'm doing
# this at the end for readability.
sed -i 's/%%NEWLINE%%/\\n/g' basicauthurl.json

# needs to print our the config change needed for master.yaml
echo "You can now run 'osc create -f basicauthurl.json"
echo ""
echo "Replace the identityProvider in /etc/openshift/master.yaml and add the following:"
echo "
  identityProviders:
  - challenge: true
    login: true
    name: basicauthurl
    provider:
      apiVersion: v1
      kind: BasicAuthPasswordIdentityProvider
      url: https://${ROUTE}/validate
      ca: /var/lib/openshift/openshift.local.certificates/ca/cert.crt
"
