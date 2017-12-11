#!/bin/sh

set -eu

chef_version='12.21.26'
chef_utils_version='c08a9ff7aa176e09410ab6381380b9ae179293de'

omnitruck_url='https://omnitruck.chef.io/install.sh'
chefctl_url="https://raw.githubusercontent.com/facebook/chef-utils/${chef_utils_version}/chefctl/chefctl.rb"
chefctl_hooks_url='https://raw.githubusercontent.com/davide125/dc-chef-utils/master/chefctl_hooks.rb'
chefctl_config_url=''
chef_config_path='/etc/chef'

# Source config to override any default settings if needed
# shellcheck disable=SC1091
[ -r /etc/chef-bootstrap-config ] && . /etc/chef-bootstrap-config

chefctl='/usr/local/sbin/chefctl.rb'
chefctl_hooks='/etc/chef/chefctl_hooks.rb'

# Check whether a command exists - returns 0 if it does, 1 if it does not
exists() {
  if command -v "$1" >/dev/null 2>&1
  then
    return 0
  else
    return 1
  fi
}

fail() {
  echo "$@"
  exit 1
}

detect_platform() {
  if [ -f /etc/debian_version ]; then
    platform='debian'
    ssh_package='openssl-clients'
  elif [ -f /etc/centos-release ]; then
    platform='centos'
    ssh_package='openssh_client'
  else
    fail 'Platform not supported!'
  fi
}

install_packages() {
  detect_platform
  case "$platform" in
  centos)
    yum install -y "$@"
    ;;
  debian)
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y "$@"
    ;;
  *)
    fail 'Unknown platform'
    ;;
 esac
}

[ "$USER" = root ] || fail 'chef_bootstrap has to be run as root!' 

# Install missing dependencies
pkgs=''
exists curl || pkgs="$pkgs curl"
exists ssh || pkgs="$pkgs $ssh_package"
exists git || pkgs="$pkgs git"
exists hg || pkgs="$pkgs mercurial"
# shellcheck disable=SC2086
[ -n "$pkgs" ] && install_packages $pkgs

# Install Chef
installed_chef_version=$(/opt/chef/bin/chef-client --version 2> /dev/null | cut -f2 -d' ')
if [ "$installed_chef_version" != "$chef_version" ]; then
  echo 'Installing Chef'
  curl -s "$omnitruck_url" | bash -s -- -v "$chef_version"
  mkdir -p $chef_config_path
fi

# Install chefctl
echo 'Installing chefctl'
curl -so ${chefctl} "$chefctl_url"
chmod +x "$chefctl"
ln -sf chefctl.rb /usr/local/sbin/chefctl

echo 'Installing chefctl_hooks'
curl -so ${chefctl_hooks} "$chefctl_hooks_url"

if [ -n "$chefctl_config_url" ]; then
  echo 'Installing chefctl config'
  curl -so /etc/chefctl-config.rb "$chefctl_config_url"
fi

echo "Run '$chefctl -i' to kick off the first Chef run"
exit 0
