#!/bin/bash
#按照合区列表进行合区
#请按照范例HeQuCfg.txt配置文件xxx.txt
#再执行:	./HeQu.sh xxx.txt
#如果同时输出日志:	./HeQu.sh HeQuCfg.txt |tee log.txt


DBUser=""
DBPasswd=""
IPList_db=()
NameList_db=()
IPList_serv=()
PortList_serv=()
ZoneList_serv=()
ZoneNameList_serv=()
#OpenTimeList_countries=()
#MergeTimeList_countries=()
#MergeCountList_countries=()
commitCountries_serv=() #指定国家分配到的目录表国家:如果为空,则采用selectCountryies的结算结果
bootDirs_serv=()

country_list=(1 2 3 4 5 6)
country_num=${#country_list[@]}

OpenTimeList_countries=()
MergeTimeList_countries=()
MergeCountList_countries=()


#中心服
IPCenter=""
DBCenter=""
domainSuffix=
domainPort=

sourceCount=0

sourcePowers=()
sourcePowers_12=() #各国第12名的战力
sourceTopCount_10=() #各国前10名的人数
selectCountryies=() #源国家分配到的国家:按照战力计算结果
sourceLevels=()

nowTime=`date +%s`

function loadConfig()
{
	if [ -z "$1" ];then
		echo -e "\t请输入配置文件名...[FAIL]"
		return 1	
	fi

	local state=0

	while read line
	do
		if expr match "$line" '[ \t]*//.*' >/dev/null
		then
			:
		elif expr match "$line" '.*\[\[.*\]\].*' >/dev/null
		then
			local tabName=`echo $line|sed -n 's/^.*\[\[\(.*\)\]\].*$/\1/p'|sed 's/^[ \t]*//'|sed 's/[ \t]*$//'`
			if [ "$tabName" = "ACCOUNT" ];then
				state=1
			elif [ "$tabName" = "DEST" ];then
				state=2
			elif [ "$tabName" = "SOURCE" ];then
				state=3
				sourceCount=`expr $sourceCount + 1`
			elif [ "$tabName" = "CENTER" ];then
				state=4
			else
				state=0
			fi
		elif [ $state -gt 0 ] 
#			expr match "${line}" '[ \t]*[^ \t:]*[ \t]*:' >/dev/null
			echo "${line}"|sed  's/^[ \t]*\([^ \t:]*[ \t]*\):.*/\1/' > /dev/null
		then	
			local propName=`echo $line|sed -n 's/^\([^:]*\):.*$/\1/p'|sed 's/^[ \t]*//'|sed 's/[ \t]*$//'`
			local propValue=`echo $line|sed -n 's/^[^:]*:\(.*\)/\1/p'|sed 's/^[ \t]*//'|sed 's/[ \t]*$//'`

			if [ "${propName}" = "" ] || [ "${propValue}" = "" ];then
				continue
			fi

			if [ "$propName" = "user" ];then
				DBUser=$propValue
			elif [ "$propName" = "passwd" ];then
				DBPasswd=$propValue
			elif [ "$propName" = "dbIP" ];then
				if [ $state = 2 ];then
					IPList_db[0]=$propValue
				elif [ $state = 3 ];then
					IPList_db[$sourceCount]=$propValue
				elif [ $state = 4 ];then
					IPCenter=$propValue	
				fi
			elif [ "$propName" = "dbName" ];then
				if [ $state = 2 ];then
					NameList_db[0]=$propValue
				elif [ $state = 3 ];then
					NameList_db[$sourceCount]=$propValue
				elif [ $state = 4 ];then
					DBCenter=$propValue
				fi	
			elif [ "$propName" = "domain_suffix" ];then
				if [ $state = 4 ];then
					domainSuffix=$propValue
				fi	
			elif [ "$propName" = "servIP" ];then
				if [ $state = 2 ];then
					IPList_serv[0]=$propValue
				elif [ $state = 3 ];then
					IPList_serv[$sourceCount]=$propValue
				fi	
			elif [ "$propName" = "servPort" ];then
				if [ $state = 2 ];then
					PortList_serv[0]=$propValue
				elif [ $state = 3 ];then
					PortList_serv[$sourceCount]=$propValue
				fi	
			elif [ "$propName" = "zone" ];then
				if [ $state = 2 ];then
					ZoneList_serv[0]=$propValue
				elif [ $state = 3 ];then
					ZoneList_serv[$sourceCount]=$propValue
				fi	
			elif [ "$propName" = "bootDir" ];then
				if [ $state = 2 ];then
					bootDirs_serv[0]=$propValue
				elif [ $state = 3 ];then
					bootDirs_serv[$sourceCount]=$propValue
				fi	
			elif [ "$propName" = "zoneName" ];then
				if [ $state = 2 ];then
					ZoneNameList_serv[0]=$propValue
				elif [ $state = 3 ];then
					ZoneNameList_serv[$sourceCount]=$propValue
				fi	

			elif [ "$propName" = "open" ] || [ "$propName" = "merge" ] || [ "$propName" = "mergecount" ];then
				if [ $state = 2 ];then
					echo "$propValue" | sed 's/;/\n/g'|sed 's/\([0-9]\)(\(.*\))/\1 \2/' > commitCountryList.tmp

					while read country time
					do
						if [ -z "$country" ] || [ -z "$time" ];then
							echo -e "\t国家分配指定时间错误，请检查...[FAIL]"
							return 1
						fi
						
						if [ "$propName" = "open" ];then
							OpenTimeList_countries[$country]=`date +%s -d "$time"`
						elif [ "$propName" = "merge" ];then
							MergeTimeList_countries[$country]=`date +%s -d "$time"`
						elif [ "$propName" = "mergeCount" ];then
							MergeCountList_countries[$country]=`date +%s -d "$time"`
						fi
					done < commitCountryList.tmp
				fi
			elif [ "$propName" = "countries" ];then
				if [ $state = 3 ];then
					echo $propValue | sed 's/;/\n/g'|sed "s/-/\t/g" > commitCountryList.tmp

					while read country toCountry
					do
						if [ -z "$country" ] || [ -z "$toCountry" ];then
							echo -e "\t国家分配指定配置错误，请检查...[FAIL]"
							return 1
						fi

						local idx=`expr $sourceCount \* $country_num + $country`
						commitCountries_serv[$idx]=$toCountry
					done < commitCountryList.tmp

					rm commitCountryList.tmp
				fi
			fi
		fi
	done<$1

	if [ $sourceCount -lt 1 ];then
		echo -e "\t配置中源区数目小与1...[FAIL]"
		return 1
	fi

	if [ "${IPList_db[0]}" = "" ] || [ "${NameList_db[0]}" = "" ];then
		echo -e "\t必须输入目标区IP和数据库配置...[FAIL]"
		return 1
	fi

	#合区目标不得与源区相同
	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		if [ "${IPList_db[$servIdx]}" = "${IPList_db[0]}" ] && [ "${NameList_db[$servIdx]}" = "${NameList_db[0]}" ];
		then
			echo -e "\t合区目标${IPList_db[$servIdx]}:${NameList_db[$servIdx]}不允许出现在源区列表中[FAIL]"
			return 1
		fi

		let "servIdx = $servIdx + 1"
	done

	return 0
}

function doPrint_config()
{
	local servIdx=0

	printf "%-3s%-32s%-6s%-32s\n"  "ID" "IP:PORT" "ZONE" "DATABASE"
	while [ $servIdx -le $sourceCount ]
	do	
		printf "%-3s%-32s%-6s%-32s\n" "${servIdx}" "${IPList_serv[$servIdx]}:${PortList_serv[$servIdx]}" "${ZoneList_serv[$servIdx]}" "${IPList_db[$servIdx]}:${NameList_db[$servIdx]}"
		
		let "servIdx = $servIdx + 1"
	done

	return 0
}


#源区检测
function checkDatabase()
{
	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		mysql -u $DBUser -p$DBPasswd -h ${IPList_db[$servIdx]} ${NameList_db[$servIdx]} -e "DESCRIBE CHARBASE" > CHARBASE_${servIdx}.txt
	
		if [ ! $? = 0 ];then
			echo -e "\t数据库不可连:${IPList_db[$servIdx]}:${NameList_db[$servIdx]}"
			return 1
		fi
		let "servIdx = $servIdx + 1"
	done

	#表差异比较
	servIdx=2
	while [ $servIdx -le $sourceCount ]
	do
		diff CHARBASE_${servIdx}.txt CHARBASE_1.txt

		if [ ! $? = 0 ];then
			echo -e "\tCHARBASE表有差异,请先修正:${IPList_db[$servIdx]}:${NameList_db[$servIdx]} [FAIL]"
			return 1
		fi
		let "servIdx = $servIdx + 1"
	done

	#取得所有的端口号
	servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		#如果不配置端口则自行扫描数据库得到端口
		if [ "${IPList_serv[$servIdx]}" = "" ];then
			local ip_port=`mysql -u $DBUser -p$DBPasswd -h ${IPList_db[$servIdx]} ${NameList_db[$servIdx]} -N -e "select IP,PORT from SERVERLIST where ID=1"`
			if [ "$ip_port" = "" ];then
				echo -e "\t$servIdx:提取区IP和端口失败"
				return 1
			else
				echo -e "\t$servIdx:IP端口=$ip_port"
			fi

			IPList_serv[$servIdx]=`echo $ip_port|awk '{print $1}'`
			PortList_serv[$servIdx]=`echo $ip_port|awk '{print $2}'`
		fi

		let "servIdx = $servIdx + 1"
	done


	return 0
}

#合区数据库初始化
function initMergeDatabase()
{
	#目标区检测
	mysql -u $DBUser -p$DBPasswd -h ${IPList_db[0]}  -e "drop database if exists ${NameList_db[0]};create database ${NameList_db[0]} character set utf8;"
	if [ ! $? = 0 ];then
		echo -e "\t数据库创建...[FAIL]"
		return 1
	else
		echo -e "\t数据库创建...[OK]"
	fi

	#取得表结构
	mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[1]} --opt -d ${NameList_db[1]} |mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}
	if [ ! $? = 0 ];then
		echo -e "\t数据库初始化...[FAIL]"
		return 1
	else
		echo -e "\t数据库初始化...[OK]"
	fi

	#为CHARBASE新增一列
	for tb in "CHARBASE" 
	do
		mysql -u $DBUser -p$DBPasswd -h ${IPList_db[0]}  ${NameList_db[0]}  -e "alter table $tb add column MERGEFLAG int(10) unsigned not null default 0;alter table $tb add column MERGECOUNTRY int(10) unsigned not null default 0;"
		if [ ! $? = 0 ];then
			echo -e "\t新增合区标记$tb...[FAIL]"
			return 1
		else
			echo -e "\t新增合区标记$tb...[OK]"
		fi
	done 

