# MySQL MHA 系统构建

本项目使用 Shell + Docker-compose 构建了 1 主 2 从的半同步复制的 MySQL 集群，并使用 MHA 对 MySQL 集群进行监控，实现了 MySQL 主节点的故障转移。

## 一 前言 

人生苦短，我用 Docker。

记的在我上大学的时候，我们学院的计算机老师教大家用 Java 的 Struts + Hibernate 框架写web。好家伙，那装个环境真是难坏了各个同学们，各种各样、层出不穷的奇葩环境问题都有。而等到我工作后，有一回要将 Centos7上面的 MySQL5.6 升级为 MySQL5.7 并迁移数据，更是被折磨到头皮发麻。

实际上，作为一个开发者，安装环境这种事情我们并不需要多专业（术业有专攻嘛，专业的找运维），快速的把环境搞好能够为我们节省下来很多的时间去编码。而 Docker 就是一个能够简化环境安装的软件，借助 Docker-compose 更是能够飞快的完成一个集成环境的搭建。

说回到本项目，MHA 的搭建方法网上有许多的教程，但是都太难复现了，可能一个小细节错了，环境就搭建失败了，而且因为至少需要四台虚拟机，搭建起来可能会涉及到不少的网络问题，且对主机的性能也是不小的负担。而本项目通过脚本将这整个过程简化了，网络问题借助 Docker-compose 屏蔽了，构建 MHA 环境只需要简单的一些命令，就能够快速的完成，极大的简化了这个过程。

> 说明：本项目需要有一定的 Docker 知识，且对于想要快速使用 MHA 功能、深入学习 Docker 使用方式的人会比较有帮助。对于想要正常搭建 MHA 环境的人，建议还是按照四个虚拟机这样的方式装。

## 二 环境说明

### 1 系统软件版本

- Linux 版本：CentOS Linux release 8.2.2004 (Core)
- Docker 版本：Docker Engine - Community 19.03.13
- Docker-compose 版本：docker-compose version 1.27.4
- MySQL 版本：MySQL 5.7.32-1debian10
- MHA 版本：0.58

### 2 容器列表

| 容器名       | Host         | 端口映射   | 描述          |
| ------------ | ------------ | ---------- | ------------- |
| mysql_master | mysql_master | 3306:3306  | MySQL 主节点  |
| mysql_slave1 | mysql_slave1 | 33061:3306 | MySQL 从节点1 |
| mysql_slave2 | mysql_slave2 | 33062:3306 | MySQL 从节点2 |
| mha_manager  | mha_manager  |            | MHA 管理机    |

## 三 快速使用

### 1 虚拟机准备

> 如果已经在centos上将 Docker、Docker-compose都装好了，可跳过当前步骤

#### 1.1 安装 Docker

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

# 安装好后使用如下命令查看安装的版本，如果正常输出说明安装成功
docker version
```

#### 1.2 安装 Docker-compose 

> 如果你已经安装过 `Docker-compose`，请略过此步骤。

推荐使用官方文档进行安装，建议参考 [官方文档](https://docs.docker.com/compose/install/#install-using-pip)，记得要选择Linux版。

如果懒得看官网，可以试试下面的命令。

```shell
sudo curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

sudo chmod +x /usr/local/bin/docker-compose

# 安装好后使用如下命令查看安装版本，如果正常输出说明安装成功
docker-compose version
```

### 2 快速构建 MHA

首先，我们来关闭centos的防火墙

```shell
# 先检查是否开启着
sudo systemctl status firewalld
# 如果是开启的（active）就将它关闭了（以下命令，虚拟机重启后会再次打开防火墙）
systemctl stop firewalld
# 然后重启docker
service docker restart
```

> 这一步一定要做！这一步一定要做！这一步一定要做！不然到时候 Docker容器里网络会有问题。

接着，将本项目 clone 到虚拟机，并执行 start.sh

```shell
git clone https://gitee.com/IceHL/mysql-mha.git \
&& cd mysql-mha \
&& sudo chmod +x start.sh reset.sh shutdown.sh \
&& ./start.sh
```

> 记得安装 git 哦

容器如果都启动成功，就说明 MySQL 主从集群已经起好了，可以使用以下命令验证看看

```shell
# 查看主库运行状态
docker exec mysql_master sh -c 'mysql -u root -proot -e "SHOW MASTER STATUS \G"'
# 查看从库运行状态
docker exec mysql_slave1 sh -c 'MYSQL_PWD=root mysql -u root -e "SHOW SLAVE STATUS \G"'
docker exec mysql_slave2 sh -c 'MYSQL_PWD=root mysql -u root -e "SHOW SLAVE STATUS \G"'

