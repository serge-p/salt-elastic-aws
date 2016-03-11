#!/bin/sh
#
# $Header: deploy_vm.sh,v 0.2 2016/03/07 svp Exp $
#
######################################################################################
######################################################################################
#
# Set ENV Variables 
#
######################################################################################


GIT_REPO=github.com/serge-p/salt-elastic-aws.git
EC2_BASE=/tmp/ec2
AMI_ID=ami-8fcee4e5
IAM_ROLE=es-role
DEFAULT_SLEEP=30


######################################################################################
#
#
# Set colors
#
#

_COLORS=${BS_COLORS:-$(tput colors 2>/dev/null || echo 0)}
detect_color_support() {
    if [ $? -eq 0 ] && [ "$_COLORS" -gt 2 ]; then
        RC="\033[1;31m"
        GC="\033[1;32m"
        BC="\033[1;34m"
        YC="\033[1;33m"
        EC="\033[0m"
    else
        RC=""
        GC=""
        BC=""
        YC=""
        EC=""
    fi
}


echoerror() {
    printf "${RC} * ERROR${EC}: %s\n" "$@" 1>&2;
}

echoinfo() {
    printf "${GC} *  INFO${EC}: %s\n" "$@";
}

echowarn() {
    printf "${YC} *  WARN${EC}: %s\n" "$@";
}

######################################################################################



usage() {
cat << EOT

Usage :  $0 [number]

$0 script takes number of nodes in the cluster as an optional input parameter

pre-requisites: 

1. before running this script. export AWS environment variables as following:

export AWS_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXX
export AWS_SECRET_KEY=XXXXXXXXXXXXXXXXXXXX 

2. for ec2 auto-discovery, we need to create a new role in IAM from AWS console with name $IAM_ROLE 
and alos following policy 

{
    "Statement": [
        {
            "Action": [
                "ec2:DescribeInstances"
            ],
            "Effect": "Allow",
            "Resource": [
                "*"
            ]
        }
    ],
    "Version": "2012-10-17"
}

EOT
} 


# Functions lib
######################################################################################
######################################################################################



do_java_check() {

        if [ -z ${AWS_ACCESS_KEY} ] || [ -z ${AWS_SECRET_KEY} ]; then
                usage
                exit 1
        else
                echoinfo "Checking for Java"
                which java 1>/dev/null || echoerror "Java not found"
                $(env | grep JAVA_HOME 1>/dev/null) || echoerror "JAVA_HOME not found"
                echoinfo "$(java -fullversion 2>&1) found at $JAVA_HOME"
        fi
}


do_set_java_env() {
        if ! [ $(which ec2-run-instances) ] ; then
                export EC2_HOME=$(ls -1d ${EC2_BASE}/ec2-api-tools-* |tail -1) || echoerror "Unable to set EC2_HOME"
                export PATH=$PATH:$EC2_HOME/bin
        fi
        if [ -z "${JAVA_HOME}" ]; then
            if [ -d /usr/java/latest ]; then export JAVA_HOME=/usr/java/latest
            elif [ -d /usr/lib/jvm/java ]; then export JAVA_HOME=/usr/lib/jvm/java
            elif [ -d /usr/lib/jvm/jre ]; then export JAVA_HOME=/usr/lib/jvm/jre
            elif [ -f /usr/libexec/java_home ]; then export JAVA_HOME=$(/usr/libexec/java_home)
            elif [ -d /usr/lib/java ]; then export JAVA_HOME=/usr/lib/java
            else echoerror "Unable to set JAVA_HOME" && return 1
            fi
        else
        echoinfo $JAVA_HOME
        fi
        echoinfo "java env set successfully"
}

do_install_ec2_cli() {

        if [ $(which ec2-run-instances) ] || [ $(ls -1d ${EC2_BASE}/ec2-api-tools-* |wc -l) -gt 0 ] ; then
                echoinfo "EC2 tools already installed"
        else
                mkdir -p ${EC2_BASE} && cd ${EC2_BASE} || return 1
                wget http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip || return 1
                unzip ec2-api-tools.zip -d $EC2_BASE 1>/dev/null || return 1
        fi
        do_set_java_env || echowarn "Unable to set ec2 env variables"
        do_java_check
}


