## Note: this repository only applies to HWA/IWS 9.4, for 9.5 version look at official containers and documentation

| Deployment | IBM Workload Automation | HCL Workload Automation |
|---|---|---|
| Kubernetes with Helm Charts | [ibm-workload-automation-chart](https://github.com/WorkloadAutomation/ibm-workload-automation-chart) | [hcl-workload-automation-chart](https://github.com/WorkloadAutomation/hcl-workload-automation-chart) |
| Docker compose | [ibm-workload-automation-docker-compose](https://github.com/WorkloadAutomation/ibm-workload-automation-docker-compose) | [hcl-workload-automation-docker-compose](https://github.com/WorkloadAutomation/hcl-workload-automation-docker-compose) |


# Creating a Docker image to run dynamic and z-centric agents

You can run dynamic and z-centric agents in docker container, this can be used to run jobs remotely, e.g. to call REST APIs or database stored procedures, or to run jobs within the container.

You can just follow the instructions to create a docker container that can run jobs remotely, or you can customize those sample to fit your needs, or you can use it as base image for other images that adds the applications to run with the agent.

## Before you begin

Before you start to prepare, build the Docker image or install it, ensure you have met the following requirements:

- A Linux server with Docker already installed

- Have a basic knowledge about Docker commands.

## Build the docker image

The scripts in the project allow the installation of docker image:

1. **agent-docker-kit/build-docker.sh**, a wrapper script for the  docker build  command;

1. **agent-docker-kit/Dockerfile**, the build definition file for the image;

1. **agent-docker-kit/\<osname\>.Dockerfile**, the build definition file for the basic OS image with the required prerequisites;

1. **agent-docker-kit/start.sh**, a file used to customize the container;

1. **agent-docker-kit/common-password**, a file used to customize the operating system in the container;

1. **agent-docker-kit/login.defs**, a file used to customize the operating system in the container.

Perform the following steps to build the Docker image:
Run **build-docker-sh** to build the container. This script wraps the docker build command to build the agent image. The following parameters are supported:

 **-h**  
 Dispalys the command usage.

 **-z,--zipfile**  
 Specifies the .zip file of the image for the agent installation. 

 **-p,--port  HTTPS_port**  
 Specifies the HTTPS port of the temporary nginx server.

 **[--os=\<osname\>]**  
 Optionally specifies if base image is ubi (default), ubuntu or centos, \<osname\>.Dockerfile is used to build the os image.

 **[--base=\<baseimg\>]**  
 Optioanlly specifies an existing image to use instead of a plain os image, if --base is specified, --os is ignored

 **[-v,--agver  agent version]**  
 Optionally specifies the version of the agent to be used to tag the Docker image. The default value is  9.4.0.05.

 **[-t,--imgname  image name]**  
 Optionally specifies the name of the image to be built. The default value is  **workload-automation-agent**.

To build a new image run the following command:
```
./build-docker.sh --os=ubi -t wa-agent -v 9.4.0.05 -z <agent_zip_full_path>/TWS94FP1_LNX_X86_64_AGENT.zip
```

To see the image just built run the following command:
```docker images```  

The command output is similar to the following:  
```
REPOSITORY                    TAG         IMAGE ID        CREATED             SIZE
workload-automation-agent     9.4.0.05    59328ed6827e    About an hour ago   1.89GB
```

## Deploy the created image in another envrironment

To Export and import the created image run the following commands:
```
docker save -o <your_path>/workload-automation-agent.tar workload-automation-agent:9.4.0.05
#copy the saved image to a new environment
docker load -i <your_path>/workload-automation-agent.tar
```
To push the created image to the desired private environment registry run the following command:
```
docker tag workload-automation-agent:9.4.0.05 <your_registry_host>:5000/workload-automation-agent:9.4.0.05
docker push <your_registry_host>:5000/workload-automation-agent:9.4.0.05
```
## Run the docker container 
The build script creates a docker-compose YAML file called **docker-compose.yml**. 

To run the container edit this file to specify custom runtime parameters following the comments in the file.

Run one of the following commands to start the container:
```
docker-compose up -d
```
 
To start more container instances, run the following command:
```
docker-compose up scale iws_agent=num_instances
```

To run the container for dynamic agent without docker-compose, use docker command specifying the configuration with environment variables
```
docker run -e AGENTNAME=AGENT1 -e SERVERHOSTNAME=ws94mdm0 -e SERVERPORT=31116 -e LICENSE=ACCEPT -v iws_agent-data:/home/wauser/TWA/TWS/stdlist workload-automation-agent:9.4.0.05
```
or for zCentric
```
docker run -p 31114:31114 -e HTTPS=YES workload-automation-agent:9.4.0.05
```
