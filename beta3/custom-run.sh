#!/bin/bash -e

function is_puma_installed() {
  [ ! -f Gemfile.lock ] && return 1
  grep ' puma ' Gemfile.lock >/dev/null
}

# The APP_ROOT_DIR needs to be exported, so the Puma or other Ruby
# application server can pick it up and use it as 'application root'
#
export APP_ROOT_DIR="${HOME}/${APP_ROOT:-.}"

export RACK_ENV=${RACK_ENV:-"production"}
export RAILS_ENV=${RAILS_ENV:-"${RACK_ENV}"}

cd $APP_ROOT_DIR

# For SCL enablement
source .bashrc

# Allow users to inspect/debug the builder image itself, by using:
# $ docker run -i -t openshift/centos-ruby-builder --debug
#
[ "$1" == "--debug" ] && exec /bin/bash

echo "---> CUSTOM STI RUN COMPLETE"

if is_puma_installed; then
  exec bundle exec "puma --config ${HOME}/etc/puma.cfg"
else
  echo "You might consider adding 'puma' into your Gemfile."
  exec bundle exec "rackup -P ${HOME}/run/rack.pid --host 0.0.0.0"
fi
