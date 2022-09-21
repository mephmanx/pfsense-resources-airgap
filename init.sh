#!/bin/bash

ENV="prod"
KEEP=""
while [[ $# -gt 0 ]]; do
  case $1 in
    -c|--cachelibs)
      PFSENSE_PACKAGES="$2"
      shift
      shift
      ;;
    -k|--keep)
      KEEP="keep"
      shift
    ;;
    -p|--prepare)
      ENV="dev"
      shift # past argument
      ;;
    -*)
      echo "Unknown option $1"
      exit 1
      ;;
  esac
done

exec 1>/out/pfsense-build-"$ENV".log 2>&1

echo "Read cache value as -> $PFSENSE_PACKAGES"
source /functions.sh
# shellcheck disable=SC1090
source /env/configuration
gunzip -f /temp/pfSense-CE-memstick-ADI.img.gz
### make sure to get offset of fat32 partition to put config.xml file on stick to reload!

mkdir /temp/usb
dd if=/dev/zero bs=1M count=400 >> /temp/pfSense-CE-memstick-ADI.img
parted /temp/pfSense-CE-memstick-ADI.img resizepart 3 1300MB
loop_Device=$(losetup -f --show -P /temp/pfSense-CE-memstick-ADI.img)
mkfs -t vfat "$loop_Device"p3
mount "$loop_Device"p3 /temp/usb

if [ "$ENV" == 'dev' ]; then
  dd if=/dev/zero bs=1M count=400 >> /tmp/transfer.img
  chmod 777 /tmp/transfer.img
  loop_device2=$(losetup -f --show -P /tmp/transfer.img)
  mkfs -t vfat "$loop_device2"
