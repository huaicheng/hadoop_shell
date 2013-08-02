#!/bin/bash
#===================================
# README
# This script sets the preparations for the hadoop installation process, and it includes setting
# the master and slave nodes's hostname and enables no password ssh login from the master node,
# when this script is done successfully, hadoop can be installed using the "cluster_prepare_com.sh.
# Prerequisites:
#	This script should be run before cluster_prepare_com.sh
#
# This script uses cluster_host_name file as a config file
# 		cluster_host_name is a hosts file, Note: Blank lines are omitted, and lines beginning with
# "#" is a comment line which won't be used.
#		the name of master is vmaster, the names of slaves are vslaveXX, XX is the number of node
# Example:
#
# 	192.168.0.145	vmaster
#	192.168.0.146	vslave01
#	192.168.0.147	vslave02
#	192.168.0.148	vslave03
#===================================

cluster_host_name="vcluster_hosts.txt"

# Check master's hostname
if [ "vmaster" != $(cat /etc/hostname) ]; then
	sudo sh -c "echo vmaster > /etc/hostname"
    if [ "X"$(cat /etc/hosts | grep "127.0.0.1" | grep "vmaster") = "X" ]; then
        sudo sed -i 's/127.0.0.1/127.0.0.1 vmaster/g' /etc/hosts
    fi
    echo "Now the machine will restart, please re-run the script after reboot..."
	sudo shutdown -r 0
	exit 0
fi

# Flush hosts
hosts_name="/etc/hosts"
hosts_bak_name="/etc/hosts.bak"
if [ -e $hosts_bak_name ]; then
	sudo sh -c "cat $hosts_bak_name | grep -v vmaster | grep -v vslave > $hosts_name"
    sudo sh -c "echo '127.0.0.1 localhost vmaster' >> $hosts_name"
else
	sudo cp $hosts_name $hosts_bak_name
fi
sudo sh -c "cat $cluster_host_name >> $hosts_name"
sudo /etc/init.d/networking restart

#Flush ssh
#mv $HOME/.ssh $HOME/.ssh.`date +%F`
rm -rf $HOME/.ssh
ssh-keygen -t rsa -P ""

cat > $HOME/.ssh/config << __EOF__
StrictHostKeyChecking no
UserKnownHostsFile=/dev/null
__EOF__

for slave in $(cat $cluster_host_name | grep -v ^$ | grep -v ^# | awk '{print $2}'); do
	sshpass -p'lhcwhu' ssh-copy-id -i $HOME/.ssh/id_rsa.pub hduser@$slave
done
echo "Key copy finished, set slaves' hostname"

for slave in $(cat $cluster_host_name | grep vslave | awk '{print $2}'); do
	echo "Setting $slave"
	# Sychronize time
	#ssh hduser@$slave "sudo ntpdate ntp.ubuntu.com"
	
	# Check hostname, if not the name we want, change it
	count=$(ssh -t hduser@$slave "hostname")
	if [ "$count" != "$slave" ]; then
		ssh -t hduser@$slave "sudo sh -c \"echo $slave > /etc/hostname\""
        ss="sudo sed -i \"s/127.0.0.1/127.0.0.1 $slave/g\" /etc/hosts"
        ssh -t hduser@$slave "$ss" 
        ssh -t hduser@$slave "sudo shutdown -r now"
	fi

	echo "$slave Done"
done

#Check alive
echo "Wait 20 seconds to check slaves"
sleep 20
while [ 1 ]; do
	
	flag_down=0
	for slave in $(cat $cluster_host_name | grep vslave | awk '{print $2}'); do
		echo "checking $slave"
        ping -c 1 $slave >/dev/null 2>&1
        if [ $? != 0 ]; then
			echo "WARNING: $slave is still down."
			flag_down=1
		fi
	done
	
	if [ $flag_down = 0 ]; then
		echo "Congratunations! All restarted."
		break
	fi
	sleep 2
done