:<<!
if else;then
	#未配置区号，则采用第一个区的区号
	if [ "${ZoneList_serv[0]}" = "" ];then
		ZoneList_serv[0]=${ZoneList_serv[1]}
	fi

	echo -e "\t目标区配置:IP=${IPList_db[0]} DB=${NameList_db[0]} PORT=${PortList_serv[0]} ZONE=${ZoneList_serv[0]}"
fi
!

	#国家初始化
	mysql -u $DBUser -p$DBPasswd -h ${IPList_db[0]}  ${NameList_db[0]} -e "INSERT INTO \`COUNTRY\` (\`ID\`, \`NAME\`) VALUES(1,'c1'),(2,'c2'),(3,'c3'),(4,'c4'),(5,'c5'),(6,'c6'),(7,'c7');"
	if [ ! $? = 0 ];then
		echo -e "\t初始化COUNTRY列表...[FAIL]"
		return 1
	else
		echo -e "\t初始化COUNTRY列表...[OK]"
	fi

	#创建空的合区战力表
	mysql -u $DBUser -p$DBPasswd -h ${IPList_db[0]}  ${NameList_db[0]} -e "DROP TABLE IF EXISTS MERGE_POWERSORT; CREATE TABLE MERGE_POWERSORT (\
MERGEFLAG int(10) unsigned NOT NULL default '0',\
COUNTRY int(10) unsigned NOT NULL default '0',\
EQUIPEVALUATE int(10) unsigned NOT NULL default '0', \
HISTORYPOWER int(10) unsigned NOT NULL default '0', \
FLATZONE int(10) unsigned NOT NULL default '0',\
CHARID int(10) unsigned NOT NULL default '0',\
ACCNAME varchar(49) NOT NULL default '',\
NAME varchar(33) NOT NULL default '')ENGINE=INNODB DEFAULT CHARSET=utf8;"  
	
	if [ ! $? = 0 ];then
		echo -e "\t创建合区战力表失败"
		return 1
	fi


	return 0
}

function doSetServIPAndPort()
{
	#取得第一个服务器的SERVERLIST配置
	mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[1]} --no-create-info --complete-insert  ${NameList_db[1]} SERVERLIST|mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}
	if [ ! $? = 0 ];then
		echo -e "\t初始化$tb表...[FAIL]"
		return 1
	else
		echo -e "\t初始化$tb表...[OK]"
	fi

	#如果有配置端口则重新配置端口
	if [ "${IPList_serv[0]}" != "" ] || [ "${PortList_serv[0]}" != "" ];then
		local servIP="${IPList_serv[0]}"
		local count=${PortList_serv[0]}
		local sql=""
		for servid in 1 11 12 20 211 212 213 214 215 216 217 221 222 231
		do
			mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "update SERVERLIST set IP='$servIP' PORT=$count AND EXTPORT=$count WHERE ID=$servid"
			if [ ! $? = 0 ];then
				echo -e "\t配置服务器IP和端口($servid=$servIP:$count)...[OK]"
			else
				echo -e "\t配置服务器IP和端口($servid=$servIP:$count)...[FAIL]"
			fi

			let "count = $count + 1"
		done
	else
		IPList_serv[0]=${IPList_serv[1]}
		PortList_serv[0]=${PortList_serv[1]}
		#不需要修改数据了
		echo -e "\t配置服务器IP和端口(${IPList_serv[0]}:${PortList_serv[0]})...[OK]"
	fi

	return 0

}



function unInitMergeDatabase()
{
	for tb in "CHARBASE"
	do
		#去掉多余的列
		mysql -u $DBUser -p$DBPasswd -h ${IPList_db[0]}  ${NameList_db[0]}  -e "alter table $tb drop column MERGEFLAG;alter table $tb drop column MERGECOUNTRY;"
	
		if [ ! $? = 0 ];then
			echo -e "\t$tb表删除合区标记...[FAIL]"
			return 1
		fi
	done
	return 0
}

#角色ID生成表合并
function doMerge_CharIDGenerator()
{
	#计算出所需最大ID
	local servIdx=1
	local maxid=1001
	while [ $servIdx -le $sourceCount ]
	do
		local id=`mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} -N -e "select AUTO_INCREMENT from information_schema.TABLES WHERE TABLE_SCHEMA='${NameList_db[$servIdx]}' AND table_name='IDGENERATE';"`
		
		if [ ! -z "$id" ] && [ $id -gt $maxid ];then
			maxid=$id
		fi

		let "servIdx = $servIdx + 1"
	done

	let "maxid = $maxid + 1"

	#清空
	mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "REPLACE INTO \`IDGENERATE\`(\`REPLACEKEY\`,\`ID\`) VALUES('A','$maxid')"
	if [ ! $? = 0 ];then
		return 1
	fi
	
	curid=`mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  -N -e "select AUTO_INCREMENT from information_schema.TABLES WHERE TABLE_SCHEMA='${NameList_db[0]}' AND table_name='IDGENERATE';"`
	echo -e "\t当前角色ID生成器起始值:$curid"

	return 0
}



#合并CHARBASE
function doMerge_CharBase()
{
	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} --no-create-info --complete-insert "--where=ZONE_STATE<=2" ${NameList_db[$servIdx]} CHARBASE|mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}

		if [ ! $? = 0 ];then
			echo -e "\t$servIdx:导入CHARBASE数据...[FAIL]"
			return 1
		else
			echo -e "\t$servIdx:导入CHARBASE数据...[OK]"
		fi

		#更新合区表识
		mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "update CHARBASE SET MERGEFLAG=$servIdx,MERGECOUNTRY=COUNTRY where MERGEFLAG=0";

		if [ ! $? = 0 ];then
			echo -t "\t${servIdx}:更新合区标识...[FAIL]"
			return 1
		fi


		let "servIdx = $servIdx + 1"
	done
	
	return 0
}

#合并离线数据
function doMerge_OfflineData()
{
	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		#删除无效的离线数据
		mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} ${NameList_db[$servIdx]} -e "DELETE OFFLINEARCHIEVE FROM OFFLINEARCHIEVE,CHARBASE WHERE OFFLINEARCHIEVE.CHARID=CHARBASE.CHARID AND CHARBASE.ZONE_STATE>2"

		#再进行合并，以避免重复ID的数据
		mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} --no-create-info --complete-insert ${NameList_db[$servIdx]} "OFFLINEARCHIEVE"|mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}

		if [ ! $? = 0 ];then
			echo -e "\t$servIdx:导入OFFLINE数据...[FAIL]"
			return 1
		else
			echo -e "\t$servIdx:导入OFFLINE数据...[OK]"
		fi

		let "servIdx = $servIdx + 1"
	done
	
	return 0
}

