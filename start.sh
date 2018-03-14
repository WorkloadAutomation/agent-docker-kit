#!/bin/bash
####################################################################
# Licensed Materials –Property of HCL*
# 
# (c) Copyright HCL Technologies Ltd. 2017 All rights reserved.
# * Trademark of HCL Technologies Limited
####################################################################
#
# Entry point script for the Docker Workload Scheduler Agent 
#
####################################################################


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

# Set some defaults
AGUSER=wauser
AGENTHOSTNAME=${AGENTHOSTNAME:-localhost}
INSTALL_DIR=${INSTALL_DIR:-/home/${AGUSER}/TWA/TWS}
SERVERPORT=${SERVERPORT:-31116}
POOL_FILE=$INSTALL_DIR/ITA/cpa/config/pools.properties

#
# These variables are overwritten in the setup script
#
ACTION_TOOL_RET_COD=0
ACTION_TOOL_RET_STDOUT=
CONFIGURATIONFILESDIR=$INSTALL_DIR/stdlist
OUTPUT_FILE=properties_agent.zip
PROPERTYFILENAME=installAgent.properties
PROPERTYFILE=$CONFIGURATIONFILESDIR/$PROPERTYFILENAME
GWID=GWID_${AGENTNAME}_${HOSTNAME}


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
    echo $USER_DECODE $PASSWORD_DECODE
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

    if [ ! -z "$CURRENT_USER" ]
        then
            ACTION_TOOL_RET_COD=1
            ACTION_TOOL_RET_STDOUT="CURRENT_USER is not correctly set."
        else echo "CURRENT_USER: $CURRENT_USER"
    fi

    if [ ! -z "$CURRENT_PASSWORD" ]
        then
            ACTION_TOOL_RET_COD=1
            ACTION_TOOL_RET_STDOUT="CURRENT_PASSWORD is not correctly set."
        else echo "CURRENT_PASSWORD: $CURRENT_PASSWORD"
    fi
    exitOnError
}


# Method to get properties and certificates from URI
getPropertiesFromZip(){
    echo "Running getPropertiesFromZip"
    checkEnvironmentVariables
    decodeUser_Password
    cd /tmp
    # Download the property file and certificates from URI and copy file into the stdlist folder
    if [ ! -z "$URI" ]
    then
        curl -v --tlsv1.2 --user "$USER_DECODE:$PASSWORD_DECODE" --output $OUTPUT_FILE $URI
        unzip $OUTPUT_FILE
        echo "Copying ./$ZIP_INNER_FOLDER/$PROPERTYFILENAME to $PROPERTYFILE"
        cp -f ./$ZIP_INNER_FOLDER/$PROPERTYFILENAME $PROPERTYFILE
        chmod 755 $PROPERTYFILE
        chown wauser:wauser $PROPERTYFILE
        echo "Copying ./$ZIP_INNER_FOLDER/TWSClientKeyStore.kdb to $CONFIGURATIONFILESDIR/TWSClientKeyStore.kdb"
        cp -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.kdb $CONFIGURATIONFILESDIR/TWSClientKeyStore.kdb
        chmod 755  $CONFIGURATIONFILESDIR/TWSClientKeyStore.kdb
        chown wauser:wauser $CONFIGURATIONFILESDIR/TWSClientKeyStore.kdb
        if [ -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.sth ];
        then
            echo "Copying ./$ZIP_INNER_FOLDER/TWSClientKeyStore.sth to $CONFIGURATIONFILESDIR/TWSClientKeyStore.sth"
            cp -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.sth $CONFIGURATIONFILESDIR/TWSClientKeyStore.sth
            chmod 755 $CONFIGURATIONFILESDIR/TWSClientKeyStore.sth
            chown wauser:wauser $CONFIGURATIONFILESDIR/TWSClientKeyStore.sth
        fi
    fi
}

# Method to get certificates from URI
getKeyStoreFromZip(){
    echo "Running getKeyStoreFromZip"
    checkEnvironmentVariables
    decodeUser_Password
    cd /tmp
    # Download the property file and certificates from URI and copy file into the stdlist folder
    if [ ! -z "$URI" ]
    then
        curl -v --tlsv1.2 --user "$USER_DECODE:$PASSWORD_DECODE" --output $OUTPUT_FILE $URI
        unzip $OUTPUT_FILE
        echo "Running command: cp -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.kdb $CONFIGURATIONFILESDIR/TWSClientKeyStore.kdb"
        cp -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.kdb $CONFIGURATIONFILESDIR/TWSClientKeyStore.kdb
        chmod 755  $CONFIGURATIONFILESDIR/TWSClientKeyStore.kdb
        chown wauser:wauser $CONFIGURATIONFILESDIR/TWSClientKeyStore.kdb
    else
        echo "No download server information provided."
    fi
    if [ -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.sth ];
    then
        cp -f ./$ZIP_INNER_FOLDER/TWSClientKeyStore.sth $CONFIGURATIONFILESDIR/TWSClientKeyStore.sth
        chmod 755 $CONFIGURATIONFILESDIR/TWSClientKeyStore.sth
        chown wauser:wauser $CONFIGURATIONFILESDIR/TWSClientKeyStore.sth
    fi
}

