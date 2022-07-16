#!/bin/bash

exec 1>/out/pfsense-build.log 2>&1
set -x

source /tmp/openstack-scripts/vm_functions.sh
source /tmp/openstack-scripts/project_config.sh
source /tmp/openstack-setup/openstack-env.sh

rm -rf /tmp/pfSense-CE-memstick-ADI.img
gunzip -f /temp/pfSense-CE-memstick-ADI.img.gz
### make sure to get offset of fat32 partition to put config.xml file on stick to reload!

mkdir /temp/usb
dd if=/dev/zero bs=1M count=400 >> /temp/pfSense-CE-memstick-ADI.img
parted /temp/pfSense-CE-memstick-ADI.img resizepart 3 1300MB
loop_Device=$(losetup -f --show -P /temp/pfSense-CE-memstick-ADI.img)
mkfs -t vfat "$loop_Device"p3
mount "$loop_Device"p3 /temp/usb

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
EOF

cp /tmp/openstack-setup/openstack-env.sh /temp/usb/
rm -rf /temp/usb/config.xml

if [ 'test' == $1 ]; then
  mv /openstack-pfsense-test.xml /temp/usb/config.xml
else
  mv /openstack-pfsense.xml /temp/usb/config.xml
fi

cp /pf_functions.sh /temp/usb/
cp /pfsense-init.sh /temp/usb/
cp /pfSense-repo.conf /temp/usb/

if [ 'prod' == $1 ]; then
  cp /tmp/repo.tar /temp/usb/
fi

## move generated file above to disk
cp /temp/init.sh /temp/usb/

### cloudfoundry TCP ports
CF_TCP_START_PORT=1024
CF_TCP_END_PORT=$((CF_TCP_START_PORT + CF_TCP_PORT_COUNT))

#### backend to change host header from whatever it comes in as to internal domain
ADVANCED_BACKEND=$(echo "http-request replace-value Host ^(.*)(\.[^\.]+){2}$ \1.$INTERNAL_DOMAIN_NAME" | base64 | tr -d '\n\r')

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
sed -i "s/{TELEGRAM_API}/$TELEGRAM_API/g" /temp/usb/config.xml
sed -i "s/{TELEGRAM_CHAT_ID}/$TELEGRAM_CHAT_ID/g" /temp/usb/config.xml
sed -i "s/{OINKMASTER}/$OINKMASTER/g" /temp/usb/config.xml
sed -i "s/{MAXMIND_KEY}/$MAXMIND_KEY/g" /temp/usb/config.xml
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

#create_server_cert /tmp "wildcard" "*"
### add filler values for certs and keys
#FILLER_CA_CERT="$(generate_specific_pwd 1818)"
#FILLER_CA_KEY="$(generate_specific_pwd 3243)"
#FILLER_WILDCARD_CERT="$(generate_specific_pwd 2041)"
#FILLER_WILDCARD_KEY="$(generate_specific_pwd 3247)"
#
#replace_string_in_iso "/tmp/pfSense-CE-memstick-ADI-prod.img" "" "$(cat </tmp/wildcard.key | base64 | tr -d '\n\r')"
#replace_string_in_iso "/tmp/pfSense-CE-memstick-ADI-prod.img" "" "$(cat </tmp/subca.key | base64 | tr -d '\n\r')"
#replace_string_in_iso "/tmp/pfSense-CE-memstick-ADI-prod.img" "" "$(cat </tmp/wildcard.crt | base64 | tr -d '\n\r')"
#replace_string_in_iso "/tmp/pfSense-CE-memstick-ADI-prod.img" "" "$(cat </tmp/subca.cert | base64 | tr -d '\n\r')"


