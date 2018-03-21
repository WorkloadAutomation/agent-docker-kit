# Creating a Docker image to run dynamic and z-centric agents

You can run dynamic and z-centric agents in docker container, this can be used to run jobs remotely, e.g. to call REST APIs or database stored procedures, or to run jobs within the container.

You can just follow the instructions to create a docker container that can run jobs remotely, or you can customize those sample to fit your needs, or you can use it as base image for other images that adds the applications to run with the agent.

## Before you begin
Before you start to prepare, build the Docker image or install it, ensure you have met the following requirements:
 - A Linux server with Docker already installed
 - Have a basic knowledge about Docker commands.

## Build the docker image
The scripts in the project allow the installation of docker image:
 1. **agent-docker-kit/Dockerfile**, the build definition file for the image;
 2. **agent-docker-kit/build-docker.sh**, a wrapper script for the  docker build  command;
 3. **agent-docker-kit/start.sh**, a file used to customize the container;
 4. **agent-docker-kit/common-password**, a file used to customize the operating system in the container;
 5. **agent-docker-kit/login.defs**, a file used to customize the operating system in the container.

Perform the following steps to build the Docker image:
Run **build-docker-sh** to build the container. This script wraps the docker build command to build the agent image. The following parameters are supported:

**-h**

Dispalys the command usage.

**-z,--zipfile**

Specifies the .zip file of the image for the agent installation. 

**-p,--port  HTTPS_port**

Specifies the HTTPS port of the temporary nginx server.

**\[-v,--agver  agent version\]**

Optionally specifies the version of the agent to be used to tag the Docker image. The default value is  9.4.0.01.

**\[-t,--imgname  image name\]**

Optionally specifies the name of the image to be built. The default value is  **workload-scheduler-agent**.

To build a new image run the following command:  
```./build-docker.sh -z <agent_zip_full_path>/TWS94FP1_LNX_X86_64_AGENT.zip```

To see the image just built run the following command:
```docker image```  

The command output is similar to the following:  
```
REPOSITORY          TAG        IMAGE ID         CREATED            SIZE
workload-scheduler-agent  9.4.0.01    af42b367cb55    About an hour ago    815.5 MB
```

## Run the docker container 
The build script creates two docker-compose YAML file called **docker-compose.yml** and **docker-compose-zcentric.yml**. Optionally edit those files to specify custom runtime parameters.

The **docker-compose.yml** file is to run the container as dynamic agent connected to a distributed master and contains the following customizable parameters:

**SERVERHOSTNAME**  
The URL of the  master domain manager. This parameter corresponds to the  ResourceAdvisorUrl  property in *theJobManagerGW.ini*  file.

**BKMSERVERHOSTNAME**  
The name of the  backup master domain manager. This parameter corresponds to the  *BackupResourceAdvisorUrls*  property in *theJobManagerGW.ini*  file.

**SERVERPORT**  
The port of the  master domain manager. This parameter corresponds to the  *ResourceAdvisorUrl*  and  *BackupResourceAdvisorUrls* properties in the *JobManagerGW.ini* file.

**AGENTID**  
The ID of the agent.

**AGENTNAME**  
The name of the agent. This parameter corresponds to the  *ComputerSystemDisplayName*  property in the *JobManager.ini*  file.

**AGENTHOSTNAME**  
The hostname of the agent. This parameter corresponds to the  hostname  property in the *JobManager.ini*  file and to the  *FullyQualifiedHostname * and *ResourceAdvisorUrl*  properties in the  *JobManagerGWID*  file.

**POOLS**  
Specify a comma-separated list of pool workstations where you want to register the agent.

**RECONFIGURE\_AGENT**  
Set to  YES  to force a refresh of all configuration options. To maintain the last configuration, set CURRENT\_AGENTID="" and RECONFIGURE\_AGENT=NO.  

The **docker-compose-zcentric.yml** is to run the container as z-centric agent connected to z/OS Controller, you can edit it to set the following customizable parameter:

**HTTPS**  
Set to YES to use secured version of HTTP. NO otherwise. The default value is YES.


Run one of the following commands to start the container:  
 ```docker-compose up -d```  
 or  
 ```
 docker run -e AGENTNAME=AGENT1 -e AGENTID=C0C04D8E238711E78E0F99F382VAA104 \
 -e SERVERHOSTNAME=ws94mdm0 \
 -e SERVERPORT=31116 -e RECONFIGURE_AGENT=NO workload-scheduler-agent:9.4.0.01
 ```
 To start more container instances, run the following command:  
 ```docker-compose up scale iws_agent=num_instances```  

 For z-centric agent, start the container, issuing:  
 ```docker-compose -f docker-compose-zcentric.yml up -d```  
  
