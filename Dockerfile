FROM quay.io/centos/centos:stream8

RUN mkdir /out
RUN dnf module install -y virt
RUN dnf install -y virt-install virt-viewer libguestfs-tools
RUN yum install -y wget telnet setroubleshoot setools

ARG PFSENSE_VERSION
ENV PF_VER=${PFSENSE_VERSION}
RUN wget -O /tmp/pfSense-CE-memstick-ADI.img.gz https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-memstick-ADI-"$PF_VER"-RELEASE-amd64.img.gz

WORKDIR /
COPY init.sh /
RUN chmod 777 /init.sh

ENTRYPOINT ["./init.sh"]