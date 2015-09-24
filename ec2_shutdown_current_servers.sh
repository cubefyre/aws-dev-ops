#!/bin/bash
# Description - Loads respone properties file, read instance ids and execute command to shutdown instances
# Author - Jitender Aswani
# May 2015
# Organization - SparklineData

. ec2_spot_server_response.properties

for instance in $instanceIDs
	do
		state=$(aws ec2 describe-instances \
		--instance-ids $instance \
		--query 'Reservations[*].Instances[0].State.Code' --output text)
		if [ $state -eq 16 ];
		then
		    echo "shutting down $instance"
		    aws ec2 terminate-instances --instance-ids $instance		
		fi
done