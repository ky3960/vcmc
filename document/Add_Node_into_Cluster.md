Adding new cluster node
===================

Description
-----------

This document is for adding new node into existing MySQL Innodb Cluster. 


Vagrant
------------

##### Add new server into Vagrant file and start new server.

Add following into Vagrantfile

```
cd mc2
vi Vagrantfile
---
config.vm.define "node4" do |node|
node.vm.box = "centos/7"
node.vm.hostname = "node4"
node.vm.network :private_network, ip: "192.168.40.40", virtualbox__intnet: "intnet"
end
---
```
Start up node4
```
vagrant up
```

##### Connect to new server and configure.

```
vagrant ssh node4
```

Edit /etc/hosts and add node4. Do this for all instances.
```
vi /etc/hosts
---
192.168.40.10 node1
192.168.40.20 node2
192.168.40.30 node3
192.168.40.40 node4
192.168.40.100 router1
---
```
Check to see if you can ping other servers. 

```
ping 192.168.40.40  
ping mysql-node4
```

Disable selinux、iptables、ip6tables on node4
```
sudo setenforce 0
sudo sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
```

##### Install Mysql & Mysql shell on node4

```
vagrant ssh node4
```
```
sudo su - 
yum install -y https://dev.mysql.com/get/mysql80-community-release-el7-1.noarch.rpm
yum install -y mysql-shell
yum install -y mysql-community-server

```

##### Start Mysql and initialize password on node4

```
sudo su - 
systemctl start mysqld

mysql -u root -p`grep 'temporary password' /var/log/mysqld.log | awk -e '{print $13}'`
 
ALTER USER root@localhost IDENTIFIED BY 'QQQNpn8csyb!?';
SHOW VARIABLES LIKE 'validate_password%';

SET GLOBAL validate_password.policy = 0;
SHOW VARIABLES LIKE 'validate_password%';
ALTER USER root@localhost IDENTIFIED BY 'test1234';

create user 'root'@'%' identified by 'test1234';
grant all on *.* to 'root'@'%' with grant option;

mysql -uroot -ptest1234
```

##### Configure Instance for cluster and add it to existing cluster

```
vagrant ssh router1
```
```
mysqlsh
dba.checkInstanceConfiguration('root@node4')
dba.configureInstance('root@node4')
cluster=dba.getCluster()
cluster.addInstance('root@node4')
cluster.status()

```
