# ----- 如果启动有问题，可用以下命令查看具体问题 -----
# 查看运行的docker容器
docker-compose ps
# 查看docker-compose运行日志
docker-compose logs
# 进入主库
docker exec -it mysql_master bash
# 进入从库
docker exec -it mysql_slave1 bash
docker exec -it mysql_slave2 bash
```

状态都正常的话，我们再启动 MHA

```shell
docker exec mha_manager /bin/bash /etc/init.d/script/mha_manager.sh
```

到此，整个环境就都构建好了，你能够看到如下的启动信息

```shell
mysql: [Warning] Using a password on the command line interface can be insecure.
 done.
    Testing mysqlbinlog output.. done.
    Cleaning up test file(s).. done.
Tue Dec  1 17:15:13 2020 - [info] Slaves settings check done.
Tue Dec  1 17:15:13 2020 - [info] 
mysql_master(172.18.0.2:3306) (current master)
 +--mysql_slave1(172.18.0.4:3306)
 +--mysql_slave2(172.18.0.3:3306)

Tue Dec  1 17:15:13 2020 - [warning] master_ip_failover_script is not defined.
Tue Dec  1 17:15:13 2020 - [warning] shutdown_script is not defined.
Tue Dec  1 17:15:13 2020 - [info] Set master ping interval 1 seconds.
Tue Dec  1 17:15:13 2020 - [warning] secondary_check_script is not defined. It is highly recommended setting it to check master reachability from two or more routes.
Tue Dec  1 17:15:13 2020 - [info] Starting ping health check on mysql_master(172.18.0.2:3306)..
Tue Dec  1 17:15:13 2020 - [info] Ping(SELECT) succeeded, waiting until MySQL doesn't respond..
```

接下来你可以打开另一个 shell 窗口，模拟主节点崩溃：**关闭掉 mysql_master 容器**

```shell
docker stop mysql_master
```

可以通过 MHA在控制台打出的切换日志，查看切换到的新主节点

```shell
----- Failover Report -----

mha_manager: MySQL Master failover mysql_master(172.18.0.2:3306) to mysql_slave1(172.18.0.4:3306) succeeded

Master mysql_master(172.18.0.2:3306) is down!

Check MHA Manager logs at 41f86ee8ba47 for details.

