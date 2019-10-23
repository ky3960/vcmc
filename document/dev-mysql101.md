Setup MySQL Cluster
------------

collation-server = utf8_unicode_ci
character-set-server = utf8  



##### Create root user 

Create root user in dev-mysql101.vm.vc/dev-mysql102.vm.vc 
```
grep temporary /var/log/mysqld.log

mysql -uroot -p'yo-.*WpwD4rG'

ALTER USER root@localhost IDENTIFIED BY 'Npn3csyb!?';
CREATE USER 'root'@'%' IDENTIFIED BY 'Npn3csyb!?';
grant all on *.* to 'root'@'%' with grant option;
exit;
```

##### Install mysql-shell (System Team)
```
yum install -y mysql-shell
yum install -y mysql-router
yum -y install pigz
```

##### Setup Cluster

Do followings in dev-mysql101.vm.vc
```
mysqlsh 
> \c root@dev-mysql101.vm.vc
> dba.checkInstanceConfiguration('root@dev-mysql101.vm.vc')
> dba.configureInstance('root@dev-mysql101.vm.vc')

Configuring local MySQL instance listening at port 3306 for use in an InnoDB cluster...

This instance reports its own address as dev-mysql101.vm.vc:3306
Clients and other cluster members will communicate with it through this address by default. If this is not correct, the report_host MySQL system variable should be changed.

NOTE: Some configuration options need to be fixed:
+--------------------------+---------------+----------------+--------------------------------------------------+
| Variable                 | Current Value | Required Value | Note                                             |
+--------------------------+---------------+----------------+--------------------------------------------------+
| binlog_checksum          | CRC32         | NONE           | Update the server variable                       |
| enforce_gtid_consistency | OFF           | ON             | Update read-only variable and restart the server |
| gtid_mode                | OFF           | ON             | Update read-only variable and restart the server |
| server_id                | 1             | <unique ID>    | Update read-only variable and restart the server |
+--------------------------+---------------+----------------+--------------------------------------------------+

Some variables need to be changed, but cannot be done dynamically on the server.
Do you want to perform the required configuration changes? [y/n]: y
Do you want to restart the instance after configuring it? [y/n]: y

```
Make sure parameters are set.

```
> dba.checkInstanceConfiguration('root@dev-mysql101.vm.vc')

The instance 'dev-mysql101.vm.vc:3306' is valid for InnoDB cluster usage.

{
    "status": "ok"
}
```

Do following in dev-mysql102.vm.vc
```
mysqlsh 
> \c root@dev-mysql102.vm.vc
> dba.checkInstanceConfiguration('root@dev-mysql102.vm.vc')
> dba.configureInstance('root@dev-mysql102.vm.vc')
> dba.checkInstanceConfiguration('root@dev-mysql102.vm.vc')
```

##### Create Cluster

```
mysqlsh
\c root@dev-mysql101.vm.vc
cluster = dba.createCluster('dev_cluster')
cluster.status()
```
You can see dev-mysql101.vm.vc is only database for cluster.

Add dev-mysql102.vm.vc into cluster
```
mysqlsh root@dev-mysql101.vm.
> cluster = dba.getCluster()
> cluster.addInstance('root@dev-mysql102.vm.vc')
```
Enter "C" for select "Clone". Check if node2 is added.

```
mysqlsh root@dev-mysql101.vm.
> cluster = status()
{
    "clusterName": "dev_cluster",
    "defaultReplicaSet": {
        "name": "default",
        "primary": "dev-mysql101.vm.vc:3306",
        "ssl": "REQUIRED",
        "status": "OK_NO_TOLERANCE",
        "statusText": "Cluster is NOT tolerant to any failures.",
        "topology": {
            "dev-mysql101.vm.vc:3306": {
                "address": "dev-mysql101.vm.vc:3306",
                "mode": "R/W",
                "readReplicas": {},
                "replicationLag": null,
                "role": "HA",
                "status": "ONLINE",
                "version": "8.0.18"
            },
            "dev-mysql102.vm.vc:3306": {
                "address": "dev-mysql102.vm.vc:3306",
                "mode": "R/O",
                "readReplicas": {},
                "replicationLag": null,
                "role": "HA",
                "status": "ONLINE",
                "version": "8.0.18"
            }
        },
        "topologyMode": "Single-Primary"
    },
    "groupInformationSourceMember": "dev-mysql101.vm.vc:3306"
}

```

