FROM quay.io/centos/centos:stream8

RUN dnf module install -y virt
RUN dnf install -y virt-install virt-viewer libguestfs-tools

ADD init.sh /init.sh

CMD /init.sh