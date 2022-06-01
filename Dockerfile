FROM quay.io/centos/centos:stream8

RUN mkdir /out
RUN dnf module install -y virt
RUN dnf install -y virt-install virt-viewer libguestfs-tools
RUN yum install -y wget

ARG PFSENSE_VERSION
ENV PF_VER=${PFSENSE_VERSION}
RUN wget -O /out/pfsense-"$PF_VER".gz https://atxfiles.netgate.com/mirror/downloads/pfSense-CE-memstick-ADI-"$PF_VER"-RELEASE-amd64.img.gz
RUN cp /out/pfSense-"$PF_VER".gz /out/pfSense-CE-memstick-ADI.img.gz
RUN rm -rf /out/pfSense-"$PF_VER".gz
RUN gunzip -f /out/pfSense-CE-memstick-ADI.img.gz

ADD init.sh /init.sh
RUN chmod 777 /init.sh

ENTRYPOINT ["./init.sh"]