sed -i "s/{CA_CRT}/$(generate_specific_pwd 1818)/g" /temp/usb/config.xml
sed -i "s/{CA_KEY}/$(generate_specific_pwd 3243)/g" /temp/usb/config.xml
sed -i "s/{INITIAL_WILDCARD_CRT}/$(generate_specific_pwd 2041)/g" /temp/usb/config.xml
sed -i "s/{INITIAL_WILDCARD_KEY}/$(generate_specific_pwd 3247)/g" /temp/usb/config.xml
###

runuser -l root -c  'umount /temp/usb'

cp /temp/pfSense-CE-memstick-ADI.img /tmp/pfSense-CE-memstick-ADI-$1.img
#start pfsense vm to gather packages to build offline resources

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
if [ 'prod' == $1 ]; then
  cmd="yes | cp /tmp/test-mnt/pfSense-repo.conf /mnt/usr/local/share/pfSense/pkg/repos/pfSense-repo.conf; cp /tmp/test-mnt/pfSense-repo.conf /mnt/usr/local/share/pfSense/pfSense-repo.conf;"
  cmdCopy="cp /tmp/test-mnt/repo.tar /mnt/usr/local/share/pfSense"
  cmdExtract="tar xf /mnt/usr/local/share/pfSense/repo.tar -C /mnt/usr/local/share/pfSense/pkg"
fi

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
  echo "$cmd";
  sleep 10;
  echo "$cmdCopy";
  sleep 10;
  echo "$cmdExtract";
  sleep 10;
  echo "chmod 777 /mnt/root/*.sh"
  sleep 10;
  echo "cd /mnt/root";
  sleep 5;
  echo "./init.sh";
  sleep 10;
) | telnet

virsh detach-disk --domain pfsense /tmp/pfSense-CE-memstick-ADI-$1.img --persistent --config --live
### cleanup
runuser -l root -c  "rm -rf /temp/usb"
#####

if [ 'dev' == $1 ]; then

  ## remove install disk from pfsense
  virsh destroy pfsense
  sleep 20;
  virsh start pfsense

  ### base64 files
  HYPERVISOR_KEY=`cat /root/.ssh/id_rsa | base64 | tr -d '\n\r'`
  HYPERVISOR_PUB_KEY=`cat /root/.ssh/id_rsa.pub | base64 | tr -d '\n\r'`

  hypervisor_key_array=( $(echo $HYPERVISOR_KEY | fold -c250 ))
  hypervisor_pub_array=( $(echo $HYPERVISOR_PUB_KEY | fold -c250 ))
  ## arg $2 is buildserver scp user, $3 is ip

  sleep 400;
  (echo open localhost 4568;
    sleep 30;
    echo 'cd /var/cache/pkg';
    sleep 5;
    echo 'tar cf repo.tar ./*';
    sleep 10;
    echo "mkdir /root/.ssh";
    sleep 10;
    echo "touch /root/.ssh/id_rsa; touch /root/.ssh/id_rsa.pub; touch /root/.ssh/id_rsa.pub.enc; touch /root/.ssh/id_rsa.enc;";
    sleep 10;
    for element in "${hypervisor_pub_array[@]}"
    do
      echo "echo '$element' >> /root/.ssh/id_rsa.pub.enc";
      sleep 5;
    done
    for element in "${hypervisor_key_array[@]}"
    do
      echo "echo '$element' >> /root/.ssh/id_rsa.enc";
      sleep 5;
    done
    echo "openssl base64 -d -in /root/.ssh/id_rsa.pub.enc -out /root/.ssh/id_rsa.pub;";
    sleep 10;
    echo "openssl base64 -d -in /root/.ssh/id_rsa.enc -out /root/.ssh/id_rsa;";
    sleep 10;
    echo "chmod 600 /root/.ssh/*";
    sleep 10;
    echo "ssh-keyscan -H $3 >> ~/.ssh/known_hosts;";
    sleep 10;
    echo "scp -B repo.tar $2@$3:/tmp"
    sleep 60;
  ) | telnet

fi

virsh destroy pfsense
virsh undefine --domain pfsense --remove-all-storage