# Use ubuntu base
FROM ubuntu:24.04 

# Prevent dpkg interactive dialogues
ENV DEBIAN_FRONTEND=noninteractive

# Install required packages
RUN apt-get update && apt-get install -y \
    bc \
    bison \
    build-essential \
    cpio \
    debhelper \
    device-tree-compiler \
    fakeroot \
    flex \
    gawk \
    gcc-aarch64-linux-gnu \
    git \
    kmod \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# Set the working directory
WORKDIR /opt
