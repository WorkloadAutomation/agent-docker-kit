#!/bin/bash
####################################################################
# Licensed Materials - Property of HCL*
# 
# (c) Copyright HCL Technologies Ltd. 2017-2018 All rights reserved.
# * Trademark of HCL Technologies Limited
####################################################################
#
# Entry point script for the Docker Workload Automation Agent 
#
####################################################################

if [ "x${WA_DEBUG_SCRIPTS}" == "xYES" ];then
	set -x
fi

# Support Arbitrary uid
MYUID=$(id -u)
MYGID=$(id -g)

#
# Set these variables in "docker run" to configure the agent to use your own TDWB server and agents
#
# SERVERHOSTNAME=ws94mdm1.example.com      # JobManagerGW.ini ResourceAdvisorUrl
# BKMSERVERHOSTNAME=ws94mdm2.example.com   # JobManagerGW.ini BackupResourceAdvisorUrls 
# SERVERPORT=31116                         # JobManagerGW.ini ResourceAdvisorUrl and BackupResourceAdvisorUrls 
# AGENTID=9F00EA76214011E786BCC9EEA2347192 # JobManager.ini UUID - AgentID (use to persist agents in the resource database and reuse the same agent in the broker)
# AGENTNAME=WSAGENT99                      # ComputerSystemDisplayName 
# AGENTHOSTNAME=myhost.example.com         # hostname in JobManager.ini and JobManagerGWID FullyQualifiedHostname and ResourceAdvisorUrl 
# RECONFIGURE_AGENT=NO                     # Set to YES to force refresh of all configuration options, must set CURRENT_AGENTID="${AGENTID}" and RECONFIGURE_AGENT=NO to keep last configuration
# POOLS                                    # Pass a comma separated list of Workstation POOLS where you want to register this agent ex.:POOLS="Po1,Po2"
# MAXWAITONEXIT                            # The timeout in seconds to wait for all the processes to complete before stopping the container. Default value: 60. Maximum allowed value: 3600
# SECRETMOUNTPATH=/opt/service-bind        # Pass the secret mount point, default: /opt/service-bind
# HTTPS=YES                                # For z-Centric only. Set to NO to force HTTP, not secured protocol, for the agent local port used to receive job submission from Controller
# LICENSE=ACCEPT                           # Use ACCEPT to accept the license agreement
# Set some defaults
AGENT_PROC="agent"
JOBMANAGER_PROC="JobManager"
TASKLAUNCHER_PROC="taskLauncher"

WA_USER=wauser
AGENTHOSTNAME=${AGENTHOSTNAME:-localhost}
INSTALL_DIR=${INSTALL_DIR:-/home/${WA_USER}/TWA/TWS}
BMFILE=${INSTALL_DIR}/.bluemix
if [ -f ${BMFILE} ];then
	SERVERPORT=${SERVERPORT:-443}
else
	SERVERPORT=${SERVERPORT:-31116}
fi
POOL_FILE=$INSTALL_DIR/ITA/cpa/config/pools.properties
SECRETMOUNTPATH=${SECRETMOUNTPATH:-/opt/service-bind}

#
# These variables are overwritten in the setup script
#
ACTION_TOOL_RET_COD=0
ACTION_TOOL_RET_STDOUT=
CONFIGURATIONFILESDIR=$INSTALL_DIR/stdlist
OUTPUT_FILE=/tmp/properties_agent.zip
PROPERTYFILENAME=installAgent.properties
PROPERTYFILE=$CONFIGURATIONFILESDIR/$PROPERTYFILENAME
GWID=GWID_${AGENTNAME}_${HOSTNAME}
GWID=`echo ${GWID//-/_}`

if [ -d /home/${WA_USER}/cert  ];then
    echo Custom certificates found
	CERTDIR=/home/${WA_USER}/cert
else
	CERTDIR=$CONFIGURATIONFILESDIR
fi	

#
#  BM specific variables
#
URI=$VCAP_SERVICES_WORKLOADSCHEDULER_0_CREDENTIALS_AGENT_CONFIG_URL
CURRENT_PASSWORD=$VCAP_SERVICES_WORKLOADSCHEDULER_0_CREDENTIALS_PASSWORD
CURRENT_USER=$VCAP_SERVICES_WORKLOADSCHEDULER_0_CREDENTIALS_USERID
ZIP_INNER_FOLDER=SCWA-SaaS
PASSWORD_DECODE=
USER_DECODE=

trap exit_gracefully 0 1 2 15

