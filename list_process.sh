#!/bin/bash

index=0
THISHOST=$(hostname)
USERNAME=$(id -un)



function GetCpu 
{ 
	CpuValue=`ps -p $1 -o pcpu |grep -v CPU | awk '{print $1}' ` 
	if [ "$CpuValue" = "" ]
	then
		CpuValue=0
	fi
    echo $CpuValue 
} 

function GetRSS
{
    MEMUsage=`ps -o rss -p $1|grep -v RSS` 
	(( MEMUsage /= 1000)) 
    echo $MEMUsage 
}

function GetVSZ 
{ 
    MEMUsage=`ps -o vsz -p $1|grep -v VSZ` 
	(( MEMUsage /= 1000)) 
    echo $MEMUsage 
} 

GetBandwidth_l_last_rx=1
GetBandwidth_l_last_tx=1
function GetBandwidth 
{
	echo Nothing
}

#=====================================================
#----------------------------
# Build relation between name and pid
#----------------------------
HADOOP_name_matched=0
HADOOP_NameNode_pid=0
HADOOP_S_NameNode_pid=0
HADOOP_DataNode_pid=0
HADOOP_JobTracker_pid=0
HADOOP_TaskTracker_pid=0
HADOOP_NameNode_name="NameNode"
HADOOP_S_NameNode_name="SecondaryNameNode"
HADOOP_DataNode_name="DataNode"
HADOOP_JobTracker_name="JobTracker"
HADOOP_TaskTracker_name="TaskTracker"

#----------------------------
#Match java process name
#----------------------------
function MatchName
{
	PID=$1
	ret="Unknown"
	if [ "$PID" = "$HADOOP_NameNode_pid" ]; then
		ret=$HADOOP_NameNode_name
	fi
	if [ "$PID" = "$HADOOP_S_NameNode_pid" ]; then
		ret=$HADOOP_S_NameNode_name
	fi
	if [ "$PID" = "$HADOOP_DataNode_pid" ]; then
		ret=$HADOOP_DataNode_name
	fi
	if [ "$PID" = "$HADOOP_JobTracker_pid" ]; then
		ret=$HADOOP_JobTracker_name
	fi
	if [ "$PID" = "$HADOOP_TaskTracker_pid" ]; then
		ret=$HADOOP_TaskTracker_name
	fi
	echo $ret
}

###################################################
# Main process

flush_index=0
ow=0
rx_byte=0
tx_byte=0

# Build java process name
for i in $(jps); do
	if   [[ $i =~ ^[0-9]+$ ]] 
	then
		p_id=$i
	else
		p_name=$i
	fi
	let "index+=1"
	let "index=$index % 2"
	if [ $index = 0 ]
	then
		if [ "$p_name" != "Jps" ]
		then
			
			if [ "$p_name" = "$HADOOP_NameNode_name" ]; then
				export HADOOP_NameNode_pid=`expr $p_id + 0`
				HADOOP_name_matched=1
			fi
			if [ "$p_name" = "$HADOOP_S_NameNode_name" ]; then
				export HADOOP_S_NameNode_pid=`expr $p_id + 0`
				HADOOP_name_matched=1
			fi
			if [ "$p_name" = "$HADOOP_DataNode_name" ]; then
				export HADOOP_DataNode_pid=`expr $p_id + 0`
				HADOOP_name_matched=1
			fi
			if [ "$p_name" = "$HADOOP_JobTracker_name" ]; then
				export HADOOP_JobTracker_pid=`expr $p_id + 0`
				HADOOP_name_matched=1
			fi		
			if [ "$p_name" = "$HADOOP_TaskTracker_name" ]; then
				export HADOOP_TaskTracker_pid=`expr $p_id + 0`
				HADOOP_name_matched=1
			fi
		fi
	fi
done
#------------------------

