#!/bin/bash

set -exu

. $(dirname $0)/../commonvar.sh

enabled_before_update=$1 # enabled / disabled
status_before_update=$2 # active / inactive

# Install the current
sudo apt install -V -y \
    /host/${distribution}/pool/${code_name}/${channel}/*/*/fluent-package_*_${architecture}.deb

# Make a dummy pacakge for the next version
dpkg-deb -R /host/${distribution}/pool/${code_name}/${channel}/*/*/fluent-package_*_${architecture}.deb tmp
last_ver=$(cat tmp/DEBIAN/control | grep "Version: " | sed -E "s/Version: ([0-9.]+)-([0-9]+)/\2/g")
sed -i -E "s/Version: ([0-9.]+)-([0-9]+)/Version: \1-$(($last_ver+1))/g" tmp/DEBIAN/control
dpkg-deb --build tmp next_version.deb

# The service should start automatically
systemctl is-active fluentd
# The service should be enabled by default
systemctl is-enabled fluentd

# Start the service
if [ "$enabled_before_update" = disabled ]; then
    sudo systemctl disable fluentd
fi
if [ "$status_before_update" = inactive ]; then
    sudo systemctl stop fluentd
fi

main_pid=$(systemctl show --value --property=MainPID fluentd)

# Install the dummy package
sudo apt install -V -y ./next_version.deb 2>&1 | tee upgrade.log

# Test: needrestart was suppressed
if dpkg-query --show --showformat='${Version}' needrestart ; then
  case $code_name in
    focal)
      # dpkg-query succeeds even though needrestart is not installed.
      (! grep "No services need to be restarted." upgrade.log)
      ;;
    *)
      grep "No services need to be restarted." upgrade.log
      ;;
  esac
fi

# The service should take over the state
if [ "$enabled_before_update" = enabled ]; then
    systemctl is-enabled fluentd
else
    (! systemctl is-enabled fluentd)
fi

if [ "$status_before_update" = active ]; then
    # The service should NOT restart automatically after update
    # (The process before update should continue to run)
    systemctl is-active fluentd
    test $main_pid -eq $(systemctl show --value --property=MainPID fluentd)
elif [ "$enabled_before_update" = enabled ]; then
    # The service should start automatically
    systemctl is-active fluentd
else
    # The service should NOT start automatically
    (! systemctl is-active fluentd)
fi
