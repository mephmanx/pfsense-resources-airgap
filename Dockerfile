FROM mephmanx/pfsense-base:2.6.0 AS OS-BASE

FROM quay.io/centos/centos:stream8

RUN mkdir /out
RUN mkdir /temp
RUN yum install -y epel-release
RUN yum install -y @virt
RUN dnf install -y virt-install virt-viewer libguestfs-tools openvpn
RUN yum install -y wget telnet setroubleshoot setools

COPY --from=OS-BASE /root/pfSense-CE-memstick-ADI.img.gz /temp/pfSense-CE-memstick-ADI.img.gz

WORKDIR /
COPY init.sh /
RUN chmod +x /init.sh

COPY openstack-pfsense.xml /
COPY openstack-pfsense-test.xml /
COPY pfsense-init.sh /
COPY pf_functions.sh /
COPY pfSense-repo.conf /

ENTRYPOINT ["./init.sh"]