#!/bin/bash
set -e

wget -O /pfsense.gz https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-memstick-ADI-$1-RELEASE-amd64.img.gz
gunzip -f /pfsense.gz

echo "done!"