Started automated(non-interactive) failover.
The latest slave mysql_slave1(172.18.0.4:3306) has all relay logs for recovery.
Selected mysql_slave1(172.18.0.4:3306) as a new master.
mysql_slave1(172.18.0.4:3306): OK: Applying all logs succeeded.
mysql_slave2(172.18.0.3:3306): This host has the latest relay log events.
Generating relay diff files from the latest slave succeeded.
mysql_slave2(172.18.0.3:3306): OK: Applying all logs succeeded. Slave started, replicating from mysql_slave1(172.18.0.4:3306)
mysql_slave1(172.18.0.4:3306): Resetting slave info succeeded.
Master failover to mysql_slave1(172.18.0.4:3306) completed successfully.
```

最后，如果本项目帮助到了你，希望你能够不吝在右上角给我点个 Star，非常感谢。如果使用后想要关闭此项目，或是删除此项目，可使用如下脚本

```
# 关闭
./shutdown.sh
# 删除
./reset.sh
```

最后，如果本项目帮助到了你，希望你能够不吝在右上角给我点个 Star，非常感谢。

## 四 搭建过程详解

如果想要详细了解各个文件有什么作用，学习本项目的搭建思路，可以继续看以下部分，如果只是用的话，可跳过。

> 注：详解中略去了一些旁支的说明，例如start.sh

### 1 虚拟机准备

同 【快速使用】中的 【虚拟机准备】一样。

### 2 配置文件准备

创建一个文件夹 `conf`，用于存放以下的配置文件

#### 2.1 创建 MySQL 主节点的配置文件：mysql_master.cnf

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

#字符集设置
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci

# 开启binlog
log-bin=mysql-bin
# 每次写入都同步到binlog
binlog_format=ROW
sync-binlog=1
# 忽略系统库的数据同步
binlog-ignore-db=information_schema 
binlog-ignore-db=mysql 
binlog-ignore-db=performance_schema 
binlog-ignore-db=sys

# 中继日志
relay_log=mysql-relay-bin

# 自动开启半同步复制 
plugin_load="rpl_semi_sync_master=semisync_master.so"
rpl_semi_sync_master_enabled=1
rpl_semi_sync_master_timeout=1000
```

#### 2.2 创建 MySQL 从节点的配置文件：mysql_slave.cnf

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

#字符集设置
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci

# 开启binlog
log-bin=mysql-bin
# 每次写入都同步到binlog
binlog_format=ROW
sync-binlog=1
# 忽略系统库的数据同步
binlog-ignore-db=information_schema 
binlog-ignore-db=mysql 
binlog-ignore-db=performance_schema 
binlog-ignore-db=sys

# 中继日志
relay_log=mysql-relay-bin
# 只读
read_only=1
relay_log_info_repository=TABLE
relay_log_recovery=ON
relay_log_purge=0

# 并行复制
slave-parallel-type=LOGICAL_CLOCK
slave-parallel-workers=16
master_info_repository=TABLE

# 自动开启半同步复制 
plugin_load="rpl_semi_sync_slave=semisync_slave.so"
rpl_semi_sync_slave_enabled=1
```

#### 2.3 创建 MHA 的配置文件：mha_manager.cnf 

```shell
[server default]
user=root
password=root
ssh_user=root

manager_workdir=/var/log/masterha/
remote_workdir=/var/log/masterha/

repl_user=hooray
repl_password=hooray
ping_interval=1

[server1]
hostname=mysql_master
port=3306
master_binlog_dir=/var/lib/mysql
ignore_fail=1
no_master=1

[server2]
hostname=mysql_slave1
port=3306
master_binlog_dir=/var/lib/mysql
candidate_master=1
check_repl_delay=0

[server3]
hostname=mysql_slave2
port=3306
master_binlog_dir=/var/lib/mysql
candidate_master=1
check_repl_delay=0
```

### 3 环境文件准备

创建一个文件夹 `env`，用于存放以下的环境文件 **mysql.env**

```shell
# MySQL root 账号密码
MYSQL_ROOT_PASSWORD=root
# 用于 MySQL 集群间同步的账号密码
MYSQL_REPLICATION_USER=hooray
MYSQL_REPLICATION_PASSWORD=hooray
```

### 4 脚本文件准备

创建一个文件夹 `init`，用于存放以下脚本

> 注意：如果你是在 Windows 下创建脚本文件然后移到虚拟机中，要记得把文件格式改为LF（Unix格式）
>
> 也可以移到虚拟机中后，在vim里输入 `:set ff=Unix` 回车，然后 `:wq` 或 `shift+z+z` 保存退出即可 

#### 4.1 创建 MySQL 主节点的初始化脚本文件：mysql_master.sh

```shell
#!/bin/bash

echo ">>>>start to init master"

set -e

# 创建用于同步的用户
MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root \
-e "CREATE USER '${MYSQL_REPLICATION_USER}'@'%' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}'; \
GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'%' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}';"
```

#### 4.2 创建 MySQL 从节点的初始化脚本文件：mysql_slave.sh

```shell
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

