#!/bin/bash
set -e

SUDO_PASS="$1"

echo "$SUDO_PASS"

echo "$SUDO_PASS" | sudo -S apt -y update
echo "$SUDO_PASS" | sudo -S apt -y dist-upgrade
echo "$SUDO_PASS" | sudo -S apt -y install nginx
echo "$SUDO_PASS" | sudo -S apt -y autoclean
echo "$SUDO_PASS" | sudo -S apt -y autoremove
