# MySQL MHA 系统构建

使用 Shell + Docker-compose 来构建 1 主 2 从的半同步复制的 MySQL 集群，并使用 MHA 来对 MySQL 集群进行监控，实现 MySQL 集群的故障转移。

## 一 环境软件版本

- Linux 版本：CentOS Linux release 8.2.2004 (Core)
- Docker 版本：Docker Engine - Community 19.03.13
- Docker-compose 版本：docker-compose version 1.27.4
- MySQL 版本：MySQL 5.7.32-1debian10
- MHA 版本： 



## 二 环境安装过程

### 1 虚拟机准备

如果已经在centos上将docker、docker-compose都装好了，可跳过当前步骤

#### 1.1 安装docker

> 如果你已经安装过 [`Docker`](https://docs.docker.com/)，请略过此步骤。

推荐使用官方文档进行安装，参考 [官方文档](https://docs.docker.com/engine/install/centos/)  。

如果懒得看官网，可以试试下面的命令。

```shell
# 更新软件包
sudo yum update -y
# 安装必要依赖
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
# 添加软件源信息
sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
# 更新 yum 缓存
sudo yum makecache fast
# 安装 Docker
sudo yum install docker-ce docker-ce-cli containerd.io
# 启动 Docker 后台服务
sudo systemctl start docker
# 新建 daemon.json 文件
sudo vim /etc/docker/daemon.json
# 将下面的配置复制进去，然后执行 service docker restart即可：
{
  "registry-mirrors": ["http://hub-mirror.c.163.com"]
}
# 如果想要用阿里云的docker镜像源，可看这个网址 https://cr.console.aliyun.com/cn-qingdao/mirrors
```

#### 1.2 安装docker-compose 

> 如果你已经安装过 `Docker-compose`，请略过此步骤。

推荐使用官方文档进行安装，建议参考 [官方文档](https://docs.docker.com/compose/install/#install-using-pip)，记得要选择Linux版。

如果懒得看官网，可以试试下面的命令。

```shell
sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

# 安装好后使用如下命令查看安装版本，如果正常输出说明安装成功
docker-compose version
```

### 2 配置文件准备

#### 2.1 创建master的my.cnf文件

```shell
[mysqld]
pid-file	= /var/run/mysqld/mysqld.pid
socket		= /var/run/mysqld/mysqld.sock
datadir		= /var/lib/mysql
#log-error	= /var/log/mysql/error.log
# By default we only accept connections from localhost
#bind-address	= 127.0.0.1
# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0

# master id
server-id=1
#log_bin
# 开启二进制日志
log-bin=mysql-bin
# 忽略系统库的数据同步
binlog-ignore-db=information_schema 
binlog-ignore-db=mysql 
binlog-ignore-db=performance_schema 
binlog-ignore-db=sys
```

#### 2.2 创建master的init.sh文件

```shell
#!/bin/bash

echo ">>>>start to init master"
MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -e "GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO 'root'@'%';"
```

#### 2.3 创建slave1的my.cnf文件

```shell
[mysqld]
pid-file	= /var/run/mysqld/mysqld.pid
socket		= /var/run/mysqld/mysqld.sock
datadir		= /var/lib/mysql
#log-error	= /var/log/mysql/error.log
# By default we only accept connections from localhost
#bind-address	= 127.0.0.1
# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0

# slave id
server-id=2
# 中继日志
relay_log=mysql-relay-bin
# 只读
read_only=1
```

#### 2.4 创建slave1的init.sh文件

```shell
#!/bin/bash

echo ">>>>start to init slave1"

set -e

until MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -h mysql-master; do
  >&2 echo "MySQL master is unavailable - sleeping"
  sleep 3
done

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -e "GRANT all privileges on *.* to 'root'@'%';"

# get master log File & Position
master_status_info=$(MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -h mysql-master1 -e "show master status\G")
LOG_FILE=$(echo "${master_status_info}" | awk 'NR!=1 && $1=="File:" {print $2}')
LOG_POS=$(echo "${master_status_info}" | awk 'NR!=1 && $1=="Position:" {print $2}')

# set slave master

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root \
-e "CHANGE MASTER TO MASTER_HOST='mysql-master', \
MASTER_USER='root', \
MASTER_PASSWORD='${MYSQL_ROOT_PASSWORD}', \
MASTER_LOG_FILE='${LOG_FILE}', \
MASTER_LOG_POS=${LOG_POS};"
```

#### 2.5 创建slave2的my.cnf文件

```shell
[mysqld]
pid-file	= /var/run/mysqld/mysqld.pid
socket		= /var/run/mysqld/mysqld.sock
datadir		= /var/lib/mysql
#log-error	= /var/log/mysql/error.log
# By default we only accept connections from localhost
#bind-address	= 127.0.0.1
# Disabling symbolic-links is recommended to prevent assorted security risks
symbolic-links=0

# slave id
server-id=3
# 中继日志
relay_log=mysql-relay-bin
# 只读
read_only=1
```

#### 2.6 创建slave2的init.sh文件

```shell
#!/bin/bash

echo ">>>>start to init slave2"

set -e

until MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -h mysql-master; do
  >&2 echo "MySQL master is unavailable - sleeping"
  sleep 3
done

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -e "GRANT all privileges on *.* to 'root'@'%';"

# get master log File & Position
master_status_info=$(MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -h mysql-master1 -e "show master status\G")
LOG_FILE=$(echo "${master_status_info}" | awk 'NR!=1 && $1=="File:" {print $2}')
LOG_POS=$(echo "${master_status_info}" | awk 'NR!=1 && $1=="Position:" {print $2}')

# set slave master

MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root \
-e "CHANGE MASTER TO MASTER_HOST='mysql-master', \
MASTER_USER='root', \
MASTER_PASSWORD='${MYSQL_ROOT_PASSWORD}', \
MASTER_LOG_FILE='${LOG_FILE}', \
MASTER_LOG_POS=${LOG_POS};"
```

#### 2.7 创建docker-compose.yml文件

```yml
#构建mysql-mha环境
version: '3.3'
services:
  mysql_master:
  	# 镜像
    image: mysql:5.7
    # 容器名称
    container_name: mysql_master
    # 端口对外映射
    ports:
      - 3306:3306
    # 数据卷映射  
    volumes:
      # mysql 配置文件
      - /root/mysql-mha/master.cnf:/etc/mysql/my.cnf
      # master 初始化配置
      - /root/mysql-mha/master-init.sh:/docker-entrypoint-initdb.d/init.sh
      # myqsl 工作目录
      - /root/mysql-mha/master/data:/var/lib/mysql
    # 环境变量  
    environment:
      - MYSQL_ROOT_PASSWORD=root
  mysql_slave1:
    image: mysql:5.7
    container_name: mysql_slave1
    ports:
      - 33061:3306
    # 启动依赖于 mysql_master  
    depends_on:
      - mysql_master
    volumes:
      - /root/mysql-mha/slave1.cnf:/etc/mysql/my.cnf
      - /root/mysql-mha/slave1-init.sh:/docker-entrypoint-initdb.d/init.sh
      - /root/mysql-mha/slave1/data:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=root
  mysql_slave2:
    image: mysql:5.7
    container_name: mysql_slave2
    ports:
      - 33062:3306
    depends_on:
      - mysql_master
    volumes:
      - /root/mysql-mha/slave1.cnf:/etc/mysql/my.cnf
      - /root/mysql-mha/slave2-init.sh:/docker-entrypoint-initdb.d/init.sh
      - /root/mysql-mha/slave2/data:/var/lib/mysql
    environment:
      - MYSQL_ROOT_PASSWORD=root      
```

\# 运行docker-compose创建容器

```shell
#运行命令
docker-compose -f /root/mysql-mha/docker-compose-mysql-mha.yml up

#删除命令
docker-compose -f /root/mysql-mha/docker-compose-mysql-mha.yml down --rmi local
```



```shell
git clone https://gitee.com/IceHL/mysql-mha.git && cd mysql-mha && sudo chmod +x start.sh && ./start.sh
```

```
chmod +x reset.sh && ./reset.sh
```

