Backup MySQL Cluster
==========================

Description
------------

Setup daily backup mysqldump and real time binlog backup.
Recover MySQL from backup and binlog files. 


Start Cluster
------------

##### Startup Cluster

Connect to router and startup mysqlrouter and cluster. 

```
cd ~/work/mc2
vagrant ssh router1
sudo systemctl restart mysqlrouter
```

```
mysqlsh
\c root@node1

dba.rebootClusterFromCompleteOutage()

cluster=dba.getCluster()
cluster.status()
```

##### Start batch job to insert/select to Mysql Cluster

```
vagrant ssh router2

cd /vagrant
vi insert_select.sh
---
i=1
ret=1

while [ ${i} -le 1000000 ]
do
    MYSQL_PWD=test1234 mysql -ukyamada -hrouter1 -P6446 -e"insert into test.test2(col2,col3) values(rand(), now())"
    MYSQL_PWD=test1234 mysql -ukyamada -hrouter1 -P6447 -e"select @@hostname,col1,col2,col3 from  test.test2 order by col3 desc limit 1"
    ret=`echo $?`
    if test ${ret} -ne 0
    then
        sleep 2
    else
        i=`expr ${i} + 1`
        sleep 2
    fi
done
---

./insert_select.sh
```
It will insert 1 record and select new record from MySQL Cluster.

```
vagrant ssh node1

sudo su - 
cd /var/lib/mysql
ls -ltr
```
Please make sure latest binlog file (binlog.??????) is growing. 


Start binlog backup
------------

Set default login

```
vagrant ssh node1

sudo su - 
mysql_config_editor set -G default -uroot -p
mysql --login-path=default
```
Install pigz

```
sudo su - 
yum -y install pigz
```

syncbinlog.sh   => Please refer vcmc/document/syncbinlog.sh
```
sudo su - 
cd /vagrant
nohup ./syncbinlog.sh --backup-dir=/backup/binlog/node1 --prefix="mybackup-" --compress --rotate=10 > binlog_node1.log 2>&1 &
```

=> You might have to delete 1st binlog
```
cd /var/lib/mysql
rm -Rf binlog.000001

vi binlog.index
```
Erase binlog.000001

##### Do the same for node2 and node3. 

Set default login

```
vagrant ssh node2

sudo su - 
mysql_config_editor set -G default -uroot -p
mysql --login-path=default
```
Install pigz

```
sudo su - 
yum -y install pigz
```

Start backup binlog job.
```
vagrant ssh node2

sudo su - 
cd /vagrant
nohup ./syncbinlog.sh --backup-dir=/backup/binlog/node2 --prefix="mybackup-" --compress --rotate=10 > binlog_node2.log 2>&1 &

nohup ./syncbinlog.sh --backup-dir=/backup/binlog/node3 --prefix="mybackup-" --compress --rotate=10 > binlog_node3.log 2>&1 &

```

Take a backup by mysqldump
------------ 

backup_innodb_cluster.sh will find Primary Node and run mysqldump. 
backup_innodb_cluster.sh   => Please refer vcmc/document/backup_innodb_cluster.sh

```
vagrant ssh node1

sudo su - 
cd /vagrant
./backup_innodb_cluster.sh
```

Backup will be created under /backup/vcmc-node1-YYYY-MM-DD.sql


##### Check binlog and backup binlog files

```
vagrant ssh node1 
sudo su - 
ls -ltr /var/lib/mysql/binlog*
```
=> Check latest binlog. 

```
vagrant ssh node1 
sudo su - 
ls -ltr /backup/binlog/node1
```
=> Make sure latest binlog backup is match with the one in previous step. 

Erase node1 and recover from the scratch
------------

Create node4 from backup. 

##### Check latest data in node1

```
vagrant ssh node1
sudo su - 
mysql -uroot -p
select max(col1) from test.test2;
+-----------+
| max(col1) |
+-----------+
|     14003 |
+-----------+
```

##### Drop node4 & re-create 

Stop MySQL in node4 and erase all data files. 
```
vagrant ssh node4

sudo su - 
systemctl stop mysqld

rm -Rf /var/lib/mysql
```

Start MySQL in node4 and set root password to be test1234.

```
vagrant ssh node1 

systemctl start mysqld
grep temporary /var/log/mysqld.log

mysql -uroot -p'rIYel4sliv+/'

ALTER USER root@localhost IDENTIFIED BY 'Npn8csyb!?';
SHOW VARIABLES LIKE 'validate_password%';

SET GLOBAL validate_password.policy = 0;
SHOW VARIABLES LIKE 'validate_password%';
ALTER USER root@localhost IDENTIFIED BY 'test1234';

create user 'root'@'%' identified by 'test1234';
grant all on *.* to 'root'@'%' with grant option;
exit;
mysql -uroot -ptest1234
exit;
```

##### Copy dump file/binlog to /vagrant/dump 

Import dump file into node4 
```
vagrant ssh node1
sudo su - 
cp /backup/vcmc-node1-2019-10-15.sql /vagrant/dump

cd /backup/binlog/node1
cp * /vagrant/binlog/node1/
```

Import dump file. 
```
vagrant ssh node4

sudo su - 
mysql -uroot -ptest1234 < /vagrant/dump/vcmc-node1-2019-10-15.sql

```

##### Check data on node1 and node4. 

```
vagrant ssh node1
mysql -uroot -p 
mysql> select max(col1) from test.test2;
+-----------+
| max(col1) |
+-----------+
|     14003 |
+-----------+
```

Check node4. 
```
vagrant ssh node4
mysql -uroot -p 
mysql> select max(col1) from test.test2;
+-----------+
| max(col1) |
+-----------+
|     13786 |
+-----------+
```

##### Apply binlog

Check Dump file to see bilog position. 

```
vagrant ssh node1 

vi /vagrant/dump/vcmc-node1-2019-10-15.sql
CHANGE MASTER TO MASTER_LOG_FILE='binlog.000010', MASTER_LOG_POS=207;
```

```
vagrant ssh nod4 

cd /vagrant/binlog/node1/
mysqlbinlog mybackup-binlog.000010 > mybackup-binlog.000010.sql

mysql -uroot -p
source mybackup-binlog.000010.sql
```
Or you can apply binlog directly

```
cd /vagrant/binlog/node1/
mysqlbinlog mybackup-binlog.000010 |mysql -uroot -p
```

```
vagrant ssh node4
mysql -uroot -p 
mysql> select max(col1) from test.test2;
+-----------+
| max(col1) |
+-----------+
|     14003 |
+-----------+
```



Reference
--------------

* [MySQL Cluster backup](https://github.com/dheerajnambr/innodbcluster/blob/master/backup_innodb_cluster.sh)
* [MySQL Binlog backup](https://github.com/ardabeyazoglu/mysql-binlog-backup/blob/master/syncbinlog.sh)

















