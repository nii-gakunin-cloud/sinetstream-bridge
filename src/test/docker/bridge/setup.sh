#!/bin/sh
set -eux
apt update
apt install -y iproute2
apt install -y telnet
apt install -y pip
apt install -y vim
apt install -y less
apt install -y procps
apt install -y daemon
pip install sinetstream_cli
