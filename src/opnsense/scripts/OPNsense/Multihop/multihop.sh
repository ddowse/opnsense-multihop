#!/bin/sh 
set -x
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
#set -x 
#set -e 

IFS=$'\n'
CONF=/usr/local/etc//multihop.conf
CCOUNT=$(cat $CONF | wc -l)
COUNT=1
PID=/var/run/multihop.pid
ROUTE=$(pluginctl -g OPNsense.multihop | jq '.general.setroute' | tr -d \")

# XXX - in an ideal world server_addr would be saved in config.xml
# and pulled from the multihop array itself. Probably going
# to change this. 

funcDFLTROUTE() {
        DFL_ROUTE=$(netstat -4nr | grep default | awk '{ print $2}')
        funcSRVIP 1
        route add -host $SRVIP $DFL_ROUTE
    }

funcSRVIP() {
SRVIP=$(pluginctl -g openvpn.openvpn-client | \
        jq '.[] | select(.vpnid=="'$(sed -n ''"$1"'p' $CONF)'")' | \
        jq '.server_addr' | \
        tr -d \")
}

#Before we start make sure all tunnels are down
funcSTOP() {
kill $(cat /var/run/dpinger-multihop.pid)
if [ -e $PID ]; then
for i in $( cat $CONF )
do
    if [ -S /var/etc/openvpn/client$i.sock ]; then
        echo "signal SIGTERM" | \
            nc -N -U /var/etc/openvpn/client$i.sock > /dev/null

        if [ $? -gt 0 ]; then 
            echo "Error: Killing client $i failed"
        fi
    fi
done
rm $PID
echo "stopped"
else
echo "multihop not running"
fi
}

funcSTART() {

#TODO forward this to the GUI
if [ $CCOUNT -lt 1 ]; then
    echo "Need at least 2 Clients"
    exit 1
else

for i in $( cat $CONF )
do
    if [ -S /var/etc/openvpn/client$i.sock ]; then
        echo "signal SIGTERM" | \
            nc -N -U /var/etc/openvpn/client$i.sock > /dev/null
fi
done

for i in $( cat $CONF )
do
    # Call the function to get server_addr from config.xml
    # from the next vpn client in your list
    COUNT=$( expr $COUNT + 1 )
    #SRVCOUNT=$(expr $COUNT + 1)
    funcSRVIP $COUNT

    if [ $ROUTE -eq 1 ]; then
        funcDFLTROUTE
    fi

    # We use this for all clients but the last
    # We bring the tunnel up with and set the routing table
    # so that the next tunnel will be using the previous tunnel

    # redirect-gateway this is mandatory or $route_vpn_gateway is empty/not available for
    # route-up 

#   route add -host $(grep remote /var/etc/openvpn/client$i.conf | cuf -f 2 -d " ")

    if [ $COUNT -le $CCOUNT ]; then
        openvpn --config /var/etc/openvpn/client$i.conf \
        --route-nopull \
        --route-noexec \
    	--redirect-gateway def1 \
        --route-up "/usr/local/opnsense/scripts/OPNsense/Multihop/addroute.sh $SRVIP"

        # lets wait some seconds to establish the connection
        # before we check the status

        sleep 5;
        echo "state all" | \
            nc -N -U /var/etc/openvpn/client$i.sock | \
            grep CONNECTED  > /dev/null

           if [ $? -gt 0 ]; then
               echo "Error: Initial client $i failed to start"
               funcSTOP
               exit
           fi
       else
        # This should run when all other tunnels are up and 
        # will use the options in config.xml / WebGUI 
        openvpn --config /var/etc/openvpn/client$i.conf \
    	--redirect-gateway def1
        sleep 5;

                    echo "state all" | \
                        nc -N -U /var/etc/openvpn/client$i.sock | \
                        grep CONNECTED 

                    if [ $? -gt 0 ]; then
                        funcSTOP
                        echo "Error: Next client $i failed to start"
                        exit
                    fi
    fi
done
touch $PID

dpinger -o /dev/null -S -L 35% \
-C "/usr/local/opnsense/scripts/OPNsense/multihop restart" \
-p /var/run/dpinger-multihop.pid $SRVIP

fi
}

funcCHECK() {
if [ -e $PID ]; then
for i in $( cat $CONF )
do
    echo "state all" | \
        nc -N -U /var/etc/openvpn/client$i.sock | \
        grep CONNECTED > /dev/null

    if [ $? -gt 0 ]; then
        funcSTOP
        rm $PID
        echo "Error: Checking Client $i\n"
	echo "Programm stopped\n"
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

case $1 in
    start)  funcSTART
            funcCHECK
         ;;
    stop)   funcSTOP
        ;;
    restart) funcSTOP
             funcSTART
             funcCHECK
            ;;
    status) funcCHECK
            ;;
    *)  echo "No Command given" 
        echo "start/stop/restart"
        ;;
esac

