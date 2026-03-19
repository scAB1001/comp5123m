#!/bin/bash

# Make read-only
# chmod 400 vm-ab_key.pem

# SSH into your virtual machine via public IP from local machine
# Get your current public IP
curl ifconfig.me && echo

# Lab Machine
ssh -v -i ~/github-projects/uni/comp5123m/vm-ab_key.pem azureuser@20.90.75.243
ssh -v -i ~/github-projects/uni/comp5123m/vm-edge_key.pem azureuser@40.120.43.27

# # Lenovo
# ssh -v -i ~/github-projects/uni/sem2/comp5123m/vm-ab_key.pem azureuser@20.90.75.243
# ssh -v -i ~/github-projects/uni/sem2/comp5123m/vm-edge_key.pem azureuser@40.120.43.27


# Your Edge VM Internal IP is: 10.0.0.5

# Open browser window for Prometheus web UI
firefox http://20.90.75.243:9090/query

# pass for grafana
# nLpY9FM%8t'V~^2

# user, pass and PAT for docker registry
# scab1001
# $:tyjcVSFL8>~hF