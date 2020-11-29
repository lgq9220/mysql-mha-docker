#!/bin/bash
# author:hooray

# 启动ssh服务
service ssh start
# 生成ssh的key
ssh-keygen -t rsa -P "" -f /root/.ssh/id_rsa
# 将pub文件拷到容器间共享目录下
cp /root/.ssh/id_rsa.pub "/root/mha_share/sshkeys/id_rsa_${KEY_SUFFIX}.pub"
# 等待3秒，别的容器也创建好sshkey后，拷贝过来
sleep 3
cat /root/mha_share/sshkeys/*.pub > /root/.ssh/authorized_keys