do_create_ec2_key_pair() { 

	if [ $(ec2-describe-keypairs test | wc -l) -gt 0 ] ; then 
		echoinfo "$(ec2-describe-keypairs test)"
	else
		ec2-create-keypair test || echowarn "Unable to create keypair"
	fi
}

do_update_ec2_sec_group() { 

#	echoinfo "Updating default security group"
#	ec2-revoke default -p -1 1>/dev/null 2>&1
#	ec2-authorize default -p -1 
	echoinfo "Creating AWS security group for Elasticsearch"
	ec2-create-group es -d "security group for Elasticsearch" || echowarn "Unable to create new security group" 
	ec2-revoke es -p -1 1>/dev/null 2>&1
	ec2-authorize es -p 22  || echowarn "Unable to add a rule to ES security group"
	ec2-authorize es -p 443  || echowarn "Unable to add a rule to ES security group"
	ec2-authorize es -p 9200 --cidr 172.31.0.0/16  || echowarn "Unable to add a rule to ES security group"
	ec2-authorize es -p 9300 --cidr  172.31.0.0/16 || echowarn "Unable to add a rule to ES security group"

}

do_gen_init_script() { 


if [ ! -z $i ] && [ $i -gt 1 ]; then NODE_ID=0${i} ; else NODE_ID=01 ; fi

#
# discovered bug in bootstrap script, which is fixed in dev version (ref https://github.com/saltstack/salt-bootstrap/issues/742) 
# uncomment to use Development branch for a salt bootstrap script :
#
export BOOTSTRAP_URL="https://raw.githubusercontent.com/saltstack/salt-bootstrap/develop/bootstrap-salt.sh"

# to use stable version of salt bootstrap script uncomment below line: 
# export BOOTSTRAP_URL=https://bootstrap.saltstack.com
# 

echoinfo "generating ec2 cloud init script"
echoinfo "cloud init log: /var/log/cloud-init-output.log"
echoinfo "salt bootstrap log: /tmp/bootstrap-salt.log"  

cat << EOF >ec2-init.sh

#!/bin/sh

echo esnode-${NODE_ID} > /etc/hostname && hostname -F /etc/hostname

yum -y install wget git 

wget ${BOOTSTRAP_URL} -O install_salt.sh || curl -L ${BOOTSTRAP_URL} -o install_salt.sh 
sh install_salt.sh

echo "file_client: local" >/etc/salt/minion.d/masterless.conf
echo "state_output: mixed" >> /etc/salt/minion.d/masterless.conf

git clone -b master https://${GIT_REPO} /srv  
salt-call --local state.highstate 1>/var/log/salt-highstate.log 2>&1
EOF

chmod +x ./ec2-init.sh
}


do_start_ec2_instance() { 
	
	do_gen_init_script || return 1  
	if [ -f ec2-init.sh ] ; then 
		echoinfo "Starting EC2 instance"
		ec2-run-instances --group es --key test --instance-type t2.micro -f ec2-init.sh $AMI_ID --iam-profile $IAM_ROLE || return 1 
		rm ./ec2-init.sh
	else 
		echoerror "Something went wrong Init file is missing" 
		return 1  
	fi
	echoinfo "Allow some time for VM to Bootstrap .."

}

do_check_ec2_instances() {

while [[ $N -gt $(ec2-describe-instances  --filter instance.group-name=es --filter  instance-state-name=running |grep INSTANCE| wc -l) ]]
do 
sleep ${DEFAULT_SLEEP}
done

ec2-describe-instances  --filter instance.group-name=es --filter  instance-state-name=running |grep INSTANCE |awk {'print $1, $2, $6, $13, $14'}

}


######################################################################################
######################################################################################
#
# Main logic starts here
#
######################################################################################
######################################################################################


detect_color_support
do_install_ec2_cli
do_create_ec2_key_pair 
do_update_ec2_sec_group

if [ ! -z $1 ] && [ $1 -gt 0 ] && [ $1 -le 5 ]; then N=$1 ; else N=1 ; fi
while [[ $N -gt $i ]]
do 
	i=$(($i+1))
	echoinfo "Starting instance $i"
	do_start_ec2_instance
done
do_check_ec2_instances