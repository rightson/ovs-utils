#!/bin/bash

export LC_ALL=C
export DEFAULT_RYU=$HOME/workspace/ryu
export DEFAULT_OVS=$HOME/workspace/ovs

Usage() {
    echo "$0 InstallRyu|StartRyuWeb|InstallOvs|StartOvs|ProbeOvsKernelModule|StartOvsDb|StartOvsSwitch"
    exit 1
}

InstallPip() {
    sudo apt-get install -y python-pip
    pip install --upgrade pip
}

InstallVirtualenv() {
    sudo apt-get install -y python-virtualenv
}

GetCpuInfo() {
    cat /proc/cpuinfo | grep processor | wc | awk '{print $1}'
}

InstallRyu() {
    local dst=$1
    if [ -z $dst ]; then
        dst=$DEFAULT_RYU
    fi
    if [ ! -d $dst ]; then
        git clone git://github.com/osrg/ryu.git $dst
    fi
    InstallPip
    InstallVirtualenv
    cd $dst
    virtualenv venv
    venv/bin/pip install six
    venv/bin/pip install .
}

StartRyuWeb() {
    local dst=$1
    if [ -z $dst ]; then
        dst=$DEFAULT_RYU
    fi
    cd $dst
    venv/bin/ryu-manager --observe-links ryu/app/gui_topology/gui_topology.py ryu/app/simple_switch_websocket_13.py
}

InstallOvs() {
    local dst=$1
    if [ -z $dst ]; then
        dst=$DEFAULT_OVS
    fi
    if [ ! -d $dst ]; then
        git clone https://github.com/openvswitch/ovs.git $dst
    fi
    sudo apt-get install -y autoconf automake libtool
    cd $dst
    ./boot.sh
    ./configure
    make -j `GetCpuInfo`
    sudo make install
    ProbeOvsKernelModule
    sudo mkdir -p /usr/local/etc/openvswitch
    sudo ovsdb-tool create /usr/local/etc/openvswitch/conf.db vswitchd/vswitch.ovsschema
}

ProbeOvsKernelModule() {
    sudo /sbin/modprobe openvswitch
    lsmod | grep openvswitch
}

StartOvsDb() {
    ProbeOvsKernelModule
    sudo ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
    --private-key=db:Open_vSwitch,SSL,private_key \
    --certificate=db:Open_vSwitch,SSL,certificate \
    --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert --pidfile --detach
    ps aux | grep ovsdb-server
}

StartOvsSwitch() {
    StartOvsDb
    sudo ovs-vswitchd --pidfile --detach
    ps aux | grep ovs-vswitchd
}

StartOvs() {
    StartOvsDb
    StartOvsSwitch
}

SetupEnv() {
    local dst=$1
    if [ -z $dst ]; then
        dst=$HOME/workspace/shell-dev-env
    fi
    git clone https://github.com/rightson/shell-dev-env $dst
    ln -s $dst $HOME/.env
}

if [ -z $1 ]; then
    Usage
else
    $*
fi