function calcCountryPower()
{
	#取得所有阵营第12名的战力值
	local totalPower_12=0
	local averagePower_12=0
	local countryNum=0

	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		for country in ${country_list[@]}
		do
			idx=`expr $servIdx \* $country_num + $country`
		
#			sql="SELECT EQUIPEVALUATE FROM CHARBASE WHERE MERGEFLAG=${servIdx} AND COUNTRY=${country} AND LASTLOGINTIME+259200>=${MergeTimeList_countries[0]} ORDER BY EQUIPEVALUATE DESC LIMIT 12,1"
			sql="SELECT HISTORYPOWER FROM CHARBASE WHERE MERGEFLAG=${servIdx} AND COUNTRY=${country} ORDER BY HISTORYPOWER DESC LIMIT 12,1"


			local power_12=`mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "${sql}"|sed -n '2p'`

			if [ ! $? = 0 ];then
				echo -e "\t取得第12名战力\"$sql\"...[FAIL]"
				return 1
			else
				echo -e "\t取得${servIdx}_${country}第12名战力:$power_12...[OK]"
			fi

			if [ -z "$power_12" ];then
				power_12=0
			fi

			sourcePowers_12[$idx]=$power_12

			let "totalPower_12 = $totalPower_12 + $power_12"
			let "countryNum = $countryNum + 1"
		done

		let "servIdx = $servIdx + 1"
	done

	if [ $countryNum -gt 0 ];then
		averagePower_12=`expr $totalPower_12 / $countryNum`
		echo -e "\t前12名平均战力:$totalPower_12 / $countryNum = $averagePower_12 ...[OK]"
	else
		echo -e "\t前12名平均战力:$totalPower_12 / $countryNum = $averagePower_12 ...[FAIL]"
	fi

	#计算强弱阵营
	servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		for country in ${country_list[@]}
		do
			idx=`expr $servIdx \* $country_num + $country`
			sourcePowers[$idx]=1

			#sql="INSERT INTO MERGE_POWERSORT (SELECT MERGEFLAG,COUNTRY,EQUIPEVALUATE,FLATZONE,CHARID,ACCID,NAME FROM CHARBASE WHERE MERGEFLAG=${servIdx} AND COUNTRY=${country} AND LASTLOGINTIME+259200>=${MergeTimeList_countries[0]} AND EQUIPEVALUATE>=${averagePower_12} ORDER BY EQUIPEVALUATE DESC LIMIT 20)"
			sql="INSERT INTO MERGE_POWERSORT (SELECT MERGEFLAG,COUNTRY,EQUIPEVALUATE,HISTORYPOWER,FLATZONE,CHARID,ACCNAME,NAME FROM CHARBASE WHERE MERGEFLAG=${servIdx} AND COUNTRY=${country} AND ZONE_STATE<=2 AND HISTORYPOWER>=${averagePower_12} ORDER BY HISTORYPOWER DESC LIMIT 20)"


			mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "${sql}"
		
			if [ ! $? = 0 ];then
				echo -e "\t\"$sql\":[FAIL]"
				return 1
			fi
		done
		let "servIdx = $servIdx + 1"
	done

	#mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "SELECT MERGEFLAG,COUNTRY,SUM(EQUIPEVALUATE) AS POWER FROM MERGE_POWERSORT GROUP BY MERGEFLAG,COUNTRY ORDER BY POWER"|sed -n '2,$p' >powersort.txt
	mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "SELECT MERGEFLAG,COUNTRY,SUM(HISTORYPOWER) AS POWER FROM MERGE_POWERSORT GROUP BY MERGEFLAG,COUNTRY ORDER BY POWER"|sed -n '2,$p' >powersort.txt

	if [ ! $? = 0 ];then
		echo -e "\t计算强弱阵营排名...[FAIL]"
		return 1
	fi

	while read mergeFlag country power
	do
		idx=`expr $mergeFlag \* $country_num + $country`
		if [ "$power" > "0" ];then
			sourcePowers[$idx]=$power
		else
			sourcePowers[$idx]=1
		fi
	done <powersort.txt

	#前10名中各国占有人数
	mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -N -e "SELECT MERGEFLAG,COUNTRY,COUNT(*) FROM (SELECT MERGEFLAG,COUNTRY,CHARID,HISTORYPOWER AS POWER FROM MERGE_POWERSORT ORDER BY POWER DESC LIMIT 10) AS A GROUP BY MERGEFLAG,COUNTRY" > top10Count.txt;
	if [ ! $? = 0 ];then
		echo -e "\t计算前10名各国席位...[FAIL]"
		return 1
	fi

	while read mergeFlag country count
	do
		#人数达到三个人，就直接分配一个国家
		idx=`expr $mergeFlag \* $country_num + $country`

		sourceTopCount_10[$idx]=$count
	done < top10Count.txt


	return 0
}


#计算阵营的各项属性
function calcCountryProps()
{
	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		for country in ${country_list[@]}
		do
			idx=`expr $servIdx \* $country_num + $country`
			sourceLevels[$idx]=0
			sourceItem1s[$idx]=0
			sourceItem2s[$idx]=0
			sourceItem3s[$idx]=0
			sourceItem4s[$idx]=0
		done
		let "servIdx = $servIdx + 1"
	done

	servIdx=1
	>countryLevels.txt
	while [ $servIdx -le $sourceCount ]
	do
		mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} ${NameList_db[$servIdx]} -Ne "select $servIdx,ID,LEVEL,ITEMNUM1,ITEMNUM2,ITEMNUM3,ITEMNUM4 from COUNTRY WHERE ID>=1 AND ID<=$country_num">> countryProps.txt		

		if [ ! $? = 0 ];then
			echo -t "\t读取源区国家等级失败"
			return 1
		fi

		let "servIdx = $servIdx + 1"
	done

	while read mergeFlag country level item1 item2 item3 item4
	do 
		idx=`expr $mergeFlag \* 3 + $country`
		sourceLevels[$idx]=$level
		sourceItem1s[$idx]=$item1
		sourceItem2s[$idx]=$item2
		sourceItem3s[$idx]=$item3
		sourceItem4s[$idx]=$item4
	done < countryProps.txt

	return 0
}



#附加阵营等级信息
function calcCountryLevel()
{
	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		for country in ${country_list[@]}
		do
			idx=`expr $servIdx \* $country_num + $country`
			sourceLevels[$idx]=0
		done
		let "servIdx = $servIdx + 1"
	done

	servIdx=1
	>countryLevels.txt
	while [ $servIdx -le $sourceCount ]
	do
		mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} ${NameList_db[$servIdx]} -e "select $servIdx,ID,LEVEL from COUNTRY"|sed -n '2,$p' >> countryLevels.txt		

		if [ ! $? = 0 ];then
			echo -t "\t读取源区国家等级失败"
			return 1
		fi

		let "servIdx = $servIdx + 1"
	done

	while read mergeFlag country level
	do 
		idx=`expr $mergeFlag \* $country_num + $country`
		sourceLevels[$idx]=$level
	done < countryLevels.txt

	return 0
}


function doSelectCountry()
{	
	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		for country in ${country_list[@]}
		do
			idx=`expr $servIdx \* $country_num + $country`
			selectCountryies[$idx]=0
		done
		let "servIdx = $servIdx + 1"
	done


	#计算阵营分配:战力总和
	mergePowers=()

	#阵营占有前10名的席位数
	top10Count=()

	for country in ${country_list[@]}
	do
		mergePowers[$country]=0
		top10Count[$country]=0
	done


	#先分配配置中指定的区国家
	servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		for country in ${country_list[@]}
		do
			idx=`expr $servIdx \* $country_num + $country`
			
			local toCountry=${commitCountries_serv[$idx]}
			if [ ! -z "${toCountry}" ] && [ "${toCountry}" -gt 0 ] ; then
				selectCountryies[$idx]=${toCountry}	

				let "mergePowers[$toCountry] = ${mergePowers[$toCountry]} + ${sourcePowers[$idx]}"
				echo -e "\t选取阵营[按配置]$servIdx:$country,战力${sourcePowers[$idx]}-->分配到阵营$toCountry,战力${mergePowers[$toCountry]}"	
				if [ ! -z "${sourceTopCount_10[$idx]}" ] && [ ${sourceTopCount_10[$idx]} -gt 2 ] ; then
					let "top10Count[$toCountry] = ${top10Count[$toCountry]} + ${sourceTopCount_10[$idx]}"
				fi
			fi
		done
		let "servIdx = $servIdx + 1"
	done
	
	#按照前10名席位数总数优先排:先派席位数多得国家
	while true
	do
		#找到最大席位数的国家
		local maxSrcServ=0
		local maxSrcCountry=0
		local maxSrcIdx=0
		local maxTop10Count=0

		servIdx=1
		while [ $servIdx -le $sourceCount ]
		do
			for ct in ${country_list[@]}
			do
				idx=`expr $servIdx \* $country_num + $ct`
	
				#尚未选择国家，且人数达到要求
				if [ "${selectCountryies[$idx]}" -eq "0" ] && [ ! -z "${sourceTopCount_10[$idx]}" ] && [ ${sourceTopCount_10[$idx]} -gt $maxTop10Count ];then
					maxTop10Count=${sourceTopCount_10[$idx]}
					maxSrcServ=$servIdx
					maxSrcIdx=$idx
					maxSrcCountry=$ct			
				fi
			done
			let "servIdx = $servIdx + 1"
		done

		if [ $maxSrcIdx -eq 0 ];then
			echo -e "\t阵营分配[按前10席位数]分配完毕...[OK]"	
			break
		fi

		#找到前10人数总和最少的国家	
		local toCountry=0
		local toCount=0
		for ct in ${country_list[@]}
		do
			if [ $toCountry -eq 0 ] || [ $toCount -gt ${top10Count[$ct]} ];then
				toCountry=$ct
				toCount=${top10Count[$ct]}
			fi
		done

		selectCountryies[$maxSrcIdx]=${toCountry}
				
		let "mergePowers[$toCountry] = ${mergePowers[$toCountry]} + ${sourcePowers[$maxSrcIdx]}"
		let "top10Count[$toCountry] = ${top10Count[$toCountry]} + ${sourceTopCount_10[$maxSrcIdx]}"

		echo -e "\t选取阵营[按前10席位数]$maxSrcServ:$maxSrcCountry,top10=${sourceTopCount_10[$maxSrcIdx]},战力${sourcePowers[$maxSrcIdx]}-->分配到阵营$toCountry,top10=${top10Count[$toCountry]},战力${mergePowers[$toCountry]}"	
	done
	
	#找到未分配的，战力最大的国家
	while true
	do
		#选取最大战力阵营
		local maxSrcServ=0
		local maxSrcCountry=0
		local maxSrcIdx=0
		local maxSrcPower=-1
		servIdx=1
		while [ $servIdx -le $sourceCount ]
		do
			for ct in ${country_list[@]}
			do
				local idx=`expr $servIdx \* $country_num + $ct`
				if [ "${selectCountryies[$idx]}" -eq "0" ] && [ "$maxSrcPower" -lt "${sourcePowers[$idx]}" ];then
					maxSrcServ=$servIdx
					maxSrcCountry=$ct
					maxSrcIdx=$idx
					maxSrcPower=${sourcePowers[$idx]}
				fi
			done
			let "servIdx = $servIdx + 1"
		done

		if [ $maxSrcIdx -eq 0 ];then
			echo -e "\t阵营分配[按战力]完毕,准备修改阵营标记...[OK]"	
			break
		fi
		
		#找到当前最小战力的国家
		local minDstCountry=0
		local minDstPower=0
		for ct in ${country_list[@]}
		do
			if [ $minDstCountry -eq 0 ] || [ $minDstPower -gt ${mergePowers[$ct]} ];then
				minDstCountry=$ct
				minDstPower=${mergePowers[$ct]}
			fi
		done

		selectCountryies[$maxSrcIdx]=$minDstCountry

		echo -e "\t选取阵营[按战力]$maxSrcServ:$maxSrcCountry,战力$maxSrcPower-->分配到阵营$minDstCountry,战力$minDstPower"	


		let "mergePowers[$minDstCountry] = ${mergePowers[$minDstCountry]} + $maxSrcPower"
	done

:<<!
if flase; then
	servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		for country in ${country_list[@]}
		do
			#找到当前最小战力的国家
			minCountry=0
			minPower=0
			for ct in ${country_list[@]}
			do
				if [ $minCountry -eq 0 ] || [ $minPower -gt ${mergePowers[$ct]} ];then
					minCountry=$ct
					minPower=${mergePowers[$ct]}
				fi
			done

			local idx=`expr $servIdx \* $country_num + $country`
			local power=${sourcePowers[$idx]}

			selectCountryies[$idx]=$minCountry

			let "mergePowers[$minCountry] = ${mergePowers[$minCountry]} + $power"
		done

		let "servIdx = $servIdx + 1"
	done
fi
!

	local countryNames=()
	for country in ${country_list[@]}
	do
		countryNames[$country]="c"${country}"·圣墟大陆"
	done


	#修改相关的国家信息以及社会关系信息
	servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		for country in ${country_list[@]}
		do
			idx=`expr $servIdx \* $country_num + $country`

			#阵营发生变化则修改
			#if [ -n "${selectCountryies[$idx]}" ] && [ ${selectCountryies[$idx]} -ne $country ];then
			if [ "${selectCountryies[$idx]}" != "$country" ];then
				echo -e "\t${servIdx}_${country}:分配到阵营${selectCountryies[$idx]}...[变动]"

				local selectCountry=${selectCountryies[$idx]}
				local sql="UPDATE CHARBASE SET COUNTRY=${selectCountryies[$idx]},MAPNAME='${countryNames[$selectCountry]}',X=79,Y=97 WHERE MERGEFLAG=$servIdx AND MERGECOUNTRY=$country"
				mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "$sql"

#				echo -e "\t${IPList_db[0]}:${NameList_db[0]},执行sql:$sql"

				if [ ! $? = 0 ];then
					echo -e "\t${servIdx}_${country}:变更CHARBASE阵营到${selectCountryies[$idx]}...[FAIL]"
				
					return 1
				else
					echo -e "\t${servIdx}_${country}:变更CHARBASE阵营到${selectCountryies[$idx]}...[OK]"
				fi

			else
				echo -e "\t${servIdx}_${country}分配到阵营${selectCountryies[$idx]}...[不变]"
			fi
		done
		let "servIdx = $servIdx + 1"
	done


	return 0
}

