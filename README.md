# Preparing and installing a Docker image for dynamic agents and z-centric

## Before you begin
Before you start to prepare, build the Docker image or install it, ensure you have met the following requirements:
 - A Linux server with Docker already installed
 - Have a basic knowledge about Docker commands.

## About this task
The scripts in the project allow the installation of docker image:
 1. **agent-docker-kit/Dockerfile**, the build definition file for the image;
 2. **agent-docker-kit/build-docker.sh**, a wrapper script for the  docker build  command;
 3.  **agent-docker-kit/start.sh**, a file used to customize the container;
 4. **agent-docker-kit/common-password**, a file used to customize the operating system in the container;
 5. **agent-docker-kit/login.defs**, a file used to customize the operating system in the container.

Perform the following steps to build the Docker image:
Run **build-docker-sh** to build the container. This script wraps the docker build command to build the agent image. The following parameters are supported:

**-h**

Dispalys the command usage.

**-z,--zipfile**

Specifies The .zip file of the image for the agent installation. 
Zip's Download available on master domain manager: 
```https://<server_hostmame>:<https_port>/ConfigDownloadWeb/DownloadAgentServlet?osType=LINUX_X86_64&osArch=X86_64&version=<agent_version>&action=update```  

*https_port* default value is  31116   
*agent_version* see -v --agver option, for the right value


**-p,--port  HTTPS_port**

Specifies the HTTPS port of the temporary nginx server.

**\[-v,--agver  agent version\]**

Optionally specifies the version of the agent to be used to tag the Docker image. The default value is  9.4.0.01.

**\[-t,--imgname  image name\]**

Optionally specifies the name of the image to be built. The default value is  **workload-scheduler-agent**.

1. To build a new image run the following command:  
```./build-docker.sh -z <agent_zip_full_path>/TWS94FP1_LNX_X86_64_AGENT.zip```

2. The build script creates a YAML file called **docker-compose.yml**. To create a container starting from the image, run the following command:  
```docker image```  
The command output is similar to the following:  
	```
	REPOSITORY          TAG        IMAGE ID         CREATED            SIZE
	workload-scheduler-agent  9.4.0.01    af42b367cb55    About an hour ago    815.5 MB
	```
3. Optionally edit the **docker-compose.yml** file to specify custom runtime parameters.
The  **docker-compose.yml**  file contains the following customizable parameters:

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

Set to  YES  to force a refresh of all configuration options. To maintain the last configuration, set CURRENT\_AGENTID="" and RECONFIGURE\_AGENT=NO.  

For z-centric agent, the build script creates a YAML file called **docker-compose-zcentric.yml**.   
Also you can edit it for the following further customizable parameter:

**HTTPS**  
Set to YES to use secured version of HTTP. NO otherwise. The default value is YES.


 4. Run one of the following commands to start the container:  
 ```docker-compose up -d```  
 or  
 ```docker run```  
 To start more container instances, run the following command:  
 ```docker-compose up scale iws_agent=num_instances```  

  For z-centric agent, start the container, issuing:  
  ```docker-compose -f docker-compose-zcentric.yml up -d```  
  
The following example shows how to install a Dynamic Agent using the docker run command:  
```
docker run -e AGENTNAME=AGENT1 -e AGENTID=C0C04D8E238711E78E0F99F382VAA104 
-e SERVERHOSTNAME=ws94mdm0 
-e SERVERPORT=31116 -e RECONFIGURE_AGENT=NO workload-scheduler-agent:9.4.0.01
```
