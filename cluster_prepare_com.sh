#!/bin/bash
#===================================
# README
# This script is followed by the tutorial at http://www.michael-noll.com/tutorials/running-hadoop-on-ubuntu-linux-multi-node-cluster/
# The prerequisites are same, this file is located at /usr/local/hadoop/scripts
#
# This script uses cluster_host_name file as a config file
# 		cluster_host_name is a hosts file, Note: it starts with a blank line
#		the name of master is mn-yuan-master, the names of slaves are vslaveXX, XX is the number of node
# Example:
#
# 	192.168.67.134	vmaster
#	192.168.67.135	vslave01
#	192.168.67.136	vslave02
#	192.168.67.137	vslave03
#===================================

cluster_host_name="vcluster_hosts.txt"

hadoop_tmp_dir="/mnt/hadoop/tmp"

tasktracker_map_tasks_maximum=2
tasktracker_red_tasks_maximum=1
slave_num=`cat $cluster_host_name | grep vslave | awk '{print $2}' | wc -l`
let "reduce_task_num=$tasktracker_red_tasks_maximum*$slave_num"
dfs_replication=1

function flush_core_site
{
	core_file_name="../conf/core-site.xml"
	if [ -e $core_file_name ]; then
		rm $core_file_name
	fi
	cat >> $core_file_name << _EOF_
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!-- Put site-specific property overrides in this file. -->
<configuration>
<!-- In: conf/core-site.xml -->
<property><name>hadoop.tmp.dir</name><value>$hadoop_tmp_dir</value></property> 
<property><name>fs.default.name</name><value>hdfs://vmaster:54310</value></property>
</configuration>

_EOF_
	
}

function flush_mapred_site
{
	mapred_file_name="../conf/mapred-site.xml"
	if [ -e $mapred_file_name ]; then
		rm $mapred_file_name
	fi
	cat >> $mapred_file_name << _EOF_
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!-- Put site-specific property overrides in this file. -->
<configuration>
<!-- In: conf/mapred-site.xml -->
<property><name>mapred.job.tracker</name><value>vmaster:54311</value></property>
<property><name>mapred.tasktracker.map.tasks.maximum</name><value>$tasktracker_map_tasks_maximum</value></property>
<property><name>mapred.tasktracker.reduce.tasks.maximum</name><value>$tasktracker_red_tasks_maximum</value></property>
<property><name>mapred.reduce.tasks</name><value>$reduce_task_num</value></property>
</configuration>

_EOF_
	
}

function flush_hdfd_site
{
	hdfd_file_name="../conf/hdfd-site.xml"
	if [ -e $hdfd_file_name ]; then
		rm $hdfd_file_name
	fi
	cat >> $hdfd_file_name << _EOF_
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!-- Put site-specific property overrides in this file. -->
<configuration>
<!-- In: conf/hdfs-site.xml -->
<property><name>dfs.replication</name><value>$dfs_replication</value></property>
</configuration>

_EOF_
	
}

#This function requires interactive


###################################################
# Main process


# Flush configuration
$(flush_core_site)
$(flush_mapred_site)
$(flush_hdfd_site)


# -------------------
# For master
master_ip=`cat $cluster_host_name | grep mn-yuan-master | awk '{print $1}'`
current_ip=`sudo ifconfig eth0 | grep 'inet ' | cut -d: -f2 | awk '{print $1}'`
master_conf_fname="../conf/master"
slaves_conf_fname="../conf/slaves"
if [ "$master_ip" = "$current_ip" ]; then
	#Master set
	echo "Setting mn-yuan-master"
	echo vmaster > $master_conf_fname
	cat $cluster_host_name | grep vslave | awk '{print $2}' > $slaves_conf_fname
	
	# Prepare the slaves
	script_dir="/usr/local/hadoop/scripts"
	script_name="cluster_prepare_com.sh"	
	for slave in $(cat $cluster_host_name | grep slave | awk '{print $2}'); do
		# Copy this script and $cluster_host_name file to /usr/local/hadoop/scripts of slaves
		# Run this script on slave machines
		echo "Preparing $slave"
		echo "Copy files to $slave"
		ssh hduser@$slave "rm -rf $script_dir; mkdir $script_dir;"
		scp $script_dir/cluster*.* hduser@$slave:$script_dir
		ssh hduser@$slave "chmod 755 $script_dir/$script_name; cd $script_dir; ./$script_name"
		echo "Done at $slave"
	done
else
	# Slave set, 
	echo "Setting $(cat /etc/hostname)"
	
	# Delete master-only files
	rm $master_conf_fname $slaves_conf_fname
	
	# Flush hosts
	hosts_name="/etc/hosts"
	hosts_bak_name="/etc/hosts.bak"
	if [ -e $hosts_bak_name ]; then
		sudo sh -c "cat $hosts_bak_name | grep -v yuan > $hosts_name"
	else
		sudo cp $hosts_name $hosts_bak_name
	fi
	sudo sh -c "cat $cluster_host_name >> $hosts_name"
	sudo /etc/init.d/networking restart
fi

# Main process ends
###########################################################
