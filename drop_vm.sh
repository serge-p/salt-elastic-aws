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
Usage :  $0 instance-id (optional)

where instance-id is EC instance-id, for example i-e696e145

pre-requisites: 

before running this script, 
export AWS environment variables as following:

export AWS_ACCESS_KEY=XXXXXXXXXXXXXXXXXXXX
export AWS_SECRET_KEY=XXXXXXXXXXXXXXXXXXXX 



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



do_drop_ec2_instance() { 

    if [ -z "$INSTANCES" ] ; then
        INSTANCES=$(ec2-describe-instances  --filter instance.group-name=es --filter  instance-state-name=running |grep INSTANCE |awk {'print $2'})
    fi
    for ID in $INSTANCES
    do 
        echoinfo "Terminating EC2 instance ${ID}"
    	ec2-terminate-instances ${ID} || return 1  
    	echoinfo "Allow some time for VM to terminate"
    done
}

do_update_ec2_sec_group() { 

    echoinfo "Deleting es security group"
    ec2-delete-group es || echowarn "Unable to delete security group es"
    
}

######################################################################################
######################################################################################
#
# Main script logic starts here
#
######################################################################################
######################################################################################

if [ "$#" -gt 1 ] ; then  INSTANCES=$* ; fi

detect_color_support
do_set_java_env
do_java_check
do_drop_ec2_instance && sleep 30
do_update_ec2_sec_group