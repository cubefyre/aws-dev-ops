#!/bin/bash
# Description - Sample script to launch spark based daily pipeline.
# The script starts spark cluser (master and workers), automatically setups spark master and fires spark-submit.
# The script emails once the job is finished and attaches the logs
# The script then shutsdown everything and cleans up. 
# Author - Jitender Aswani
# May 2015
# Organization - SparklineData (Now CubeFyre)

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

    let COUNTER=COUNTER+1
done
echo $sparkMaster

echo "SSH to $masterMachine and run spark-submit"
SSH_PREFIX="ssh -i $keyName.pem -o StrictHostKeyChecking=no root@$masterMachine"
$SSH_PREFIX 'cd /mnt/data1 && aws s3 cp s3://sparklinedata/scala-lib/ sparkline-lib --recursive; aws s3 cp s3://sparklinedata/customer/pipeline/ . --recursive && chmod a+x run-etl-pipeline-ec2.sh'
$SSH_PREFIX 'cd /mnt/data1 && ./run-etl-pipeline-ec2.sh '$sparkMaster

secs=$((900))
while [ $secs -gt 0 ]; do
   echo -ne "Waiting... $secs\033[0K\r"
   sleep 1
   : $((secs--))
done
$SSH_PREFIX 'cd /mnt/data1 && cat last-job.log | mail -s "Nightly ETL Status Report" -r ETLDeamon etl@customer-admin.com'

# CurPID=$(<"etl_job.pid")
# ps -p `cat etl_job.pid` > /dev/null 2>&1 && echo Running || echo "Not Running"

#
# source script which shuts down cluster
#
source ec2_shutdown_current_servers.sh

#
# source script which shuts down cluster
#
source ec2_cancel_spot_request.sh