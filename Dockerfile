FROM quay.io/centos/centos:stream8

RUN dnf module install -y virt
RUN dnf install -y virt-install virt-viewer libguestfs-tools
RUN yum install -y wget
ADD init.sh /init.sh
RUN chmod 777 /init.sh
CMD /init.sh