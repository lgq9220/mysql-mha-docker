#!/bin/bash

echo ">>>>start to init slave"

set -e

until MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -h mysql_master; do
  echo >&2 "MySQL master is unavailable - sleeping"
  sleep 3
done

# 创建用于同步master的用户
MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -e \
"CREATE USER '${MYSQL_REPLICATION_USER}'@'%' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}'; \
GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'%';"

# 查看主服务器的状态
MASTER_STATUS=$(MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -h mysql_master -e "show master status")
# binlog文件名字,对应 File 字段,值如: mysql-bin.000004
MASTER_LOG_FILE=$(echo "${MASTER_STATUS}" | awk '{print $6}')
# binlog位置,对应 Position 字段,值如: 1429
MASTER_LOG_POS=$(echo "${MASTER_STATUS}" | awk '{print $7}')

# 设置主节点的同步sql
MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -e \
"CHANGE MASTER TO MASTER_HOST='mysql-master', \
	      MASTER_USER='${MYSQL_REPLICATION_USER}', \
	      MASTER_PASSWORD='${MYSQL_REPLICATION_PASSWORD}', \
	      MASTER_LOG_FILE='${MASTER_LOG_FILE}', \
	      MASTER_LOG_POS=${MASTER_LOG_POS};
START SLAVE;"
