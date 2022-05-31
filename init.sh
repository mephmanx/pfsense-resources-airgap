#!/bin/bash
set -e

wget -O /pfsense.gz https://nyifiles.netgate.com/mirror/downloads/pfSense-CE-memstick-ADI-$1-amd64.img.gz
gunzip -f /pfsense.gz

echo "done!"