# This method is used for abnormal termination. The following parameters must be passed
#   reason      -   failure explanation
#  exitOnError exit code
exitOnError()
{
    # Action Result Handling
    if [ $ACTION_TOOL_RET_COD -ne 0 ]
    then
        # Print Debug Information
        echo "${ACTION_TOOL_RET_STDOUT}"
        exit 1
    fi
}


# Method to decode user and password
decodeUser_Password(){
    echo Decoding user and password
    USER_DECODE=$(printf '%b' "${CURRENT_USER//%/\\x}")
    PASSWORD_DECODE=$(printf '%b' "${CURRENT_PASSWORD//%/\\x}")
    echo $USER_DECODE xxxxxxxxxxxx
}


# Execute a command
# Arguments:
#       <command> args
execute_command()
{
    $@
    if [ $? -ne 0 ]
    then
        echo "start script failed executing: $@."
        exit 1
    fi
}


# Method to check if the environment variables are correctly set
checkEnvironmentVariables(){

    if [ -z "$CURRENT_USER" ]
	then
		ACTION_TOOL_RET_COD=1
		ACTION_TOOL_RET_STDOUT="CURRENT_USER is not correctly set."
	else 
		echo "CURRENT_USER: $CURRENT_USER"
    fi

    if [ -z "$CURRENT_PASSWORD" ]
	then
		ACTION_TOOL_RET_COD=1
		ACTION_TOOL_RET_STDOUT="CURRENT_PASSWORD is not correctly set."
	else
		echo "CURRENT_PASSWORD: xxxxxxxxxxxxxxxx"
    fi
    exitOnError
}


# Method to get properties and certificates from URI
getPropertiesFromZip(){
    # Download the property file and certificates from URI and copy file into the stdlist folder
    if [ ! -z "$URI" ]
    then
	    echo "Running getPropertiesFromZip"
	    checkEnvironmentVariables
	    decodeUser_Password
	    cd /tmp
        curl -v --tlsv1.2 --user "$USER_DECODE:$PASSWORD_DECODE" --output $OUTPUT_FILE $URI
        unzip $OUTPUT_FILE
        if [ $? -ne 0 ]
        then
        	ACTION_TOOL_RET_COD=2
			ACTION_TOOL_RET_STDOUT="Unable to download property file and certificates from URI $URI."
		    exitOnError
        fi
        echo "Copying ./$ZIP_INNER_FOLDER/$PROPERTYFILENAME to $PROPERTYFILE"
        cp -f ./$ZIP_INNER_FOLDER/$PROPERTYFILENAME $PROPERTYFILE
        chmod 775 $PROPERTYFILE
        mychown wauser:wauser $PROPERTYFILE
        echo "Copying ./$ZIP_INNER_FOLDER/TWSClientKeyStore.kdb to $CERTDIR/TWSClientKeyStore.kdb"
        cp -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.kdb $CERTDIR/TWSClientKeyStore.kdb
        chmod 775  $CERTDIR/TWSClientKeyStore.kdb
        mychown wauser:wauser $CERTDIR/TWSClientKeyStore.kdb
        if [ -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.sth ];
        then
            echo "Copying ./$ZIP_INNER_FOLDER/TWSClientKeyStore.sth to $CERTDIR/TWSClientKeyStore.sth"
            cp -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.sth $CERTDIR/TWSClientKeyStore.sth
            chmod 775 $CERTDIR/TWSClientKeyStore.sth
            mychown wauser:wauser $CERTDIR/TWSClientKeyStore.sth
        fi
        if [ -f $OUTPUT_FILE ]
        then
        	rm -f $OUTPUT_FILE
        fi
        if [ -d $ZIP_INNER_FOLDER ]
        then
	        rm -Rf $ZIP_INNER_FOLDER
	    fi
        if [ -d /tmp/.self ]
        then
	        rm -Rf /tmp/.self
	    fi
    else
        echo "No download server information provided."
    fi
}

