####################################################################
# Licensed Materials �Property of HCL*
# 
# (c) Copyright HCL Technologies Ltd. 2017-2018 All rights reserved.
# * Trademark of HCL Technologies Limited
####################################################################
# Docker image based on ubi8/ubi:latest image
FROM registry.access.redhat.com/ubi8/ubi:latest

USER 0

# Install some useful Linux package
RUN echo "Installing useful packages" \
  && yum update --disableplugin=subscription-manager -y \
  && yum install --disableplugin=subscription-manager libstdc++.i686 libstdc++ wget unzip vim net-tools curl iputils bind-utils hostname procps -y \
  && rm -rf /var/cache/yum