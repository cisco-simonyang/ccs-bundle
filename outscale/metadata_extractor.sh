#!/bin/bash
 
#First input argument is the cloud family, second is the bundle URL
CLOUD_FAMILY=$1
BUNDLE_URL=$2
#NOTE: Do not change the output file path
METADATA_FILE="/usr/local/metadata.out"
 
#Write cloud family and bundle URL to metadata file
echo "CLOUD_FAMILY=$CLOUD_FAMILY," > $METADATA_FILE
echo "BUNDLE_URL=$BUNDLE_URL," >> $METADATA_FILE
 
AWS_METADATA_BASE_URL="http://169.254.169.254/latest/meta-data/"
instanceId="$AWS_METADATA_BASE_URL/instance-id"
instanceType="$AWS_METADATA_BASE_URL/instance-type"
amiId="$AWS_METADATA_BASE_URL/ami-id"
hostname="$AWS_METADATA_BASE_URL/hostname"
privateIp="$AWS_METADATA_BASE_URL/local-ipv4"
publicIp="$AWS_METADATA_BASE_URL/public-ipv4"
   
instId=`curl $instanceId`
instType=`curl $instanceType`
privIP=`curl $privateIp`
pubIP=`curl $publicIp`
hostname=`curl $hostname`
amiId=`curl $amiId`
 
#################################################
#NOTE: The following 6 Property Names should NOT be changed
echo "INSTANCE_ID=$instId," >> $METADATA_FILE
echo "INSTANCE_TYPE=$instType," >> $METADATA_FILE
echo "PRIVATE_IP=$privIP," >> $METADATA_FILE
echo "PUBLIC_IP=$pubIP," >> $METADATA_FILE
echo "HOSTNAME=$hostname," >> $METADATA_FILE
echo "AMID_ID=$amiId," >> $METADATA_FILE
#################################################
