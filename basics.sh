#!/bin/bash
#===================================
# README
# This file prepare the slave machines. It only runs on master machine
# This file is located at /usr/local/hadoop/scripts
# Prerequisites:
#	This script should be run before cluster_prepare_com.sh
#
# This script uses cluster_host_name file as a config file
# 		cluster_host_name is a hosts file, Note: it starts with a blank line
#		the name of master is vmaster, the names of slaves are vslaveXX, XX is the number of node
# Example:
#
# 	192.168.67.134	vmaster
#	192.168.67.135	vslave01
#	192.168.67.136	vslave02
#	192.168.67.137	vslave03
#===================================
cluster_host_name="vcluster_hosts.txt"


# Check master's hostname
if [ "vmaster" != $(cat /etc/hostname) ]; then
	sudo echo mn-yuan-master > /etc/hostname
	sudo shutdown -r 0
	exit 0
fi

# Flush hosts
hosts_name="/etc/hosts"
hosts_bak_name="/etc/hosts.bak"
if [ -e $hosts_bak_name ]; then
	sudo cat $hosts_bak_name | grep -v vmaster | grep -v vslave > $hosts_name
else
	sudo cp $hosts_name $hosts_bak_name
fi
sudo cat $cluster_host_name >> $hosts_name
sudo /etc/init.d/networking restart

#Flush ssh
sudo rm -f $HOME/.ssh/known_hosts
ssh-keygen -t rsa -P ""
for slave in $(cat $cluster_host_name | grep -v ^$ | grep -v ^# | awk '{print $2}'); do
	sshpass -p 'lhcwhu' ssh-copy-id -i $HOME/.ssh/id_rsa.pub hduser@$slave
done
echo "Key copy finished, set slaves' hostname"

for slave in $(cat $cluster_host_name | grep vslave | awk '{print $2}'); do
	echo "Setting $slave"
	# Sychronize time
	#ssh hduser@$slave "sudo ntpdate ntp.ubuntu.com"
	
	# Check hostname, if not the name we want, change it
	count=$(ssh -t hduser@$slave "hostname")
	if [ "$count" != "$slave" ]; then
		sshpass -p 'lhcwhu' ssh -t hduser@$slave "sudo echo $slave > /etc/hostname"
		sshpass -p 'lhcwhu' ssh -t hduser@$slave "sudo shutdown -r 0"
	fi

	echo "$slave Done"
done

#Check alive
echo Wait 20 seconds to check slaves
sleep 20
while [ 1 ]; do
	
	flag_down=0
	for slave in $(cat $cluster_host_name | grep vslave | awk '{print $2}'); do
		echo "checking $slave"
		count=$(ssh -t hduser@$slave "hostname")
		if [ "$count" != "$slave" ]; then
			echo "WARNING: $slave is still down. Current hostname is $count"
			flag_down=1
		fi
	done
	
	if [ $flag_down = 0 ]; then
		echo "Congratunations! All restarted."
		break
	fi
	sleep 2
done

