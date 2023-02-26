#!/bin/bash

set -eE 
trap 'echo Error: in $0 on line $LINENO' ERR

if [ "$(id -u)" -ne 0 ]; then 
    echo "Please run as root"
    exit 1
fi

cd "$(dirname -- "$(readlink -f -- "$0")")" && cd ..

# Build the docker container 
docker build -t ubuntu-orange-pi5-build docker

# Invoke build script inside the docker container
docker run --privileged -it -v "$(pwd)":/opt -v /dev:/dev ubuntu-orange-pi5-build /usr/bin/bash ./build.sh
