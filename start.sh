#!/bin/bash
# author:hooray

#################### 变量定义 ####################
root_password="root"    # 每台服务器的root密码
mysql_user="hooray"     # 主服务器允许从服务器登录的用户名
mysql_password="hooray" # 主服务器允许从服务器登录的密码

#################### 环境文件生成 ####################
# 生成mysql_master.env
echo "
# root账号密码
MYSQL_ROOT_PASSWORD=${root_password}
# 数据库配置
MYSQL_REPLICATION_USER=${mysql_user}
MYSQL_REPLICATION_PASSWORD=${mysql_password}
" >./env/mysql_master.env

# 生成mysql_slave.env
echo "
# root账号密码
MYSQL_ROOT_PASSWORD=${root_password}
# 数据库配置
MYSQL_REPLICATION_USER=${mysql_user}
MYSQL_REPLICATION_PASSWORD=${mysql_password}
" >./env/mysql_slave.env

#################### docker-compose初始化 ####################
docker-compose build
docker-compose up -d
