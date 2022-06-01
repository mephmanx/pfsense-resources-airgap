#!/bin/bash

exec 1>/out/pfsense-build.log 2>&1
set -x


ls -al /out
ls -al /tmp
echo "done!"