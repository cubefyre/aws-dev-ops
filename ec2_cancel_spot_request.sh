#!/bin/bash
# Description - Loads a properties file, read spot request id and execute command to cancel spot request
# Author - Jitender Aswani
# May 2015
# Organization - SparklineData

# load server response properties
. ec2_spot_server_response.properties


aws ec2 cancel-spot-instance-requests \
--spot-instance-request-ids $spotRequestIDs \
--query 'CancelledSpotInstanceRequests[*].State' \
--output text
