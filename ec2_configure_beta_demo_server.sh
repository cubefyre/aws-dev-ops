#!/bin/bash
# Description - Helper script to launch sparkline beta demo
# This script will login to the remote machine, update linux packages, install nginx, aws cli, 
# Java, Scala, Spark etc.  Will copy the package from local machine to remote machine. 
# It will then start desired beta app.
# Author - Jitender Aswani
# May 2015
# Organization - SparklineData

echo "Setting up $instanceIDs"

if [ "$machine" != "" ]    
then
	# assign elastic IP
	echo "Elastic IP is: $machine Assigning to the instance"
	aws ec2 associate-address --instance-id ${instanceIDs} --public-ip $machine
else
	# get public dns
	echo "Elastic ip not set, getting public DNS"
	machine=$(aws ec2 describe-instances \
	        --instance-ids $instanceIDs \
	        --query 'Reservations[*].Instances[0].PublicDnsName' \
	        --output text)
	echo "Public DNSs is: $machine"
	echo "dns='$machine'" >> "$propsFile"
fi

# aws tag assignment
aws ec2 create-tags --resources ${instanceIDs}  --tags "Key='Name',Value=$instanceName"

privateDns=$(aws ec2 describe-instances \
    --instance-ids $instanceIDs \
    --query 'Reservations[*].Instances[0].PrivateDnsName' \
    --output text)
echo "Private DNS is : $privateDns"
echo "privateDns='$privateDns'" >> "$propsFile"
sparkMaster=$(echo $privateDns | sed 's/\(ip-[0-9]*-[0-9]*-[0-9]*-[0-9]*\)\.ec2\.internal/\1/')


# setup SSH and SCP commands
SSH_PREFIX="ssh -i $keyName.pem -o StrictHostKeyChecking=no root@$machine"
SCP_PREFIX="scp -i $keyName.pem -o StrictHostKeyChecking=no "
SCP_POSTFIX=" root@$machine:"

# login and update the machine, mount few drives
$SSH_PREFIX 'mkdir /mnt/data1 && mount /dev/xvdf /mnt/data1 && echo /dev/xvdf /mnt/data      ext4    defaults        1 2 >> /etc/fstab'
$SSH_PREFIX 'mkdir /mnt/data2 && mount /dev/xvdg /mnt/data2 && echo /dev/xvdg /mnt/data2      ext4    defaults        1 2 >> /etc/fstab'


# install beta demo app and move configuration file
echo 'Installing beta app...'
$SSH_PREFIX 'tar xzf sparkline-beta-demo.tar.gz --directory /mnt/data1'

#start nginx, spark
echo 'Starting nginx and beta app'
$SSH_PREFIX '/etc/init.d/nginx start; /mnt/data1/sparkline/start.sh'

echo "Setup complete for $machine"