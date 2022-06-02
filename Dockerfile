FROM quay.io/centos/centos:stream8

RUN mkdir /out
RUN mkdir /out/pfsense
RUN yum install -y @virt
RUN dnf install -y virt-install virt-viewer libguestfs-tools
RUN yum install -y wget telnet setroubleshoot setools openvpn

ARG PFSENSE_VERSION
ENV PF_VER=${PFSENSE_VERSION}
RUN wget -O /out/pfsense/pfSense-CE-memstick-ADI.img.gz https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-memstick-ADI-"$PF_VER"-RELEASE-amd64.img.gz

WORKDIR /
COPY init.sh /
RUN chmod 777 /init.sh

COPY openstack-pfsense.xml /
RUN chmod 777 openstack-pfsense.xml



ENTRYPOINT ["./init.sh"]