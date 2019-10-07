
option + command + o   

to show preview on Chrome.

MySQL Innodb Cluster

https://www.percona.com/blog/2018/07/09/innodb-cluster-in-a-nutshell-part-1/

3 MySQL Servers + 1 MySQL Router on local vagrant centos7 virtual box. 

---------------------------------------------
1. Startup Cluster

2. Transaction test

  - Create/Drop table
  - Insert/Update/Delete Data.
  
3. Disaster Recovery 

  - Start pinging cluster
  - Shutdown first one
  - Shutdown Second one
  - Shutdown 2 of them
  
4. Cluster Maintenance  
  - Add 1 cluster node. 
  - Remove 1 cluster node.

5. Create Cluster from scratch

###########################################
1. Startup Cluster
###########################################

1. Vagrant up for all linux boxes on local laptop.

cd ~/work/mc2
vi Vagrantfile
####
Vagrant.configure(2) do |config|

config.vm.synced_folder "/Users/kyamada_macbookpro/work/mc2", "/vagrant", type:"virtualbox"
if Vagrant.has_plugin?("vagrant-timezone")
config.timezone.value = "Asia/Tokyo"

end

config.vm.define "node1" do |node|
node.vm.box = "centos/7"
node.vm.hostname = "node1"
node.vm.network :private_network, ip: "192.168.40.10", virtualbox__intnet: "intnet"
end

config.vm.define "node2" do |node|
node.vm.box = "centos/7"
node.vm.hostname = "node2"
node.vm.network :private_network, ip: "192.168.40.20", virtualbox__intnet: "intnet"
end

config.vm.define "node3" do |node|
node.vm.box = "centos/7"
node.vm.hostname = "node3"
node.vm.network :private_network, ip: "192.168.40.30", virtualbox__intnet: "intnet"
end

config.vm.define "node4" do |node|
node.vm.box = "centos/7"
node.vm.hostname = "node4"
node.vm.network :private_network, ip: "192.168.40.40", virtualbox__intnet: "intnet"
end

config.vm.define "node5" do |node|
node.vm.box = "centos/7"
node.vm.hostname = "node5"
node.vm.network :private_network, ip: "192.168.40.50", virtualbox__intnet: "intnet"
end

config.vm.define "router1" do |node|
node.vm.box = "centos/7"
node.vm.hostname = "router1"
node.vm.network :private_network, ip: "192.168.40.100", virtualbox__intnet: "intnet"
end

config.vm.define "router2" do |node|
node.vm.box = "centos/7"
node.vm.hostname = "router2"
node.vm.network :private_network, ip: "192.168.40.110", virtualbox__intnet: "intnet"
end

end
####


vagant up 

2. Restart Mysql all 3 instances

vagrant ssh node1
sudo su - 
systemctl restart mysqld

-> Do the same for node2 & node3.

3. Restart router

vagant ssh router1
sudo systemctl restart mysqlrouter

mysqlsh
\c root@node1
cluster=dba.getCluster()

-> It will show error. Then issue following command. 

dba.rebootClusterFromCompleteOutage()
y
y
y

cluster=dba.getCluster()
cluster.status()

=>  https://www.percona.com/blog/2018/07/09/innodb-cluster-in-a-nutshell-part-1/

###########################################
2. Transaction test from mysql 
###########################################

vagrant ssh node1 

mysql -u root -p

create table test.test3(col1 int(10) auto_increment primary key, col2 char(50));

insert into test.test3(col2) values ('This is test');
insert into test.test3(col2) select col2 from test.test3;
select * from test.test3;

select @@hostname;

vagrant ssh node2
mysql -u root -p
use test;
select * from test3;

vagrant ssh node3
mysql -u root -p
use test;
select * from test3;


-----------------------------

vagrant ssh router1

mysqlsh    => Ctrl+D to exit. 

mysqlsh 
\c root@192.168.40.10
\c root@node1

mysqlsh root@192.168.40.10
mysqlsh root@node1

Port 6446 for Read/Write

mysqlsh --uri root@localhost:6446 --sql 

mysqlsh --uri root@router1:6446 --sql 

insert into test.test3(col2) values ('This is test');
insert into test.test3(col2) select col2 from test.test3;
use test;
select * from test3;

delete from test.test3;
select * from test3;

----
Port 6447 for Read only.

mysqlsh --uri root@router1:6447 --sql 

select * from test3;
insert into test.test3(col2) values ('This is test');
drop table test.test3;


