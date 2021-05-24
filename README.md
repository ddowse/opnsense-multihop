#  _Advanced Users only_

# opnsense-multihop
Multihop with OpenVPN Tunnels on OPNsense

---

Check if your provider supports this. [Perfect Privacy](https://www.perfect-privacy.com/en/features/multi-hop-vpn) is known to support at least 4 Tunnel.   


Build Instructions

``` bash
git clone https://github.com/opnsense/plugins
git clone https://github.com/ddowse/opnsense-multihop plugins/security/openvpn-multihop
cd plugins/security/openvpn-multihop
make package
```

# Install Instructions

Copy the Package from the work/pkg directory to your local testing opnsense and run

``` bash
pkg install os-openvpn-multihop-$VERSION.txz
```

# Usage

1. Go to OpenVPN->Clients and add at least 2 Clients
2. Go to System->Routes->Configuration and add the `Remote IP` of the first Tunnel in the cascade to the Static Routing Table and choose your WAN Gateway as Gatway e.g `85.17.28.145/32 -> Gateway 192.168.1.1` 
3. Go to OpenVPN->Multihop->Tab Clients and add your Clients.
4. Click the Start Button on the top right. 
5. Check your Routing Table, you should see something like `80.255.7.98 -> 10.3.0.1` this indicates that all traffic to the host will be going to the VPN Gateway.

You can also control the tunnel cascade on the shell like this:

```bash
configctl multihop [stop|start|status]
```

Check your IP

```bash
curl -s https://checkip.perfect-privacy.com/json | jq 
``` 

---

# Some simple Technical Information

1. The Plugin will extract the VPNID and creates a list and stores that information in  `/usr/local/etc/multihop.conf`.
1. The Shellscript `/usr/local/opnsense/scripts/OPNsense/Multihop/multihop.sh` will be executed when the service API triggers `configd`.

   1. The Shellscript will read the list of VPNID's from its own conf file.   
   1. Get's the `server_addr` field  of the next VPNID int the list by using `pluginclt` and parse it with `jq`   
   1. The correct `server_addr` is passed to the `--route-up` script. This adds the GW of the current OpenVPN Tunnel to the routing table for `server_addr`. The  Shellscript skips `--route-up` on the last VPNID and set the routing options from the clients settings.

2. The static route to the first tunnel is needed to prevent a network traffic loop. 

The OPNsense OpenVPN Client Configuration is not touched. Altough VPN Clients that are used for mutlihopping should be disabled in OpenVPN->Client or they will 
startup on reboot, too - as this is the default.


You **may** also have to take care of *NAT and Filter settings*.   
Some examples can be found in my other repo [pfSense-pkg-openvpn-multihop](https://github.com/ddowse/pfSense-pkg-openvpn-multihop). 

---

You are welcome to open issues (code/errors) or improve this plugin. It might be a good idea to mix VPN providers and report your results if you want.


The inital idea for VPN Multihopping Plugin was created by a customer who wants to remain anonymous.
The customer also provided some funds to me to realise his idea for him and the opnsense/vpn community as well. 

Thank you!. 