##### Restart MySQL and start up cluster

```
systemctl restart mysqld

mysqlsh
> \c root@dev-mysql101.vm.vc
> dba.rebootClusterFromCompleteOutage('dev_cluster')
> c=dba.getCluster()
> c.status()
```

##### Setup MySQL Router

Configure MySQL Router for existing cluster. 
```
sudo su - 
mysqlrouter --bootstrap root@dev-mysql101.vm.vc --user=mysqlrouter

Please enter MySQL password for root:
# Bootstrapping system MySQL Router instance...

- Checking for old Router accounts
  - No prior Router accounts found
- Creating mysql account 'mysql_router1_zw44ig1xny21'@'%' for cluster management
- Storing account in keyring
- Adjusting permissions of generated files
- Creating configuration /etc/mysqlrouter/mysqlrouter.conf

# MySQL Router configured for the InnoDB cluster 'dev_cluster'

After this MySQL Router has been started with the generated configuration

    $ /etc/init.d/mysqlrouter restart
or
    $ systemctl start mysqlrouter
or
    $ mysqlrouter -c /etc/mysqlrouter/mysqlrouter.conf

the cluster 'dev_cluster' can be reached by connecting to:

## MySQL Classic protocol

- Read/Write Connections: localhost:6446
- Read/Only Connections:  localhost:6447

## MySQL X protocol

- Read/Write Connections: localhost:64460
- Read/Only Connections:  localhost:64470

```
##### Start MySQL Router

```
sudo su - 
systemctl start mysqlrouter
ps -ef | grep router
```

Setup MySQL router on dev-mysql102.vm.vc 
```
ssh root@dev-mysql102.vm.vc
sudo su - 
mysqlrouter --bootstrap root@dev-mysql101.vm.vc --user=mysqlrouter
systemctl start mysqlrouter
ps -ef | grep router
```

##### Connect through mysqlrouter

```
mysqlsh root@localhost:6446

mysqlsh root@localhost:6447

```

##### Create admin user

```
CREATE USER 'kyamada'@'localhost' IDENTIFIED WITH mysql_native_password BY 'Npn3csyb!?';
CREATE USER 'kyamada'@'%' IDENTIFIED WITH mysql_native_password BY 'Npn3csyb!?';
grant all privileges on *.* to kyamada@'%' with grant option;

mysqlsh kyamada@dev-mysql101.vm.vc
```

##### Setup ping job for cluster testing.
```
mysqlsh root@localhost:6446 --sql

create database test;
create table test.test2(col1 int auto_increment primary key
,col2 char(25)
,col3 datetime);

```

Start batch job
```
cd ~/work/vcmc/document
./insert_select.sh

```

##### Start binlog backup

Set default login

```
ssh kyamada@dev-mysql101.vm.vc
sudo su - 

mysql_config_editor set -G default -uroot -p
mysql --login-path=default
```

syncbinlog.sh   => Please refer vcmc/document/syncbinlog.sh
```
sudo su - 
mkdir -p /shell/bin
mkdir -p /shell/log
mkdir -p /backup/binlog/dev-mysql101.vm.vc
```
Copy local syncbinlog.sh into /shell/bin
```
cd /shell/bin
nohup ./syncbinlog.sh --backup-dir=/backup/binlog/dev-mysql101.vm.vc --prefix="backup-" --compress --rotate=10 > /shell/log/syncbinlog.dev-mysql101.vm.vc.log 2>&1 &
```

=> Do the same on dev-mysql102.vm.vc 

```
sudo su - 
mkdir -p /shell/bin
mkdir -p /shell/log
mkdir -p /backup/binlog/dev-mysql101.vm.vc

cd /shell/bin
nohup ./syncbinlog.sh --backup-dir=/backup/binlog/dev-mysql102.vm.vc --prefix="backup-" --compress --rotate=10 > /shell/log/syncbinlog.dev-mysql102.vm.vc.log 2>&1 &

```

##### Take a backup by mysqldump
------------ 

backup_innodb_cluster.sh will find Primary Node and run mysqldump. 

/shell/bin/backup_innodb_cluster.sh   => Please refer vcmc/document/backup_innodb_cluster.sh