# Method to get certificates from URI
getKeyStoreFromZip(){
    cd /tmp
    # Download the property file and certificates from URI and copy file into the stdlist folder
    if [ ! -z "$URI" ]
    then
	    echo "Running getKeyStoreFromZip"
	    checkEnvironmentVariables
	    decodeUser_Password
        curl -v --tlsv1.2 --user "$USER_DECODE:$PASSWORD_DECODE" --output $OUTPUT_FILE $URI
        unzip $OUTPUT_FILE
        if [ $? -ne 0 ]
        then
        	ACTION_TOOL_RET_COD=2
			ACTION_TOOL_RET_STDOUT="Unable to download property file and certificates from URI $URI."
		    exitOnError
        fi
        echo "Running command: cp -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.kdb $CERTDIR/TWSClientKeyStore.kdb"
        cp -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.kdb $CERTDIR/TWSClientKeyStore.kdb
        chmod 775  $CERTDIR/TWSClientKeyStore.kdb
        mychown wauser:wauser $CERTDIR/TWSClientKeyStore.kdb
    else
        echo "No download server information provided."
    fi
    if [ -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.sth ];
    then
        cp -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.sth $CERTDIR/TWSClientKeyStore.sth
        chmod 775 $CERTDIR/TWSClientKeyStore.sth
        mychown wauser:wauser $CERTDIR/TWSClientKeyStore.sth
    fi
    if [ -f $OUTPUT_FILE ]
    then
    	rm -f $OUTPUT_FILE
    fi
    if [ -d $ZIP_INNER_FOLDER ]
    then
        rm -Rf $ZIP_INNER_FOLDER
    fi
    if [ -d /tmp/.self ]
    then
        rm -Rf /tmp/.self
    fi
}

copy_certs (){
#Copy Certificate
    if [ -f $CERTDIR/TWSClientKeyStore.kdb ]
    then
        echo "Copying custom certificate kes TWSClientKeyStore.kdb"
        cp -f $CERTDIR/TWSClientKeyStore.kdb $INSTALL_DIR/ITA/cpa/ita/cert/
        chmod 775  $INSTALL_DIR/ITA/cpa/ita/cert/TWSClientKeyStore.kdb 
        mychown wauser:wauser  $INSTALL_DIR/ITA/cpa/ita/cert/TWSClientKeyStore.kdb
    else
        echo "Custom key store TWSClientKeyStore.kdb not present."
    fi
    if [ -f $CERTDIR/TWSClientKeyStore.sth ]
    then
    echo "Copying stash file TWSClientKeyStore.sth"
        cp -f $CERTDIR/TWSClientKeyStore.sth $INSTALL_DIR/ITA/cpa/ita/cert/
        chmod 775 $INSTALL_DIR/ITA/cpa/ita/cert/TWSClientKeyStore.sth
        mychown wauser:wauser $INSTALL_DIR/ITA/cpa/ita/cert/TWSClientKeyStore.sth
    else
    	echo "Custom stash file TWSClientKeyStore.sth not present."
    fi
}


