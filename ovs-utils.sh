#!/bin/bash

Usage() {
    echo "$0 Bootstrap|ProbeOvsKernelModule|StartOvsDb|StartOvsSwitch"
    exit 1
}

Bootstrap() {
    local dst=$HOME/workspace/ovs
    if [ ! -f $dst ]; then
        git clone https://github.com/openvswitch/ovs.git $dst
    fi
    sudo apt-get install -y autoconf automake libtool
    cd $dst
    ./boot.sh
    ./configure
    make -j `cat /proc/cpuinfo | grep processor | wc  | awk '{print $1}'`
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

SetupEnv() {
    local dst=$HOME/workspace/shell-dev-env
    git clone https://github.com/rightson/shell-dev-env $dst
    ln -s $dst $HOME/.env
}

if [ -z $1 ]; then
    Usage
else
    $*
fi

