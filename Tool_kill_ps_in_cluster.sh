#!/bin/bash
#===================================
# README
# Prerequisites:
#	This script should be run on master machine
#
#===================================

cluster_host_name="cluster_hosts.txt"

if [ -z "$1" ]; then
	echo "Process name needed"
	exit
else
	echo "Process name is $1"
fi
process_name=$1

for slave in $(cat $cluster_host_name | grep yuan | awk '{print $2}'); do
	echo "Clearing $slave Process name: $process_name"
	for p_id in $(ssh hduser@$slave "ps aux" | grep $process_name | grep -v grep | grep -v $0 | awk '{print $2}'); do
		echo $p_id
		ssh hduser@$slave "sudo kill -9 $p_id"
	done
done
	