```
vagrant ssh dev-mysql101.vm.vc

sudo su - 
cd 
./backup_innodb_cluster.sh
```

Backup will be created under /backup/vcmc-node1-YYYY-MM-DD.sql
Schedule backup on cron.
```
00 2 * * * /shell/bin/backup_innodb_cluster.sh >/dev/null
```


Recovery 
------------

##### 

Start batch job
```
cd ~/work/vcmc/document
./insert_select.sh

```

##### Take fulldump 

```
dev-mysql101.vm.vc 

sudo su - 
/shell/bin/backup_innodb_cluster.sh >/dev/null

```

##### Check backup dump file and binlog

```
ls -l /backup
drwxr-xr-x 3 root root      31 Oct 18 20:44 binlog
-rw-r--r-- 1 root root 1076776 Oct 18 21:19 vcmc-dev-mysql101-2019-10-18.sql
-rw-r--r-- 1 root root 1112175 Oct 19 02:00 vcmc-dev-mysql101-2019-10-19.sql
-rw-r--r-- 1 root root 1112175 Oct 20 02:00 vcmc-dev-mysql101-2019-10-20.sql
-rw-r--r-- 1 root root 1154396 Oct 21 21:28 vcmc-dev-mysql101-2019-10-21.sql

ls -l /backup/binlog/dev-mysql101.vm.vc
[root@dev-mysql101.vm.vc dev-mysql101.vm.vc]# ls -l /backup/binlog/dev-mysql101.vm.vc
total 492
-rw-r----- 1 root root   127 Oct 18 20:46 backup-binlog.000001.gz.original
-rw-r----- 1 root root   136 Oct 18 20:46 backup-binlog.000001.original.gz
-rw-r----- 1 root root   133 Oct 21 21:25 backup-binlog.000002.gz
-rw-r----- 1 root root   133 Oct 18 20:46 backup-binlog.000002.gz.original
-rw-r----- 1 root root  4353 Oct 21 21:25 backup-binlog.000003.gz
-rw-r----- 1 root root  4353 Oct 18 20:46 backup-binlog.000003.gz.original
-rw-r----- 1 root root   331 Oct 21 21:25 backup-binlog.000004.gz
-rw-r----- 1 root root   331 Oct 18 20:46 backup-binlog.000004.gz.original
-rw-r----- 1 root root 36987 Oct 21 21:25 backup-binlog.000005.gz
-rw-r----- 1 root root 36987 Oct 18 21:06 backup-binlog.000005.gz.original
-rw-r----- 1 root root 36996 Oct 18 21:06 backup-binlog.000005.original.gz
-rw-r----- 1 root root  2474 Oct 21 21:25 backup-binlog.000006.gz
-rw-r----- 1 root root  2474 Oct 18 21:07 backup-binlog.000006.gz.original
-rw-r----- 1 root root 22196 Oct 21 21:25 backup-binlog.000007.gz
-rw-r----- 1 root root 22196 Oct 18 21:19 backup-binlog.000007.gz.original
-rw-r----- 1 root root 53630 Oct 21 21:25 backup-binlog.000008.gz
-rw-r----- 1 root root 53630 Oct 19 02:00 backup-binlog.000008.gz.original
-rw-r----- 1 root root   469 Oct 21 21:25 backup-binlog.000009.gz
-rw-r----- 1 root root   469 Oct 20 02:00 backup-binlog.000009.gz.original
-rw-r----- 1 root root   473 Oct 21 21:25 backup-binlog.000010.gz
-rw-r----- 1 root root   473 Oct 21 02:00 backup-binlog.000010.gz.original
-rw-r----- 1 root root 58240 Oct 21 21:25 backup-binlog.000011.gz
-rw-r----- 1 root root 58235 Oct 21 21:25 backup-binlog.000011.original.gz
-rw-r----- 1 root root   149 Oct 21 21:25 backup-binlog.000012.gz
-rw-r----- 1 root root 47480 Oct 21 21:34 backup-binlog.000013
```

##### Restart MySQL and start up cluster

```
dev-mysql101.vm.vc/dev-mysql102.vm.vc
sudo systemctl restart mysqld

mysqlsh
> \c root@dev-mysql101.vm.vc
> dba.rebootClusterFromCompleteOutage('dev_cluster')
> c=dba.getCluster()
> c.status()
```

##### Stop insert_select.sh and check record count