copy_certs (){
#Copy Certificate
    if [ -f $CONFIGURATIONFILESDIR/TWSClientKeyStore.kdb ]
    then
        echo "Copying certificate TWSClientKeyStore.kdb"
        cp -f $CONFIGURATIONFILESDIR/TWSClientKeyStore.kdb $INSTALL_DIR/ITA/cpa/ita/cert/
        chmod 755  $INSTALL_DIR/ITA/cpa/ita/cert/TWSClientKeyStore.kdb 
        chown wauser:wauser  $INSTALL_DIR/ITA/cpa/ita/cert/TWSClientKeyStore.kdb
    else
        echo "Certificate TWSClientKeyStore.kdb not present."
    fi
    if [ -f $CONFIGURATIONFILESDIR/TWSClientKeyStore.sth ]
    then
        echo "Configuring the TWSClientKeyStore.sth key store"
        cp -f $CONFIGURATIONFILESDIR/TWSClientKeyStore.sth $INSTALL_DIR/ITA/cpa/ita/cert/
        chmod 755 $INSTALL_DIR/ITA/cpa/ita/cert/TWSClientKeyStore.sth
        chown wauser:wauser $INSTALL_DIR/ITA/cpa/ita/cert/TWSClientKeyStore.sth
        execute_command "$cmd -updateProperty $INSTALL_DIR/ITA/cpa/ita/ita.ini cert_label saasclient"
    fi
}


# Reconfigure agent
reconfigure_agent (){
    COMMAND_DIR="$IMAGESDIR/ACTIONTOOLS/TWSupdate_file"
    cmd="$COMMAND_DIR "

    # Update hostname
    echo "Setting hostname = ${AGENTHOSTNAME} in JobManager.ini and JobManagerGWID"
    $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManager.ini FullyQualifiedHostname ${AGENTHOSTNAME}
    $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManagerGW.ini FullyQualifiedHostname ${AGENTHOSTNAME}
    $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManager.ini ResourceAdvisorUrl https://localhost:31114/ita/JobManagerGW/JobManagerRESTWeb/JobScheduler/resource
    
    $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManagerGW.ini JobManagerGWURIs https://localhost:31114/ita/JobManagerGW/JobManagerRESTWeb/JobScheduler/resource
  
    if [ ! -z "$SERVERHOSTNAME" -a ! -z "$SERVERPORT" ]
        then
        echo "Setting server name = ${SERVERHOSTNAME}:${SERVERPORT}"
        $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManagerGW.ini ResourceAdvisorUrl https://${SERVERHOSTNAME}:${SERVERPORT}/JobManagerRESTWeb/JobScheduler/resource
        if [ ! -z "$BKMSERVERHOSTNAME" ]
            then
            echo "Setting backup server name = ${BKMSERVERHOSTNAME}"
            $INSTALL_DIR/_uninstall/ACTIONTOOLS/TWSupdate_file -updateProperty $INSTALL_DIR/ITA/cpa/config/JobManagerGW.ini BackupResourceAdvisorUrls  "https://${BKMSERVERHOSTNAME}:${SERVERPORT}/JobManagerRESTWeb/JobScheduler/resource"
        fi
    fi

    if [ -z "$AGENTNAME" ]
        then
        if [ ! -z "$ComputerSystemDisplayName" ]
            then
            AGENTNAME=$ComputerSystemDisplayName
        else
            AGENTNAME=AGTDFT
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
    echo "CURRENT_AGENTID=$CURRENT_AGENTID"
    echo "RECONFIGURE_AGENT=$RECONFIGURE_AGENT"
    echo "SERVERHOSTNAME=$SERVERHOSTNAME"
    echo "BKMSERVERHOSTNAME=$BKMSERVERHOSTNAME"
    echo "SERVERPORT=$SERVERPORT"
    echo "AGENTID=$AGENTID"
    echo "AGENTNAME=$AGENTNAME"
    echo "AGENTHOSTNAME=$AGENTHOSTNAME"
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
        else
            if [  ! -z "$SERVERHOSTNAME" ];
            then
                echo "Configuring from environment variables..."
                createPropertyFile
                reconfigure_agent
            else
                if [ ! -z "$URI" ];
                then
                    echo "Configuring from the zip file downloaded from $URI"
                    getPropertiesFromZip
                    copy_certs
                    set_properties_from_environment
                    reconfigure_agent
                else
                    echo "No parameters were set. Not configured."
                fi
            fi
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
}

rm -rf /tmp/*
# modify stdlist access rights for bluemix
chmod 777 $CONFIGURATIONFILESDIR
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
taskCount0=999
agentPID=$(pidof agent)
while [ ! -z "$agentPID" ]
  do
    taskCount=$(pidof taskLauncher | wc -w)
    CDATE=`date -u +"%Y-%m-%d %H:%M:%S"`
    [ $taskCount -ne $taskCount0 ] && echo "$CDATE $taskCount jobs running." 
    sleep 30
    taskCount0=$taskCount
    agentPID=$(pidof agent)
  done
RC=$?
exit $RC


