#!/bin/bash

inters_home="$HOME/.mybin"
source $inters_home/config/00_cluster_settings.sh
source $inters_home/config/01_ec2_env.sh
source $inters_home/config/02_instance_settings.sh
set +e
set +u

CMDNAME=`basename $0`

while getopts ati:n: OPT
do
  case $OPT in
    "t" ) FLG_T="TRUE" ;;
    "a" ) FLG_A="TRUE" ;;
    "i" ) FLG_I="TRUE" ; VALUE_I="$OPTARG" ;;
    "n" ) FLG_N="TRUE" ; VALUE_N="$OPTARG" ;;
    * ) echo "Usage: $CMDNAME [-t(erminate)] [-a(ll)] [-i INSTANCE_ID] [-n hostnum]" 1>&2
    exit 1 ;;
  esac
done

if [ "$FLG_A" = "TRUE" ]; then
  VPN_IDS=$(ec2-describe-instances -F tag:Name="$CLUSTER_NAME*" | grep ^INS | awk '{print $2}')
else
  VPN_IDS=$(ec2-describe-instances -F tag:Name="$CLUSTER_NAME$VALUE_N" | grep ^INS | awk '{print $2}')
fi
echo "ec2-describe-instances -F tag:Name=\"$CLUSTER_NAME*\""
echo $VPN_IDS

for instance_id in $VPN_IDS
do
  echo "stop instance: $instance_id"
  ec2-stop-instances $instance_id
  if [ "$FLG_T" = "TRUE" ]; then
    ssh -F $ssh_config -o ConnectTimeout=2 "$CLUSTER_NAME""1" sudo /var/lib/gems/1.8/bin/puppetca -c $CLUSTER_NAME$VALUE_N.$hostdomain || true
    echo "destroy instance: $instance_id"
    ec2-terminate-instances $instance_id
    echo "remove tags from instance: $instance_id"
    ec2-delete-tags $instance_id -t LRM-Role -t VPN-Role -t Name -t VPN-Address
  fi
done

if [ "$FLG_T" = "TRUE" ]; then
  if [ "$VALUE_N" = "1" -o "$FLG_A" = "TRUE" ]; then
    elastic_ip=`ec2-describe-tags | awk '/ElasticIP/ {print $5}'`
    instance_id=`ec2-describe-tags | awk '/ElasticIP/ {print $3}'`
    if [ ! -z "$elastic_ip" -a ! -z "$instance_id" ]; then
      ec2-release-address $elastic_ip
      ec2-delete-tags $instance_id -t ElasticIP
    fi
  fi
fi
