#!/bin/bash
#===================================
# README
# This script is followed by the tutorial at http://www.michael-noll.com/tutorials/running-hadoop-on-ubuntu-linux-multi-node-cluster/
# This script uses vcluster_host_name file as a config file
# 		vcluster_host_name is a hosts file, Note: Blank lines are omitted.
#		the name of master is vmaster, the names of slaves are vslaveXX, XX is the number of node
# Example:
#
# 	192.168.0.145	vmaster
#	192.168.0.146	vslave01
#	192.168.0.147	vslave02
#	192.168.0.148	vslave03
#===================================

cluster_host_name="vcluster_hosts.txt"
HADOOP=$HOME/hadoop

#core-site.xml
fs_default_name="hdfs://vmaster:54310"
hadoop_tmp_dir="$HADOOP/MR/tmp"

#hdfs-site.xml
dfs_name_dir="$HADOOP/MR/name"
dfs_data_dir="$HADOOP/MR/data"
dfs_replication=1

#mapred-site.xml
mapred_job_tracker="vmaster:54311"
mapred_local_dir="$HADOOP/MR/local"
mapred_system_dir="$HADOOP/MR/system"
tasktracker_map_tasks_maximum=2
tasktracker_red_tasks_maximum=1
slave_num=`cat $cluster_host_name | grep vslave | awk '{print $2}' | wc -l`
let "reduce_task_num=$tasktracker_red_tasks_maximum*$slave_num"

flush_core_site ()
{
	core_file_name="$HADOOP/conf/core-site.xml"
	if [ -e $core_file_name ]; then
		rm $core_file_name
	fi
	cat >> $core_file_name << __EOF__
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!-- Put site-specific property overrides in this file. -->
<configuration>
<!-- In: conf/core-site.xml -->
<property><name>hadoop.tmp.dir</name><value>$hadoop_tmp_dir</value></property> 
<property><name>fs.default.name</name><value>$fs_default_name</value></property>
</configuration>

__EOF__
}

flush_mapred_site ()
{
	mapred_file_name="$HADOOP/conf/mapred-site.xml"
	if [ -e $mapred_file_name ]; then
		rm $mapred_file_name
	fi
	cat >> $mapred_file_name << __EOF__
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!-- Put site-specific property overrides in this file. -->
<configuration>
<!-- In: conf/mapred-site.xml -->
<property><name>mapred.job.tracker</name><value>$mapred_job_tracker</value></property>
<property><name>mapred.tasktracker.map.tasks.maximum</name><value>$tasktracker_map_tasks_maximum</value></property>
<property><name>mapred.tasktracker.reduce.tasks.maximum</name><value>$tasktracker_red_tasks_maximum</value></property>
<property><name>mapred.reduce.tasks</name><value>$reduce_task_num</value></property>
<property><name>mapred.local.dir</name><value>$mapred_local_dir</value></property>
<property><name>mapred.system.dir</name><value>$mapred_system_dir</value></property>
</configuration>

__EOF__
}

flush_hdfs_site ()
{
	hdfd_file_name="$HADOOP/conf/hdfs-site.xml"
	if [ -e $hdfd_file_name ]; then
		rm $hdfd_file_name
	fi
	cat >> $hdfd_file_name << __EOF__
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<!-- Put site-specific property overrides in this file. -->
<configuration>
<!-- In: conf/hdfs-site.xml -->
<property><name>dfs.replication</name><value>$dfs_replication</value></property>
<property><name>dfs.name.dir</name><value>$dfs_name_dir</value></property>
<property><name>dfs.data</name><value>$dfs_data_dir</value></property>
</configuration>

__EOF__
}

#This function requires interactive


###################################################
# Main process


# Flush configuration
flush_core_site
flush_mapred_site
flush_hdfs_site


# -------------------
# For master
master_ip=`cat $cluster_host_name | grep vmaster | awk '{print $1}'`
current_ip=`sudo ifconfig eth0 | grep 'inet ' | cut -d: -f2 | awk '{print $1}'` # what if bridge ?
master_conf_fname="$HADOOP/conf/masters"
slaves_conf_fname="$HADOOP/conf/slaves"
if [ "$master_ip" = "$current_ip" ]; then
	#Master set
	echo "Setting vmaster"
	echo "vmaster" > $master_conf_fname
	cat $cluster_host_name | grep vslave | awk '{print $2}' > $slaves_conf_fname
fi

cd ~
tar czf hadoop.tar.gz hadoop*
cd -
for slave in $(cat $cluster_host_name | grep vslave | awk '{print $2}'); do
    #ssh -t hduser@$slave "sudo chmod 775 /opt"
    ssh -t hduser@$slave "rm -rf hadoop*"
    scp ~/hadoop.tar.gz hduser@$slave:~
    ssh -t hduser@$slave "cd ~; tar xzvf hadoop.tar.gz; rm -f hadoop.tar.gz"
done
echo "hadoop installation completed!"
	
# Main process ends
###########################################################
