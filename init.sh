#!/bin/bash

exec 1>/out/pfsense-build.log 2>&1
set -x

gunzip -f /tmp/pfSense-CE-memstick-ADI.img.gz
cp /tmp/pfSense-CE-memstick-ADI.img /out

ls -al /out
ls -al /tmp
echo "done!"