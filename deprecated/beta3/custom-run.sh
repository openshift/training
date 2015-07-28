#!/bin/bash

function is_puma_installed() {
  [ ! -f Gemfile.lock ] && return 1
  grep ' puma ' Gemfile.lock >/dev/null
}

# For SCL enablement
source .bashrc

set -e

export RACK_ENV=${RACK_ENV:-"production"}
export RAILS_ENV=${RAILS_ENV:-"${RACK_ENV}"}

echo "---> CUSTOM STI RUN COMPLETE"

if is_puma_installed; then
  exec bundle exec "puma --config ../etc/puma.cfg"
else
  echo "You might consider adding 'puma' into your Gemfile."
  if [ -f Gemfile ]; then
    exec bundle exec "rackup -P /tmp/rack.pid --host 0.0.0.0 --port 8080"
  else
    exec rackup -P /tmp/rack.pid --host 0.0.0.0 --port 8080
  fi
fi
