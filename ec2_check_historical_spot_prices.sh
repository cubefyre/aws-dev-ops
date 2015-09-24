#!/bin/bash
# Description - Check spot prices for a machine type in any region/zone. Also calculate mean prices
# -- check spot prices
#	where:
#	    -h  --help show this help text
#	    -i  --configure use interactive wizzard to configure cluster/server settings (some values from ec2_spot_server_request.properties will be overwritten"
# Author - Jitender Aswani
# May 2015
# Organization - SparklineData (Now CubeFyre)

. ec2_spot_server_request.properties
usage="$(basename "$0") [-h] [-i] -- check spot prices
	where:
	    -h  --help show this help text
	    -i  --configure use interactive wizzard to configure cluster/server settings (some values from ec2_spot_server_request.properties will be overwritten"

case "$1" in
    "-h") 	echo
		echo  "$usage"
		exit 1
		;;
    "-i") 	
		echo "Enter availability zone and press enter (Default: us-east-1e):"
		read availabilityZone
		availabilityZone=${availabilityZone:-us-east-1e}

		echo "Enter instance type (Default: m1.xlarge):"
		read instanceType
		instanceType=${instanceType:-m1.xlarge}
		echo "Checking spot prices..."
       ;;
    \?) echo 'unknown option' 
		exit 1
		;;
esac

startTime=$(date -v-7d +"%Y-%m-%d")
endTime=$(date +"%Y-%m-%d")

spotPrices=$(aws ec2 describe-spot-price-history --instance-types $instanceType --availability-zone $availabilityZone --product-description Linux/UNIX --start-time $startTime --end-time $endTime --query 'SpotPriceHistory[*].SpotPrice' --output text)

echo "Calculating average, min, max prices for $instanceType in $availabilityZone..."
fileName="spot_prices_$instanceType.txt"

if [ ! -f $fileName ]; then
	touch $fileName
else 
	rm $fileName
fi

for price in $spotPrices
	do
		echo $price >> $fileName
done

if [ "$1" == "-i" ];
then
	awk '{if(min==""){min=max=$1}; if($1>max) {max=$1}; if($1<min) {min=$1}; total+=$1; count+=1} END {print "Average price: " total/count " Max Price: " max " Min Price: " min}' $fileName   
else
	awk '{if(min==""){min=max=$1}; if($1>max) {max=$1}; if($1<min) {min=$1}; total+=$1; count+=1} END {print "Average price: " total/count " Max Price: " max " Min Price: " min}' $fileName   
	averageSpotPrice=$(awk '{total+=$1; count+=1} END {print total/count}' $fileName)
fi