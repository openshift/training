#!/bin/bash -e
#
# Default STI assemble script for the 'ruby-20-centos' image.
#

if [ "$1" = "-h" ]; then
  exec /opt/ruby/bin/usage
fi

function rake_assets_precompile() {
  [ -f .sti/markers/disable_asset_compilation ] && return
  [ ! -f Gemfile ] && return
  [ ! -f Rakefile ] && return
  ! grep " rails " Gemfile.lock >/dev/null && return
  ! grep " execjs " Gemfile.lock >/dev/null && return
  ! bundle exec "rake -T" | grep "assets:precompile" >/dev/null && return

  echo "---> Starting asset compilation."
  bundle exec rake assets:precompile
}

# For SCL enablement
source .bashrc

set -e

if [ "$(ls /tmp/artifacts/ 2>/dev/null)" ]; then
  echo "Restoring build artifacts"
  mv /tmp/artifacts/* $HOME/.
fi

APP_RUNTIME_DIR="${HOME}/src"
APP_SRC_DIR="/tmp/src"

echo "---> Installing application source"
mkdir -p ${APP_RUNTIME_DIR}
cp -Rf ${APP_SRC_DIR}/* ${APP_RUNTIME_DIR}/

pushd "$APP_RUNTIME_DIR/${APP_ROOT}" >/dev/null
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
  # We can't use 'exec' here because it will exit from the script after the
  # bundle install command finish. Thus the bundle install cannot receive SIGINT
  # from console (ctrl+c)
  #
  echo "---> Running 'bundle install ${ADDTL_BUNDLE_ARGS}'"
  bundle install --path ${HOME}/bundle ${ADDTL_BUNDLE_ARGS}

  echo "---> Cleaning up unused ruby gems"
  bundle clean -V
fi

if [[ "$RAILS_ENV" == "production" || "$RACK_ENV" == "production" ]]; then
  rake_assets_precompile
fi

# TODO: Add `rake db:migrate` if linked with DB container

popd >/dev/null
