#!/bin/sh
#
# $Example Header: deploy_vm.sh,v 0.2 2016/03/07 svp Exp $
#
######################################################################################
######################################################################################
#
# Set ENV Variables 
#
######################################################################################


myname="deploy_vm.sh"
DEFAULT_SLEEP=3
GIT_REPO=github.com/serge-p/salt-elastic-aws
EC2_BASE=/tmp/ec2
AMI_ID=ami-8fcee4e5


#
# export AWS_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXX
# export AWS_SECRET_KEY=XXXXXXXXXXXXXXXXXXXX
#



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

set your AWS environment variables first as following:

export AWS_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXX
export AWS_SECRET_KEY=XXXXXXXXXXXXXXXXXXXX 

Usage :  ${myname}


Bootstrap options:
    - salt masterless 
##    - shell 

EOT
} 


# Functions lib
######################################################################################
######################################################################################


#do_java_install() {

	## To be implemented, 
	## for now we are assuming, you've got JDK preinstalled as a prerequsuite
#}



do_java_check() {

	if [ -z ${AWS_ACCESS_KEY} ] || [ -z ${AWS_SECRET_KEY} ]; then 
		usage
		exit 1
	else
		echoinfo "Checking for Java binaries"
		which java 1>/dev/null || echoerror "Java no found"  
		echoinfo "Java Home $(/usr/libexec/java_home)" || echoerror "Java Home not found"
		echoinfo "$(java -fullversion 2>&1)"
	fi
}




do_set_java_env() {
	ls -1d ${EC2_BASE}/ec2-api-tools-* |tail -1 || return 1
	export EC2_HOME=$(ls -1d ${EC2_BASE}/ec2-api-tools-* |tail -1) || echoerror "Unable to set EC2_HOME"
	export JAVA_HOME=$(/usr/libexec/java_home) || echoerror "Unable to set JAVA_HOME"
	export PATH=$PATH:$EC2_HOME/bin
	echoinfo "EC2 CLI variables set successfully"
}


do_install_ec2_cli() {

	if [ $(ls -1d ${EC2_BASE}/ec2-api-tools-* |wc -l) -gt 0 ] ; then 
		echoinfo "EC2 tools already installed"
	else
		mkdir -p ${EC2_BASE} && cd ${EC2_BASE} || return 1
		wget http://s3.amazonaws.com/ec2-downloads/ec2-api-tools.zip || return 1 
		unzip ec2-api-tools.zip -d $EC2_BASE 1>/dev/null || return 1 
	fi
	do_set_java_env || echowarn "Unable to set ec2 env variables"
}

do_create_ec2_key_pair() { 

	if [ $(ec2-describe-keypairs test | wc -l) -gt 0 ] ; then 
		echoinfo $(ec2-describe-keypairs test)
	else
		ec2-create-keypair test || echowarn "Unable to create keypair"
	fi
}

do_update_ec2_sec_group() { 

	echoinfo "Updating default security group"
	ec2-revoke default -p -1 1>/dev/null 2>&1
	ec2-authorize default -p -1 || echowarn "Unable to create new security rule in a default group" 

}

do_gen_init_script() { 

#
# For stable version of salt bootstrap script uncomment below line: 
# export BOOTSTRAP_URL=https://bootstrap.saltstack.com
# 
# discovered bug in bootstrap script, which is fixed in dev version (ref https://github.com/saltstack/salt-bootstrap/issues/742) 
# uncomment to use Development branch for a salt bootstrap script : 
export BOOTSTRAP_URL="https://raw.githubusercontent.com/saltstack/salt-bootstrap/develop/bootstrap-salt.sh"

echoinfo "Generating ec2-init.sh script, which will be executed by cloud-init"
echoinfo "default log for a cloud init: /var/log/cloud-init-output.log"
echoinfo "default log for a salt bootstrap script: /tmp/bootstrap-salt.log"  

cat << EOF >ec2-init.sh
#!/bin/sh
yum -y install wget git 
wget ${BOOTSTRAP_URL} -O install_salt.sh  || curl -L ${BOOTSTRAP_URL} -o install_salt.sh 
sh install_salt.sh
echo "file_client: local" >/etc/salt/minion.d/masterless.conf
echo "state_output: mixed" >> /etc/salt/minion.d/masterless.conf
mkdir -p /srv/salt && git clone https://${GIT_REPO}.git && mv salt-elastic-aws/salt/* /srv/salt/  
salt-call --local state.highstate -l debug 1>/tmp/highstaterun.log 2>&1
EOF
chmod +x ./ec2-init.sh
}


do_start_ec2_instance() { 
	
	if [ -f ec2-init.sh ] ; then 
		echoinfo "Starting EC2 instance"
		ec2-run-instances --group es --key test --instance-type t2.micro -f ec2-init.sh $AMI_ID || return 1 
		rm ./ec2-init.sh
	else 
		echowarn "Init file is missing, starting plain instance using keypair test" 
		ec2-run-instances --group es  --key test --instance-type t2.micro $AMI_ID || return 1 
		return 1  
	fi
	echoinfo "Allow some time for VM to Bootstrap .."
	sleep ${DEFAULT_SLEEP}
	ec2-describe-instances
}


######################################################################################
######################################################################################
#
# Main logic starts here
#
######################################################################################
######################################################################################

detect_color_support
do_java_check
do_install_ec2_cli
do_create_ec2_key_pair 
do_update_ec2_sec_group
do_gen_init_script || echoerror "unable to generate init script, check the logs"
do_start_ec2_instance