# 设置主节点的信息
MYSQL_PWD=${MYSQL_ROOT_PASSWORD} mysql -u root -e \
"CREATE USER '${MYSQL_REPLICATION_USER}'@'%' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}'; \
GRANT REPLICATION SLAVE ON *.* TO '${MYSQL_REPLICATION_USER}'@'%' IDENTIFIED BY '${MYSQL_REPLICATION_PASSWORD}'; \
CHANGE MASTER TO MASTER_HOST='mysql_master', \
	      MASTER_USER='${MYSQL_REPLICATION_USER}', \
	      MASTER_PASSWORD='${MYSQL_REPLICATION_PASSWORD}', \
	      MASTER_LOG_FILE='${MASTER_LOG_FILE}', \
	      MASTER_LOG_POS='${MASTER_LOG_POS}'; \
START SLAVE;"
```

#### 4.3 创建 MHA 的初始化脚本文件：mha_manager.sh

```shell
#!/bin/bash
# author:hooray

# # 检查容器间的 SSH
masterha_check_ssh  --conf=/etc/mha/mha_manager.cnf

# # 检查 MySQL 的主从复制
masterha_check_repl --conf=/etc/mha/mha_manager.cnf 

# 启动 manager
masterha_manager --conf=/etc/mha/mha_manager.cnf  --remove_dead_master_conf --ignore_last_failover
```

#### 4.4 复制修复了 MHA-0.58 无法解析 MySQL 长版本号问题的脚本：[NodeUtil.pm](https://gitee.com/IceHL/mysql-mha/blob/master/init/NodeUtil.pm)

> 该脚本是参考[该网址](https://blog.csdn.net/ctypyb2002/article/details/88344274)，修改的 NodeUtil.pm。

### 5 共享sshkey的脚本

创建一个文件夹 `script`，用于存放以下脚本

#### 5.1 创建生成 rsa 公钥秘钥的脚本：ssh_generate_key.sh

```shell
#!/bin/bash
# author:hooray