# Reconfigure agent
reconfigure_agent (){
    COMMAND_DIR="$IMAGESDIR/ACTIONTOOLS/TWSupdate_file"
    cmd="$COMMAND_DIR "

    ls -l $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file
    ls -l $INSTALL_DIR/ITA/cpa/config/JobManager*.ini
    # Update hostname
    echo "Setting hostname = ${AGENTHOSTNAME} in JobManager.ini and JobManagerGWID"
    $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManager.ini FullyQualifiedHostname ${AGENTHOSTNAME}
    $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManagerGW.ini FullyQualifiedHostname ${AGENTHOSTNAME}
    $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/ita/ita.ini tcp_port 0
    $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/ita/ita.ini ssl_port 31114
    
    if [ ! -z "$SERVERHOSTNAME" -a ! -z "$SERVERPORT" ]
        then
        echo "Setting server name = ${SERVERHOSTNAME}:${SERVERPORT}"
        $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManagerGW.ini autostart yes
        $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManager.ini ResourceAdvisorUrl https://localhost:31114/ita/JobManagerGW/JobManagerRESTWeb/JobScheduler/resource
        $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManagerGW.ini ResourceAdvisorUrl https://${SERVERHOSTNAME}:${SERVERPORT}/JobManagerRESTWeb/JobScheduler/resource
        $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManagerGW.ini JobManagerGWURIs https://localhost:31114/ita/JobManagerGW/JobManagerRESTWeb/JobScheduler/resource
        if [ ! -z "$BKMSERVERHOSTNAME" ]
            then
            echo "Setting backup server name = ${BKMSERVERHOSTNAME}"
            $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManagerGW.ini BackupResourceAdvisorUrls  "https://${BKMSERVERHOSTNAME}:${SERVERPORT}/JobManagerRESTWeb/JobScheduler/resource"
        fi
    else
		# zCentric
        $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManagerGW.ini autostart no
        $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManager.ini ResourceAdvisorUrl https://localhost:0/ita/JobManagerGW/JobManagerRESTWeb/JobScheduler/resource
        $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManagerGW.ini JobManagerGWURIs https://localhost:31114/ita/JobManagerGW/JobManagerRESTWeb/JobScheduler/resource
        
        if [ "x$HTTPS" == "xNO" ]
        then
            $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/ita/ita.ini tcp_port 31114
            $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/ita/ita.ini ssl_port 0
        fi
    fi

    if [ -z "$AGENTNAME" ]
        then
        if [ ! -z "$ComputerSystemDisplayName" ]
            then
            AGENTNAME=$ComputerSystemDisplayName
        else
			if [ -f ${BMFILE} ];then
				AGENTNAME=AGT4BM
			else
				AGENTNAME=AGTDFT
			fi
        fi
    fi
    echo "Setting agent display name to ${AGENTNAME}"
    $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManager.ini ComputerSystemDisplayName ${AGENTNAME}
    $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManagerGW.ini ComputerSystemDisplayName ${AGENTNAME}
 
    if [ ! -z "$JobManagerGWID" ]
        then
            GWID=$JobManagerGWID
    fi
    echo "Setting gateway ID = $GWID in JobManager.ini"
    $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManagerGW.ini JobManagerGWID $GWID
    
    if [ ! -z "$AGENTID" ]
        then
        if grep -q "AgentID" $INSTALL_DIR/ITA/cpa/config/JobManager.ini
            then
            echo "AgentID key exists in JobManager.ini file. Updating property to ${AGENTID}"
            $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManager.ini AgentID ${AGENTID}
        else
            echo "AgentID key does not exist in JobManager.ini file. Using provided agent ID ${AGENTID}"
            $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -addRow  $INSTALL_DIR/ITA/cpa/config/JobManager.ini AgentID ${AGENTID}  [ResourceAdvisorAgent]
        fi
    else
        # AGENTID is not set
        echo "Agent ID not specified. Agent will create a new ID."
        $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -delRow $INSTALL_DIR/ITA/cpa/config/JobManager.ini AgentID
    fi

    if [ $MYGID -eq 0 ]; then
      $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManager.ini AllowRoot true
    fi

}

set_properties_from_environment ()
{
. $PROPERTYFILE
}

createPropertyFile () {
    if [ ! -z "$SERVERHOSTNAME" ]
    then
        echo SERVERHOSTNAME=$SERVERHOSTNAME >> $PROPERTYFILE
    fi

    if [ ! -z "$BKMSERVERHOSTNAME" ]
    then
        echo BKMSERVERHOSTNAME=$BKMSERVERHOSTNAME >> $PROPERTYFILE
    fi

    if [ ! -z "$AGENTID" ]
    then
        echo AGENTID=$AGENTID >> $PROPERTYFILE
    fi
    
    if [ ! -z "$AGENTNAME" ]
    then
        echo ComputerSystemDisplayName=$AGENTNAME >> $PROPERTYFILE
    fi
    
    if [ ! -z "$GWID" ]
    then
        echo JobManagerGWID=$GWID >> $PROPERTYFILE
    fi
    
    if [ ! -z "$AGENTHOSTNAME" ]
    then
        echo AGENTHOSTNAME=$AGENTHOSTNAME >> $PROPERTYFILE
    fi
    
    if [ ! -z "$LICENSE" ]
    then
        echo LICENSE=$LICENSE >> $PROPERTYFILE
    fi
    
	mychown wauser:wauser $PROPERTYFILE
	chmod 775 $PROPERTYFILE
}

create_pool() {
    if [ ! -z "$POOLS" ]
    then
      touch $POOL_FILE
      sed -e 's/^"//' -e 's/"$//' <<<"$POOLS" | sed -n 1'p' | tr ',' '\n' | while read pool; do
        grep -q -F "${pool}" $POOL_FILE || echo ${pool} | awk '{$1=$1};1' >> $POOL_FILE
      done
    fi
}

display_properties(){
	echo "LICENSE=$LICENSE"
    echo "CURRENT_AGENTID=$CURRENT_AGENTID"
    echo "RECONFIGURE_AGENT=$RECONFIGURE_AGENT"
    echo "SERVERHOSTNAME=$SERVERHOSTNAME"
    echo "BKMSERVERHOSTNAME=$BKMSERVERHOSTNAME"
    echo "SERVERPORT=$SERVERPORT"
    echo "AGENTID=$AGENTID"
    echo "AGENTNAME=$AGENTNAME"
    echo "AGENTHOSTNAME=$AGENTHOSTNAME"
    echo "MAXWAITONEXIT=$MAXWAITONEXIT"
}

