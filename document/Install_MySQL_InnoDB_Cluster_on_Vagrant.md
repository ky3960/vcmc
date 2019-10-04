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




























