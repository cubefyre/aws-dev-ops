# Description - Launch a barebone spark cluster 
# We built our own scripts to launch spark cluster, control the AMI and other intricate things.
# Author - Jitender Aswani
# May 2015
# Organization - SparklineData (Now CubeFyre)

export AWS_SECRET_ACCESS_KEY="YOUR_KEY"
export AWS_ACCESS_KEY_ID="YOUR_KEY"

spark-ec2 \
--key-pair=demo \
--identity-file=demo.pem \
--slaves=2 \
--instance-type=m3.2xlarge \
--zone=us-east-1e \
--region=us-east-1 \
--spark-version=1.4.0 \
--spot-price=.08 \
--no-ganglia \
--copy-aws-credentials \
--hadoop-major-version=2.4 \
launch sparkline-etl-cluster

# AMI being used by spark-ec2 scripts ami-35b1885c

## Destroy cluster
# spark-ec2 destroy sparkline-etl-cluster

