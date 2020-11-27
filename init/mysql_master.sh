#!/bin/bash

echo ">>>>start to init master"

set -e

# create replication user

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -e \
"CREATE USER '${MYSQL_REPLICATION_USER}'@'%' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}'; \
GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'%';"
