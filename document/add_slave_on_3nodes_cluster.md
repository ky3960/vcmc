
Adding Slave on MySQL Cluster
==========================

Description
------------

It shows how to add Slave DB on 3 nodes MySQL Innodb Cluster. 

Start Cluster
------------

##### Startup Cluster

Connect to database nodes and restart MySQL. 

```
vagrant ssh node1
sudo systemctl restart mysqld

vagrant ssh node2
sudo systemctl restart mysqld

vagrant ssh node3
sudo systemctl restart mysqld

```
Connect to router and startup mysqlrouter. 

```
cd ~/work/mc2
vagrant ssh router1
sudo systemctl restart mysqlrouter
```

Reboot Cluster by mysqlsh
```

vagrant ssh router1

mysqlsh
\c root@node1

dba.rebootClusterFromCompleteOutage()

cluster=dba.getCluster()
cluster.status()
```

Start script for insert/seelct 
------------

##### Start insert/select on router2. 
```
vagrant ssh router2

cd /vagrant
./insert_select.sh
```

Replication Parameter
------------
##### Set parameter for replication and restart database on all 3 nodes. 

You can do it from each node or you can do it from mysqlsh on router1. 
validate_password.policy = 0 is only for demo. We should set it to 1 for production.
```
vagrant ssh router1

mysqlsh root@node1

\sql
SET PERSIST validate_password.policy = 0;
##SET PERSIST server_id=10;
##SET PERSIST_ONLY gtid_mode=ON;
##SET PERSIST_ONLY enforce_gtid_consistency=true;
restart;

\c root@node2

SET PERSIST validate_password.policy = 0;
##SET PERSIST server_id=20;
##SET PERSIST_ONLY gtid_mode=ON;
##SET PERSIST_ONLY enforce_gtid_consistency=true;
restart;

\c root@node3

SET PERSIST validate_password.policy = 0;
##SET PERSIST server_id=30;
##SET PERSIST_ONLY gtid_mode=ON;
##SET PERSIST_ONLY enforce_gtid_consistency=true;
restart;

\c root@node1
\js
cluster=dba.getCluster();
cluster.status();

```
Remove existing database on new slave(node4)
------------

##### Erase database on node4

Remove database files.
```
vagrant ssh node4

sudo su - 
systemctl stop mysqld

rm -Rf /var/lib/mysql
```

Start Mysql and set root password 

```
systemctl start mysqld

grep temporary /var/log/mysqld.log
```
Copy & Paste new password to mysql command below. 
```
mysql -uroot -p'=AN<zkO!6wh7'

ALTER USER root@localhost IDENTIFIED BY 'Npn8csyb!?';
SET GLOBAL validate_password.policy = 0;
ALTER USER root@localhost IDENTIFIED BY 'test1234';

create user 'root'@'%' identified by 'test1234';
grant all on *.* to 'root'@'%' with grant option;

set persist validate_password.policy = 0;
restart;
exit;
```

Check conncetion 
```
mysql -uroot -ptest1234
exit;
```

##### Create replication user on R/W node(node1)

Create user repl for slave(192.168.40.40).
```

vagrant ssh router1

mysqlsh root@node1 --sql

create user repl@node4 identified by 'test1234';
grant REPLICATION SLAVE on *.* to repl@node4 with grant option;

```

##### Check connection from node4 to node1

```
vagrant ssh node4
sudo su - 
mysql -urepl -ptest1234 -hnode1
mysql -urepl -ptest1234 -hnode2
mysql -urepl -ptest1234 -hnode3

```

##### Take Master DB Dump

```
vagrant ssh node1
sudo su - 

mysqldump -u root -p \
--all-databases \
--events \
--single-transaction \
--flush-logs \
--master-data=2 \
--hex-blob \
--default-character-set=utf8 > /vagrant/node1_dump.sql
```

Setup slave server(node4) and start replication
------------

Set parameters for replication.
```
vagrant ssh node4

mysql -uroot -ptest1234
SET PERSIST validate_password.policy = 0;
SET PERSIST server_id=40;
SET PERSIST_ONLY gtid_mode=ON;
SET PERSIST_ONLY enforce_gtid_consistency=true;
restart;
```
##### Import node1 data into node4
```
vagrant ssh node4
sudo su - 
mysql -u root -ptest1234 < /vagrant/node1_dump.sql
```
=> Since gtid-mode=ON, we don't have to check binlog and log position. 

##### Start replication on slave. 

```
vagrant ssh node4

mysql -u root -ptest1234

CHANGE MASTER TO
 MASTER_HOST='node1',
 MASTER_PORT=3306,
 MASTER_USER='repl',
 MASTER_PASSWORD='test1234',
 master_auto_position=1;
 
start slave;
show slave status\G
```

##### Change master to node2

```
vagrant ssh node4

mysql -u root -ptest1234

stop slave;

CHANGE MASTER TO
 MASTER_HOST='node2',
 MASTER_PORT=3306,
 MASTER_USER='repl',
 MASTER_PASSWORD='test1234',
 master_auto_position=1;
 
start slave;
show slave status\G
```

##### Change master to node3

```
vagrant ssh node4

mysql -u root -p

stop slave;

CHANGE MASTER TO
 MASTER_HOST='node3',
 MASTER_PORT=3306,
 MASTER_USER='repl',
 MASTER_PASSWORD='test1234',
 master_auto_position=1;

start slave;
show slave status\G
```

Add node5 as a slave of node4
------------

Remove database on node5
```
vagrant ssh node5

sudo su - 
systemctl stop mysqld

rm -Rf /var/lib/mysql
```

Start Mysql and initialize password 

```
systemctl start mysqld
grep temporary /var/log/mysqld.log
```
Copy & Paste new password to mysql command below. 
```
mysql -uroot -p'SglBj5FfoW.b'

ALTER USER root@localhost IDENTIFIED BY 'Npn8csyb!?';
SET GLOBAL validate_password.policy = 0;
ALTER USER root@localhost IDENTIFIED BY 'test1234';

create user 'root'@'%' identified by 'test1234';
grant all on *.* to 'root'@'%' with grant option;

SET PERSIST validate_password.policy = 0;
SET PERSIST server_id=50;
SET PERSIST_ONLY gtid_mode=ON;
SET PERSIST_ONLY enforce_gtid_consistency=true;
restart;
exit;
```

Check conncetion
```
mysql -uroot -ptest1234
exit;
```

Create user repl for node5(192.168.40.50).
```

vagrant ssh node1

mysqlsh root@node1 --sql

create user repl@node5 identified by 'test1234';
grant REPLICATION SLAVE on *.* to repl@node5 with grant option;

vagrant ssh node5
mysql -uroot -ptest1234 -hnode1

```

##### Take dump again

vagrant ssh node1
sudo su - 

```
mysqldump -u root -p \
--all-databases \
--events \
--single-transaction \
--flush-logs \
--master-data=2 \
--hex-blob \
--default-character-set=utf8 > /vagrant/node1_dump2.sql
```

##### Import node1 data into node5
```
vagrant ssh node5
sudo su - 
mysql -u root -p < /vagrant/node1_dump2.sql
```
=> Since gtid-mode=ON, we don't have to check binlog and log position. 

##### Start replication on slave. 

```
vagrant ssh node5

mysql -u root -ptest1234

CHANGE MASTER TO
 MASTER_HOST='node1',
 MASTER_PORT=3306,
 MASTER_USER='repl',
 MASTER_PASSWORD='test1234',
 master_auto_position=1;
 
start slave;
show slave status\G
```


replicate-do-db=dx

v8 : slave of slave   1
v5.7 - v8 :           4




