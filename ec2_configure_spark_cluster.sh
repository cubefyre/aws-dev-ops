#!/bin/bash
# Description - Helper script to launch spark cluster
# This script will login to the remote machine, update linux packages and other software, mount drives,
# setup spark and zeppelin. 
# Author - Jitender Aswani
# May 2015
# Organization - SparklineData (Now CubeFyre)


#. ec2_spot_server_response.properties
echo "Setting up $instanceIDs"
# get public dns
MACHINES=$(aws ec2 describe-instances \
        --instance-ids $instanceIDs \
        --query 'Reservations[*].Instances[0].PublicDnsName' \
        --output text)
echo "Public DNSs are: $MACHINES"
echo "dns='$MACHINES'" >> "$propsFile"

COUNTER=1
for machine in $MACHINES
do
    echo "Setting up $machine"
    # setup SSH and SCP commands
    SSH_PREFIX="ssh -i $keyName.pem -o StrictHostKeyChecking=no root@$machine"
    SCP_PREFIX="scp -i $keyName.pem -o StrictHostKeyChecking=no "
    SCP_POSTFIX=" root@$machine:"

    # login and update the machine, mount few drives
    $SCP_PREFIX "$keyName.pem" $SCP_POSTFIX
    $SSH_PREFIX "mv '$keyName.pem /root/.ssh/id_rsa"
    $SSH_PREFIX 'yum -y update'
    $SSH_PREFIX 'mkdir /mnt/data1 && mount /dev/xvdf /mnt/data1 && echo /dev/xvdf /mnt/data      ext4    defaults        1 2 >> /etc/fstab'
    $SSH_PREFIX 'mkdir /mnt/data2 && mount /dev/xvdg /mnt/data2 && echo /dev/xvdg /mnt/data2      ext4    defaults        1 2 >> /etc/fstab'
    #$SSH_PREFIX 'echo export AWS_ACCESS_KEY_ID=AKIAIOVG3I235W5NVR4A >> .bashrc; echo export AWS_SECRET_ACCESS_KEY=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 >> .bashrc; . .bashrc'

    # install spark and move spark-env file
    echo 'Setting up spark'
    $SSH_PREFIX 'tar xzf spark-1.4.0-bin-hadoop2.4.tar.gz --directory /mnt/data1; rm /mnt/data1/spark-1.4.0-bin-hadoop2.4/conf/spark-env.sh'

    if [ $COUNTER -eq 1  ]; then
        masterMachine=$machine
        echo "Setting up $machine as Spark Master..."
        sparkMaster="spark://$machine:7077"
        echo "Starting master on $machine"
        $SSH_PREFIX 'cd /mnt/data1/spark-1.4.0-bin-hadoop2.4 && SPARK_MASTER_OPTS="-XX:MaxPermSize=512m" ./sbin/start-master.sh --host '$machine
        # aws tag assignment
        aws ec2 create-tags --resources ${instanceIDs[1]}  --tags 'Key="Name",Value=sparkline-master'
    else
        aws ec2 create-tags --resources ${instanceIDs[1]}  --tags 'Key="Name",Value=sparkline-worker$COUNTER'
    fi
    
    echo "Starting worker on $machine"
    $SSH_PREFIX 'cd /mnt/data1/spark-1.4.0-bin-hadoop2.4  && SPARK_WORKER_OPTS="-XX:MaxPermSize=512m" ./sbin/start-slave.sh '$sparkMaster

    # install zeppelin and move configuration file
    echo 'Installing zeppelin...'
    echo "Spark Master is: MASTER=$sparkMaster"
    $SSH_PREFIX 'tar xzf zeppelin.tar.gz --directory /mnt/data1 && cd /mnt/data1/zeppelin/conf && echo export MASTER='$sparkMaster'>> zeppelin-env.sh'

    #start nginx, spark
    echo 'Starting nginx, spark..'
    $SCP_PREFIX '.htpasswd' $SCP_POSTFIX'/mnt/data1'
    #$SSH_PREFIX 'rm /etc/nginx/conf.d/nginx-default.conf && /etc/init.d/nginx start; cd /mnt/data1/spark-1.4.0-bin-hadoop2.4 && ./sbin/start-all.sh; /root/start-zeppelin.sh'
    $SSH_PREFIX 'rm /etc/nginx/conf.d/nginx-default.conf && /etc/init.d/nginx start'
    echo "Setup complete for $machine"

    let COUNTER=COUNTER+1
done
echo $masterMachine
echo $sparkMaster