mysqlsh --uri root@localhost:6446 --sql -e "select @@hostname"
mysqlsh --uri root@localhost:6447 --sql -e "select @@hostname"

mysqlsh --uri root@localhost:6446 --password=test1234 --sql -e "select @@hostname"
mysqlsh --uri root@router1:6446 --password=test1234 --sql -e "select @@hostname"
mysqlsh --uri root@192.168.40.100:6446 --password=test1234 --sql -e "select @@hostname"

mysqlsh --uri root@localhost:6447 --password=test1234 --sql -e "select @@hostname"
mysqlsh --uri root@router1:6447 --password=test1234 --sql -e "select @@hostname"
mysqlsh --uri root@192.168.40.100:6447 --password=test1234 --sql -e "select @@hostname"


##############################################################################
3. Disaster Recovery 
##############################################################################

1. Started ping cluster. It should survive till the end.

vagrant ssh router2
sudo su - 
cd /vagrant

vi test.sh
i=1
ret=1

while [ ${i} -le 1000000 ]
do
    MYSQL_PWD=test1234 mysql -ukyamada -hrnode1 -P6446 -e"insert into test.test2(col2,col3) values(rand(), now())"
    MYSQL_PWD=test1234 mysql -ukyamada -hrnode1 -P6447 -e"select @@hostname,col1,col2,col3 from  test.test2 order by col3 desc limit 1"
    ret=`echo $?`
    if test ${ret} -ne 0
    then
        sleep 2
    else
        i=`expr ${i} + 1`
        sleep 2
    fi
done

chmod 755 test.sh
./test.sh

2. Shutdown node3 

vagrant ssh node3 
sudo su - 
systemctl stop mysqld

=> Watch log of test.sh. It will show 1 error and start connecting node2 instead.

vagrant ssh router1

mysqlsh root@node1
cluster=dba.getCluster()
cluster.status()

=> node3 became "MISSING"

3. Start up node3

vagrant ssh node3 
sudo su - 
systemctl start mysqld

=> Watch log of test.sh. It will start connecting node3 again. 

mysqlsh root@node1
cluster=dba.getCluster()
cluster.status()

=> cluster status of node3 become "ONLINE" automatically.

4. Shutdown node1 

vagrant ssh node1
sudo su - 
systemctl stop mysqld

=> Watch log of test.sh. Writing of test table never stops. 
   But it only select from node3 since node2 became writeable. 
   
mysqlsh root@node2
cluster=dba.getCluster()
cluster.status()   

=> Cluster status of node1 becomes "MISSING" and mode of node2 becomes "R/W".

5. Start node1 

vagrant ssh node1
sudo su - 
systemctl start mysqld

=> Watch log of test.sh. It starts selecting from node1 as a ReadOnly site. 
   
mysqlsh root@node1
cluster=dba.getCluster()
cluster.status() 

=> node1 joins cluster with "ReadOnly" mode and node2 stays as Writeable node. 

6. Shutdown node2(R/W) and node3(R/O)

vagrant ssh node2 and node3
sudo su - 
systemctl stop mysqld

=> Watch log of test.sh. It shows a error and recover quickly. It only select from node1
   and insert it going on. 
   
mysqlsh root@node1
cluster=dba.getCluster()
cluster.status()

=> node1 becomes writeable node and 2 others become MISSING. 

7. Startup node2 and node3. 

vagrant ssh node2 and node3
sudo su - 
systemctl start mysqld

=> Watch log of test.sh. It starts selecting from node2 and node3.
   And insert is still going on. 
   
mysqlsh root@node1
cluster=dba.getCluster()
cluster.status()

=> node2 and node3 will be added as R/O node.

##############################################################################
4. Cluster Maintenance  
##############################################################################

1. Check mysql on node4.

mysql is installed on node4 and root password is test to test1234. 

vagrant ssh node4

mysql -u root -ptest1234
use test;

test database is not created yet. 

2. Add node4 into cluster. 

vagrant ssh router1

mysqlsh
dba.checkInstanceConfiguration('root@node4')

dba.configureInstance('root@node4')
y
y

mysqlsh
\c root@node1
cluster = dba.getCluster()
cluster.status()
cluster.addInstance('root@node4')

=> Watch log of test.sh. It starts selecting from node4. 

vagrant ssh node4
mysql -uroot -p

select * from test.test2;

=> Table is copied from other node. 

2. Remove 1 node. 

vagrant ssh router1

mysqlsh root@node1 

