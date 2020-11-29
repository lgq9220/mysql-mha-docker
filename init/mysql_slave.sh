#!/bin/bash

echo ">>>>start to init slave"

set -e

until MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -h mysql_master; do
	echo "MySQL master is unavailable - sleeping"
	sleep 3
done

# 查看主服务器的状态
MASTER_STATUS=$(MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -h mysql_master -e "show master status\G")
# binlog文件名字,对应 File 字段,值如: mysql-bin.000004
MASTER_LOG_FILE=$(echo "${MASTER_STATUS}" | awk 'NR!=1 && $1=="File:" {print $2}')
# binlog位置,对应 Position 字段,值如: 1429
MASTER_LOG_POS=$(echo "${MASTER_STATUS}" | awk 'NR!=1 && $1=="Position:" {print $2}')

# 设置主节点的信息 开启半同步复制
MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -e \
"CHANGE MASTER TO MASTER_HOST='mysql_master', \
	      MASTER_USER='${MYSQL_REPLICATION_USER}', \
	      MASTER_PASSWORD='${MYSQL_REPLICATION_PASSWORD}', \
	      MASTER_LOG_FILE='${MASTER_LOG_FILE}', \
	      MASTER_LOG_POS=${MASTER_LOG_POS};
install plugin rpl_semi_sync_slave soname 'semisync_slave.so';
set global rpl_semi_sync_slave_enabled=1;
START SLAVE;"

# 启动ssh服务
service ssh start