function doPrint_result()
{
	> countrysort.txt
	printf "%-6s%-32s%-32s%-8s%-16s%-10s%-6s%-6s%-12s%-6s\n"   "IDX" "SERVERIP" "DATABASE" "COUNTRY" "POWER_ALL" "POWER_12" "TOP10" "LEVEL" "TO_COUNTRY" "TO_LV">> countrysort.txt
	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		for country in ${country_list[@]}
		do
			idx=`expr $servIdx \* $country_num + $country`
			printf "%-6s%-32s%-32s%-8s%-16s%-10s%-6s%-6s%-12s%-6s\n" "$servIdx" "${IPList_serv[$servIdx]}:${PortList_serv[$servIdx]}"  "${IPList_db[$servIdx]}:${NameList_db[$servIdx]}" "$country" "${sourcePowers[$idx]}" "${sourcePowers_12[$idx]}" "${sourceTopCount_10[$idx]}" "${sourceLevels[$idx]}" "${selectCountryies[$idx]}:${commitCountries_serv[$idx]}" "${maxCountryLvs[${selectCountryies[$idx]}]}">> countrysort.txt
		done
		let "servIdx = $servIdx + 1"
	done
}


#阵营等级设定
function doSetCountryProps()
{
	maxCountryLvs=()
	maxItem1s=()
	maxItem2s=()
	maxItem3s=()
	maxItem4s=()

	for country in ${country_list[@]}
	do
		maxCountryLvs[$country]=1
		maxItem1s[$country]=0
		maxItem2s[$country]=0
		maxItem3s[$country]=0
		maxItem4s[$country]=0
	done

	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		for country in ${country_list[@]}
		do
			idx=`expr $servIdx \* $country_num + $country`
		
			local selectCountry=${selectCountryies[$idx]}
			local selectIdx=`expr $servIdx \* $country_num + $selectCountry`

			if [ ${maxCountryLvs[$selectCountry]} -lt ${sourceLevels[$idx]} ];then
				maxCountryLvs[$selectCountry]=${sourceLevels[$idx]}		
			fi

			if [ ${maxItem1s[$selectCountry]} -lt ${sourceItem1s[$idx]} ];then
				maxItem1s[$selectCountry]=${sourceItem1s[$idx]}		
			fi
			if [ ${maxItem2s[$selectCountry]} -lt ${sourceItem2s[$idx]} ];then
				maxItem2s[$selectCountry]=${sourceItem2s[$idx]}		
			fi
			if [ ${maxItem3s[$selectCountry]} -lt ${sourceItem3s[$idx]} ];then
				maxItem3s[$selectCountry]=${sourceItem3s[$idx]}		
			fi
			if [ ${maxItem4s[$selectCountry]} -lt ${sourceItem4s[$idx]} ];then
				maxItem4s[$selectCountry]=${sourceItem4s[$idx]}		
			fi

#			if [ ${maxCountryLvs[$selectCountry]} -lt ${sourceLevels[$selectIdx]} ];then
#				maxCountryLvs[$selectCountry]=${sourceLevels[$selectIdx]}
#			fi
		done
		let "servIdx = $servIdx + 1"
	done
	
	for country in ${country_list[@]}
	do
		mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "update COUNTRY set LEVEL=${maxCountryLvs[$country]},MONEY=0,ITEMNUM1=${maxItem1s[$country]},ITEMNUM2=${maxItem2s[$country]},ITEMNUM3=${maxItem3s[$country]},ITEMNUM4=${maxItem4s[$country]} where ID=$country"
		if [ ! $? = 0 ]; then
			echo -e "\t阵营等级设定...[FAIL]"
			return 1
		else
			echo -e "\t阵营$country:设定等级=${maxCountryLvs[$country]},ITEM1=${maxItem1s[$country]},ITEM2=${maxItem2s[$country]},ITEM3=${maxItem3s[$country]},ITEM4=${maxItem4s[$country]}"
		fi
	done

	return 0
}

#阵营等级设定
function doSetCountryLevel()
{
	maxCountryLvs=()
	for country in ${country_list[@]}
	do
		maxCountryLvs[$country]=1
	done

	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		for country in ${country_list[@]}
		do
			idx=`expr $servIdx \* $country_num + $country`
		
			local selectCountry=${selectCountryies[$idx]}
			local selectIdx=`expr $servIdx \* $country_num + $selectCountry`

			if [ ${maxCountryLvs[$selectCountry]} -lt ${sourceLevels[$idx]} ];then
				maxCountryLvs[$selectCountry]=${sourceLevels[$idx]}		
			fi

#			if [ ${maxCountryLvs[$selectCountry]} -lt ${sourceLevels[$selectIdx]} ];then
#				maxCountryLvs[$selectCountry]=${sourceLevels[$selectIdx]}
#			fi
		done
		let "servIdx = $servIdx + 1"
	done
	
	for country in ${country_list[@]}
	do
		mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "update COUNTRY set LEVEL=${maxCountryLvs[$country]},MONEY=0 where ID=$country"
		if [ ! $? = 0 ]; then
			echo -e "\t阵营等级设定...[FAIL]"
			return 1
		else
			echo -e "\t阵营$country:设定等级=${maxCountryLvs[$country]}"
		fi
	done

	return 0
}