cluster=dba.getCluster()
cluster.removeInstance('root@node3:3306')

=> Watch log of test.sh. It starts selecting from node2 & node4. 

cluster.status()

=> It doesn't show node3 any more. 

-- Reset for Demo 

cluster.addInstance('root@node3')
cluster.removeInstance('root@node4:3306')

node4
sudo systemctl restart mysqld

mysql -uroot -p
drop database test;

sudo systemctl stop mysqld



##############################################################################
5. Create Cluster from scratch
##############################################################################

1. Remove instance from Mysql nodes

cd ~/work/mc2
vagrant ssh node1

sudo su - 
systemctl stop mysqld

rm -Rf /var/lib/mysql

#Start Mysql and initialize password 

systemctl start mysqld

grep temporary /var/log/mysqld.log

mysql -uroot -p'tXkGaw9LfX?!'
 
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

=> Do the same for node2,3,4,5
   Empty MySQL server has been setup on node1-5. 
   And root user accepts connection from any server with easy password. 

2. Stop mysqlrouter on rnode1

vagrant ssh router1 
sudo systemctl stop mysqlrouter

=> Check log of test.sh 


Cluster Setup
--------------------------------------------------------------------
1. Edit /etc/hosts for all instances.

sudo vi /etc/hosts
192.168.40.10 node1
192.168.40.20 node2
192.168.40.30 node3
192.168.40.40 node4
192.168.40.50 node5
192.168.40.100 router1
192.168.40.110 router2
192.168.40.200 master
192.168.40.210 slave

2. Disable selinux、iptables、ip6tables on all instances.

sudo setenforce 0
sudo sed -i -e 's/SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config

3. Check Group Replication on router1 

vagrant ssh router1 

mysqlsh
dba.checkInstanceConfiguration('root@node1')
dba.checkInstanceConfiguration('root@node2')
dba.checkInstanceConfiguration('root@node3')

4. Configure Group Replication

dba.configureInstance('root@node1')

Enter "y" for perform configration. 
Enter "y" for restart after configration.

=> Check instance again. It says "ok" for status.
dba.checkInstanceConfiguration('root@node1')

Repeat this for others servers. 
dba.configureInstance('root@node2')
dba.configureInstance('root@node3')

5. Create cluster and add nodes
Command list: http://masato.ushio.org/blog/index.php/2017/04/23/uco-tech_how-to-use-innodb-cluster/

mysqlsh
\c root@node1
cluster = dba.createCluster('mycluster')
cluster.status()

 => You can see node1 is only 1 node for cluster.

cluster.addInstance('root@node2')


Enter "C" for select "Clone"
Check if node2 is added.

cluster.status()

Add node3 

cluster.addInstance('root@node3')

Enter "C" for select "Clone"

cluster.status()

 => mysql innodb cluster are created with 3 nodes. 
 

mysql -uroot -p
select user,host from mysql.user;

 => Users for clusters are created. 
 
 show databases; 

 => Database: mysql_innodb_cluster_metadata is created.
  
 sudo cat /var/lib/mysql/mysqld-auto.cnf  

 => mysqld-auto.conf is set. 

6. Test replication of 3 nodes.

 => Cluster is configured for 3 nodes. node1 is RW. node2 & 3 are read only. 
    If I connect to node1 and create table, it will be replicated to 2 & 3.

vagrant ssh node1

mysql -uroot -p
create database test;
use test;
create table test1(col1 int(11) auto_increment primary key ,col2 char(100));
insert into test1(col2) values (rand());
insert into test1(col2) select col2 from test1;
insert into test1(col2) select col2 from test1;
insert into test1(col2) select col2 from test1;

=> Check if data is replicated to node2 and node3.

select * from test.test1;

7. Install & Start Mysql Router
 
vagrant ssh router1

sudo yum install -y mysql-router 

sudo mysqlrouter --bootstrap root@node1 --user=mysqlrouter

sudo systemctl start mysqlrouter
ps -ef | grep router

8. Check connection though mysql router.

mysqlsh --uri root@localhost:6446 -ptest1234 --sql -e "select @@hostname"

mysqlsh --uri root@localhost:6447 -ptest1234 --sql -e "select @@hostname"


9. Insert Select Checking

vagrant ssh node1 

mysql -uroot -ptest1234 -hnode1


SET GLOBAL validate_password.policy = 0;
CREATE USER 'kyamada'@'localhost' IDENTIFIED WITH mysql_native_password BY 'test1234';
CREATE USER 'kyamada'@'%' IDENTIFIED WITH mysql_native_password BY 'test1234';
grant all privileges on test.* to kyamada@'%' with grant option;

