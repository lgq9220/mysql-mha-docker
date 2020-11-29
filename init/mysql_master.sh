#!/bin/bash

echo ">>>>start to init master"

set -e

# 创建用于同步的用户 并开启半复制
MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root \
-e "CREATE USER '${MYSQL_REPLICATION_USER}'@'%' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}'; \
GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'%' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}';
install plugin rpl_semi_sync_master soname 'semisync_master.so';
set global rpl_semi_sync_master_enabled=1;
set global rpl_semi_sync_master_timeout=1000;"

