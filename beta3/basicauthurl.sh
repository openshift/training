ROUTE="basicauthurl.example.com"
GIT_REPO="git://github.com/brenton/basicauthurl-example.git"

rm -f basicauthurl.json
cp basicauthurl.template basicauthurl.json

# --hostnames need to match route
sed -i "s@%%ROUTE%%@${ROUTE}@" basicauthurl.json

# need a way to inject their own git url
sed -i "s@%%GIT_REPO%%@${GIT_REPO}@" basicauthurl.json

pushd /var/lib/openshift
  if [ ! -d "openshift.local.certificates/basicauthurl" ]; then
    openshift admin create-server-cert --cert='openshift.local.certificates/basicauthurl/cert.crt' --hostnames="${ROUTE}" --key='openshift.local.certificates/basicauthurl/key.key'
  else
    echo "Found preexiting certificates."
  fi
popd


echo "Generating basicauthurl.json."
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