create database test;
create table test.test2(col1 int auto_increment primary key
,col2 char(25)
,col3 datetime);


vagrant ssh router2

sudo su - 
cd /vagrant

vi test.sh
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


chmod 755 test.sh
./test.sh


10. Add 2nd router. 

vagrant ssh router2

sudo yum install -y mysql-router 

sudo mysqlrouter --bootstrap root@node1 --user=mysqlrouter

sudo systemctl start mysqlrouter
ps -ef | grep router

8. Check connection though mysql router.

mysqlsh --uri root@localhost:6446 -ptest1234 --sql -e "select @@hostname"

mysqlsh --uri root@localhost:6447 -ptest1234 --sql -e "select @@hostname"


Setup Mysqlrouter @ application server is the simple solution. 
=> https://lefred.be/content/mysql-innodb-cluster-is-the-router-a-single-point-of-failure/

11. Add node4, node5

vagrant ssh router1 

mysqlsh
dba.checkInstanceConfiguration('root@node4')
dba.checkInstanceConfiguration('root@node5')

dba.configureInstance('root@node4')
dba.configureInstance('root@node5')

Enter "y" for perform configration. 
Enter "y" for restart after configration.

=> Check instance again. It says "ok" for status.
dba.checkInstanceConfiguration('root@node4')
dba.checkInstanceConfiguration('root@node5')

cluster.addInstance('root@node4')
cluster.addInstance('root@node5')

cluster=dba.getCluster()
cluster.status()


cluster.removeInstance('root@node4:3306')
cluster.removeInstance('root@node5:3306')


cd ~/work/mc2
vagrant halt

-------------------------------------------
Install PHP and ping cluster
-------------------------------------------

vagrant ssh router2
sudo su - 
yum update

PHP 7.1.32 (cli) (built: Aug 28 2019 13:15:08) ( NTS ) will be installed.

yum install -y epel-release
rpm -Uvh http://rpms.famillecollet.com/enterprise/remi-release-7.rpm
yum remove php-*
yum install -y --enablerepo=remi,remi-php71 php php-mysqlnd php-devel php-mbstring php-pdo php-gd php-xml php-mcrypt
php -v

cd /vagrant 

vi ping.php
-------------
<?php
$servername = "router1";
$username = "kyamada";
$password = "test1234";
$dbname = "test";
$port = "6446";
$read_only_port = "6447";
$sleep_count = 3;

// Create connection
while(1) {

  $conn = new mysqli($servername, $username, $password, $dbname, $port);
  echo "Port: $port".PHP_EOL;
  if ($conn->connect_error) {
      echo $conn->connect_error . "\n";
      //die("Connection failed: " . $conn->connect_error);
  }
  echo "Connected successfully\n";
  $up = "insert into test.test2(col2,col3) values(rand(), now())";
  $result = $conn->query($up);
  $sql = "SELECT @@hostname h,col1, col2,col3 from test.test2 order by col3 desc limit 1";
  $result = $conn->query($sql);

  if ($result->num_rows > 0) {
      while($row = $result->fetch_assoc()) {
          echo "hostname: " . $row["h"]
             . " - col1: " . $row["col1"]
             . " - col2: " . $row["col2"]
             . " - col3: " . $row["col3"]
             . "\n";
      }
  } else {
      echo "0 results";
  }

  $conn = new mysqli($servername, $username, $password, $dbname, $read_only_port);
  echo "Port: $read_only_port".PHP_EOL;
  if ($conn->connect_error) {
      echo $conn->connect_error . "\n";
      //die("Connection failed: " . $conn->connect_error);
  }
  echo "Connected successfully\n";

  $sql = "SELECT @@hostname h,col1, col2,col3 from test.test2 order by col3 desc limit 1";
  $result = $conn->query($sql);

  if ($result->num_rows > 0) {
      while($row = $result->fetch_assoc()) {
          echo "hostname: " . $row["h"]
             . " - col1: " . $row["col1"]
             . " - col2: " . $row["col2"]
             . " - col3: " . $row["col3"]
             . "\n";
      }
  } else {
      echo "0 results";
  }
  echo "The time is " . date("Y/m/d h:i:sa"). "\n";
  echo "\n";
  sleep ($sleep_count);

} // while
$conn->close();

?>             
-------


MySQL Router configuration.























