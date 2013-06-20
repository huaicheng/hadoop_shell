#!/bin/bash
#===================================
# README
# Prerequisites:
#	This script should be run on master machine
#
#===================================
use_s3=0

if [ -z "$copy_data" ]; then
	if [ 1 = $use_s3 ]; then
		copy_data=0
	else
		copy_data=1
	fi
fi

if [ -z "$format_hdfs" ]; then
	format_hdfs=1
fi

if [ -z "$flag_service" ]; then
	flag_service=1
fi


if [ -z "$tar_result" ]; then
	tar_result=1
fi

if [ 1 = $use_s3 ]; then
	hdfs_data_dir="s3n://free-tier-yuan/hadoop/input/simpleTest"
	hdfs_output_dir="s3n://free-tier-yuan/hadoop/results/simpleTest-$(date +%F_%H-%M-%S)"
else
	hdfs_data_dir="/user/hduser/input"
	hdfs_output_dir="/user/hduser/output"
fi


flag_monitor=1
run_task=1

hadoop_tmp_dir="/mnt/hadoop/tmp"

cluster_host_name="vcluster_hosts.txt"

master_name="vmaster"

hadoop_dir="/opt/hadoop"
script_dir="$hadoop_dir/scripts"
monitor_script_name="list_process.sh"
data_dir="/data/wiki"
output_dir="/tmp/yuan-output"

hadoop_task_output="task_output.txt"

result_dir_file="result-$(date +%F_%H-%M-%S)"
result_dir="$hadoop_dir/scripts/$result_dir_file"
mkdir $result_dir

# Stop services
if [ $flag_service = 1 ]; then
	echo "Stopping services"
	rm $hadoop_dir/logs/*.*
	# Stop first
	$hadoop_dir/bin/stop-all.sh
	echo "Stopping done"
fi

# Format hdfs first 
if [ $format_hdfs = 1 ]; then
	echo "Formating hdfs"
	
	#Remove all temp file first
	for slave in $(cat $cluster_host_name | grep yuan | awk '{print $2}'); do
		ssh hduser@$slave "sudo rm -rf $hadoop_tmp_dir"
		ssh hduser@$slave "sudo mkdir -p $hadoop_tmp_dir"
		ssh hduser@$slave "sudo chown -R hduser:hadoop $hadoop_tmp_dir"
	done
	
	$hadoop_dir/bin/hadoop namenode -format	
	echo "Formating done"
fi

# Start services
if [ $flag_service = 1 ]; then
	echo "Starting services"
	rm $hadoop_dir/logs/*.*
	$hadoop_dir/bin/start-all.sh
	echo "Sleep 10 second to wait service fully started"
	sleep 20
	echo "Starting done"
fi

# Copy data
if [ $copy_data = 1 ]; then
	echo "Copying data"
	$hadoop_dir/bin/hadoop dfs -rmr $hdfs_data_dir
	$hadoop_dir/bin/hadoop dfs -copyFromLocal $data_dir $hdfs_data_dir
	echo "Copying done"
fi

# Start monitoring
if [ $flag_monitor = 1 ]; then
	echo "Starting monitor"
	echo "Kill monitor procss first"
	./Tool_kill_ps_in_cluster.sh $monitor_script_name
	for slave in $(cat $cluster_host_name | grep yuan | awk '{print $2}'); do
		if [ "$slave" != "$master_name" ]; then
			echo "$slave"
			ssh hduser@$slave "rm $hadoop_dir/logs/*.*"
			scp $script_dir/$monitor_script_name hduser@$slave:$script_dir
		fi
		echo "ssh $slave"
		sh -c "ssh hduser@$slave \"chmod 755 $script_dir/$monitor_script_name; cd $script_dir; ./$monitor_script_name > mon-result-$slave.txt\"" &
	done
	echo "Starting monitor done"
fi



# Run task
if [ $run_task = 1 ]; then
	echo "Runing task"
	$hadoop_dir/bin/hadoop dfs -rmr $hdfs_output_dir
	$hadoop_dir/bin/hadoop dfs -ls $hdfs_data_dir
	sh -c "$hadoop_dir/bin/hadoop jar $hadoop_dir/hadoop*examples*.jar wordcount $hdfs_data_dir $hdfs_output_dir" > $result_dir/$hadoop_task_output 2>&1
	#sleep 10
	echo "Task done"
fi


# Stop monitoring
if [ $flag_monitor = 1 ]; then
	echo "Ending monitor"
	./Tool_kill_ps_in_cluster.sh $monitor_script_name
	

	# Gather results
	monitor_result_dir="$result_dir/monitor-results"
	log_result_dir="$result_dir/logs"
	mkdir $monitor_result_dir
	mkdir $log_result_dir
	monitor_total_result="monitor-result.txt"
	rm $result_dir/$monitor_total_result
	for slave in $(cat $cluster_host_name | grep yuan | awk '{print $2}'); do
		scp hduser@$slave:$script_dir/mon-result-$slave.txt $monitor_result_dir
		cat $monitor_result_dir/mon-result-$slave.txt >> $result_dir/$monitor_total_result
		ssh hduser@$slave "rm $script_dir/mon-result-$slave.txt"
		
		mkdir $log_result_dir/logs-$slave
		scp hduser@$slave:$hadoop_dir/logs/*.* $log_result_dir/logs-$slave
	done
	
	mkdir $result_dir/conf 
	cp $hadoop_dir/conf/* $result_dir/conf
	#Compress the result for downloading
	if [ 1 = $tar_result ]; then
		tar -zcvf $result_dir_file.tar.gz $result_dir
	fi
	echo "Ending monitor done"
fi

echo "Job done"
