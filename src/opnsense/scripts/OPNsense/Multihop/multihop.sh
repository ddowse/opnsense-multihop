#!/bin/sh 

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


# XXX - in an ideal world server_addr would be saved in config.xml
# and pulled from the multihop array itself. Probably going
# to change this. 

funcROUTE() {
SRVIP=$(pluginctl -g openvpn.openvpn-client | \
        jq '.[] | select(.vpnid=="'$(sed -n ''"$1"'p' $CONF)'")' | \
        jq '.server_addr' | \
        tr -d \")
}

#Before we start make sure all tunnels are down
funcSTOP() {
for i in $( cat $CONF )
do
    if [ -S /var/etc/openvpn/client$i.sock ]; then
        echo "signal SIGTERM" | \
            nc -N -U /var/etc/openvpn/client$i.sock > /dev/null

        if [ $? ]; then 
            echo "Error: Killing client $i failed"
        fi
    fi
done
}

funcSTART() {

#TODO forward this to the GUI
if [ $CCOUNT -lt 1 ]; then
    echo "Need at least 2 Clients"
    exit 1
else

funcSTOP

COUNT=1

for i in $( cat $CONF )
do
    # Call the function to get server_addr from config.xml
    # from the next vpn client in your list
    SRVCOUNT=$(expr $COUNT + 1)
    funcROUTE $SRVCOUNT
   
    # We use this for all clients but the last
    # We bring the tunnel up with and set the routing table
    # so that the next tunnel will be using the previous tunnel

    if [ $COUNT -lt $CCOUNT ]; then
        openvpn --config /var/etc/openvpn/client$i.conf \
        --route-nopull \
        --route-noexec \
        --route-up "/usr/local/opnsense/scripts/OPNsense/Multihop/addroute.sh $SRVIP"

        # lets wait some seconds to establish the connection
        # before we check the status

        sleep 5;
        echo "state all" | \
            nc -N -U /var/etc/openvpn/client$i.sock | \
            grep CONNECTED  > /dev/null

           if [ $? ]; then
               echo "Error: Initial client $i failed to start"
               funcSTOP
               exit
           fi
       else
        # This should run when all other tunnels are up and 
        # will use the options in config.xml / WebGUI 
        openvpn --config /var/etc/openvpn/client$i.conf
        sleep 5;

                    echo "state all" | \
                        nc -N -U /var/etc/openvpn/client$i.sock | \
                        grep CONNECTED 

                    if [ $? ]; then
                        funcSTOP
                        echo "Error: Next client $i failed to start"
                        exit
                    fi
    fi
done
fi
}

funcCHECK() {
for i in $( cat $CONF )
do
    echo "state all" | \
        nc -N -U /var/etc/openvpn/client$i.sock | \
        grep CONNECTED 

    if [ $? ]; then
        funcSTOP
        rm /var/run/multihop.pid
        echo "Error: Checking Client $i"
        exit
    fi
done
touch /var/run/multihop.pid
}

case $1 in
    start)  funcSTOP
            funcSTART
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