retrieve_properties(){
    CURRENT_AGENTID=$(grep -Po "(?<=^AgentID = ).*" $INSTALL_DIR/ITA/cpa/config/JobManager.ini)
    echo "Reconfiguring is required if RECONFIGURE_AGENT=YES or the current AgentID is empty."
    echo "  RECONFIGURE_AGENT=$RECONFIGURE_AGENT"
    echo "  CURRENT_AGENTID=$CURRENT_AGENTID"
    if [ "$RECONFIGURE_AGENT" == "YES" -o  -z "$CURRENT_AGENTID" ];
    then
        echo "Reconfiguring the agent..."
        if [ -f $PROPERTYFILE ];
        then
            echo "Configuring from the properties in $PROPERTYFILE"
            getKeyStoreFromZip
            copy_certs
            set_properties_from_environment
            reconfigure_agent
        elif [ ! -z "$URI" ];
        then
            echo "Configuring from the zip file downloaded from $URI"
            getPropertiesFromZip
            copy_certs
            set_properties_from_environment
            reconfigure_agent
        else
            echo "Configuring from environment variables..."
            copy_certs
            createPropertyFile
            reconfigure_agent
        fi
    else
        echo "No configuration change requested."
    fi

}

store_agent_ID () {
    currentAgentId=$(grep -Po "(?<=^AgentID = ).*" $INSTALL_DIR/ITA/cpa/config/JobManager.ini )
    if [ ! -z "$currentAgentId" ]
        then
        if [ -f $PROPERTYFILE ]
        then
            AGENTID=$(grep -Po "(?<=^AGENTID=).*" $PROPERTYFILE)
            if [ ! -z "$AGENTID" ]
            then
                $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $PROPERTYFILE AGENTID ${currentAgentId}
            else
                # add value
                echo AGENTID=$currentAgentId >> $PROPERTYFILE
            fi
        else
            # add value
            echo AGENTID=$currentAgentId >> $PROPERTYFILE
        fi
    fi
 }

exit_gracefully() {
    # stop the agent
    echo "Caught kill signal. Shutting down agent"
    $INSTALL_DIR/ShutDownLwa
    # wait for completion of all the jobs
	wait_for_jobs_completion
}

count_running_procs()
{	
	PROC_NAME=$1
	PROC_COUNT=0
	if [ ! -z ${PROC_NAME} ];then
		PROC_COUNT=$(pgrep ${PROC_NAME} | wc -w)
	fi
	return ${PROC_COUNT}
}

count_running_jobs()
{
	PREVIOUS_JOBS=$1
  	count_running_procs ${TASKLAUNCHER_PROC}
  	CURRENT_JOBS=$?
    CDATE=`date -u +"%Y-%m-%d %H:%M:%S"`
    [ ${CURRENT_JOBS} -ne ${PREVIOUS_JOBS} ] && echo "${CDATE} ${CURRENT_JOBS} jobs running." 
	return ${CURRENT_JOBS}
}

wait_for_jobs_completion() {
	START_TIME=$(date +%s)
	ELAPSED=0
	CLEAN_SHUTDOWN=1
	while [ ${ELAPSED} -le ${MAXWAITONEXIT} ];do
		get_jobs
		if [ $? -eq 0 ]
		then
			CLEAN_SHUTDOWN=0
			ELAPSED=`expr ${MAXWAITONEXIT} + 1`
		else
			CURR_TIME=$(date +%s)
			ELAPSED=$((CURR_TIME - START_TIME))
			sleep 5
		fi
	done
	if [ ${CLEAN_SHUTDOWN} -eq 1 ]
	then
		echo "Timeout expired; agent processes are still running and will be killed!"
	fi
}

get_jobs()
{
	PROCESSES=0
	count_running_procs ${TASKLAUNCHER_PROC}
	TASKLAUNCHER_COUNT=$?
	if [ ${TASKLAUNCHER_COUNT} -gt 0 ];then
		PROCESSES=`expr ${PROCESSES} + ${TASKLAUNCHER_COUNT}`
		echo "${TASKLAUNCHER_COUNT} \"${TASKLAUNCHER_PROC}\" processes are running; waiting for shutdown..."
	else
		count_running_procs ${JOBMANAGER_PROC}
		JOBMANAGER_COUNT=$?
		if [ ${JOBMANAGER_COUNT} -gt 0 ];then
		   	PROCESSES=`expr ${PROCESSES} + ${JOBMANAGER_COUNT}`
			echo "${JOBMANAGER_PROC} process is running; waiting for shutdown..."
		fi
	fi
	return ${PROCESSES}
}

