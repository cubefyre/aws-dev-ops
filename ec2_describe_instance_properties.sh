#!/bin/bash
# Description - Loads a properties file, read instance type and execute command to read a desired property
# Author - Jitender Aswani
# May 2015
# Organization - SparklineData (Now CubeFyre)

# load server response properties
. ec2_spot_server_response.properties

# describe an instance - variable $instance-type is picked from server_response.properties
aws ec2 describe-instances \ 
--filters "Name=instance-type, Values=$instanceType" \ 
"Name=image-id, Values=ami-28971a40" \ 
"Name=instance-state-code, Values=16" \ 
"Name=availability-zone,Values=us-east-1e" 
"Name=instance-lifecycle, Values=spot" \
--query 'Reservations[*].Instances[0].PrivateDnsName' \
--output text