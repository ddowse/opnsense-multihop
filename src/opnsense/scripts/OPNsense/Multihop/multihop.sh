#!/bin/sh 
set -x 
#set -e 

IFS=$'\n'
CONF=/usr/local/etc/openvpn-multihop/multihop.conf
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

        if [ $? -gt 0 ]; then 
            echo "something wrong with killing client $i"
        fi
    fi
done
}

funcSTART() {

if [ $CCOUNT -lt 1 ]; then
    echo "Need at least 2 Clients"
    exit
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
            grep CONNECTED 

           if [ $? -gt 0 ]; then
               echo "something wrong starting client $i"
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

                    if [ $? -gt 0 ]; then
                        funcSTOP
                        echo "something wrong with starting client $i"
                        echo "Check your logs"
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

    if [ $? -gt 0 ]; then
        echo "something wrong with starting client $i"
        exit
    fi
done
}

case $1 in
    start) funcSTART
         ;;
    stop) funcSTOP
        ;;
    restart) funcSTOP
             funcSTART
            ;;
    *) "No Command given - Please use start/stop/restart - thanks"
esac

