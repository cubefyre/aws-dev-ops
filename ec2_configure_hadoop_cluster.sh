#!/bin/bash
# Description - Helper script to launch a n-node hadoop cluster without using blueprint.
# This script will login to the remote machine, update linux packages, mount drives,
# download latest rev of ambari, install ambari on one machine and prepare rest of the machienes for joining 
# the cluster.  Note that you have to login to Ambari to setup the cluster.  
# Check out the single-node setup which leverages blueprint to setup the cluster without requiring any manual setup.
# Author - Jitender Aswani
# May 2015
# Organization - SparklineData

# break instances into instance array
instanceIDs=($instanceIDs)

MACHINES=$(aws ec2 describe-instances \
        --instance-ids $instanceIDs \
        --query 'Reservations[*].Instances[0].PublicDnsName' \
        --output text)

COUNTER=1
for machine in $MACHINES
do
    echo "Setting up $machine"
    SSH_PREFIX="ssh -i $keyName.pem -o StrictHostKeyChecking=no root@$machine"
    scp -i demo.pem -o StrictHostKeyChecking=no demo.pem root@$machine:
    $SSH_PREFIX 'mv demo.pem /root/.ssh/id_rsa'
    $SSH_PREFIX 'yum -y update'
    $SSH_PREFIX 'yum -y install sudo'
    $SSH_PREFIX 'mkdir /mnt/data'
    $SSH_PREFIX 'mount /dev/xvdf /mnt/data'
    $SSH_PREFIX 'echo /dev/xvdf /mnt/data      ext4    defaults        1 2 >> /etc/fstab'
    $SSH_PREFIX 'mkdir /mnt/data1'
    $SSH_PREFIX 'mkdir /mnt/data2'
    $SSH_PREFIX 'mkdir /mnt/data3'
    $SSH_PREFIX 'mount /dev/xvdg /mnt/data1'
    $SSH_PREFIX 'mount /dev/xvdh /mnt/data2'
    $SSH_PREFIX 'mount /dev/xvdi /mnt/data3'
    $SSH_PREFIX 'echo /dev/xvdg /mnt/data1      ext4    defaults        1 2 >> /etc/fstab'
    $SSH_PREFIX 'echo /dev/xvdh /mnt/data2      ext4    defaults        1 2 >> /etc/fstab'
    $SSH_PREFIX 'echo /dev/xvdi /mnt/data3      ext4    defaults        1 2 >> /etc/fstab'
    $SSH_PREFIX 'mount -a'
    $SSH_PREFIX 'chkconfig ntpd on'
    $SSH_PREFIX 'chkconfig iptables off'
    $SSH_PREFIX '/etc/init.d/iptables stop'
    $SSH_PREFIX 'service ntpd start'

    if [ $COUNTER -eq 1  ]; then
        echo "Setting up $machine as Ambari Server..."
        $SSH_PREFIX 'yum -y install sudo'
        $SSH_PREFIX 'wget -nv http://public-repo-1.hortonworks.com/ambari/centos6/2.x/updates/2.0.0/ambari.repo'
        $SSH_PREFIX 'cp ambari.repo /etc/yum.repos.d'
        $SSH_PREFIX 'yum -y install ambari-server'
        $SSH_PREFIX 'ambari-server setup -s -v'
        $SSH_PREFIX 'ambari-server start'
        aws ec2 create-tags --resources ${instanceIDs[1]}  --tags 'Key="Name",Value=cl-ambari'
    else
        aws ec2 create-tags --resources ${instanceIDs[1]}  --tags 'Key="Name",Value=cl-m$COUNTER'
    fi

    echo "Setup complete for $machine"
    let COUNTER=COUNTER+1
done