ARG PFSENSE_VERSION
FROM mephmanx/pfsense-base:$PFSENSE_VERSION AS OS-BASE

FROM quay.io/centos/centos:stream8

RUN mkdir /out
RUN mkdir /temp
RUN yum install -y epel-release
RUN yum install -y @virt
RUN dnf install -y virt-install virt-viewer libguestfs-tools openvpn expect wget telnet setroubleshoot setools

COPY --from=OS-BASE /root/pfSense-CE-memstick-ADI.img.gz /temp/pfSense-CE-memstick-ADI.img.gz

RUN export PFSENSE_VERSION=$PFSENSE_VERSION
WORKDIR /
COPY init.sh /
RUN chmod +x /init.sh

COPY openstack-pfsense.xml /
COPY openstack-pfsense-test.xml /
COPY pfsense-init.sh /
COPY pf_functions.sh /
COPY pfSense-repo.conf /
COPY functions.sh /
COPY command-processor.sh /

ENTRYPOINT ["./init.sh"]