#!/bin/bash
echo "Host ip: $(cat /etc/resolv.conf | grep nameserver | awk '{ print $2 }')"
echo "WSL client ip: $(hostname -I | awk '{print $1}')"s