check_license() {
	LICENSE_VAR=`echo ${LICENSE}|tr "[:lower:]" "[:upper:]"`
	if [ "$LICENSE_VAR" != "ACCEPT" ]
    then
        echo "License agreement not accepted. Add LICENSE=ACCEPT parameter to accept the license agreement."
        exit -66
    fi
}    

mychown() {
  if [ $MYUID -eq 0 ]; then
    chown $*
  fi
}

rm -rf /tmp/*

#Check if passed value contains a valid number
if [ -z "${MAXWAITONEXIT##*[!0-9]*}" ]
then
	echo "Wrong value for MAXWAITONEXIT: \"${MAXWAITONEXIT}\". Expected integer number."
	MAXWAITONEXIT=60
else
	if [ ${MAXWAITONEXIT} -gt 3600 ]
	then
		echo "Wrong value for MAXWAITONEXIT: \"${MAXWAITONEXIT}\". Maximum allowed value is 3600."
		${MAXWAITONEXIT}=3600
	fi
fi

# Check if container already started with different user
if [ -f $PROPERTYFILE ]; then
    propuid=`stat -c '%u' $PROPERTYFILE`
    if [ $propuid -ne $MYUID ]; then
        ACTION_TOOL_RET_COD=4
        ACTION_TOOL_RET_STDOUT="ERROR: The container is started with uid=$MYUID, but the volume mounted on /home/wauser/TWA/TWS/stdlist has been used with uid=$propuid. Restart with uid=$propuid or with an empty volume"
		exitOnError
    fi
fi

if ! whoami &> /dev/null; then
  if [ -w /etc/passwd ]; then
    echo "Replacing wauser to $MYUID:$MYGID"

    #get current wauser
    p=`cat /etc/passwd | grep wauser`
    IFS=":" tokens=( $p )
    cuid=${tokens[2]}
    cgid=${tokens[3]}
    sed "s/$cuid:$cgid/$MYUID:$MYGID/g" /etc/passwd > /tmp/passwd
    cp /tmp/passwd /etc/passwd
    rm /tmp/passwd
  fi
fi

# Check if we are in the new BM Kube env
if [ -z "$URI" ]
then
	if [ -f "$SECRETMOUNTPATH/binding" ]
	then
		echo "Using $SECRETMOUNTPATH/binding secret."
	   URI=$(jq -r '.agent_config_url' $SECRETMOUNTPATH/binding)
	   CURRENT_PASSWORD=$(jq -r '.password' $SECRETMOUNTPATH/binding)
	   CURRENT_USER=$(jq -r '.userId' $SECRETMOUNTPATH/binding)
	else
		if [ -f "$SECRETMOUNTPATH/agent_config_url" ]
		then
			echo "Using $SECRETMOUNTPATH/agent_config_url secret."
			URI=`cat ${SECRETMOUNTPATH}/agent_config_url`
		fi
		if [ -f "$SECRETMOUNTPATH/password" ]
		then
			echo "Using $SECRETMOUNTPATH/password secret."
			CURRENT_PASSWORD=`cat ${SECRETMOUNTPATH}/password`
		fi
		if [ -f "$SECRETMOUNTPATH/userId" ]
		then
			echo "Using $SECRETMOUNTPATH/userId secret."
			CURRENT_USER=`cat ${SECRETMOUNTPATH}/userId`
		fi
	fi
fi

#this section has been commented because now the container runs as no-root, so these changes get permission denied error
if [ ! -f ${BMFILE} ];then
	check_license
#	mychown ${WA_USER}:${WA_USER} $CONFIGURATIONFILESDIR
#	chmod 775 $CONFIGURATIONFILESDIR
#else
#	# modify stdlist access rights for bluemix
#	chmod 777 $CONFIGURATIONFILESDIR
fi

retrieve_properties
display_properties
create_pool
sleep 10

export RECONFIGURE_AGENT=NO
# Start Agent
$INSTALL_DIR/StartUpLwa
sleep 30
store_agent_ID
# infinite loop for the agent
runningJobs=9999
agentPID=$(pgrep ${AGENT_PROC})
while [ ! -z "$agentPID" ]
  do
	count_running_jobs ${runningJobs}
	runningJobs=$?
    sleep 30
    agentPID=$(pgrep ${AGENT_PROC})
  done
RC=$?
exit $RC
