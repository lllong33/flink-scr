#!/bin/bash
hostip=$(cat /etc/resolv.conf | grep nameserver | awk '{ print $2 }')
wslip=$(hostname -I | awk '{print $1}')
port=7890
PROXY_SOCKS="socks5://${hostip}:${port}"

function display() {
    echo "Host ip: ${hostip}"
    echo "WSL client ip: ${wslip}"
    echo "current PROXY: ${PROXY_SOCKS}"
}

function set_proxy() {
    export http_proxy="${PROXY_SOCKS}"
    export https_proxy="${PROXY_SOCKS}"
    echo "env http/https proxy set."
}

function unset_proxy() {
    unset http_proxy
    unset https_proxy
    echo "env proxy unset."
}

function set_git_proxy() {
    git config --global http.proxy "${PROXY_SOCKS}"
    git config --global https.proxy "${PROXY_SOCKS}"
    echo "git config proxy set."
}

function unset_git_proxy() {
    git config --global --unset http.proxy
    git config --global --unset https.proxy
    echo "git conffig proxy unset."
}

if [ "$1" = "display" ]; then
    display
elif [ "$1" = "set" ]; then
    set_proxy
elif [ "$1" = "unset" ]; then
    unset_proxy
elif [ "$1" = "setgit" ]; then
    set_git_proxy
elif [ "$1" = "ungit" ]; then
    unset_git_proxy
else
    echo "incorrect arguments."
fi