while [ 1 ]; do
	sleep 5

	let "flush_index+=1"
	last_ow=$ow
	ow=$(date +"%s")
	tmp_file="tmp.txt"

	last_rx_byte=$rx_byte
	last_tx_byte=$tx_byte
	ifconfig eth0 > $tmp_file
	rx_byte=`cat $tmp_file |grep "RX bytes" | awk '{print $2}' |grep -o "[0-9]*"`
	tx_byte=`cat $tmp_file |grep "RX bytes" | awk '{print $6}' |grep -o "[0-9]*"`
	if [ -z $rx_byte ]
	then
		ifconfig eth0 > $tmp_file
		rx_byte=`cat $tmp_file |grep "RX bytes" | awk '{print $2}' |grep -o "[0-9]*"`
	fi
	
	if [ -z $tx_byte ]
	then
		ifconfig eth0 > $tmp_file
		tx_byte=`cat $tmp_file |grep "RX bytes" | awk '{print $6}' |grep -o "[0-9]*"`
	fi
	
	last_r_sector=$r_sector
	last_w_sector=$w_sector
	vmstat -D > $tmp_file
	r_sector=`cat $tmp_file |grep "read sectors" | awk '{print $1}'`
	w_sector=`cat $tmp_file |grep "written sectors" | awk '{print $1}'`
	if [ -z $r_sector ]
	then
		vmstat -D > $tmp_file
		r_sector=`cat $tmp_file |grep "read sectors" | awk '{print $1}'`
	fi	
	if [ -z $w_sector ]
	then
		vmstat -D > $tmp_file
		w_sector=`cat $tmp_file |grep "written sectors" | awk '{print $1}'`
	fi	
	
	#rm $tmp_file
	if [ $flush_index = 1 ]
	then
		continue
	fi
	
	
	#Collect the total bandwidth data
	p_name='Total'
	p_id=0
	ps -Ao pid,%cpu,vsz,rss | grep -v VSZ> $tmp_file
	cpu_usage=$(cat $tmp_file | awk '{sum +=$2}; END {print sum}')
	mem_vsz=$(cat $tmp_file | awk '{sum +=$3}; END {print sum}')
	mem_rss=$(cat $tmp_file | awk '{sum +=$4}; END {print sum}')
	#rm $tmp_file
	let "time_past=$ow-$last_ow"
	let "r_bandwidth=$rx_byte-$last_rx_byte"
	let "r_bandwidth=$r_bandwidth/$time_past"
	let "t_bandwidth=$tx_byte-$last_tx_byte"
	let "t_bandwidth=$t_bandwidth/$time_past"
	
	# Collect disk io data (KB/s)
	let "r_sector_rate=$r_sector-$last_r_sector"
	let "r_sector_rate=$r_sector_rate/$time_past"
	let "w_sector_rate=$w_sector-$last_w_sector"
	let "w_sector_rate=$w_sector_rate/$time_past"
	let "disk_r_rate=$r_sector_rate*512"
	let "disk_w_rate=$w_sector_rate*512"
	
	echo $ow $flush_index $THISHOST $USERNAME $p_name $p_id  $cpu_usage $mem_vsz $mem_rss $r_bandwidth $t_bandwidth $disk_r_rate $disk_w_rate
	
	#Collect the process data
	for p_id in $(ps aux | grep java | grep -v grep | awk '{print $2}'); do
		p_name=`MatchName $p_id`
		index=0
		for i in $( cat $tmp_file | grep $p_id); do
			# TODO: cpu, vsz or rss result may equal to pid
			if [ $index = 1 ]; then
				cpu_usage=$i
			fi
			if [ $index = 2 ]; then
				mem_vsz=$i
			fi
			if [ $index = 3 ]; then
				mem_rss=$i
			fi
			let "index+=1"
		done
		
		r_bandwidth=0
		t_bandwidth=0
		disk_r_rate=0
		disk_w_rate=0	
		echo $ow $flush_index $THISHOST $USERNAME $p_name $p_id  $cpu_usage $mem_vsz $mem_rss $r_bandwidth $t_bandwidth $disk_r_rate $disk_w_rate
	done
		
done	
#Main process ends
###########################################################