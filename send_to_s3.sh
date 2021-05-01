#!/bin/bash

set -xe

# install AWS CLI v2
if ! [[ $(command -v  aws) ]]; then
  echo 'Installing missing CLI tool aws'
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
  unzip awscliv2.zip
  sudo ./aws/install
else 
  echo 'aws already installed'
fi

# copy the tiles to S3

aws s3 cp /tmp/tiles s3://gb-world-maps/map1 --recursive
