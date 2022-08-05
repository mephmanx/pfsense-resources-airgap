#!/bin/bash

exec 1>/out/pfsense-build-"$1".log 2>&1
set -x

source /tmp/openstack-scripts/vm_functions.sh
source /tmp/openstack-scripts/project_config.sh
source /tmp/openstack-setup/openstack-env.sh
yum install -y expect
gunzip -f /temp/pfSense-CE-memstick-ADI.img.gz
### make sure to get offset of fat32 partition to put config.xml file on stick to reload!

mkdir /temp/usb
dd if=/dev/zero bs=1M count=400 >> /temp/pfSense-CE-memstick-ADI.img
parted /temp/pfSense-CE-memstick-ADI.img resizepart 3 1300MB
loop_Device=$(losetup -f --show -P /temp/pfSense-CE-memstick-ADI.img)
mkfs -t vfat "$loop_Device"p3
mount "$loop_Device"p3 /temp/usb

dd if=/dev/zero bs=1M count=400 >> /tmp/transfer.img
loop_device2=$(losetup -f --show -P /tmp/transfer.img)
mkfs -t vfat "$loop_device2"

### initial cfg script
##  This runs after install but before first reboot
cat > /temp/init.sh <<EOF
DRIVE_KB=\`geom disk list | grep Mediasize | sed 1d | awk '{ print \$2 }'\`
DRIVE_SIZE=\$((DRIVE_KB / 1024 / 1024 * 75/100))
HOSTNAME_SUFFIX=\$(cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 5 ; echo);
RANDOM_PWD=\$(cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 31 ; echo);
HOSTNAME="$ORGANIZATION-\$HOSTNAME_SUFFIX"

sed -i -e 's/{CACHE_SIZE}/'\$DRIVE_SIZE'/g' /mnt/cf/conf/config.xml
sed -i -e 's/{HOSTNAME}/'\$HOSTNAME'/g' /mnt/cf/conf/config.xml
sed -i -e 's/{OPENVPN_CERT_PWD}/'\$RANDOM_PWD'/g' /mnt/cf/conf/config.xml
echo "fin" > /tmp/init.complete
EOF

cp /tmp/openstack-setup/openstack-env.sh /temp/usb/
if [ 'dev' == "$1" ]; then
  mv /openstack-pfsense-test.xml /temp/usb/config.xml
else
  mv /openstack-pfsense.xml /temp/usb/config.xml
fi

cp /pf_functions.sh /temp/usb/
cp /pfsense-init.sh /temp/usb/
cp /pfSense-repo.conf /temp/usb/

if [ 'prod' == "$1" ]; then
  cp /tmp/repo.tar /temp/usb/
  mv /tmp/repo.tar /tmp/repo-backup.tar
fi

## move generated file above to disk
cp /temp/init.sh /temp/usb/

### cloudfoundry TCP ports
CF_TCP_START_PORT=1024
CF_TCP_END_PORT=$((CF_TCP_START_PORT + CF_TCP_PORT_COUNT))

#### backend to change host header from whatever it comes in as to internal domain
ADVANCED_BACKEND=$(echo "http-request replace-value Host ^(.*)(\.[^\.]+){2}$ \1.$INTERNAL_DOMAIN_NAME" | base64 | tr -d '\n\r')

######  variables to remove from PFSense cloud router
sed -i "s/{TELEGRAM_API}/$TELEGRAM_API/g" /temp/usb/config.xml
sed -i "s/{TELEGRAM_CHAT_ID}/$TELEGRAM_CHAT_ID/g" /temp/usb/config.xml
sed -i "s/{OINKMASTER}/$OINKMASTER/g" /temp/usb/config.xml
sed -i "s/{MAXMIND_KEY}/$MAXMIND_KEY/g" /temp/usb/config.xml
#######

##### replace PFSense template vars
sed -i "s/{CF_TCP_START_PORT}/$CF_TCP_START_PORT/g" /temp/usb/config.xml
sed -i "s/{CF_TCP_END_PORT}/$CF_TCP_END_PORT/g" /temp/usb/config.xml
sed -i "s/{INTERNAL_VIP}/$INTERNAL_VIP/g" /temp/usb/config.xml
sed -i "s/{EXTERNAL_VIP}/$EXTERNAL_VIP/g" /temp/usb/config.xml
sed -i "s/{LAN_CENTOS_IP}/$LAN_CENTOS_IP/g" /temp/usb/config.xml
sed -i "s/{GATEWAY_ROUTER_IP}/$GATEWAY_ROUTER_IP/g" /temp/usb/config.xml  #set to dhcp for local testing
sed -i "s/{GATEWAY_ROUTER_DHCP_START}/$GATEWAY_ROUTER_DHCP_START/g" /temp/usb/config.xml
sed -i "s/{GATEWAY_ROUTER_DHCP_END}/$GATEWAY_ROUTER_DHCP_END/g" /temp/usb/config.xml
sed -i "s/{INTERNAL_DOMAIN_NAME}/$INTERNAL_DOMAIN_NAME/g" /temp/usb/config.xml
sed -i "s/{NETWORK_PREFIX}/$NETWORK_PREFIX/g" /temp/usb/config.xml
sed -i "s/{CLOUDFOUNDRY_VIP}/$CLOUDFOUNDRY_VIP/g" /temp/usb/config.xml
sed -i "s/{IDENTITY_VIP}/$IDENTITY_VIP/g" /temp/usb/config.xml
sed -i "s/{SUPPORT_VIP}/$SUPPORT_VIP/g" /temp/usb/config.xml
sed -i "s/{BASE_DN}/$(baseDN)/g" /temp/usb/config.xml
sed -i "s/{LB_ROUTER_IP}/$LB_ROUTER_IP/g" /temp/usb/config.xml
sed -i "s/{LB_DHCP_START}/$LB_DHCP_START/g" /temp/usb/config.xml
sed -i "s/{LB_DHCP_END}/$LB_DHCP_END/g" /temp/usb/config.xml
sed -i "s/{ADVANCED_BACKEND}/$ADVANCED_BACKEND/g" /temp/usb/config.xml
sed -i "s/{VPN_NETWORK}/$VPN_NETWORK/g" /temp/usb/config.xml
#######

##### cert placeholders.  lengths are VERY important!!
sed -i "s/{CA_CRT}/$(generate_specific_pwd 2465)/g" /temp/usb/config.xml
sed -i "s/{CA_KEY}/$(generate_specific_pwd 4389)/g" /temp/usb/config.xml
sed -i "s/{INITIAL_WILDCARD_CRT}/$(generate_specific_pwd 2765)/g" /temp/usb/config.xml
sed -i "s/{INITIAL_WILDCARD_KEY}/$(generate_specific_pwd 4393)/g" /temp/usb/config.xml
###

runuser -l root -c  'umount /temp/usb'

cp /temp/pfSense-CE-memstick-ADI.img /tmp/pfSense-CE-memstick-ADI-"$1".img
#start pfsense vm to gather packages to build offline resources
if [ 'dev' == "$1" ] || [ 'keep' == "$2" ]; then

  create_line="virt-install "
  create_line+="--hvm "
  create_line+="--virt-type=kvm "
  create_line+="--name=pfsense "
  create_line+="--memory=1000 "
  create_line+="--cpu=host-passthrough,cache.mode=passthrough "
  create_line+="--vcpus=8 "
  create_line+="--boot hd,menu=off,useserial=off "
  create_line+="--disk /tmp/pfSense-CE-memstick-ADI-$1.img "
  create_line+="--disk pool=VM-VOL,size=40,bus=virtio,sparse=no "
  create_line+="--connect qemu:///system "
  create_line+="--os-type=freebsd "
  create_line+="--serial tcp,host=0.0.0.0:4567,mode=bind,protocol=telnet "
  create_line+="--serial tcp,host=0.0.0.0:4568,mode=bind,protocol=telnet "
  create_line+="--network type=direct,source=ext-con,model=virtio "
  create_line+="--network network=default "
  create_line+="--network network=default "
  create_line+="--os-variant=freebsd12.0 "
  create_line+="--graphics=vnc "

  create_line+="--channel unix,target.type=virtio,target.name='org.qemu.guest_agent.0' "

  create_line+="--autostart --wait 0"

  eval "$create_line"

  ## arg $1 is build repo cache or build prod image
  cmd=""
  cmdExtract=""
  cmdCopy=""
  if [ 'prod' == "$1" ]; then
    cmd="mkdir /mnt/tmp/repo-dir"
    cmdExtract="tar xf /mnt/root/repo.tar -C /mnt/tmp/repo-dir"
    cmdRepoSetup="yes | cp /tmp/test-mnt/pfSense-repo.conf /mnt/usr/local/share/pfSense/pfSense-repo.conf; yes | cp /tmp/test-mnt/pfSense-repo.conf /mnt/usr/local/share/pfSense/pkg/repos/pfSense-repo.conf; yes | cp /tmp/test-mnt/pfSense-repo.conf /mnt/etc/pkg/FreeBSD.conf"
  fi

cat > /temp/pf-init-1.sh <<EOF
mount -u -o rw /
mkdir /tmp/test-mnt
mount -v -t msdosfs /dev/vtbd0s3 /tmp/test-mnt
cp /tmp/test-mnt/* /mnt/root
$cmd
$cmdExtract
$cmdRepoSetup
chmod +x /mnt/root/*.sh
cd /mnt/root
./init.sh

## important!  endless loop if below is removed!
echo "fin" > /tmp/init.complete
EOF

  PFSENSE_INIT=$(cat </temp/pf-init-1.sh | base64 | tr -d '\n\r')

  pfsense_init_array=( $(echo "$PFSENSE_INIT" | fold -c250 ))

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
    sleep 10;
    echo "touch /mnt/root/pf-init-1.sh; touch /mnt/root/pf-init-1.sh.enc;";
    sleep 10;
    for element in "${pfsense_init_array[@]}"
      do
        echo "echo '$element' >> /mnt/root/pf-init-1.sh.enc";
        sleep 5;
      done
    echo "openssl base64 -d -in /mnt/root/pf-init-1.sh.enc -out /mnt/root/pf-init-1.sh;";
    sleep 10;
    echo "rm -rf /mnt/root/*.enc";
    sleep 10;
    echo "cd /mnt/root/"
    sleep 10;
    echo "chmod +x pf-init-1.sh;"
    sleep 10;
    echo "./pf-init-1.sh"
    sleep 10;
  ) | telnet

### add wait before restart
cat > /temp/wait1.sh <<EOF
#!/usr/bin/expect
set timeout -1;
spawn telnet localhost 4568
send "echo ''\n"
expect "#"
send "\n"
send "yes|pkg install bash;bash -c 'while \[ true \];do sleep 5;if \[ -f /tmp/init.complete \];then rm -rf /tmp/init.complete;exit;fi;done;'\n"
EOF

chmod +x /temp/wait1.sh
./temp/wait1.sh
####

  virsh detach-disk --domain pfsense /tmp/pfSense-CE-memstick-ADI-"$1".img --persistent --config --live
  ### cleanup
  runuser -l root -c  "rm -rf /temp/usb"
  #####
fi

if [ 'dev' == "$1" ]; then

  ## remove install disk from pfsense
  virsh destroy pfsense
  sleep 20;
  virsh start pfsense

  ### mount transfer img, copy file, detach and move to host
  virsh attach-disk pfsense --source /tmp/transfer.img --target vdc --persistent --config --live

cat > /temp/pf-init-3.sh <<EOF
while ! grep "process finished successfully" /var/log/system.log > /dev/null;
do
  sleep 10;
  echo "testing"
done

## important!  endless loop if below is removed!
echo "fin" > /tmp/init.complete
EOF

  PFSENSE_INIT=$(cat </temp/pf-init-3.sh | base64 | tr -d '\n\r')

  pfsense_init_array=( $(echo "$PFSENSE_INIT" | fold -c250 ))

  ### add wait based on checking for progress complete in system.log file
  sleep 60;
  (echo open localhost 4568;
    sleep 30;
    echo "touch /root/pf-init-3.sh; touch /root/pf-init-3.sh.enc;";
    sleep 10;
    for element in "${pfsense_init_array[@]}"
      do
        echo "echo '$element' >> /root/pf-init-3.sh.enc";
        sleep 5;
      done
    echo "openssl base64 -d -in /root/pf-init-3.sh.enc -out /root/pf-init-3.sh;";
    sleep 10;
    echo "rm -rf /root/*.enc";
    sleep 10;
    echo "cd /root/"
    sleep 10;
    echo "chmod +x pf-init-3.sh;"
    sleep 10;
    echo "./pf-init-3.sh"
    sleep 10;
  ) | telnet
  sleep 2000;
  ########

### add wait before restart
cat > /temp/wait3.sh <<EOF
#!/usr/bin/expect
set timeout -1;
spawn telnet localhost 4568
send "echo ''\n"
expect "#"
send "\n"
send "yes|pkg install bash;bash -c 'while \[ true \];do sleep 5;if \[ -f /tmp/init.complete \];then rm -rf /tmp/init.complete;exit;fi;done;'\n"
EOF

  chmod +x /temp/wait3.sh
  ./temp/wait3.sh
  ####

cat > /temp/pf-init-2.sh <<EOF
mkdir /tmp/repo-dir
cd /tmp/repo-dir
pkg create -a > \& /tmp/pkg-create-a.out
pkg fetch -o /tmp/repo-dir -y qemu-guest-agent
yes | pkg install bash
bash

for col in \$(cat /tmp/pkg-create-a.out | grep -B 1 missing | grep for | cut -d " " -f 4); do
  pkg fetch -r pfSense -o /tmp/repo-dir -y \$col;
  mv /tmp/repo-dir/All/* /tmp/repo-dir
done;

for col in \$(cat /tmp/pkg-create-a.out | grep -B 1 "No such file or directory" | grep for | cut -d " " -f 4); do
  pkg fetch -r pfSense -o /tmp/repo-dir -y \$col;
  mv /tmp/repo-dir/All/* /tmp/repo-dir
done;

exit
pkg repo -o /tmp/repo-dir /tmp/repo-dir
tar cf /tmp/repo.tar ./*
mkdir /tmp/transfer
mount_msdosfs /dev/vtbd0 /tmp/transfer
cp /tmp/repo.tar /tmp/transfer
sleep 30
umount /tmp/transfer

## important!  endless loop if below is removed!
echo "fin" > /tmp/init.complete
EOF

  PFSENSE_INIT=$(cat </temp/pf-init-2.sh | base64 | tr -d '\n\r')

  pfsense_init_array=( $(echo "$PFSENSE_INIT" | fold -c250 ))

  (echo open localhost 4568;
    sleep 30;
    echo "touch /root/pf-init-2.sh; touch /root/pf-init-2.sh.enc;";
    sleep 10;
    for element in "${pfsense_init_array[@]}"
      do
        echo "echo '$element' >> /root/pf-init-2.sh.enc";
        sleep 5;
      done
    echo "openssl base64 -d -in /root/pf-init-2.sh.enc -out /root/pf-init-2.sh;";
    sleep 10;
    echo "rm -rf /root/*.enc";
    sleep 10;
    echo "cd /root/"
    sleep 10;
    echo "chmod +x pf-init-2.sh;"
    sleep 10;
    echo "./pf-init-2.sh"
    sleep 10;
  ) | telnet

### add wait before restart
cat > /temp/wait2.sh <<EOF
#!/usr/bin/expect
set timeout -1;
spawn telnet localhost 4568
send "echo ''\n"
expect "#"
send "\n"
send "yes|pkg install bash;bash -c 'while \[ true \];do sleep 5;if \[ -f /tmp/init.complete \];then rm -rf /tmp/init.complete;exit;fi;done;'\n"
EOF

chmod +x /temp/wait2.sh
./temp/wait2.sh
####

  virsh detach-disk --domain pfsense /tmp/transfer.img --persistent --config --live
  mkdir /tmp/transfer
  mount /tmp/transfer.img /tmp/transfer
  cp /tmp/transfer/repo.tar /tmp
  umount /tmp/transfer
  rm -rf /tmp/transfer
  rm -rf /tmp/transfer.img
fi

if [ -n "$2" ]; then
  if [ 'keep' == "$2" ]; then
    exit 0
  fi
fi

if [ 'dev' == "$1" ]; then
  virsh destroy pfsense
  virsh undefine --domain pfsense --remove-all-storage
fi