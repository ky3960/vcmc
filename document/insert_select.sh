i=1
ret=1

while [ ${i} -le 1000000 ]
do
    MYSQL_PWD=Npn3csyb!? mysql -ukyamada -hdev-mysql101.vm.vc -P6446 -e"insert into test.test2(col2,col3) values(rand(), now())"
    MYSQL_PWD=Npn3csyb!? mysql -ukyamada -hdev-mysql102.vm.vc -P6447 -e"select @@hostname,col1,col2,col3 from  test.test2 order by col3 desc limit 1"
    ret=`echo $?`
    if test ${ret} -ne 0
    then
        sleep 2
    else
        i=`expr ${i} + 1`
        sleep 2
    fi
done