function doMerge_Simple()
{
	tblist=(
			"CENSUS_ACC_ZONE,,,--insert-ignore"
			"GM_TARGET_ZONE,,,--insert-ignore"
			"ZONEMERGE"
			"RELATION" 	
			"ALLIANCEMEMBER"
			"MAIL"
			"BILLLIST"
			"GUILDMEMBER"
			"GIFT"
			"SEQUENCE"
			"CLOUDBUYACTIVITY"
			"REDBAG,,ID"
			"MARRIAGE,COUNTRY,ID"
			"GROUPGIFT,,ACTID"
			"GUILD,COUNTRYID"
			"MARKETORDER,COUNTRY"
			"OVORACE,COUNTRY"
			"OPENZONEREWARD,COUNTRY,,--where=CHARID>10"
			"ACTIVITYDATARECORD,COUNTRY"
			"LEADERBOARDACT"
			"GODSGUESS"
			)

	for x in ${tblist[@]}
	do
		tb=`echo $x|awk -F, '{print $1}'`
		column=`echo $x|awk -F, '{print $2}'`
		autoid=`echo $x|awk -F, '{print $3}'`
		where=`echo $x|awk -F, '{print $4}'`
		force=`echo $x|awk -F, '{print $5}'`



		if [ ! $column = "" ];then
			mysql -u $DBUser -p$DBPasswd -h ${IPList_db[0]}  ${NameList_db[0]}  -e "alter table $tb add column MERGEFLAG int(10) unsigned not null default 0;alter table $tb add column MERGECOUNTRY int(10) unsigned not null default 0;"

			if [ ! $? = 0 ];then
				echo -e "\t$tb:导入前增加标记...[FAIL]"
			else
				echo -e "\t$tb:导入前增加标记...[OK]"
			fi
		fi

		if [ ! $autoid = "" ];then
			mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "alter table $tb change $autoid $autoid int(10) unsigned not null default 0;alter table $tb drop primary key;"
			if [ ! $? = 0 ];then
				echo -e "\t$tb:导入前去掉自增ID...[FAIL]"
			else
				echo -e "\t$tb:导入前去掉自增ID...[OK]"
			fi
		fi

		local servIdx=1
		while [ $servIdx -le $sourceCount ]
		do
			if [ -z "$where" ];then
				mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} --no-create-info --complete-insert $force ${NameList_db[$servIdx]} $tb|mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}
			else
				mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} --no-create-info --complete-insert $force "$where" ${NameList_db[$servIdx]} $tb|mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}
			fi

			if [ ! $? = 0 ];then
				echo -e "\t$tb:导入数据库表${servIdx}...[FAIL]"
			else
				echo -e "\t${tb}:导入数据库表${servIdx}...[OK]"
			fi

			#修改国家信息
			if [ ! $column = "" ];then
				for country in ${country_list[@]}
				do
					idx=`expr $servIdx \* $country_num + $country`
					if [ ! $country -eq ${selectCountryies[$idx]} ];then
						mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "UPDATE $tb SET $column=${selectCountryies[$idx]} WHERE MERGEFLAG=$servIdx AND MERGECOUNTRY=$country"
						if [ ! $? = 0 ];then
							echo -e "\t$tb:变更阵营${servIdx}_${country}->${selectCountryies[$idx]}...[FAIL]"
						else
							echo -e "\t$tb:变更阵营${servIdx}_${country}->${selectCountryies[$idx]}...[OK]"
						fi
					fi
				done
			fi

			let "servIdx = $servIdx + 1"
		done

		if [ ! $column = "" ];then
			mysql -u $DBUser -p$DBPasswd -h ${IPList_db[0]}  ${NameList_db[0]}  -e "alter table $tb drop column MERGEFLAG;alter table $tb drop column MERGECOUNTRY;"

			if [ ! $? = 0 ];then
				echo -e "\t$tb:导入后清理...[FAIL]"
			else
				echo -e "\t$tb:导入后清理...[OK]"
			fi
		fi

		if [ ! $autoid = "" ];then
			mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "update $tb set $autoid=0;alter table $tb change $autoid $autoid int(10) unsigned not null auto_increment primary key;"
	
			if [ ! $? = 0 ];then
				echo -e "\t$tb:导入会回复自增ID...[FAIL]"
			else
				echo -e "\t$tb:导入后回复自增ID...[OK]"
			fi
		fi

	done

#取消所有官员
#	mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "UPDATE ALLIANCEMEMBER SET ID=0"


	return 0
}

function doMerge_Legion()
{
    >legion.tmp.txt
    
    local servIdx=1
    while [ $servIdx -le $sourceCount ]
    do
        local sql="SELECT $servIdx,LEGION.ID,LEGION.SCORE FROM LEGION"
        mysql -u${DBUser} -p${DBPasswd} -h${IPList_db[$servIdx]} ${NameList_db[$servIdx]} -Ne "${sql}" >> legion.tmp.txt
        let "servIdx=$servIdx+1"
    done
    
    local legionList=(`cat legion.tmp.txt |awk 'BEGIN{legion[1]=0;score[1]=0;legion[2]=0;score[2]=0;legion[3]=0;score[3]=0} {if(score[$2] < $3){legion[$2]=$1;score[$2]=$3;}} END{print legion[1],legion[2],legion[3]}'`)
    
    local legionIdx=1
	for selectServIdx in ${legionList[@]}
	do
		echo -e "\t军团设定:军团$legionIdx<-服$selectServIdx"

		if [ ! -z "$selectServIdx" ] && [ $selectServIdx -gt 0 ];
        then	
			mysqldump -u${DBUser} -p${DBPasswd} -h${IPList_db[$selectServIdx]} --no-create-info --complete-insert "--where=ID=$legionIdx" ${NameList_db[$selectServIdx]} LEGION|mysql -u${DBUser} -p${DBPasswd} -h${IPList_db[0]} ${NameList_db[0]}
		fi

		let "legionIdx = $legionIdx + 1"
	done
	
	return 0
}

function doMerge_Alliance()
{
	>alliance.tmp.txt

	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		local sql="SELECT $servIdx,ALLIANCE.ID,ALLIANCE.KINGID,ALLIANCEMEMBER.POWER FROM ALLIANCE,ALLIANCEMEMBER WHERE ALLIANCE.KINGID = ALLIANCEMEMBER.MEMBERID"

		mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]}  ${NameList_db[$servIdx]} -Ne "${sql}" >> alliance.tmp.txt
		
		let "servIdx = $servIdx + 1"
	done
	
	local allianceList=(`cat alliance.tmp.txt |awk 'BEGIN{k[1]=0;p[1]=0;k[2]=0;p[2]=0;k[3]=0;p[3]=0} {if(p[$2] < $4){k[$2]=$1;p[$2]=$4;}} END{print k[1],k[2],k[3]}'`)

#for ((i=0;i<${#allianceList[@]};i++))
	
	local alliance=1
	for selectServIdx in ${allianceList[@]}
	do
		echo -e "\t联盟设定:联盟$alliance<-服$selectServIdx"

		if [ ! -z "$selectServIdx" ] && [ $selectServIdx -gt 0 ];then	
			mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$selectServIdx]} --no-create-info --complete-insert "--where=ID=$alliance" ${NameList_db[$selectServIdx]} ALLIANCE|mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}
		fi

		let "alliance = $alliance + 1"
	done

#歌剧院处理
	>opera.tmp.txt

	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		local sql="SELECT ALLIANCE.ID, ALLIANCE.OPERAWINREC, ALLIANCE.OPERAWINRECTIME FROM ALLIANCE"

		mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]}  ${NameList_db[$servIdx]} -Ne "${sql}" >> opera.tmp.txt
		
		let "servIdx = $servIdx + 1"
	done

	local operaList=(`cat opera.tmp.txt | awk 'BEGIN{r[1]=0;t[1]=0;r[2]=0;t[2]=0;r[3]=0;t[3]=0} { if (0==r[$1] && 0!=$2) {r[$1]=$2;t[$1]=$3;}  else if (0!=$2 && r[$1]>$2) {r[$1]=$2;t[$1]=$3;} else if(0!=$2 && r[$1]==$2 && t[$1]>$3) {r[$1]=$2;t[$1]=$3;} } END{print r[1],t[1],r[2],t[2],r[3],t[3]}'`)

	local idx=0
	let "alliance = 1"
	while [ $alliance -le 3 ]
	do
		echo -e "\t歌剧院设定:联盟$alliance"

		mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "UPDATE ALLIANCE SET OPERAOPENCNT=0, OPERAWINREC=${operaList[idx*2]}, OPERAWINRECTIME=${operaList[idx*2+1]} WHERE ID=$alliance;"

		let "idx = $idx + 1"
		let "alliance = $alliance + 1"
	done
	
#国家科技处理
#合服科技树重置
	>technology.tmp.txt

	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		local sql="SELECT ALLIANCE.ID, ALLIANCE.TECHLEVEL, ALLIANCE.TECHMONEY, ALLIANCE.TECHRESOURCE, ALLIANCE.TECHPOINT, ALLIANCE.TECHUSEDPOINT FROM ALLIANCE"

		mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]}  ${NameList_db[$servIdx]} -Ne "${sql}" >> technology.tmp.txt
		
		let "servIdx = $servIdx + 1"
	done

	local technologyList=(`cat technology.tmp.txt | awk 'BEGIN{l[1]=0;m[1]=0;r[1]=0;p[1]=0;u[1]=0;l[2]=0;m[2]=0;r[2]=0;p[2]=0;u[2]=0;l[3]=0;m[3]=0;r[3]=0;p[3]=0;u[3]=0} { if (l[$1] < $2) {l[$1]=$2;m[$1]=$3;r[$1]=$4;p[$1]=$5;u[$1]=$6} } END{print l[1],m[1],r[1],p[1],u[1],l[2],m[2],r[2],p[2],u[2],l[3],m[3],r[3],p[3],u[3]}'`)
	
	local idx=0
	let "alliance = 1"
	while [ $alliance -le 3 ]
	do
		echo -e "\联盟科技设定:联盟$alliance"

		mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "UPDATE ALLIANCE SET TECHLEVEL=${technologyList[$idx*5]}, TECHMONEY=${technologyList[$idx*5+1]}, TECHRESOURCE=${technologyList[$idx*5+2]}, TECHPOINT=${technologyList[$idx*5+3]} + ${technologyList[$idx*5+4]}, TECHUSEDPOINT=0 WHERE ID=$alliance;"
		let "idx = $idx + 1"
		let "alliance = $alliance + 1"
	done
	
	return 0
}



#统计日志合并
function doMerge_Census()
{
	tblist=(
			"CENSUS_SERV_DAY"
			"CENSUS_SERV_HOOK"
			"CENSUS_SERV_MON"
			"CENSUS_SERV_REALTIME"
			)

	for x in ${tblist[@]}
	do
		local servIdx=1
		while [ $servIdx -le $sourceCount ]
		do
			mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} ${NameList_db[$servIdx]} -Ne "select * from $tb"

			if [ ! $? = 0 ];then
				echo -e "\t$tb:导入数据库表${servIdx}...[FAIL]"
			else
				echo -e "\t${tb}:导入数据库表${servIdx}...[OK]"
			fi

			let "servIdx = $servIdx + 1"
		done
	done
	
	return 0
}

