#!/bin/bash
# Description - Helper script to launch a single-node hadoop cluster
# This script will login to the remote machine, update linux packages and other software, mount drives,
# download latest rev of ambari and hue (if set in properties file). 
# The script will use python code to generate ambari ini file and will use blueprint to setup the cluster. 
# Author - Jitender Aswani
# May 2015
# Organization - SparklineData (Now CubeFyre)

# Sample properties - put these properties in spot_server_request.properties file
## hadoop cluster properties for ambari using blueprint rest apis
# setupCluster=1
# blueprintName=SingleNodeCluster
# blueprintFile=SingleNodeClusterBlueprint.json
# clusterName=SparklineOne
# hostMappingFile=ClusterHostMapping.json
## setup hue (0 or 1) - no or yes
# setupHue=1
## hadoop centos image 
# imageID=ami-28971a40
# securityGroup=sparkline-cluster-security-group
## hadoop single node cluster script
# configureServerScript=ec2_configure_single_node_hadoop.sh


echo "Setting up $instanceIDs"

machine=$(aws ec2 describe-instances \
        --instance-ids $instanceIDs \
        --query 'Reservations[*].Instances[0].PublicDnsName' \
        --output text)

echo "Public DNSs are: $machine"
echo "dns='$machine'" >> "$propsFile"

privateDns=$(aws ec2 describe-instances \
    --instance-ids $instanceIDs \
    --query 'Reservations[*].Instances[0].PrivateDnsName' \
    --output text)
echo "private DNS are : $privateDns"
echo "privateDns='$privateDns'" >> "$propsFile"

