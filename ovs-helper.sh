#!/bin/bash

usage() {
	echo "$0 bootstrap|ovsdb|ovs|modprobe|env"
}

modprobe() {
	sudo /sbin/modprobe openvswitch
	lsmod | grep openvswitch
}

bootstrap() {
	local dst=~/workspace/ovs
	if [ ! -f $dst ]; then
    	git clone https://github.com/openvswitch/ovs.git $dst
    fi
    sudo apt-get install -y autoconf automake libtool
    cd $dst
    ./boot.sh
    ./configure
    make -j `cat /proc/cpuinfo | grep processor | wc  | awk '{print $1}'`
    sudo make install
    modprobe
	sudo mkdir -p /usr/local/etc/openvswitch
	sudo ovsdb-tool create /usr/local/etc/openvswitch/conf.db vswitchd/vswitch.ovsschema
} 

ovsdb() {
    modprobe
	sudo ovsdb-server --remote=punix:/usr/local/var/run/openvswitch/db.sock \
	--remote=db:Open_vSwitch,Open_vSwitch,manager_options \
	--private-key=db:Open_vSwitch,SSL,private_key \
	--certificate=db:Open_vSwitch,SSL,certificate \
	--bootstrap-ca-cert=db:Open_vSwitch,SSL,ca_cert --pidfile --detach
	ps aux | grep ovsdb-server

}

start-ovs() {
    ovsdb
	sudo ovs-vswitchd --pidfile --detach
	ps aux | grep ovs-vswitchd
} 

setup-env() {
    local dst=~/workspace/shell-dev-env
    git clone https://github.com/rightson/shell-dev-env $dst
    ln -s $dst ~/.env
}

case $1 in
    bootstrap)  bootstrap;;
    modprobe)   modprobe;;
    ovsdb)      ovsdb;;
    ovs)        start-ovs;;
    env)        setup-env;;
    *)          usage;;
esac