function doMerge_LeaderboardAct()
{
	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		lbActList=`mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} ${NameList_db[$servIdx]} -Ne "SHOW TABLES LIKE 'LEADERBOARDSORT%'"|xargs`

		for tb in ${lbActList[@]}
		do
#echo -e "\t准备导入表$servIdx:$tb"

			#创建表
			curtb=`mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -Ne "SHOW TABLES LIKE '$tb'"`
		
			if [ "$curtb" = "" ];then
				result=`mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} ${NameList_db[$servIdx]} -Ne "show create table $tb\G"`
				if [ $? = 0 ];then
					sql=`echo "$result"|sed -n '3,$p'`
						
#					echo -e "\t准备创建表:$sql"

					mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "$sql"
					if [ ! $? = 0 ];then
						echo -e "\t$tb:创建数据库表...[FAIL]"
						exit 1;
					else
						echo -e "\t$tb:创建数据库表...[OK]"
						#checkkey=1
					fi
				fi
			fi

			mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} --no-create-info --complete-insert ${NameList_db[$servIdx]} $tb|mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}
	
			if [ ! $? = 0 ];then
				echo -e "\t$tb:导入数据库表${servIdx}...[FAIL]"
			else
				echo -e "\t$tb:导入数据库表${servIdx}...[OK]"
			fi
		done
		let "servIdx = $servIdx + 1"
	done
	
	return 0
}

function doMerge_Log()
{
	logtbllist=()
	keytblist=()

	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		logList=`mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} ${NameList_db[$servIdx]} -Ne "SHOW TABLES LIKE 'log_%'"|xargs`

		for tb in ${logList[@]}
		do
#echo -e "\t准备导入表$servIdx:$tb"

			#创建表
			curtb=`mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -Ne "SHOW TABLES LIKE '$tb'"`
		
			checkkey=0
			if [ "$curtb" = "" ];then
				result=`mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} ${NameList_db[$servIdx]} -Ne "show create table $tb\G"`
				if [ $? = 0 ];then
					sql=`echo "$result"|sed -n '3,$p'`
						
#					echo -e "\t准备创建表:$sql"

					mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "$sql"
					if [ ! $? = 0 ];then
						echo -e "\t$tb:创建数据库表...[FAIL]"
						exit 1;
					else
						echo -e "\t$tb:创建数据库表...[OK]"
						checkkey=1
					fi
				fi
			else
				mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "show create table $tb"|grep PRIMARY > /dev/null
				if [ $? = 0 ];then
					checkkey=1
				fi
			fi

			if [ $checkkey -eq 1 ];then
				suffix=`echo $tb |awk -F_ '{print $NF}'`
				if [ "$suffix" = "1" ];then				
					mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "alter table $tb change logseq logseq int(10) unsigned not null default 0;alter table $tb drop primary key;"
					echo -e "\t$tb:修改数据库表...[OK]"

					#elif expr match "$suffix" '[0-9]\+' >/dev/null
					keytblist+=($tb)
				fi
			fi

			mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} --no-create-info --complete-insert ${NameList_db[$servIdx]} $tb|mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}
	
			if [ ! $? = 0 ];then
				echo -e "\t$tb:导入数据库表${servIdx}...[FAIL]"
			else
				echo -e "\t$tb:导入数据库表${servIdx}...[OK]"
			fi
		done
		let "servIdx = $servIdx + 1"
	done
	
	for tb in ${keytblist[@]}
	do
		mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "update $tb set logseq=0;alter table $tb change logseq logseq int(10) unsigned not null auto_increment primary key;"
		if [ ! $? = 0 ];then
			echo -e "\t$tb:重新分配logseq...[FAIL]"
			return 1
		else
			echo -e "\t$tb:重新分配logseq...[OK]"
		fi		
	done

	
	return 0
}





#服务器状态合并
function doMerge_ServData()
{
#直接取得第一个服的
	mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[1]} --no-create-info --complete-insert ${NameList_db[1]} SERVERDATA|mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}

	
	mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "UPDATE SERVERDATA SET VALUE=0,TIME=0 WHERE TYPE=259"


	return 0
}


#合并MARRIAGE
function doMerge_Merriage()
{
	mysql -u $DBUser -p$DBPasswd -h ${IPList_db[0]}  ${NameList_db[0]}  -e "alter table MARRIAGE add column MERGEFLAG int(10) unsigned not null default 0;alter table MARRIAGE add column MERGECOUNTRY int(10) unsigned not null default 0;"

	if [ ! $? = 0 ];
	then
		echo -e "\tMERRIAGE表合并前准备失败,无法添加Flag"
		return 1
	fi

	mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "alter table MARRIAGE change ID ID int(10) unsigned not null;alter table MARRIAGE drop primary key;"
	
	if [ ! $? = 0 ];
	then
		echo -e "\tMERRIAGE表合并前准备失败,无法去除主键"
		return 1
	fi
			
	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} --no-create-info --complete-insert ${NameList_db[$servIdx]} MARRIAGE|mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}

		if [ ! $? = 0 ];then
			echo -e "\t$servIdx:导入MARRIAGE数据...[FAIL]"
			return 1
		fi

		#更新合区表识
		mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "update MARRIAGE SET MERGEFLAG=$servIdx,MERGECOUNTRY=COUNTRY where MERGEFLAG=0";

		if [ ! $? = 0 ];then
			echo -e "\t$servIdx:更新MARRIAGE合区标识...[FAIL]"
			return 1;
		fi

		echo -e "\t$servIdx:导入MARRIAGE数据...[OK]"


		#修改国家信息
		for country in ${country_list[@]}
		do
			idx=`expr $servIdx \* $country_num + $country`

			if [ ! $country -eq ${selectCountryies[$idx]} ];then

				mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "UPDATE MARRIAGE SET COUNTRY=${selectCountryies[$idx]} WHERE MERGEFLAG=$servIdx AND MERGECOUNTRY=$country"

				if [ ! $? = 0 ];then
					echo -e "\t${servIdx}_${country}:变更MERRIAGE到阵营${selectCountryies[$idx]} 失败...[FAIL]"
					return 1
				else
					echo -e "\t${servIdx}_${country}:变更MERRIAGE到阵营${selectCountryies[$idx]}成功...[OK]"
				fi
			fi
		done

		let "servIdx = $servIdx + 1"
	done


	#补上主键
	mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "update MARRIAGE set ID=0;alter table MARRIAGE change ID ID int(10) unsigned not null auto_increment primary key;"
	if [ ! $? = 0 ];then
		echo -e "\t重新分配MERRIAGE表ID...[FAIL]"
		return 1
	else
		echo -e "\t重新分配MERRIAGE表ID...[OK]"
	fi

	return 0
}


:<<CLEAR
#特殊处理邮件表
function doMerge_Mail()
{
if false;then
	mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "alter table MAIL change ID ID int(10);alter table MAIL drop primary key;alter table MAIL drop index TOID;"
	
	if [ ! $? = 0 ];then
		echo -e "\t重新分配邮件表ID_1...[FAIL]"
		return 1
	else
		echo -e "\t重新分配邮件表表ID_1...[OK]"
	fi

	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} --no-create-info --complete-insert ${NameList_db[$servIdx]} MAIL|mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}

		if [ ! $? = 0 ];then
			echo -e "\t${servIdx}导入MAIL表...[FAIL]"
			return 1
		else
			echo -e "\t${servIdx}导入MAIL表...[OK]"
		fi
		
		let "servIdx = $servIdx + 1"
	done
	
	#还原主键
	mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "update MAIL set ID=0;alter table MAIL change ID ID int(10) unsigned not null auto_increment primary key;alter table MAIL add index(TOID)"

	if [ ! $? = 0 ];then
		echo -e "\t重新分配邮件表ID_2...[FAIL]"
		return 1
	else
		echo -e "\t重新分配邮件表表ID_2...[OK]"
	fi

fi

	return 0
}
CLEAR

#导入各种排行榜
doMergeSort()
{
	#清空战天魔周期伤害排行榜
	#mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "truncate table WORLDBOSSDMGSORT";
	#清空战天魔每日伤害排行榜
	#mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "truncate table WORLDBOSSDAYDMGSORT";
	
	sortlist=`mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -Ne "SHOW TABLES LIKE '%SORT'"|egrep -v "MERGE_POWERSORT"`

	for tb in ${sortlist[@]}
	do
		mysql -u $DBUser -p$DBPasswd -h ${IPList_db[0]}  ${NameList_db[0]}  -e "alter table $tb add column MERGEFLAG int(10) unsigned not null default 0;alter table $tb add column MERGECOUNTRY int(10) unsigned not null default 0;"
		if [ ! $? = 0 ];then
			echo -e "\t$tb:导入前准备失败...[FAIL]"
		else
			echo -e "\t$tb:导入前准备成功...[OK]"
		fi


		local servIdx=1
		while [ $servIdx -le $sourceCount ]
		do
		#清除非源区的数据
#mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} ${NameList_db[$servIdx]} -e "DELETE FROM NEWFLOWERSORT WHERE CHARID NOT IN (SELECT CHARID FROM CHARBASE)";
#mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} ${NameList_db[$servIdx]} -e "DELETE NEWFLOWERSORT FROM NEWFLOWERSORT,CHARBASE WHERE NEWFLOWERSORT.CHARID=CHARBASE.CHARID AND CHARBASE.ZONE_STATE > 2";
			mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} --no-create-info --complete-insert ${NameList_db[$servIdx]} $tb |mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}
	
			if [ ! $? = 0 ];then
				echo -e "\t$tb:导入数据库表${servIdx}...[FAIL]"
			else
				echo -e "\t$tb:导入数据库表${servIdx}...[OK]"
			fi
			
			columnname="COUNTRYTYPE"
			if [ "$tb" = "TIANTINGSCORESORT" ] || [ "$tb" = "MARRIEDNEWACTSORT" ] || [ "$tb" = "RESOURCEFIGHTSORT" ] ;then
				columnname="COUNTRY"
			fi

			mysql -u $DBUser -p$DBPasswd -h ${IPList_db[0]}  ${NameList_db[0]}  -e "update $tb set MERGEFLAG=$servIdx,MERGECOUNTRY=$columnname WHERE MERGEFLAG=0;"

			for country in ${country_list[@]}
			do
				idx=`expr $servIdx \* $country_num + $country`

				if [ ! $country -eq ${selectCountryies[$idx]} ];then
					mysql -u ${DBUser} -p${DBPasswd} -h ${IPList_db[0]}  ${NameList_db[0]} -e "UPDATE $tb SET $columnname=${selectCountryies[$idx]} WHERE MERGEFLAG=$servIdx AND MERGECOUNTRY=$country"
					if [ ! $? = 0 ];then
						echo -e "\t$tb:变更阵营${servIdx}_${country}->${selectCountryies[$idx]} 失败...[FAIL]"
					else
						echo -e "\t$tb:变更阵营${servIdx}_${country}->${selectCountryies[$idx]} 成功...[OK]"
					fi
				fi
			done

			let "servIdx = $servIdx + 1"
		done

		mysql -u $DBUser -p$DBPasswd -h ${IPList_db[0]}  ${NameList_db[0]}  -e "alter table $tb drop column MERGEFLAG;alter table $tb drop column MERGECOUNTRY;"

		if [ ! $? = 0 ];then
			echo -e "\t$tb:导入后清理失败...[FAIL]"
		else
			echo -e "\t$tb:导入后清理成功...[OK]"
		fi
	done

	return 0
}


