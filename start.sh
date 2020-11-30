#!/bin/bash
# author:hooray

#################### 变量定义 ####################
MYSQL_ROOT_PASSWORD="root"               # 每台服务器的root密码
MYSQL_REPLICATION_USER="hooray"          # 主服务器允许从服务器登录的用户名
MYSQL_REPLICATION_PASSWORD="hooray"      # 主服务器允许从服务器登录的密码

#################### 环境文件生成 ####################
# 生成mysql.env
echo "# mysql root账号密码
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
# 数据库配置
MYSQL_REPLICATION_USER=${MYSQL_REPLICATION_USER}
MYSQL_REPLICATION_PASSWORD=${MYSQL_REPLICATION_PASSWORD}
" >./env/mysql.env

#################### 配置文件生成 ####################
# 生成mha_manager.cnf文件
echo "[server default]
user=root
password=${MYSQL_ROOT_PASSWORD}
ssh_user=root

# 配置工作目录
manager_workdir=/usr/local/mha
remote_workdir=/usr/local/mha

# 配置mysql的同步用户
repl_user=${MYSQL_REPLICATION_USER}
repl_password=${MYSQL_REPLICATION_PASSWORD}

# 配置host
[server0]
hostname=mysql_master

[server1]
hostname=mysql_slave1

[server2]
hostname=mysql_slave2
" >./conf/mha_manager.cnf

#################### docker-compose初始化 ####################
docker-compose build
docker-compose up -d

#################### 执行挂载好的脚本 ####################
# 生成ssh key
docker exec -it mysql_master /bin/bash /etc/init.d/script/ssh_generate_key.sh
docker exec -it mysql_slave1 /bin/bash /etc/init.d/script/ssh_generate_key.sh
docker exec -it mysql_slave2 /bin/bash /etc/init.d/script/ssh_generate_key.sh
docker exec -it mha_manager /bin/bash /etc/init.d/script/ssh_generate_key.sh
# 授权ssh key
docker exec -it mysql_master /bin/bash /etc/init.d/script/ssh_auth_keys.sh
docker exec -it mysql_slave1 /bin/bash /etc/init.d/script/ssh_auth_keys.sh
docker exec -it mysql_slave2 /bin/bash /etc/init.d/script/ssh_auth_keys.sh
docker exec -it mha_manager /bin/bash /etc/init.d/script/ssh_auth_keys.sh
# 启动mha
docker exec -it mha_manager masterha_manager /etc/init.d/script/mha_manager.sh