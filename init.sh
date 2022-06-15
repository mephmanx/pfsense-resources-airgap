#!/bin/bash

exec 1>/out/pfsense-build.log 2>&1
set -x

source /tmp/openstack-scripts/vm_functions.sh
source /tmp/project_config.sh
source /tmp/openstack-env.sh

rm -rf /tmp/pfSense-CE-memstick-ADI.img
gunzip -f /temp/pfSense-CE-memstick-ADI.img.gz
### make sure to get offset of fat32 partition to put config.xml file on stick to reload!

mkdir /temp/usb
dd if=/dev/zero bs=1M count=400 >> /temp/pfSense-CE-memstick-ADI.img
parted /temp/pfSense-CE-memstick-ADI.img resizepart 3 1300MB
loop_Device=$(sudo losetup -f --show -P /temp/pfSense-CE-memstick-ADI.img)
sudo mkfs -t vfat "$loop_Device"p3
mount "$loop_Device"p3 /temp/usb

### initial cfg script
cat > /temp/init.sh <<EOF
DRIVE_KB=\`geom disk list | grep Mediasize | sed 1d | awk '{ print \$2 }'\`
DRIVE_SIZE=\$((DRIVE_KB / 1024 / 1024 * 75/100))

sed -i -e 's/{CACHE_SIZE}/'\$DRIVE_SIZE'/g' /mnt/cf/conf/config.xml
EOF

cp /tmp/openstack-env.sh /temp/usb/
rm -rf /temp/usb/config.xml

cp /openstack-pfsense.xml /temp/usb/
mv /temp/usb/openstack-pfsense.xml /temp/usb/config.xml

cp /pf_functions.sh /temp/usb/
cp /pfsense-init.sh /temp/usb/
cp /temp/init.sh /temp/usb/

## generate OpenVPN TLS secret key
runuser -l root -c  'openvpn --genkey --secret /temp/openvpn-secret.key'

### replace variables
## load generated cert variables
CA_KEY=$(cat </tmp/id_rsa | base64 | tr -d '\n\r')
CA_CRT=$(cat </tmp/id_rsa.crt | base64 | tr -d '\n\r')

INITIAL_WILDCARD_CRT=$(cat </tmp/wildcard.crt | base64 | tr -d '\n\r')
INITIAL_WILDCARD_KEY=$(cat </tmp/wildcard.key | base64 | tr -d '\n\r')

OPEN_VPN_TLS_KEY=$(cat </temp/openvpn-secret.key | base64 | tr -d '\n\r')
#########

### cloudfoundry TCP ports
CF_TCP_START_PORT=1024
CF_TCP_END_PORT=$((CF_TCP_START_PORT + CF_TCP_PORT_COUNT))

#### backend to change host header from whatever it comes in as to internal domain
ADVANCED_BACKEND=$(echo "http-request replace-value Host ^(.*)(\.[^\.]+){2}$ \1.$INTERNAL_DOMAIN_NAME" | base64 | tr -d '\n\r')

## generate random hostname suffix so that if multiple instances are run on the same network there are no issues
HOWLONG=5 ## the number of characters
HOSTNAME_SUFFIX=$(< /dev/urandom tr -dc A-Za-z0-9 | head -c100 | head -c$((20+(RANDOM%20))) | tail -c$((20+(RANDOM%20))) | head -c${HOWLONG});
HOSTNAME="$ORGANIZATION-$HOSTNAME_SUFFIX"
###

##### replace PFSense template vars
sed -i "s/{HOSTNAME}/$HOSTNAME/g" /temp/usb/config.xml
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
sed -i "s/{OPENVPN_CERT_PWD}/$(generate_random_pwd 31)/g" /temp/usb/config.xml
sed -i "s/{TELEGRAM_API}/$TELEGRAM_API/g" /temp/usb/config.xml
sed -i "s/{TELEGRAM_CHAT_ID}/$TELEGRAM_CHAT_ID/g" /temp/usb/config.xml
sed -i "s/{OINKMASTER}/$OINKMASTER/g" /temp/usb/config.xml
sed -i "s/{MAXMIND_KEY}/$MAXMIND_KEY/g" /temp/usb/config.xml
sed -i "s/{CA_CRT}/$CA_CRT/g" /temp/usb/config.xml
sed -i "s/{CA_KEY}/$CA_KEY/g" /temp/usb/config.xml
sed -i "s/{INITIAL_WILDCARD_CRT}/$INITIAL_WILDCARD_CRT/g" /temp/usb/config.xml
sed -i "s/{INITIAL_WILDCARD_KEY}/$INITIAL_WILDCARD_KEY/g" /temp/usb/config.xml
sed -i "s/{OPEN_VPN_TLS_KEY}/$OPEN_VPN_TLS_KEY/g" /temp/usb/config.xml
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

runuser -l root -c  'umount /temp/usb'

cp /temp/pfSense-CE-memstick-ADI.img /tmp
#start pfsense vm to gather packages to build offline resources

create_line="virt-install "
create_line+="--hvm "
create_line+="--virt-type=kvm "
create_line+="--name=pfsense "
create_line+="--memory=1000 "
create_line+="--cpu=host-passthrough,cache.mode=passthrough "
create_line+="--vcpus=8 "
create_line+="--boot hd,menu=off,useserial=off "
create_line+="--disk /tmp/pfSense-CE-memstick-ADI.img "
create_line+="--disk pool=default,size=40,bus=virtio,sparse=no "
create_line+="--connect qemu:///system "
create_line+="--os-type=freebsd "
create_line+="--serial tcp,host=0.0.0.0:4567,mode=bind,protocol=telnet "
create_line+="--serial tcp,host=0.0.0.0:4568,mode=bind,protocol=telnet "
create_line+="--network type=direct,source=enp4s0f0,model=virtio,source_mode=bridge --network type=direct,source=enp4s0f1,model=virtio,source_mode=bridge --network network=default "
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
  sleep 10;
  echo 'mount -u -o rw /';
  sleep 10;
  echo 'mkdir /tmp/test-mnt';
  sleep 10;
  echo 'mount -v -t msdosfs /dev/vtbd0s3 /tmp/test-mnt';
  sleep 10;
  echo 'cp /tmp/test-mnt/openstack-env.sh /mnt/root/openstack-env.sh';
  sleep 10;
  echo 'cp /tmp/test-mnt/pf_functions.sh /mnt/root/pf_functions.sh';
  sleep 10;
  echo 'cp /tmp/test-mnt/pfsense-init.sh /mnt/root/pfsense-init.sh';
  sleep 10;
  echo 'cp /tmp/test-mnt/init.sh /mnt/root/init.sh'
  sleep 10;
  echo "chmod 777 /mnt/root/*.sh"
  sleep 10;
  echo "cd /mnt/root";
  sleep 5;
  echo "./init.sh";
  sleep 10;
) | telnet

## remove install disk from pfsense
#virsh detach-disk --domain pfsense /tmp/pfSense-CE-memstick-serial.img --persistent --config --live
#virsh reboot pfsense

### cleanup
runuser -l root -c  "rm -rf /temp/usb"
#####

#virsh destroy pfsense
#virsh undefine --domain pfsense --remove-all-storage
