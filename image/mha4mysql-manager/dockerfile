FROM debian:buster 

ENV MANAGER_TAR_TAG mha4mysql-manager-0.58
ENV NODE_TAR_TAG mha4mysql-node-0.58
COPY ./${MANAGER_TAR_TAG}.tar.gz /tmp/
COPY ./${NODE_TAR_TAG}.tar.gz /tmp/

# 更新apt-get源
RUN echo \
    deb http://mirrors.aliyun.com/debian/ buster main non-free contrib\
    deb-src http://mirrors.aliyun.com/debian/ buster main non-free contrib\
    deb http://mirrors.aliyun.com/debian-security buster/updates main\
    deb-src http://mirrors.aliyun.com/debian-security buster/updates main\
    deb http://mirrors.aliyun.com/debian/ buster-updates main non-free contrib\
    deb-src http://mirrors.aliyun.com/debian/ buster-updates main non-free contrib\
    deb http://mirrors.aliyun.com/debian/ buster-backports main non-free contrib\
    deb-src http://mirrors.aliyun.com/debian/ buster-backports main non-free contrib\
    > /etc/apt/sources.list

RUN build_deps='ssh sshpass perl libdbi-perl libmodule-install-perl libdbd-mysql-perl libconfig-tiny-perl liblog-dispatch-perl libparallel-forkmanager-perl make' \
    && apt-get -y update \
    && apt-get -y --allow-downgrades --allow-remove-essential --allow-change-held-packages install $build_deps \
    && tar -zxf /tmp/${NODE_TAR_TAG}.tar.gz -C /opt \
    && cd /opt/${NODE_TAR_TAG} \
    && perl Makefile.PL \
    && make \
    && make install \
    && tar -zxf /tmp/${MANAGER_TAR_TAG}.tar.gz -C /opt \
    && cd /opt/${MANAGER_TAR_TAG} \
    && perl Makefile.PL \
    && make \
    && make install \
    && cd /opt \
    && rm -rf /opt/mha4mysql-* \
    && apt-get clean
