README:
This file describes how to use this tool.
The description of config file and script file is at the end of this file.


====================
Prerequisite: 
	1) Build a single node cluster based on tutorial at http://www.michael-noll.com/tutorials/running-hadoop-on-ubuntu-linux-single-node-cluster/
	2) Save this VM as an virtual image (BasicNode) because we will use this image as master and slave nodes.
	3) For master node, "sshpass" is required.

====================
Example steps:
We will build a cluster with 1 master and 4 slaves (all types are small)for example.	
 	1) Create 5 small instances using BasicNode image;
	2) You choose one instanse as master, and write "cluster_hosts.txt". 
	3) Copy the scripts files (files, not folder) to master node, the location is /usr/local/hadoop/scripts
	4) Run "all_in_one.sh" or run "basics.sh, cluster_prepare_com.sh, run_hadoop_task.sh" in turn.
 	
====================
Common problem shooting:
	1)	Inter connection problem. 
		Nodes may have problems with inter connection. Check they are in the same Security Groups. Or terminate it and re-create one.
	
====================
File description:

--------------------
Configuration file:
The cluster configuration file is "cluster_hosts.txt". The format is: For every line, we specify the private IP and hostnames. 
The first line is for master node. The hostname is default "mn-yuan-master". 
The other lines are for slave nodes. The format is "mn-yuan-slaveXX".
For example:
10.72.55.244	mn-yuan-master
10.151.89.13	mn-yuan-slave01
10.151.22.106	mn-yuan-slave02
10.151.53.132	mn-yuan-slave03
10.151.86.126	mn-yuan-slave04

--------------------
basics.sh
Basic configuration settings for the cluster. It set hostname, SSH, network and synchronize time.
After running this file, you can visit every node in this cluster by hostname "ssh mn-yuan-xxxx" at any node in cluster.

--------------------
cluster_prepare_com.sh
Setting Hadoop. It generates config files for Hadoop.
All settings are default. You can change them as you wish. 
For example: 
tasktracker_map_tasks_maximum specifies the max in-parallel map task number on a slave.
tasktracker_red_tasks_maximum specifies the max in-parallel reduce task number on a slave.

--------------------
run_hadoop_task.sh
Run a MapReduce job. The default input data location is specified by variable "data_dir". 
Steps:
	1) 	Build a HDFS on top of slave node and copy input data into HDFS;
	2)	Start Hadoop services;
	3)	Copy monitoring script	"list_process.sh" to every slave node; You can use yours.
	4)	Run the job, the job output is redirected to "task_output.txt";
	5)	Stop monitoring and collect monitoring result.
	
--------------------
Tool_kill_ps_in_cluster.sh
A subroutine script for clearing monitoring environment. It kills all monitoring process in the cluster.

 