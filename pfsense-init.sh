#!/bin/sh
## this script will run on pfsense reboot and then remove itself
## this script is run on a FreeBSD system, not centos, not bash.  Makes some things slightly different

yes | pkg install bash
yes | pkg install qemu-guest-agent

echo 'qemu_guest_agent_enable="YES"' >> /etc/rc.conf
echo 'qemu_guest_agent_flags="-d -v -l /var/log/qemu-ga.log"' >> /etc/rc.conf

service qemu-guest-agent start

yes | pkg install pfSense-pkg-squid
yes | pkg install pfSense-pkg-telegraf
yes | pkg install pfSense-pkg-haproxy-devel
yes | pkg install pfSense-pkg-openvpn-client-export
yes | pkg install pfSense-pkg-Service_Watchdog

## important!  endless loop if below is removed!
echo "fin" > /tmp/init2.complete

cat <<EOF >> /tmp/listen.sh
HOST=127.0.0.1; PORT=8080; CONTENT_TYPE=application/json; while true; do BODY=\$(printf "{\r\n  \"Date\": \"$(date)\"\r\n}\r\n");RESPONSE=\$(printf "HTTP/1.0 200 OK\r\nContent-Type: \${CONTENT_TYPE}\r\nContent-Length: \$((\${#BODY}+1))\r\nConnection: close\r\n\r\n\${BODY}"); echo "---\$((X=X+1))---"; echo "\$RESPONSE" | nc -N -l \$HOST \$PORT; done
EOF
chmod +x /tmp/listen.sh
cd /tmp || exit
./listen.sh &