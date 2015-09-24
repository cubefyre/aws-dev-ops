#!/bin/bash 
#
# This script will read properties from a propertiese file or can run it in interactive mode to set properties
# Script will call following scripts:
# 	1	ec2_check_historical_spot_prices.sh 		for checking spot price
# 	2 	ec2_send_spot_server_request.ssh 			for sending spot requests
# 	3 	$configureServerScript 						for configuring launched machines (write your own script and plug it in .peroperties file)
# 
# Author - Jitender Aswani
# May 2015
# Organization - SparklineData (Now CubeFyre)
. ec2_spot_server_request.properties

usage="$(basename "$0") [-h] [-c] -- design and launch a single machine or a set of machines
	where:
	    -h  --help show this help text
	    -i  --configure use interactive wizzard to configure cluster/server settings (some values from ec2_spot_server_request.properties will be overwritten"

case "$1" in
    "-h") 	echo
		echo  "$usage"
		;;
    "-c") 	
		echo "Entering interactive mode..."
		echo "Enter number of nodes in the cluster and press enter (Default: 1):"
		read instanceCount
		instanceCount=${instanceCount:-1}

		echo "Enter instance type (Default: m1.xlarge):"
		read instanceType
		instanceType=${instanceType:-m1.xlarge}

		echo "Enter availability zone (Default: us-east-1e):"
		read availabilityZone
		availabilityZone=${availabilityZone:-us-east-1e}

		echo "Checking last one week's spot prices for this instance..."
		
		# source script which checks spot proces and sets the price
		source ec2_check_historical_spot_prices.sh
		
		echo "Enter spot price (Default: average spot price - $averageSpotPrice):"
		read spotPrice
		spotPrice=${spotPrice:-$averageSpotPrice}    

		echo "Enter ssh key name (Default: ssh key - demo):"
		read keyName
		keyName=${keyName:-demo}  

		echo "Enter AMI (Default: AMI - ami-28971a40):"
		read imageID
		imageID=${imageID:-ami-28971a40}  
       ;;
    \?) echo 'unknown option' ;;
esac

# preapring a lauch group id
currentTimeinMS=$(date +%s)
launchGroup="sparky$currentTimeinMS"

echo "Saving the cluster properties in $propsFile for later use..."
echo "keyName=$keyName" > "$propsFile"
echo "instanceCount=$instanceCount" >> "$propsFile"
echo "instanceType=$instanceType" >> "$propsFile"
echo "availabilityZone=$availabilityZone" >> "$propsFile"
echo "spotPrice=$spotPrice" >> "$propsFile"
echo "imageID=$imageID" >> "$propsFile"
echo "securityGroup=$securityGroup" >> "$propsFile"
echo "launchGroup=$launchGroup" >> "$propsFile"

#
# source script which submits spot request
#
source ec2_send_spot_server_request.sh

#
# following set of lines will check if the request has been fulfilled and will get the instance ids
#
echo "Starting to check status of spot requests..."
keepCheckingStatus=true
while [ "$keepCheckingStatus" = true ];
do
	STATUS=$(aws ec2 describe-spot-instance-requests \
	--spot-instance-request-ids $spotRequestIDs \
	--query 'SpotInstanceRequests[*].Status.Code' \
	--output text)
	echo "Current status is $STATUS"
	for st in $STATUS 
	do
		if [[ $st =~ "canceled" ]] || [[ $st =~ "price-too-low" ]] || [[ $st =~ "launch-group-constraint" ]];
		then
    		keepCheckingStatus=false
			echo "Spot request cancelled."
    		exit 1
		elif [[ $st =~ "pending" ]];
		then
			keepCheckingStatus=true
		elif [ $st == "fulfilled" ]; 
		then
			keepCheckingStatus=false
    		currentState=0
    		break 2 # break out of while loop
    	fi
    	break
	done
	secs=$((60))
	while [ $secs -gt 0 ]; do
	   echo -ne "Waiting... $secs\033[0K\r"
	   sleep 1
	   : $((secs--))
	done
done
echo "The request status is - $currentState"

if [ $currentState -eq 0 ]; 
then
	instanceIDs=$(aws ec2 describe-spot-instance-requests \
	--spot-instance-request-ids $spotRequestIDs \
	--query 'SpotInstanceRequests[*].InstanceId' \
	--output text)	
	echo "requestFulfilled=true" >> "$propsFile"
	echo "instanceIDs='$instanceIDs'" >> "$propsFile"

	#
	# Get ready to configure the machines once the servers are up 
	#
	echo "Preparing to check if the instance has come up..."
	# sleep 30s
	keepChecking=true
	while [ "$keepChecking" = true ];
	do
	    echo "Checking status of instances $instanceIDs..."
	    clusterUp=true
	    STATUS=$(aws ec2 describe-instances \
	        --instance-ids $instanceIDs \
	        --query 'Reservations[*].Instances[0].State.Code' \
	        --output text)
	    
	    echo "Current status of machines in the cluster is $STATUS"
	    for st in $STATUS 
	    do
	        if [  $st == "0" ];
	        then
	            clusterUp=false 
	        elif [  $st == "32" ] || [  $st == "48" ] || [  $st == "64" ] || [  $st == "80" ];
	        then
	            echo "Machine is stopped or shutdown or terminated."
	            exit 1;
	        fi
	    done
	    if [ $clusterUp = true ];
	    then
	        echo "The entire cluster is up, gettting ready to configure..."
	        break
	    fi
	    echo
		secs=$((60))
		while [ $secs -gt 0 ]; do
		   echo -ne "Waiting... $secs\033[0K\r"
		   sleep 1
		   : $((secs--))
		done
	done
	#
	# get ready to configure the machine, pluging-in machine/instance configure script
	#
	echo "Getting DNS names of cluster machines..."
	source $configureServerScript
fi

