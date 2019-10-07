MySQL InnoDB Cluster
===================

Description
-----------

This document is for install and setup MySQL InnoDB Cluster. It uses Vagrant to have virtual linux servers on local laptop. We install MySQL v8.0.17 on CentOS v7 and setup group replication on 3 MySQL nodes and 1 MySQL router. Please refer following link for diagram.

* [Diagram](https://www.percona.com/blog/2018/07/09/innodb-cluster-in-a-nutshell-part-1)

Please install Vagrant and VirtualBox before you start this tutorial

* [Vagrant](https://www.vagrantup.com/)
* [VirtualBox](https://www.virtualbox.org/)

Vagrant
------------

##### Copy Vagrantfile into your local directory.

```
$ cp vcmc/document/Vagrantfile ~/work/mc2/  
```

##### Startup Vagrant
```
$ cd ~/work/mc2
$ vagrant plugin install vagrant-vbguest
$ vagrant up
```

It will start 5 nodes with following hostname and ip address.  

```
node1     192.168.40.10  
node2     192.168.40.20  
node3     192.168.40.30  
router1   192.168.40.100  
router2   192.168.40.200  
```

##### Connect to servers 

```
cd ~/work/mc2
vagrant ssh node1
vagrant ssh node2
vagrant ssh node3
vagrant ssh router1
vagrant ssh router2
```

CentOS 7
------------

##### Edit /etc/hosts for all instances  

```
sudo vi /etc/hosts
---
192.168.40.10 node1
192.168.40.20 node2
192.168.40.30 node3
192.168.40.100 router1
192.168.40.110 router2
---
```

##### Check to see if you can ping all servers each other. 

```
$ vagrant ssh node1 
```
```
$ ping 192.168.40.100
$ ping node1
```

##### Disable SELINUX

Run followings on all 5 severs.  

```
$ sudo setenforce 0
$ sudo sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
```

MySQL 8.0 
------------

##### Add official repository & Install Mysql & Mysql shell.(node1 - node3)

```
$ cd ~/work/mc2
$ vagrant ssh node1
```
```
$ sudo su - 
$ yum install -y https://dev.mysql.com/get/mysql80-community-release-el7-1.noarch.rpm
$ yum install -y mysql-shell
$ yum install -y mysql-community-server
```

Install mysql-shell on rnode1 and rnode2
```
$ cd ~/work/mc2
$ vagrant ssh router1
```

```
sudo su - 
yum install -y https://dev.mysql.com/get/mysql80-community-release-el7-1.noarch.rpm
yum install -y mysql-shell
```

##### Set MySQL configration parameter
Please set those parameters on all 3 nodes.

```
vi /etc/my.cnf
---
[client]
default-character-set=utf8

[mysql]
default-character-set=utf8

[mysqld]
collation-server = utf8_unicode_ci
character-set-server = utf8
default_authentication_plugin = mysql_native_password
---
```

##### Start Mysql and initialize password on node1,2,and 3

Restart MySQL
```
vagrant ssh node1
sudo su - 

systemctl start mysqld
```

Login using temporary password and make sure you can connect. You can find temporary password in /var/log/mysqld.log
```
mysql -u root -p`grep 'temporary password' /var/log/mysqld.log | awk -e '{print $13}'`
 
ALTER USER root@localhost IDENTIFIED BY 'QQpn8csyb!?';
SHOW VARIABLES LIKE 'validate_password%';

SET GLOBAL validate_password.policy = 0;
SHOW VARIABLES LIKE 'validate_password%';
ALTER USER root@localhost IDENTIFIED BY 'test1234';

create user 'root'@'%' identified by 'test1234';
grant all on *.* to 'root'@'%' with grant option;

mysql -uroot -ptest1234
```



Setup MySQL Group Replication
------------

##### Login to router1 and run followings.

```
vagrant ssh router1
```
Check configration for node1
```
$ mysqlsh
dba.checkInstanceConfiguration('root@node1')
```

Configure node1
```
dba.configureInstance('root@node1')

Enter "y" for perform configration. 
Enter "y" for restart after configration.
```

Configure node2 and node3, too.

```
dba.configureInstance('root@node2')
dba.configureInstance('root@node3')
```

##### Create cluster and add nodes

```
mysqlsh
\c root@node1
cluster = dba.createCluster('vccluster')
cluster.addInstance('root@node2')
```
Enter "C" for select "Clone". Add node3, too.

```
cluster.addInstance('root@node3')
```

##### Check group replication users and configration files. 

mysql innodb cluster users are created.

```
mysql -uroot -p
select user,host from mysql.user;
```
Database: mysql_innodb_cluster_metadata is created.
```
show databases;

```
mysqld-auto.conf is set. 
```
$ cat /var/lib/mysql/mysqld-auto.cnf     
```

Install Mysql Router and start.
------------
On router1
```
sudo yum install -y mysql-router 
```
Configure mysqlrouter and start.
```
sudo mysqlrouter --bootstrap root@node1 --user=mysqlrouter
sudo systemctl start mysqlrouter
```

Check MySQL Cluster operation
------------

Connect to MySQL through mysqlrouter.
```
vagrant ssh router1

mysqlsh --uri root@localhost:6446 --sql

mysqlsh --uri root@localhost:6447 --sql

select @@hostname;
```
Connect and run select from command line
```
mysqlsh --uri root@localhost:6447 --sql -e "select @@hostname"
```
Connect through network
```
mysqlsh --uri root@192.168.40.100:6446 --sql 
```

Create table from node1

```
mysql -uroot -p 
create database test;
use test;
create table test1(col1 int(4) primary key,col2 char(10));
insert into test1 values (1,'sss'),(2,'fff'),(3,'www');
```

Connect by mysql shell and check Cluster status. 
```
vagrant ssh router1
mysqlsh 
\c root@192.168.40.10
\c root@192.168.40.20  
\c root@192.168.40.30  
\c root@node1
\c root@node2
\c root@node3
cluster= dba.getCluster();
cluster.status()
```

Check round robin ReadOnly server selection. 

Port 6446 always connect to Read/Write node.
Port 6447 conncets to one of those read only nodes.

```
vagrant ssh router1
mysqlsh --uri root@localhost:6446 --sql -e "select @@hostname" -ptest1234

mysqlsh --uri root@localhost:6447 --sql -e "select @@hostname" -ptest1234

```
















