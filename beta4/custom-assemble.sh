#!/bin/bash

function rake_assets_precompile() {
  [ -n $DISABLE_ASSET_COMPILATION ] && return
  [ ! -f Gemfile ] && return
  [ ! -f Rakefile ] && return
  ! grep " rails " Gemfile.lock >/dev/null && return
  ! grep " execjs " Gemfile.lock >/dev/null && return
  ! bundle exec 'rake -T' | grep "assets:precompile" >/dev/null && return

  echo "---> Starting asset compilation."
  bundle exec rake assets:precompile
}

# For SCL enablement
source .bashrc

set -e

echo "---> Installing application source"
cp -Rf /tmp/src/* ./

echo "---> Building your Ruby application from source"
if [ -f Gemfile ]; then
  ADDTL_BUNDLE_ARGS=""
  if [ -f Gemfile.lock ]; then
    ADDTL_BUNDLE_ARGS="--deployment"
  fi

  if [[ "$RAILS_ENV" == "development" || "$RACK_ENV" == "development" ]]; then
    BUNDLE_WITHOUT=${BUNDLE_WITHOUT:-"test"}
  elif [[ "$RAILS_ENV" == "test" || "$RACK_ENV" == "test" ]]; then
    BUNDLE_WITHOUT=${BUNDLE_WITHOUT:-"development"}
  else
    BUNDLE_WITHOUT=${BUNDLE_WITHOUT:-"development:test"}
  fi

  echo "---> Running 'bundle install ${ADDTL_BUNDLE_ARGS}'"
  bundle install --path ./bundle ${ADDTL_BUNDLE_ARGS}

  echo "---> Cleaning up unused ruby gems"
  bundle clean -V
fi

if [[ "$RAILS_ENV" == "production" || "$RACK_ENV" == "production" ]]; then
  rake_assets_precompile
fi

echo "---> CUSTOM S2I ASSEMBLE COMPLETE"

# TODO: Add `rake db:migrate` if linked with DB container