doMergeGift()
{
:<<!
if false;then
	local servIdx=1
	
	local maxActID=1	
	while [ $servIdx -le $sourceCount ]
	do
		local maxID=`mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]}  ${NameList_db[$servIdx]} -e  "SHOW TABLE STATUS LIKE 'GROUPGIFT'"|sed -n '2p'|awk -F'\t' '{print $11}'`;
	
		if [ ! $? = 0 ];then
			echo -e "\t${servIdx}:获取补偿活动最大ID...[FAIL]"
		else
			echo -e "\t${servIdx}:获取补偿活动最大ID=$maxID...[OK]"
		fi

		if [ -z "$maxID" ];then
			maxID=1
		fi

		if [ $maxActID -lt $maxID ];then
			maxActID=$maxID;
		fi

		let "servIdx = $servIdx + 1"
	done

	mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "alter table GROUPGIFT auto_increment=$maxActID";

	if [ ! $? = 0 ];then
		echo -e "\t设置最终补偿活动最大ID=$maxActID...[FAIL]"
	else
		echo -e "\t设置最终补偿活动最大ID=$maxActID...[OK]"
	fi
fi
!
	return 0
}


#武神纪元合并
doMergeWuShengJiYuan()
{
	local servIdx=1
	
	while [ $servIdx -le $sourceCount ]
	do
		mysqldump -u ${DBUser} -p${DBPasswd} -h ${IPList_db[$servIdx]} --no-create-info --complete-insert ${NameList_db[$servIdx]} WUSHENJIYUAN |mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]}

		let "servIdx = $servIdx + 1"
	done

	#NUM取和
	mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "UPDATE WUSHENJIYUAN,(SELECT TYPE, RANK, SUM(NUM) AS n FROM WUSHENJIYUAN GROUP BY TYPE, RANK) AS w SET WUSHENJIYUAN.NUM = w.n WHERE WUSHENJIYUAN.TYPE = w.TYPE AND WUSHENJIYUAN.RANK = w.RANK";

	#去掉重复的
	mysql -u${DBUser} -p${DBPasswd} -h ${IPList_db[0]} ${NameList_db[0]} -e "DELETE FROM WUSHENJIYUAN using WUSHENJIYUAN ,(select CHARID,TYPE,RANK,MIN(TIME) as TIME from WUSHENJIYUAN GROUP BY TYPE,RANK HAVING COUNT(1)>1) AS b WHERE WUSHENJIYUAN.CHARID=b.CHARID AND WUSHENJIYUAN.TYPE=b.TYPE AND WUSHENJIYUAN.RANK=b.RANK AND WUSHENJIYUAN.TIME!=b.TIME";

	if [ ! $? = 0 ];then
		echo -e "\t合并武神纪元...[FAIL]"
	else
		echo -e "\t合并武神纪元...[OK]"
	fi
	return 0
}


doRegToCenter()
{
	if [ "$IPCenter" = "" ] || [ "${DBCenter}" == "" ];then
		return 0
	fi

	local maxid1=`find . -name "FLATZONE.*.sql"|sed 's/.*FLATZONE\.\(.*\)\.sql/\1/'|sort -n -r |sed -n '1p'`
	local maxid2=`find . -name "ZONELIST.*.sql"|sed 's/.*ZONELIST\.\(.*\)\.sql/\1/'|sort -n -r |sed -n '1p'`
	
	if [ -z "$maxid1" ];then
		maxid1=0
	fi

	if [ -z "$maxid2" ];then
		maxid2=0
	fi

	if [ $maxid1 -lt $maxid2 ];then
		maxid1=$maxid2
	fi

	let "maxid1 = $maxid1 + 1"
	
	mysqldump -u  $DBUser -p$DBPasswd -h ${IPCenter} ${DBCenter}  ZONELIST > ZONEList.$maxid1.sql
	if [ ! $? = 0 ];then
		echo -e "\t备份ZONELIST到文件:ZONEList.$maxid1.sql ...[FAIL]"
	else
		echo -e "\t备份ZONELIST到文件:ZONEList.$maxid1.sql ...[OK]"
	fi
		
	mysqldump -u  $DBUser -p$DBPasswd -h ${IPCenter} ${DBCenter}  FLATZONE > FLATZONE.$maxid1.sql
	if [ ! $? = 0 ];then
		echo -e "\t备份FLATZONE到文件:FLATZONE.$maxid1.sql ...[FAIL]"
	else
		echo -e "\t备份FLATZONE到文件:FLATZONE.$maxid1.sql ...[OK]"
	fi

	>ZoneList.temp.txt
	local servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		#配置了中心服，则向中心服验证
		mysql -u $DBUser -p$DBPasswd -h ${IPCenter} ${DBCenter} -Ne "select '$servIdx',ZONE,IDX,IP,PORT,NAME,ZONEOPENTIME,ZONEMERGETIME,ZONEMERGECOUNT from ZONELIST where IP='${IPList_serv[$servIdx]}' and PORT=${PortList_serv[$servIdx]}" >> ZoneList.temp.txt

		if [ ! $? = 0 ];then
			echo -e "\t查询游戏区号:${IPList_serv[$servIdx]}:${PortList_serv[$servIdx]}...[FAIL]"
			return 1
		fi
		let "servIdx = $servIdx + 1"
	done

	echo -e "\t所有内部区列表:"
	cat ZoneList.temp.txt

	#计算时间次数
	local openTimeList=()
	local mergeCountList=()

	for country in 0 ${country_list[@]}
	do
		openTimeList[$country]=0
		mergeCountList[$country]=0
	done

	local maxMergeCount=0
	
	while read serv zone country ip port name opentime mergetime mergecount
	do
		if [ ! -z "$opentime" ] && [ $opentime -gt 0 ];then
			if [ -z "${openTimeList[$country]}" ] || [ ${openTimeList[$country]} -eq 0 ] || [ ${openTimeList[$country]} -gt $opentime ];then
				openTimeList[$country]=$opentime		
			fi
		fi

		#各国最大的合区次数
		if [ ! -z "$mergecount" ] && [ $mergecount -gt 0 ];then
			if [ -z "${mergeCountList[$country]}" ] || [ ${mergeCountList[$country]} -lt $mergecount ];then
				mergeCountList[$country]=$mergecount		
			fi
		fi

		if [ ! -z "$mergecount" ] && [ $mergecount -gt 0 ];then
			if [ -z "$maxMergeCount" ] || [ $maxMergeCount -lt $mergecount ];then
				maxMergeCount=$mergecount		
			fi
		fi

		ZoneList_serv[$serv]=$zone
		ZoneNameList_serv[$serv]=$name
	done < ZoneList.temp.txt

#echo ${openTimeList[@]}
#	echo ${mergeCountList[@]}


	#未配置区号，则采用第一个区的区号
	if [ -z "${ZoneList_serv[0]}" ];then
		ZoneList_serv[0]=${ZoneList_serv[1]}
	fi
	if [ -z "${ZoneNameList_serv[0]}" ];then
		ZoneNameList_serv[0]=${ZoneNameList_serv[1]}
	fi

	echo -e "\t目标区设置为:IP=${IPList_db[0]} DB=${NameList_db[0]} PORT=${PortList_serv[0]} ZONE=${ZoneList_serv[0]} ZONENAME=${ZoneNameList_serv[0]}"


	let "maxMergeCount = $maxMergeCount + 1"

	#开启新服
	for country in 0 ${country_list[@]}
	do
		local selectOpenTime=0
		local selectMergeTime=0
		local selectMergeCount=0

		if [ ! -z "${OpenTimeList_countries[$country]}" ];then
			selectOpenTime=${OpenTimeList_countries[$country]}
		else
			selectOpenTime=${openTimeList[$country]}
		fi

		if [ ! -z "${MergeTimeList_countries[$country]}" ];then
			selectMergeTime=${MergeTimeList_countries[$country]}
		else
			selectMergeTime=$nowTime
		fi

		if [ ! -z "${MergeCountList_countries[$country]}" ];then
			selectMergeCount=${MergeCountList_countries[$country]}
		else
			selectMergeCount=$maxMergeCount
		fi

		#合区次数设置为最大合区次数+1
		sql="INSERT INTO ZONELIST(ZONE,IDX,NAME,IP,PORT,ZONEOPENTIME,ZONEMERGETIME,ZONEMERGECOUNT,INUSE) VALUES(${ZoneList_serv[0]},$country,'${ZoneNameList_serv[0]}','${IPList_serv[0]}',${PortList_serv[0]},$selectOpenTime,$selectMergeTime,$selectMergeCount,1) ON DUPLICATE KEY UPDATE NAME=IF(VALUES(NAME)='',NAME,VALUES(NAME)),ZONEOPENTIME=VALUES(ZONEOPENTIME),ZONEMERGETIME=VALUES(ZONEMERGETIME),ZONEMERGECOUNT=VALUES(ZONEMERGECOUNT)"

		mysql -u $DBUser -p$DBPasswd -h $IPCenter $DBCenter -e "$sql"

		if [ ! $? = 0 ];then
			echo -e "\t创建新子服($selectMergeCount):${ZoneList_serv[0]},$country,'${ZoneNameList_serv[0]}','${IPList_serv[0]}',${PortList_serv[0]},$selectOpenTime,$selectMergeTime,$selectMergeCount...[FAIL]"
		else
			echo -e "\t创建新子服($selectMergeCount):${ZoneList_serv[0]},$country,'${ZoneNameList_serv[0]}','${IPList_serv[0]}',${PortList_serv[0]},$selectOpenTime,$selectMergeTime,$selectMergeCount...[OK]"
		fi
	done


	#取出目标区的对外地址和端口
	mysql -u $DBUser -p$DBPasswd -h ${IPCenter} ${DBCenter} -e "SELECT FLATZONE.SID,FLATZONE.ZONE,FLATZONE.IDX,DOMAINNAME,DOMAINPORT FROM FLATZONE,ZONELIST WHERE FLATZONE.ZONE=ZONELIST.ZONE AND FLATZONE.IDX=ZONELIST.IDX AND ZONELIST.IP='${IPList_serv[0]}' and ZONELIST.PORT=${PortList_serv[0]}" > FlatZoneList.temp.txt
	
	if [ ! $? = 0 ];then
		echo -e "\t取得对外地址...[FAIL]"
	else
		echo -e "\t取得对外地址...[OK]"
	fi

	cat FlatZoneList.temp.txt;

	local domainList=()
	local portList=()
	while read sid zone country domain port
	do
		domainList[$country]=$domain
		portList[$country]=$port
	done<FlatZoneList.temp.txt


	#关闭旧服，并且重定向
	servIdx=1
	while [ $servIdx -le $sourceCount ]
	do
		#关闭不开放的内部区
		if [ "${IPList_serv[$servIdx]}" != "${IPList_serv[0]}" ] || [ "${PortList_serv[$servIdx]}" != "${PortList_serv[0]}" ];then
			mysql -u $DBUser -p$DBPasswd -h $IPCenter $DBCenter -e "update ZONELIST set INUSE=0 where IP='${IPList_serv[$servIdx]}' and PORT=${PortList_serv[$servIdx]};"	
			if [ ! $? = 0 ];then
				echo -e "\t内部区<关闭>${IPList_serv[$servIdx]}:${PortList_serv[$servIdx]}...[FAIL]"
			else
				echo -e "\t内部区<关闭>${IPList_serv[$servIdx]}:${PortList_serv[$servIdx]}...[OK]"
			fi
		else
				echo -e "\t内部区<保留>${IPList_serv[$servIdx]}:${PortList_serv[$servIdx]}...[OK]"
		fi

		for country in ${country_list[@]}
		do
			local idx=`expr $servIdx \* $country_num + $country`

			local dstCountry=${selectCountryies[$idx]}
	
			#mysql -u $DBUser -p$DBPasswd -h $IPCenter $DBCenter -Ne "SELECT SID,ZONE,IDX,DOMAINNAME,DOMAINPORT FROM where ZONE=${ZoneList_serv[$servIdx]}"  >> FlatZoneList.temp.txt

			local sids=`mysql -u $DBUser -p$DBPasswd -h $IPCenter $DBCenter -Ne "SELECT SID FROM FLATZONE where ZONE=${ZoneList_serv[$servIdx]} and IDX=$country"|xargs`

			mysql -u $DBUser -p$DBPasswd -h $IPCenter $DBCenter -e "update FLATZONE set ZONE=${ZoneList_serv[0]},IDX=$dstCountry,DOMAINNAME='${domainList[$dstCountry]}',DOMAINPORT=${portList[$dstCountry]} where ZONE=${ZoneList_serv[$servIdx]} and IDX=$country"

			if [ ! $? = 0 ];then
				echo -e "\t${servIdx}_$country (${sids[@]}) 重定向到 ${ZoneList_serv[0]}_$dstCountry:${domainList[$dstCountry]}:${portList[$dstCountry]} ...[FAIL]"
			else
				echo -e "\t${servIdx}_$country (${sids[@]}) 重定向到 ${ZoneList_serv[0]}_$dstCountry:${domainList[$dstCountry]}:${portList[$dstCountry]} ...[OK]"
			fi
		done


		let "servIdx = $servIdx + 1"
	done

	return 0
}

