#!/bin/bash
# Description - Called by ec2_launch_spot_server script - this script submits the spot requests
# Author - Jitender Aswani
# May 2015
# Organization - SparklineData (Now CubeFyre)

 echo 'Submitting request: '
 echo aws ec2 request-spot-instances \
    --spot-price "$spotPrice" \
    --instance-count $instanceCount \
    --type "one-time" \
    --launch-group "$launchGroup" \
    --launch-specification "{\"ImageId\":\"$imageID\", \"KeyName\":\"$keyName\", \"InstanceType\":\"$instanceType\", \"SecurityGroups\":[\"$securityGroup\"],\"Placement\":{\"AvailabilityZone\":\"$availabilityZone\"}}" \
    --query 'SpotInstanceRequests[*].SpotInstanceRequestId' --output text

 spotRequestIDs=$(aws ec2 request-spot-instances \
    --spot-price "$spotPrice" \
    --instance-count $instanceCount \
    --type "one-time" \
    --launch-group "$launchGroup" \
    --launch-specification "{\"ImageId\":\"$imageID\", \"KeyName\":\"$keyName\", \"InstanceType\":\"$instanceType\", \"SecurityGroups\":[\"$securityGroup\"],\"Placement\":{\"AvailabilityZone\":\"$availabilityZone\"}}" \
    --query 'SpotInstanceRequests[*].SpotInstanceRequestId' --output text)

echo "Requests submitted, request ids are: $spotRequestIDs"
echo "spotRequestIDs='$spotRequestIDs'" >> "$propsFile"