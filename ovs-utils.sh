#!/bin/bash

export LC_ALL=C
export DEFAULT_SRC_PREFIX=$HOME/workspace
export DEFAULT_RYU_SRC=$DEFAULT_SRC_PREFIX/ryu
export DEFAULT_FLOODLIGHT_SRC=$DEFAULT_SRC_PREFIX/floodlight
export DEFAULT_OVS_SRC=$DEFAULT_SRC_PREFIX/ovs
export OVS_INSTALL_PREFIX=/usr/local

Usage() {
    echo "$0 OPTION"
    echo ""
    echo "OPTION"
    echo "  Ryu Helper:         GetRyuSource | InstallRyu | StartRyu"
    echo "  Floodlight Helper:  GetFloodlightSource | InstallFloodlight | StartFloodlight"
    echo "  OVS Helper:         GetOvsSource | InstallOvs | StartOvs"
    echo "                      StartOvsDb | StartOvsSwitch | ProbeOvsKernelModule"
    exit 0
}

InstallPip() {
    sudo apt-get install -y python-pip
    sudo -H pip install --upgrade pip
}

InstallVirtualenv() {
    sudo apt-get install -y python-virtualenv
}

GetCpuInfo() {
    cat /proc/cpuinfo | grep processor | wc | awk '{print $1}'
}

GetRyuSource() {
    echo "[GetRyuSource]"
    local dst=$1
    if [ -z $dst ]; then
        dst=$DEFAULT_RYU_SRC
    fi
    if [ ! -d $dst ]; then
        git clone git://github.com/osrg/ryu.git $dst
    fi
}

InstallRyu() {
    echo "[InstallRyu]"
    local dst=$1
    if [ -z $dst ]; then
        dst=$DEFAULT_RYU_SRC
    fi
    GetRyuSource $dst
    InstallPip
    InstallVirtualenv
    cd $dst
    virtualenv venv
    venv/bin/pip install six
    venv/bin/pip install .
}

StartRyu() {
    echo "[StartRyuWeb]"
    local dst=$1
    if [ -z $dst ]; then
        dst=$DEFAULT_RYU_SRC
    fi
    cd $dst
    venv/bin/ryu-manager --observe-links ryu/app/gui_topology/gui_topology.py ryu/app/simple_switch_websocket_13.py
}

GetFloodlightSource() {
    echo "[GetFloodlightSource]"
    local dst=$1
    if [ -z $dst ]; then
        dst=$DEFAULT_FLOODLIGHT_SRC
    fi
    if [ ! -d $dst ]; then
        git clone git://github.com/floodlight/floodlight.git $dst
    fi
}

InstallFloodlight() {
    echo "[InstallFloodlight]"
    local dst=$1 
    if [ -z $dst ]; then
        dst=$DEFAULT_FLOODLIGHT_SRC
    fi
    GetFloodlightSource $dst
    sudo apt-get install -y build-essential ant maven python-dev
    ant
    sudo mkdir /var/lib/floodlight
    sudo chmod 777 /var/lib/floodlight
}

StartFloodlight() {
    echo "[StartFloodlight]"
    local dst=$1
    if [ -z $dst ]; then
        dst=$DEFAULT_FLOODLIGHT_SRC
    fi
    cd $dst
    java -jar target/floodlight.jar
}

GetOvsSource() {
    echo "[GetOvsSource]"
    local dst=$1
    if [ -z $dst ]; then
        dst=$DEFAULT_OVS_SRC
    fi
    if [ ! -d $dst ]; then
        git clone https://github.com/openvswitch/ovs.git $dst
    fi
}

InstallOvs() {
    echo "[InstallOvs]"
    local dst=$1
    if [ -z $dst ]; then
        dst=$DEFAULT_OVS_SRC
    fi
    GetOvsSource $dst
    sudo apt-get install -y autoconf automake libtool
    cd $dst
    ./boot.sh
    ./configure
    make -j `GetCpuInfo`
    sudo make install
    ProbeOvsKernelModule
    sudo mkdir -p $OVS_INSTALL_PREFIX/etc/openvswitch
    sudo ovsdb-tool create $OVS_INSTALL_PREFIX/etc/openvswitch/conf.db vswitchd/vswitch.ovsschema
}

ProbeOvsKernelModule() {
    echo "[ProbeOvsKernelModule]"
    sudo /sbin/modprobe openvswitch
    lsmod | grep --color openvswitch
}

StartOvsDb() {
    echo "[StartOvsDb]"
    ProbeOvsKernelModule
    sudo ovsdb-server --remote=punix:$OVS_INSTALL_PREFIX/var/run/openvswitch/db.sock \
    --remote=db:Open_vSwitch,Open_vSwitch,manager_options \
    --private-key=db:Open_vSwitch,SSL,private_key \
    --certificate=db:Open_vSwitch,SSL,certificate \
    --bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert --pidfile --detach
    ps aux | grep --color ovsdb-server
}

StartOvsSwitch() {
    echo "[StartOvsSwitch]"
    StartOvsDb
    sudo ovs-vswitchd --pidfile --detach --log-file
    ps aux | grep --color ovs-vswitchd
}

StartOvs() {
    echo "[StartOvs]"
    StartOvsDb
    StartOvsSwitch
}

StopOvs() {
    echo "[StopOvs]"
    sudo killall -9 ovs-vswitchd ovsdb-server
    sudo /sbin/modprobe -r openvswitch
}

RestartOvs() {
    echo "[RestartOvs]"
    StopOvs
    StartOvs
}

if [ -z $1 ]; then
    Usage
else
    $*
fi

