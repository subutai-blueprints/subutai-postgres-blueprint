#!/bin/bash

set -e
set -x

apt-get update
apt-get install locales
echo "locales locales/locales_to_be_generated multiselect en_US.UTF-8 UTF-8" | debconf-set-selections
echo "locales locales/default_environment_locale select en_US.UTF-8" | debconf-set-selections
sed -i 's/^# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
dpkg-reconfigure --frontend=noninteractive locales