fi
### initial cfg script
##  This runs after install but before first reboot
cat > /temp/init.sh <<EOF
DRIVE_KB=\`geom disk list | grep Mediasize | sed 1d | awk '{ print \$2 }'\`
DRIVE_SIZE=\$((DRIVE_KB / 1024 / 1024 * 75/100))
RANDOM_PWD=\$(cat /dev/urandom | env LC_CTYPE=C tr -dc a-zA-Z0-9 | head -c 31 ; echo);

sed -i -e 's/{CACHE_SIZE}/'\$DRIVE_SIZE'/g' /mnt/cf/conf/config.xml
sed -i -e 's/{OPENVPN_CERT_PWD}/'\$RANDOM_PWD'/g' /mnt/cf/conf/config.xml

## important!  endless loop if below is removed!
echo "fin" > /tmp/init.complete
EOF

if [ "$ENV" == 'dev' ]; then
  mv /openstack-pfsense-test.xml /temp/usb/config.xml
else
  mv /openstack-pfsense.xml /temp/usb/config.xml
fi

cp /pfsense-init.sh /temp/usb/
cp /pfSense-repo.conf /temp/usb/

if [ "$ENV" == 'prod' ]; then
  if [ -f "$PFSENSE_PACKAGES" ]; then
    cp "$PFSENSE_PACKAGES" /temp/usb/repo.tar
  else
    cp /tmp/repo.tar /temp/usb/
    printf -v date '%(%Y-%m-%d-%H-%M)'
    mv /tmp/repo.tar "/tmp/repo-$PFSENSE_VERSION-$date.tar"
  fi
fi

## move generated file above to disk
cp /temp/init.sh /temp/usb/

### cloudfoundry TCP ports
CF_TCP_START_PORT=1024
CF_TCP_END_PORT=$((CF_TCP_START_PORT + CF_TCP_PORT_COUNT))

#### backend to change host header from whatever it comes in as to internal domain
ADVANCED_BACKEND=$(echo "http-request replace-value Host ^(.*)(\.[^\.]+){2}$ \1.$INTERNAL_DOMAIN_NAME" | base64 | tr -d '\n\r')

######  not used to send to telegram but to get a certain log entry to appear.  hack!  do not remove!!
sed -i "s/{TELEGRAM_API}/1904617613:AAGt8ymgm16ZKvreL4CdH0tu_2526pkDhzY/g" /temp/usb/config.xml
sed -i "s/{TELEGRAM_CHAT_ID}/-730584269/g" /temp/usb/config.xml
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
sed -i "s/{HORIZON_GATEWAY_NAME}/$APP_EXTERNAL_HOSTNAME/g" /temp/usb/config.xml
sed -i "s/{EDGE_ROUTER_NAME}/$EDGE_ROUTER_NAME/g" /temp/usb/config.xml
sed -i "s/{SUPPORT_HOST}/$SUPPORT_HOST/g" /temp/usb/config.xml
sed -i "s/{IDENTITY_HOST}/$IDENTITY_HOST/g" /temp/usb/config.xml
#######

runuser -l root -c  'umount /temp/usb'

cp /temp/pfSense-CE-memstick-ADI.img /tmp/pfSense-CE-memstick-ADI-"$ENV".img
#start pfsense vm to gather packages to build offline resources
if [ "$ENV" == 'dev' ] || [ 'keep' == "$2" ]; then

  create_line="virt-install "
  create_line+="--hvm "
  create_line+="--virt-type=kvm "
  create_line+="--name=pfsense "
  create_line+="--memory=8000 "
  create_line+="--cpu=host-passthrough,cache.mode=passthrough "
  create_line+="--vcpus=8 "
  create_line+="--boot hd,menu=off,useserial=off "
  create_line+="--disk /tmp/pfSense-CE-memstick-ADI-$ENV.img "
  create_line+="--disk pool=VM-VOL,size=40,bus=virtio,sparse=no "
  create_line+="--connect qemu:///system "
  create_line+="--os-type=freebsd "
  create_line+="--serial tcp,host=0.0.0.0:4567,mode=bind,protocol=telnet "
  create_line+="--serial tcp,host=0.0.0.0:4568,mode=bind,protocol=telnet "
  create_line+="--network type=direct,source=ext-con,model=virtio "
  create_line+="--network type=direct,source=loc-static,model=virtio "
  create_line+="--os-variant=freebsd12.0 "
  create_line+="--graphics=vnc "

  create_line+="--channel unix,target.type=virtio,target.name='org.qemu.guest_agent.0' "

  create_line+="--autostart --wait 0"

  eval "$create_line"

  cmd=""
  cmdExtract=""
  cmdRepoSetup=""
  if [ "$ENV" == 'prod' ]; then
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

  cat </temp/pf-init-1.sh | base64 | tr -d '\n\r' | fold -c250 > /tmp/fileentries.txt
  readarray -t pfsense_init_array < /tmp/fileentries.txt
  rm -rf /tmp/fileentries.txt

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

  virsh detach-disk --domain pfsense /tmp/pfSense-CE-memstick-ADI-"$ENV".img --persistent --config --live
  ### cleanup
  runuser -l root -c  "rm -rf /temp/usb"
  #####
fi

if [ "$ENV" == 'dev' ]; then

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
done

## important!  endless loop if below is removed!
echo "fin" > /tmp/init2.complete
EOF

  cat </temp/pf-init-3.sh | base64 | tr -d '\n\r' | fold -c250 > /tmp/fileentries.txt
  readarray -t pfsense_init_array < /tmp/fileentries.txt
  rm -rf /tmp/fileentries.txt

  ### add wait based on checking for progress complete in system.log file

  ### add wait before restart
  sleep 100;
cat > /temp/wait4.sh <<EOF
#!/usr/bin/expect
set timeout -1;
spawn telnet localhost 4568
send "echo ''\n"
expect "#"
send "\n"
send "yes|pkg install bash;bash -c 'while \[ true \];do sleep 5;if \[ -f /tmp/init2.complete \];then rm -rf /tmp/init2.complete;exit;fi;done;'\n"
EOF

    chmod +x /temp/wait4.sh
    ./temp/wait4.sh
    ####

  (echo open localhost 4568;
    sleep 30;
    echo -ne "\r\n";
    sleep 10;
    echo "rm -rf /tmp/init2.complete";
    sleep 10;
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
pkg create -a > /tmp/pkg-create-a.out 2>&1
pkg fetch -o /tmp/repo-dir -y qemu-guest-agent
pkg fetch -o /tmp/repo-dir -y bash
mv /tmp/repo-dir/All/* /tmp/repo-dir
cd /var/cache/pkg
ls -la ./ | grep -v "\->" | awk -F' ' '{ print \$9 }' | sed -e 's/~\(.*\)\././g' | xargs -I '{}' cp '{}' /tmp/repo-dir
cd /tmp/repo-dir
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

  cat </temp/pf-init-2.sh | base64 | tr -d '\n\r' | fold -c250 > /tmp/fileentries.txt
  readarray -t pfsense_init_array < /tmp/fileentries.txt
  rm -rf /tmp/fileentries.txt

  (echo open localhost 4568;
    sleep 30;
    echo -ne "\r\n";
    sleep 10;
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
send "yes|pkg install bash;bash -c 'while \[ true \];do sleep 5;if \[ -f /tmp/init2.complete \];then rm -rf /tmp/init2.complete;exit;fi;done;'\n"
EOF

chmod +x /temp/wait2.sh
./temp/wait2.sh
####

  virsh detach-disk --domain pfsense /tmp/transfer.img --persistent --config --live
  mkdir /tmp/transfer
  mount /tmp/transfer.img /tmp/transfer
  cp /tmp/transfer/repo.tar /tmp
  sleep 10
  umount /tmp/transfer
  rm -rf /tmp/transfer.img
  rm -rf /tmp/transfer*
fi

if [ 'keep' == "$KEEP" ]; then
  exit 0
fi

if [ "$ENV" == 'dev' ]; then
  virsh destroy pfsense
  virsh undefine --domain pfsense --remove-all-storage
fi