#!/bin/bash

exec 1>/out/pfsense-build.log 2>&1
set -x

gunzip -f /tmp/pfSense-CE-memstick-ADI.img.gz
cp /tmp/pfSense-CE-memstick-ADI.img /out

#start pfsense vm to gather packages to build offline resources

create_line="virt-install "
create_line+="--hvm "
create_line+="--virt-type=kvm "
create_line+="--name=pfsense "
create_line+="--memory=1000 "
create_line+="--cpu=host-passthrough,cache.mode=passthrough "
create_line+="--vcpus=8 "
create_line+="--boot hd,menu=off,useserial=off "
create_line+="--disk /out/pfSense-CE-memstick-ADI.img "
create_line+="--disk pool=default,size=40,bus=virtio,sparse=no "
create_line+="--connect qemu:///system "
create_line+="--os-type=freebsd "
create_line+="--serial tcp,host=0.0.0.0:4567,mode=bind,protocol=telnet "
create_line+="--serial tcp,host=0.0.0.0:4568,mode=bind,protocol=telnet "
create_line+="--network network=default "
create_line+="--os-variant=freebsd12.0 "
create_line+="--graphics=vnc "

create_line+="--channel unix,target.type=virtio,target.name='org.qemu.guest_agent.0' "

create_line+="--autostart --wait 0"

eval "$create_line"

sleep 30;
(echo open localhost 4568;
  sleep 60;
  echo "ansi";
  sleep 5;
  echo 'A'
  sleep 5;
  echo -ne '\r\n';
  sleep 5;
  echo -ne '\r\n';
  sleep 5;
  echo -ne '\r\n';
  sleep 5;
  echo -ne '\r\n';
  sleep 5;
  echo -ne '\r\n';
  sleep 5;
  echo 'v';
  echo ' ';
  echo -ne '\r\n';
  sleep 5;
  echo 'Y'
  sleep 160;
  echo 'N';
  sleep 5;
  echo 'S';
  sleep 5;
) | telnet


## remove install disk from pfsense
virsh detach-disk --domain pfsense /out/pfSense-CE-memstick-ADI.img --persistent --config --live
virsh reboot pfsense

sleep 120;

### cleanup
runuser -l root -c  "rm -rf /tmp/usb"
#####

virsh destroy pfsense
virsh undefine --domain pfsense --remove-all-storage