#!/bin/sh -
#
#
# $Example Header: deploy_vm.sh,v 0.2 2016/03/07 svp Exp $
#
######################################################################################
######################################################################################
#
# Set ENV Variables 
#
######################################################################################


myname="drop_vm.sh"
DEFAULT_SLEEP=60
EC2_BASE=/tmp/ec2

 
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
 Usage :  ${myname} instance-ID 

  Example instance-ID:	i-e696e145
EOT
} 

if [ "$#" -ne 1 ]; then
    usage
    exit 1
fi

export ID=$1

# Functions lib
######################################################################################
######################################################################################

do_java_check() {

    echoinfo "Checking for Java binaries"
    which java 1>/dev/null || echoerror "Java no found"  
    echoinfo "Java Home $(/usr/libexec/java_home)" || echoerror "Java Home not found"
    echoinfo "$(java -fullversion 2>&1)"
}




do_set_java_env() {
    ls -1d ${EC2_BASE}/ec2-api-tools-* |tail -1 || return 1
    export EC2_HOME=$(ls -1d ${EC2_BASE}/ec2-api-tools-* |tail -1) || echoerror "Unable to set EC2_HOME"
    export JAVA_HOME=$(/usr/libexec/java_home) || echoerror "Unable to set JAVA_HOME"
    export PATH=$PATH:$EC2_HOME/bin
 }



do_update_ec2_sec_group() { 

    ec2-revoke default -p -1 || echowarn "Unable to delete rule in default security group" 
    
}

do_drop_ec2_instance() { 

	echoinfo "Terminating EC2 instance"
	ec2-terminate-instances ${ID} || return 1 
	echoinfo "Allow some time for VM to terminate"
	ec2-describe-instances ${ID}
}

######################################################################################
######################################################################################
#
# Main script logic starts here
#
######################################################################################
######################################################################################

detect_color_support
do_java_check
do_set_java_env
do_update_ec2_sec_group
do_drop_ec2_instance