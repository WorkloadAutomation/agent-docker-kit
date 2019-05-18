####################################################################
# Licensed Materials �Property of HCL*
# 
# (c) Copyright HCL Technologies Ltd. 2017-2018 All rights reserved.
# * Trademark of HCL Technologies Limited
####################################################################
# Docker image based on ubuntu:16.04 LTS image
FROM ubuntu:16.04

USER 0

# Install some useful Linux package
RUN echo "Installing useful packages" \
&& apt-get update \
&& apt-get -y dist-upgrade \
&& apt-get install wget unzip vim net-tools bc curl libcurl3 libcurl3-dev iputils-ping dnsutils --assume-yes \
&& apt-get clean \
&& rm -rf /var/lib/apt/lists/*

