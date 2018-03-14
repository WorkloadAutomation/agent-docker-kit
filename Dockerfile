####################################################################
# Licensed Materials –Property of HCL*
# 
# (c) Copyright HCL Technologies Ltd. 2017 All rights reserved.
# * Trademark of HCL Technologies Limited
####################################################################
# Docker image based on ubuntu:16.04 LTS image
# ARGS:
# - SERVERHOSTNAME      Specify the full hostname of the Master Domain Manager
# - SERVERPORT          Specify the HTTPS port of the Websphere Application Server of the Master Domain Manager.
# - BUILD_DATE          Specify the build date to be used to tag internally the image
FROM ubuntu:16.04
ARG SERVERHOSTNAME
ARG SERVERPORT=31116
ARG BUILD_DATE
ARG VERSION=9.4.0.0
ENV SERVERHOSTNAME $SERVERHOSTNAME
ENV SERVERPORT $SERVERPORT


# Copy files from local
COPY start.sh /start.sh
COPY login.defs  /tmp/login.defs
COPY common-password /tmp/common-password

# Install some useful Linux package
# create the wauser for tws
# Install workload scheduler agent
RUN apt-get update \
&& apt-get install wget unzip vim net-tools bc curl libcurl3 libcurl3-dev --assume-yes  \
&& echo "Creating group and user for wauser" \
&& groupadd -r wauser && useradd -m -r -g wauser wauser \
&& cd /tmp \
&& mv -f /tmp/common-password /etc/pam.d/common-password \
&& mv -f /tmp/login.defs /etc/login.defs \
&& chmod go-w /var \
&& chmod go-w /usr \
&& chmod go-w /var/log \
&& echo "Downloading the LINUX_X86_64 agent from the server ${SERVERHOSTNAME}..." \
&& wget -q --no-check-certificate -O TWS_LNX_X86_64_AGENT.zip "https://${SERVERHOSTNAME}:${SERVERPORT}/ConfigDownloadWeb/DownloadAgentServlet?osType=LINUX_X86_64&osArch=X86_64&version=${VERSION}&action=update" \
&& unzip  TWS_LNX_X86_64_AGENT.zip \
&& echo "Running '/tmp/TWS/LINUX_X86_64/twsinst -new -uname wauser -acceptlicense yes -tdwbhostname MDM_DOCKER -gateway local -gwid GWID_DOCKER'" \
&& su - wauser -c  '/tmp/TWS/LINUX_X86_64/twsinst -new -uname wauser -acceptlicense yes -tdwbhostname MDM_DOCKER -gateway local -gwid GWID_DOCKER' \
&& chmod 777 /start.sh \
&& /home/wauser/TWA/TWS/_uninstall/ACTIONTOOLS/TWSupdate_file -addRow /home/wauser/TWA/TWS/ITA/cpa/config/JobManager.ini  JobTableDir /home/wauser/TWA/TWS/stdlist Launchers  \
&& sed -i.bak '/AgentID/d'  /home/wauser/TWA/TWS/ITA/cpa/config/JobManager.ini  \
&& /home/wauser/TWA/TWS/_uninstall/ACTIONTOOLS/TWSupdate_file -delRow /home/wauser/TWA/TWS/ITA/cpa/config/JobManager.ini AgentID \ 
&& rm -rf /tmp/*

# Set image entrypoint
ENTRYPOINT ["/start.sh"]

# Set the volume
# VOLUME /home/wauser/TWA/TWS/stdlist

# Set metatag to report version info
LABEL DOCKERFILE.version="1.0" agent.docker.builddate="${BUILD_DATE}"
