#!/bin/bash
# author:hooray

#################### 变量定义 ####################
MYSQL_ROOT_PASSWORD="root"               # 每台服务器的root密码
MYSQL_REPLICATION_USER="hooray"          # 主服务器允许从服务器登录的用户名
MYSQL_REPLICATION_PASSWORD="hooray"      # 主服务器允许从服务器登录的密码
NODE_TAR_TAG="mha4mysql-node-0.58"       # mha-node版本
MANAGER_TAR_TAG="mha4mysql-manager-0.58" # mha-node版本

#################### 环境文件生成 ####################
# 生成mha4mysql-noder.env
echo "
# mysql root账号密码
MYSQL_ROOT_PASSWORD=${MYSQL_ROOT_PASSWORD}
# 数据库配置
MYSQL_REPLICATION_USER=${MYSQL_REPLICATION_USER}
MYSQL_REPLICATION_PASSWORD=${MYSQL_REPLICATION_PASSWORD}

# MHA-NODE 版本
#NODE_TAR_TAG=${NODE_TAR_TAG}
" >./env/mha4mysql-node.env

# 生成mha4mysql-manager.env
echo "
# MHA-NODE 版本
#NODE_TAR_TAG=${NODE_TAR_TAG}
# MHA-MANAGER 版本
#MANAGER_TAR_TAG=${MANAGER_TAR_TAG}
" >./env/mha4mysql-manager.env

#################### 配置文件生成 ####################
# 生成mha_manager.conf文件
echo "
[server default]
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
" >./conf/mha_manager.conf

#################### docker-compose初始化 ####################
docker-compose build
docker-compose up -d
