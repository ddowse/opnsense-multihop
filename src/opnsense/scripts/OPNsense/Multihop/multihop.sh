#!/bin/sh 
#set -x
# Copyright (C) 2021 Daniel Dowse <dev@daemonbytes.net>

# All rights reserved.
# 
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
# 
# 1. Redistributions of source code must retain the above copyright notice,
#    this list of conditions and the following disclaimer.
# 
# 2. Redistributions in binary form must reproduce the above copyright
#    notice, this list of conditions and the following disclaimer in the
#    documentation and/or other materials provided with the distribution.
# 
# THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED WARRANTIES,
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE
# AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY,
# OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.

VPNID=$(pluginctl -g OPNsense.multihop | jq -r '.[].client[]? | .vpnid')
ROUTE=$(pluginctl -g OPNsense.multihop | jq -r '.general.setroute')
AUTO=$(pluginctl -g OPNsense.multihop | jq -r '.general.autorestart')
INET6=$(pluginctl -g OPNsense.multihop | jq -r '.general.inet6')
DFL_ROUTE=$(netstat -4nr | grep default | awk '{ print $2}')
HOPS=$(echo $VPNID | wc -w)
COUNT=1
PID=/var/run/multihop.pid

func_addroute() {
    func_nexthopip $1
    route add -host $SRVIP $DFL_ROUTE
}

func_delroute() {
    func_nexthopip $1
    route del -host $SRVIP $DFL_ROUTE
}

#Return server_addr from config.xml by vpnid
func_nexthopip() {
    SRVIP=$(pluginctl -g openvpn.openvpn-client | \
        jq '.[] | select(.vpnid=="'$1'")' | jq -r '.server_addr')
    }

#Stop all tunnels
func_stop() {
    #XXX this looks buggy
    for pid in $(ls /var/run/dpinger-multihop*)
    do
        kill $(cat $pid)
    done

    for ID in $VPNID
    do
        if [ -S /var/etc/openvpn/client$ID.sock ]; then
            echo "signal SIGTERM" | \
                nc -N -U /var/etc/openvpn/client$ID.sock > /dev/null

            if [ $? -gt 0 ]; then 
                echo "Error: Killing client $ID failed"
            fi
        fi
    done

    #XXX this could lead to problems
    IP=$( echo $VPNID | awk '{ print $1 }' )
    func_delroute $IP

    if [ -e $PID ]; then
        rm $PID
        echo "stopped"
    else
        echo "multihop not running"
    fi
}

func_check() {
    if [ -e $PID ]; then
        for ID in $VPNID
        do
            echo "state all" | \
                nc -N -U /var/etc/openvpn/client$ID.sock | \
                grep CONNECTED > /dev/null

            if [ $? -gt 0 ]; then
                func_stop
                echo "Error: Checking Client $ID"
                echo "Programm stopped"
                exit 1
            fi
        done
        echo "multihop is running"
        return 0
    else
        echo "multihop is not running"
        return 1
    fi
}

func_start() {

#TODO forward this to the GUI and check 
if [ $HOPS -lt 1 ]; then
    echo "Need at least 2 Clients"
    exit 1
else

    # Set static route
    if [ $ROUTE -eq 1 ]; then
        IP=$( echo $VPNID | awk '{ print $1 }' )
        func_addroute $IP
    fi

    if [ $INET6 -eq 1 ]; then
        NET6='--redirect-gateway ipv6'
    fi

    #Bring up the tunnels

    for HOP in $VPNID
    do
        COUNT=$( expr $COUNT + 1 )
        IP=$( echo $VPNID | awk '{ print $'"$COUNT"' }' )
        if [ $COUNT -le $HOPS ]; then

    #Get the IP to pass to --route-up command
    func_nexthopip $IP

    #Start Tunnel
    openvpn --config /var/etc/openvpn/client$HOP.conf \
        --route-nopull \
        --route-noexec \
        --redirect-gateway def1 \
        --route-up "/usr/local/opnsense/scripts/OPNsense/Multihop/addroute.sh $SRVIP"

        # lets wait some seconds to establish the connection
        # before we check the status

        sleep 5;

        echo "state all" | \
            nc -N -U /var/etc/openvpn/client$HOP.sock | \
            grep CONNECTED  > /dev/null

        if [ $? -gt 0 ]; then
            echo "Error: Initial client $HOP failed to start"
            func_stop
        fi
    else
        #Start last tunnel
        openvpn --config /var/etc/openvpn/client$HOP.conf \
            --route-nopull \
            --redirect-gateway def1 \
            $NET6

        sleep 5;

                    echo "state all" | \
                        nc -N -U /var/etc/openvpn/client$HOP.sock | \
                        grep CONNECTED 

                    if [ $? -gt 0 ]; then
                        func_stop
                        echo "Error: Next client $HOP failed to start"
                        func_stop
                    fi
        fi
    done

    touch $PID

    if [ $AUTO -eq 1 ]; then
        DPING=$(netstat -4nr | grep ovpnc | grep UGS | \
            awk '{ print $2 }' | sort -u)

        for GW in $DPING
        do 
            dpinger -o /dev/null -S -L 35% \
                -C "/usr/local/opnsense/scripts/OPNsense/Multihop/multihop.sh restart" \
                -p /var/run/dpinger-multihop-`echo $GW | sed 's/\./-/g'`.pid $GW
            done
    fi
fi
#End Tunnel Function
}


case $1 in
    start)  func_start
        func_check
        ;;
    stop)   func_stop
        ;;
    restart) func_stop
        func_start
        func_check
        ;;
    status) func_check
        ;;
    *)  echo "No Command given" 
        echo "start/stop/restart"
        ;;
esac