# 启动ssh服务
service ssh start
# 生成ssh的key
ssh-keygen -t rsa -P "" -f /root/.ssh/id_rsa
# 将pub文件拷到容器间共享目录下
cp /root/.ssh/id_rsa.pub "/root/share_sshkeys/id_rsa_${KEY_SUFFIX}.pub"
```

#### 5.2 共享容器间 rsa 公钥的脚本：ssh_auth_keys.sh

```shell
# 将共享目录下的ssh key在容器间同步
cat /root/share_sshkeys/*.pub > /root/.ssh/authorized_keys
```

###  6 创建核心文件：docker-compose.yml 

```yml
#构建mysql-mha环境
version: "3.3"
services:
  mysql_master: &mysql_master # 使用制作好的镜像
    image: hooray/mha4mysql-node
    # 环境变量文件
    env_file:
      - ./env/mysql.env
    # 指定特殊的环境变量
    environment:
      - KEY_SUFFIX=mysql_master
    # 容器名称
    container_name: mysql_master
    # 在容器退出时总是重启
    restart: unless-stopped
    # 端口对外映射
    ports:
      - 3306:3306
    # 数据卷挂载
    volumes:
      # mha 容器间共享目录
      - ./data/share_sshkeys:/root/share_sshkeys
      # mysql 配置文件
      - ./conf/mysql_master.cnf:/etc/mysql/mysql.conf.d/mysqld.cnf
      # myqsl 工作目录
      - ./data/master:/var/lib/mysql
      # mysql 数据初始化
      # - ./init/schema.sql:/docker-entrypoint-initdb.d/1-schema.sql
      # - ./init/data.sql:/docker-entrypoint-initdb.d/2-data.sql
      # mysql_master 初始化配置
      - ./init/mysql_master.sh:/docker-entrypoint-initdb.d/3-mysql_init.sh
      # 挂载容器启动后要执行的脚本
      - ./script:/etc/init.d/script
    # 容器启动后默认执行的命令
    command: ["--server-id=1"]

  mysql_slave1:
    # 继承mysql_master的属性
    <<: *mysql_master
    env_file:
      - ./env/mysql.env
    environment:
      - KEY_SUFFIX=mysql_slave1
    container_name: mysql_slave1
    ports:
      - 33061:3306
    # 启动依赖于 mysql_master
    depends_on:
      - mysql_master
    volumes:
      - ./data/share_sshkeys:/root/share_sshkeys
      - ./conf/mysql_slave.cnf:/etc/mysql/mysql.conf.d/mysqld.cnf
      - ./data/slave1:/var/lib/mysql
      # - ./init/schema.sql:/docker-entrypoint-initdb.d/1-schema.sql
      # - ./init/data.sql:/docker-entrypoint-initdb.d/2-data.sql
      # mysql_slave 初始化配置
      - ./init/mysql_slave.sh:/docker-entrypoint-initdb.d/3-mysql_init.sh
      - ./script:/etc/init.d/script
    command: ["--server-id=21"]

  mysql_slave2:
    <<: *mysql_master
    env_file:
      - ./env/mysql.env
    environment:
      - KEY_SUFFIX=mysql_slave2
    container_name: mysql_slave2
    ports:
      - 33062:3306
    depends_on:
      - mysql_master
    volumes:
      - ./data/share_sshkeys:/root/share_sshkeys
      - ./conf/mysql_slave.cnf:/etc/mysql/mysql.conf.d/mysqld.cnf
      - ./data/slave2:/var/lib/mysql
      # - ./init/schema.sql:/docker-entrypoint-initdb.d/1-schema.sql
      # - ./init/data.sql:/docker-entrypoint-initdb.d/2-data.sql
      - ./init/mysql_slave.sh:/docker-entrypoint-initdb.d/3-mysql_init.sh
      - ./script:/etc/init.d/script
    command: ["--server-id=22"]
  mha_manager:
    image: hooray/mha4mysql-manager
    environment:
      - KEY_SUFFIX=mha_manager
    container_name: mha_manager
    depends_on:
      - mysql_master
      - mysql_slave1
      - mysql_slave2
    restart: always
    volumes:
      - ./data/share_sshkeys:/root/share_sshkeys
      # 挂载mha配置文件
      - ./conf/mha_manager.cnf:/etc/mha/mha_manager.cnf
      # 修复mha无法解析长名称mysql的问题
      - ./init/NodeUtil.pm:/usr/share/perl5/MHA/NodeUtil.pm
      # 挂载mha数据文件
      - ./data/mha_manager:/var/log/masterha/
      - ./init/mha_manager.sh:/etc/init.d/script/mha_manager.sh
      - ./script:/etc/init.d/script
    # 防止启动后退出
    entrypoint: "tail -f /dev/null"

```

### 7 启动并测试

到这里我们的配置文件就已经创建完成了，你会得到以下结构的文件集

```
├── conf/
|   ├── mha_manager.cnf
|   ├── mysql_master.cnf
|   └── mysql_slave.cnf
├── docker-compose.yml
├── env/
|   └── mysql.env	
├── init/
|   ├── mha_manager.sh
|   ├── mysql_master.sh
|   ├── mysql_slave.sh
|   └── NodeUtil.pm
└── script/
    ├── ssh_auth_keys.sh
    └── ssh_generate_key.sh
```

接下来关闭centos的防火墙

```shell
# 先检查是否开启着
sudo systemctl status firewalld
# 如果是开启的（active）就将它关闭了（以下命令，虚拟机重启后会再次打开防火墙）
systemctl stop firewalld
# 然后重启docker
service docker restart
```

> 这一步一定要做！这一步一定要做！这一步一定要做！不然到时候 Docker容器里网络会有问题。

使用 Docker-compose 初始化四个容器

```
docker-compose build
docker-compose up -d
```

容器如果都启动成功，就说明 MySQL 主从集群已经起好了，可以使用以下命令验证看看

```shell
# 查看主库运行状态
docker exec mysql_master sh -c 'mysql -u root -proot -e "SHOW MASTER STATUS \G"'
# 查看从库运行状态
docker exec mysql_slave1 sh -c 'MYSQL_PWD=root mysql -u root -e "SHOW SLAVE STATUS \G"'
docker exec mysql_slave2 sh -c 'MYSQL_PWD=root mysql -u root -e "SHOW SLAVE STATUS \G"'

# ----- 如果启动有问题，可用以下命令查看具体问题 -----
# 查看运行的docker容器
docker-compose ps
# 查看docker-compose运行日志
docker-compose logs
# 进入主库
docker exec -it mysql_master bash
# 进入从库
docker exec -it mysql_slave1 bash
docker exec -it mysql_slave2 bash
```

状态都正常的话，我们再启动 MHA之后我们使用挂载到容器中的脚本同步 ssh key、启动 MHA

```shell
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
# 启动 MHA
docker exec mha_manager /bin/bash /etc/init.d/script/mha_manager.sh
```

此时如果一切正常，控制台显示着你的 MHA 启动信息，且命令被阻塞着没有报错。恭喜你，这就说明整个环境已经搭建成功了。

例如如下的启动信息

```shell
mysql: [Warning] Using a password on the command line interface can be insecure.
 done.
    Testing mysqlbinlog output.. done.
    Cleaning up test file(s).. done.
Tue Dec  1 17:15:13 2020 - [info] Slaves settings check done.
Tue Dec  1 17:15:13 2020 - [info] 
mysql_master(172.18.0.2:3306) (current master)
 +--mysql_slave1(172.18.0.4:3306)
 +--mysql_slave2(172.18.0.3:3306)

Tue Dec  1 17:15:13 2020 - [warning] master_ip_failover_script is not defined.
Tue Dec  1 17:15:13 2020 - [warning] shutdown_script is not defined.
Tue Dec  1 17:15:13 2020 - [info] Set master ping interval 1 seconds.
Tue Dec  1 17:15:13 2020 - [warning] secondary_check_script is not defined. It is highly recommended setting it to check master reachability from two or more routes.
Tue Dec  1 17:15:13 2020 - [info] Starting ping health check on mysql_master(172.18.0.2:3306)..
Tue Dec  1 17:15:13 2020 - [info] Ping(SELECT) succeeded, waiting until MySQL doesn't respond..
```

接下来你可以打开另一个 shell 窗口，模拟主节点崩溃：**关闭掉 mysql_master 容器**

```shell
docker stop mysql_master
```

可以通过 MHA在控制台打出的切换日志，查看切换到的新主节点

```shell
----- Failover Report -----

mha_manager: MySQL Master failover mysql_master(172.18.0.2:3306) to mysql_slave1(172.18.0.4:3306) succeeded

Master mysql_master(172.18.0.2:3306) is down!

Check MHA Manager logs at 41f86ee8ba47 for details.

Started automated(non-interactive) failover.
The latest slave mysql_slave1(172.18.0.4:3306) has all relay logs for recovery.
Selected mysql_slave1(172.18.0.4:3306) as a new master.
mysql_slave1(172.18.0.4:3306): OK: Applying all logs succeeded.
mysql_slave2(172.18.0.3:3306): This host has the latest relay log events.
Generating relay diff files from the latest slave succeeded.
mysql_slave2(172.18.0.3:3306): OK: Applying all logs succeeded. Slave started, replicating from mysql_slave1(172.18.0.4:3306)
mysql_slave1(172.18.0.4:3306): Resetting slave info succeeded.
Master failover to mysql_slave1(172.18.0.4:3306) completed successfully.
```

最后，如果本项目帮助到了你，希望你能够不吝在右上角给我点个 Star，非常感谢。

## 五 参考资料

1. https://github.com/docker-box/mysql-cluster
2. https://github.com/breeze2/mysql-mha-docker
3. https://blog.csdn.net/ctypyb2002/article/details/88344274