#!/bin/bash
# =====================================================================================
# Author: coperd, <lhcwhu@gmail.com>
# Date: 2013-6-17
# this script executes in one of the physical host to copy the base image and XML files 
# to the other physical hosts
# =====================================================================================

# the master host is the initial storage server where the base files lie in
PWD=`pwd`
#MASTER_HOST=192.168.0.190
vm_per_host=4
hostname=`hostname`

# VM specific settings
VM_NAME=$HOSTNAME
VM_DESC=$HOSTNAME
# memory unit : MiB
VM_RAM=512
VM_VCPUS=2
# all the KVM image files are put in the $HOME/vcluster directory
vcluster_dir=$HOME/vcluster

if [ ! -d ${vcluster_dir} ]
then
    mkdir ${vcluster_dir}
else
    #rm -rf vcluster/*
    echo "vcluster directory already exists"
fi

# copy operations in the localhost
cp base/base64.tar.bz2 $HOME/vcluster/
sudo cp base/base.xml /etc/libvirt/qemu/
sudo mv /etc/libvirt/qemu/base.xml /etc/libvirt/qemu/${hostname}_0.xml
cd $HOME/vcluster
tar xjf base64.tar.bz2 
mv base64.img ${hostname}_0.img
for ((i = 1; i < vm_per_host; i++))
do
    cp ${hostname}_0.img ${hostname}_$i.img 
    cp /etc/libvirt/qemu/${hostname}_0.xml /etc/libvirt/qemu/${hostname}_$i.xml
done
echo "localhost base file copying work is done"

# transfer the base image and XML file, then decompress it
# the scp doesn't work under ssh environment, enable the hosts with nopasswd login
# each other. That's A<-->B(-- means one can login without passwd)

for i in $(cat pcluster_hosts.txt | grep -v ${hostname} | grep -v ^$ | grep -v ^# | awk {'print $1'})
do
    ssh hduser@$i /bin/bash << __EOF__ 
        if [ ! -d $vcluster_dir ]
        then
            mkdir $vcluster_dir
        done
    __EOF__
    # put the base directory and the script file in the same directory
    scp base/base64.tar.bz2 hduser@$i:~/vcluster
    scp base/base.xml hduser@$i:~/
    ssh hduser@$i /bin/bash << __EOF__
        sudo cp base.xml /etc/libvirt/qemu
        cd /etc/libvirt/qemu
        for ((j = 0; j < $vm_per_host; j++))
        do
            sudo cp base.xml `hostname`_$i.xml
        done
    __EOF__
done

# modify those XML files
if [ ! -e /usr/bin/kvm ]
then
    sudo ln -s `which qemu-system_x86_64` /usr/bin/kvm
fi

for i in `ls /etc/libvirt/qemu | grep xml`
do
    sed -i "9s/base/${VM_NAME}/" $i  # 9: <name>
    UUID_RAN=`echo "$RANDOM % 100 + 100" | bc`
    sed -i "10s/XXX/${UUID_RAN}/" $i  # 10: <uuid>
    sed -i "11s/base/${VM_DESC}/" $i  # 11: <description>
    sed -i "12,13s/base/${VM_RAM}/" $i # 12,13: <ram>
    sed -i "14s/base/${VM_VCPUS}/" $i  # 14: <vcpu>
    sed -i "32s/base/`echo $i | sed 's/xml/img/'`/gg" $i  # 32: <source file>
    MAC_RAN=`echo "$RANDOM % 90 + 10" | bc`
    sed -i "49s/XX/${MAC_RAN}/" $i  # 49: <macaddr>
done
echo "All XML configuratino files done!"

# according to the XML files to define the KVM virtual machines
for ((i = 0; i < $vm_per_host; i++))
do
    virsh define /etc/libvirt/qemu/$hostname_$i.xml # how to handle the errors if there are some
done
