FROM quay.io/centos/centos:stream8

RUN mkdir /out
RUN mkdir /temp
RUN yum install -y epel-release
RUN yum install -y @virt
RUN dnf install -y virt-install virt-viewer libguestfs-tools openvpn
RUN yum install -y wget telnet setroubleshoot setools

ARG PFSENSE_VERSION
ENV PF_VER=${PFSENSE_VERSION}
RUN wget -O /temp/pfSense-CE-memstick-ADI.img.gz https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-memstick-ADI-"$PF_VER"-RELEASE-amd64.img.gz

WORKDIR /
COPY init.sh /
RUN chmod 777 /init.sh

COPY openstack-pfsense.xml /
COPY pfsense-init.sh /
COPY pf_functions.sh /
COPY pfSense-repo.conf /

RUN chmod 777 openstack-pfsense.xml

ENTRYPOINT ["./init.sh"]