doModifyBootConfig()
{
	if [ "${bootDirs_serv[0]}" = "" ];then
		return 0
	fi

	configfile="${bootDirs_serv[0]}/config.xml"

	line=`grep -n "<SuperServer" $configfile 2> /dev/null | sed -n '1p' |awk -F: '{print $1}'`

	if [ -z $line ];then
		echo -e "\t配置文件不存在或者不正确...[FAIL]"
		return 0
	fi

	ret=(`mysql -u $DBUser -p$DBPasswd -h ${IPList_db[0]} ${NameList_db[0]} -Ne "select IP,PORT from SERVERLIST where ID=1"|xargs`)


	globalstart=(`grep -n "<global>" $configfile 2> /dev/null | sed -n '1p' |awk -F: '{print $1}'`)
	globalend=(`grep -n "</global>" $configfile 2> /dev/null | sed -n '1p' |awk -F: '{print $1}'`)

	quickPort=${ret[1]}
	let "quickPort = $quickPort - 1"
	
	sed -i "s/<superserver.*port.*<\/superserver>/<superserver port=\"${ret[1]}\" quickPort=\"$quickPort\">${ret[0]}<\/superserver>/" $configfile

	sed -i "$globalstart,$globalend s/\(mysql:\/\/.*\)@\(.*\):\(.*\)\/\(.*\)</\1@${IPList_db[0]}:\3\/${NameList_db[0]}</" $configfile

	sed -i "$line,$ s/\(mysql:\/\/.*\)@\(.*\):\(.*\)\/\(.*\)</\1@${IPList_db[0]}:\3\/${NameList_db[0]}</" $configfile

	if [ ! $? = 0 ];then
		echo -e "\t$configfile:修改为(${IPList_db[0]}:${NameList_db[0]})失败...[FAIL]"
	else
		echo -e "\t$configfile:修改为(${IPList_db[0]}:${NameList_db[0]})成功...[OK]"
	fi
}


#####################################################################################
echo -e "【文本配置读入】"
if loadConfig $1
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi

echo "【数据库检测】"
curDB=`mysql -u $DBUser -p$DBPasswd -h ${IPList_db[0]} -e "show databases like '${NameList_db[0]}'"|sed -n '2p'`
if [ ! $? = 0 ];then
	echo -e "\t合服数据库检测失败"
	exit 1
fi

if [ "$curDB" != "" ];then
	echo -e "\t合区目标数据库$curDB已存在。继续合区，将会造成该数据库清空...【警告】"
	echo -e -n "\t您是否继续?请输入(yes/no):"

	read line
	
	if [ "$line" != "yes" ];then
		echo "\t退出合并"
		exit 1
	fi
fi


if checkDatabase
then 
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi

echo -e "【数据库初始化】"
if initMergeDatabase
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi

echo -e "【设置地址端口】"
if doSetServIPAndPort
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi

:<<CLEAR
if false;then
echo "【设置开区时间】"
if doSetZoneTime
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi
fi
CLEAR

echo -e "【参数配置输出】"
if doPrint_config
then 
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi

echo "【重新合并联盟】"
if doMerge_Alliance
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi

echo "【重新合并军团】"
if doMerge_Legion
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi

echo -e "【合并玩家基本表】"
if doMerge_CharBase
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi

echo -e "【合并玩家离线数据表】"
if doMerge_OfflineData
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi


echo "【计算阵营战力排行】"
if calcCountryPower
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi

echo "【获取各区阵营属性】"
if calcCountryProps
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi

echo "【重新分配阵营】"
if doSelectCountry
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi

echo "【设定阵营属性】"
if doSetCountryProps
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
fi

echo "【阵营分配结果】"
if doPrint_result
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi


echo "【合并常规表】"
if doMerge_Simple
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
fi

echo "【各排行榜合并】"
if doMergeSort
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
fi

echo "【排行榜活动合并】"
if doMerge_LeaderboardAct
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
fi


echo "【SERVDATA合并】"
if doMerge_ServData
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
fi

echo "【合区完毕清理】"
if unInitMergeDatabase
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
	exit 1
fi

echo " 【修改启动配置】"
if doModifyBootConfig
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
fi


echo "【注册到中心服】"
if doRegToCenter
then
	echo -e "\t<OK>"
	echo "【合区完毕】已注册中心服。请随后热加载或者重启中心服!!!"
else
	echo -e "\t<FAIL>"
	echo "【恭喜你】未注册到中心服。请手动注册后，热加载或者重启所有中心服!!!"
fi

echo "请检查中心服FLATZONE中的ZONE、DOMAINNAME,DOMAINPORT是否修改为实际使用的内部区号以及对外域名和端口"
echo "如果内网版本:请修改config.ini将向某个区的连接地址端口改为:$domain:$port(注意:区号不用动)"

echo "【日志合并】"
if doMerge_Log
then
	echo -e "\t<OK>"
else
	echo -e "\t<FAIL>"
fi


