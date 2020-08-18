#!/bin/bash

DBName="test"
count=0
totalcount=`cat errorCharge.txt|wc -l`

echo "----------------------------------------------------------------------------">>异常.txt
echo "---------------------------------------------------------------------------">>待处理.txt
while read oid 
do 
	infos=(`mysql -u root $DBName -Ne "select UNAME,FLATID,GETTIME FROM TOTALCHARGE WHERE OID='$oid'"|xargs`)
		
	if [ ! $? = 0 ]; then
		echo "订单不存在0:${oid}" >>异常.txt
		continue
	fi

	if [ -z ${infos[0]} ];then
		echo "订单不存在1:${oid}">>异常.txt
		continue

	fi

	if [ -z ${infos[1]} ];then
		echo "订单不存在2:${oid}">>异常.txt
		continue

	fi

	if [ -z ${infos[2]} ];then
		echo "订单不存在3:${oid}">>异常.txt
		continue
	fi

		
	if [ ! ${infos[2]} -eq 0 ]; then
		echo "订单被冒领,$oid,${infos[0]},${infos[1]}" >> 待处理.txt
	fi

	mysql -u root $DBName -Ne "DELETE FROM TOTALCHARGE WHERE OID='$oid'"
	
	if [ ! $? = 0 ]; then
		echo "删除订单失败,$oid,${infos[0]},${infos[1]}" >> 待处理.txt
	fi
	
	let "count = $count + 1"

	echo -e "\r$count/$totalcount"

done <errorCharge.txt


echo "删除订单:$count/$totalcount"
