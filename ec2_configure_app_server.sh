#!/bin/bash
# Description - Helper script to launch an app-server 
# This script will login to the remote machine, update linux packages, install nginx, python and packages, aws cli, 
# Java, Scala, Spark etc.  Will copy the package from local machine to remote machine. 
# It will then start desired web and app services.
# Author - Jitender Aswani
# May 2015
# Organization - SparklineData

    echo "Setting up $instanceIDs"
    
    # assign a tag
    aws ec2 create-tags --resources ${instanceIDs}  --tags 'Key="Name",Value=sparkline-app'
    
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

    # machine=$(aws ec2 describe-instances \
    #    --instance-ids $instanceIDs \
    #    --query 'Reservations[0].Instances[0].PublicDnsName' \
    #    --output text)
    
    echo "Setting up $machine"

    SSH_PREFIX="ssh -i $keyName.pem -o StrictHostKeyChecking=no ubuntu@$machine"
    SCP_PREFIX="scp -i $keyName.pem "
    SCP_POSTFIX=" ubuntu@$machine:"
    $SSH_PREFIX 'sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 7F0CEB10 && echo "deb http://repo.mongodb.org/apt/ubuntu "$(lsb_release -sc)"/mongodb-org/3.0 multiverse" |  sudo tee /etc/apt/sources.list.d/mongodb-org-3.0.list'
    $SSH_PREFIX 'sudo apt-get --yes --force-yes update && sudo apt-get --yes --force-yes install nginx && sudo apt-get install -y mongodb-org'
    $SCP_PREFIX 'sparkline-app.tar.gz' $SCP_POSTFIX'/home/ubuntu/.'
    $SSH_PREFIX 'tar xvzf sparkline-app.tar.gz'
    $SSH_PREFIX 'sudo mv app.sparklinedata.com /etc/nginx/sites-available/app.sparklinedata.com'
    $SSH_PREFIX 'sudo rm /etc/nginx/sites-enabled/default; sudo ln -s /etc/nginx/sites-available/app.sparklinedata.com /etc/nginx/sites-enabled/app.sparklinedata.com'
    
    # setting up python
    echo 'Setting up Python and AWS CLI'
    $SSH_PREFIX 'sudo apt-get -y install python-pip build-essential python-dev'
    $SSH_PREFIX 'sudo pip install pymongo PyJWT tornado awscli'
    
    echo 'Setting up AWS'
    $SSH_PREFIX 'mkdir .aws; echo "[default]" > .aws/config && echo "region = us-east-1" >> .aws/config && echo "output = json" >> .aws/config'
    $SSH_PREFIX 'echo "[default]" > .aws/credentials && echo "aws_access_key_id = YOUR_KEY" >> .aws/credentials && echo "aws_secret_access_key = YOUR_SECRET" >> .aws/credentials'    
    
    echo 'Starting app server'
    $SSH_PREFIX 'mkdir -p logs/web; sudo nginx -s reload; cd server && ./start_server.bash'
    echo "Setup complete for $machine"