SSH_PREFIX="ssh -i $keyName.pem -o StrictHostKeyChecking=no root@$machine"
SCP_PREFIX="scp -i $keyName.pem "
SCP_POSTFIX=" root@$machine:"
scp -i demo.pem -o StrictHostKeyChecking=no demo.pem root@$machine:

    $SSH_PREFIX 'mv demo.pem /root/.ssh/id_rsa'
    $SSH_PREFIX 'yum -y update'
    $SSH_PREFIX 'yum -y install sudo'
    $SSH_PREFIX 'mkdir /mnt/data'
    $SSH_PREFIX 'mount /dev/xvdf /mnt/data'
    $SSH_PREFIX 'echo /dev/xvdf /mnt/data      ext4    defaults        1 2 >> /etc/fstab'
    $SSH_PREFIX 'mkdir /mnt/data1'
    $SSH_PREFIX 'mkdir /mnt/data2'
    $SSH_PREFIX 'mkdir /mnt/data3'
    $SSH_PREFIX 'mount /dev/xvdg /mnt/data1'
    $SSH_PREFIX 'mount /dev/xvdh /mnt/data2'
    $SSH_PREFIX 'mount /dev/xvdi /mnt/data3'
    $SSH_PREFIX 'echo /dev/xvdg /mnt/data1      ext4    defaults        1 2 >> /etc/fstab'
    $SSH_PREFIX 'echo /dev/xvdh /mnt/data2      ext4    defaults        1 2 >> /etc/fstab'
    $SSH_PREFIX 'echo /dev/xvdi /mnt/data3      ext4    defaults        1 2 >> /etc/fstab'
    $SSH_PREFIX 'mount -a'
    $SSH_PREFIX 'chkconfig ntpd on'
    $SSH_PREFIX 'chkconfig iptables off'
    $SSH_PREFIX '/etc/init.d/iptables stop'
    $SSH_PREFIX 'service ntpd start'

    echo "Setting up $machine as Ambari Server..."
    $SSH_PREFIX 'wget -nv http://public-repo-1.hortonworks.com/ambari/centos6/2.x/updates/2.0.0/ambari.repo'
    $SSH_PREFIX 'cp ambari.repo /etc/yum.repos.d'
    $SSH_PREFIX 'yum -y install ambari-server'
    $SSH_PREFIX 'ambari-server setup -s -v'
    $SSH_PREFIX 'ambari-server start'
    $SSH_PREFIX 'yum -y install ambari-agent'

    # prepare env for other softwares
    $SSH_PREFIX 'yum install -y ant asciidoc cyrus-sasl-devel cyrus-sasl-gssapi gcc gcc-c++ krb5-devel libtidy libxml2-devel libxslt-devel make mysql mysql-devel openldap-devel python-devel sqlite-devel gmp-devel'

    # install maven
    $SSH_PREFIX 'wget -nv http://mirror.olnevhost.net/pub/apache/maven/maven-3/3.3.3/binaries/apache-maven-3.3.3-bin.tar.gz'
    $SSH_PREFIX 'tar xzf apache-maven-3.3.3-bin.tar.gz'
    $SSH_PREFIX 'mv apache-maven-3.3.3/ /usr/local/maven'
    $SSH_PREFIX 'ln -s /usr/local/maven/bin/mvn /usr/bin/mvn'

    #install scala
    $SSH_PREFIX 'wget -nv http://www.scala-lang.org/files/archive/scala-2.10.4.tgz && tar xzf scala-2.10.4.tgz && mv scala-2.10.4 /usr/local/scala'
    $SSH_PREFIX "echo 'export SCALA_HOME=/usr/local/scala' >> .bashrc  && echo 'export PATH=$PATH:$SCALA_HOME/bin' >> .bashrc"

    # install sbt
    $SSH_PREFIX 'curl https://bintray.com/sbt/rpm/rpm | tee /etc/yum.repos.d/bintray-sbt-rpm.repo'
    $SSH_PREFIX 'yum -y install sbt'

    # install spark
    $SSH_PREFIX 'wget -nv http://www.webhostingjams.com/mirror/apache/spark/spark-1.2.1/spark-1.2.1-bin-hadoop2.4.tgz && tar xzf spark-1.2.1-bin-hadoop2.4.tgz && mv spark-1.2.1-bin-hadoop2.4 /usr/local/spark'
    $SSH_PREFIX "echo 'export SPARK_HOME=/usr/local/spark' >> .bashrc  && echo 'export PATH=$PATH:$SPARK_HOME/bin' >> .bashrc"

    # hive conf dir
    $SSH_PREFIX 'echo "export HIVE_CONF_DIR=/etc/hive/conf" >> .bashrc'

    # aws tag assignment
    aws ec2 create-tags --resources ${instanceIDs}  --tags 'Key="Name",Value=single-node-hadoop'

    if [ $setupHue == "1" ]; then
        # download and make hue
        echo "Setting up $machine as hue..."
        $SSH_PREFIX 'wget -nv https://dl.dropboxusercontent.com/u/730827/hue/releases/3.8.1/hue-3.8.1.tgz && tar xzf hue-3.8.1.tgz && cd hue-3.8.1 && make install'
        $SCP_PREFIX 'hue.ini' $SCP_POSTFIX'/usr/local/hue/desktop/conf/hue.ini'
        $SSH_PREFIX 'useradd -U hue && chown -R hue:hue /usr/local/hue && /usr/local/hue/build/env/bin/supervisor -d'
    fi

    # setup cluster
    if [ $setupCluster == "1" ]; then
        echo "Getting ready to setup ambari agent"
        echo python ambari_agent_setup.py $privateDns
        python ambari_agent_setup.py $privateDns 
        $SCP_PREFIX 'ambari-agent.ini' $SCP_POSTFIX'/etc/ambari-agent/conf/ambari-agent.ini'
        $SSH_PREFIX 'ambari-agent start'
        
        echo "Now calling ambari setup script to setup cluster"
        echo python ambari_cluster_setup.py $machine $blueprintName $blueprintFile $clusterName $hostMappingFile $privateDns
        python ambari_cluster_setup.py $machine $blueprintName $blueprintFile $clusterName $hostMappingFile $privateDns
    fi

echo "Setup complete for $machine"