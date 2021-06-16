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

IFS=$'\n'

CONF=/usr/local/etc//multihop.conf
CCOUNT=$(cat $CONF | wc -l | tr -d " ")
COUNT=1
PID=/var/run/multihop.pid

ROUTE=$(pluginctl -g OPNsense.multihop | jq '.general.setroute' | tr -d \")
AUTO=$(pluginctl -g OPNsense.multihop | jq '.general.autorestart' | tr -d \")

#Set static route
funcDFLTROUTE() {
        echo $1
        DFL_ROUTE=$(netstat -4nr | grep default | awk '{ print $2}')
        if [ $1 == "set" ];then
        funcSRVIP 1
        route add -host $SRVIP $DFL_ROUTE
        else
        funcSRVIP 1
        route del -host $SRVIP $DFL_ROUTE
        fi
    }

#Return server_addr from config.xml by vpnid
funcSRVIP() {
SRVIP=$(pluginctl -g openvpn.openvpn-client | \
        jq '.[] | select(.vpnid=="'$(sed -n ''"$1"'p' $CONF)'")' | \
        jq '.server_addr' | \
        tr -d \")
}

#Stop all tunnels
funcSTOP() {
funcDFLTROUTE
for pid in $(ls /var/run/dpinger-multihop*)
do
kill $(cat $pid)
done

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
if [ -e $PID ]; then
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
    COUNT=$( expr $COUNT + 1 )


    # Set the first tunnel + static route if enabled
    if [ $COUNT -le $CCOUNT ]; then

    if [ $ROUTE -eq 1 ]; then
        funcDFLTROUTE "set"
    fi

    funcSRVIP $COUNT

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

        # Start next tunnel 
        openvpn --config /var/etc/openvpn/client$i.conf \
        --route-nopull \
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
if [ $AUTO -eq 1 ]; then
    DPING=$(netstat -4nr | grep ovpnc | grep UGS | awk '{ print $2 }'\
        | sort -u)
    for gw in $DPING
    do 
	dpinger -o /dev/null -S -L 35% \
	-C "/usr/local/opnsense/scripts/OPNsense/Multihop/multihop.sh restart" \
	-p /var/run/dpinger-multihop-`echo $gw | sed 's/\./-/g'`.pid $gw
    done    
	fi 
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