```

mysqlsh root@localhost:6446 --sql
> select count(*) from test.test2;
+----------+
| count(*) |
+----------+
|     2663 |
+----------+
1 row in set (0.0011 sec)
```

##### Generate .sql file from binlog

Check binlog number in backup file.
```
dev-mysql101.vm.vc 

cd /backup
vi vcmc-dev-mysql101-2019-10-21.sql
-- CHANGE MASTER TO MASTER_LOG_FILE='binlog.000013', MASTER_LOG_POS=207;
```

Generate .sql file for recovery 
```
cd /backup/binlog/dev-mysql101.vm.vc
mkdir /backup/tmp
cp backup-binlog.000013.gz /backup/tmp/
cp backup-binlog.000014.gz /backup/tmp/
cp backup-binlog.000015 /backup/tmp/

cd /backup/tmp
gunzip backup-binlog.000013.gz
gunzip backup-binlog.000014.gz

mysqlbinlog backup-binlog.000013 > backup-binlog.000013.sql
mysqlbinlog backup-binlog.000014 > backup-binlog.000014.sql
mysqlbinlog backup-binlog.000015 > backup-binlog.000015.sql

```

##### Recover Database from full backup & binlog

```
cd ~/work/mc2
vagrant up
vagrant ssh node5
```

Copy backup file to vagrant share folder
```
cd ~/work/mc2/dev-mysql101.vm.vc
scp kyamada@dev-mysql101.vm.vc:/backup/vcmc-dev-mysql101-2019-10-21.sql .

scp kyamada@dev-mysql101.vm.vc:/backup/tmp/backup-binlog.000013.sql .
scp kyamada@dev-mysql101.vm.vc:/backup/tmp/backup-binlog.000014.sql .
scp kyamada@dev-mysql101.vm.vc:/backup/tmp/backup-binlog.000015.sql .

```

##### Start fresh database on node5

```
sudo su - 
systemctl stop mysqld

rm -Rf /var/lib/mysql

#Start Mysql and initialize password 

systemctl start mysqld

grep temporary /var/log/mysqld.log
```
Copy & Paste new password to mysql command below. 
```
mysql -uroot -p'j;2pfsz%_pWm'
 
ALTER USER root@localhost IDENTIFIED BY 'Npn8csyb!?';
SHOW VARIABLES LIKE 'validate_password%';

SET GLOBAL validate_password.policy = 0;
SHOW VARIABLES LIKE 'validate_password%';
ALTER USER root@localhost IDENTIFIED BY 'test1234';

create user 'root'@'%' identified by 'test1234';
grant all on *.* to 'root'@'%' with grant option;

exit;

systemctl restart mysqld

mysql -uroot -ptest1234
exit;

```
##### Set replication parameter from mysqlrouter

```
vagrant ssh router1 

mysqlsh root@node5
dba.checkInstanceConfiguration('root@node5')
dba.configureInstance('root@node5')
dba.checkInstanceConfiguration('root@node5')

```

##### Recover from backup

```
vagrant ssh node5

sudo su - 
cd /vagrant/dev-mysql101.vm.vc
mysql -uroot -ptest1234 < vcmc-dev-mysql101-2019-10-21.sql

```

Check record count in test.test2
```
mysql -uroot -ptest1234
> select count(*) from test.test2;
+----------+
| count(*) |
+----------+
|     2301 |
+----------+
1 row in set (0.12 sec)
```

Generate .sql file. 
```
mysql -uroot -ptest1234
source backup-binlog.000013.sql
source backup-binlog.000014.sql
source backup-binlog.000015.sql

mysql -uroot -ptest1234
> select count(*) from test.test2;
+----------+
| count(*) |
+----------+
|     2663 |
+----------+
1 row in set (0.05 sec)

```

##### dev-mysql001.vc dump

```
hostname: dev-mysql001.vc
user/pwd: dbadmin cijA[hg1!hgnkwv8
```

```
ssh kyamada@dev-mysql001.vc
sudo su - 

vi backup.sh
---
cd /backup/work/dump
mysqldump -u dbadmin -p \
--all-databases \
--events \
--single-transaction \
--flush-logs \
--master-data=2 \
--hex-blob \
--default-character-set=utf8 > dev-mysql001.sql 
---

nohup ./backup.sh &

```








