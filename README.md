#  _Advanced Users only_ 

# opnsense-multihop
Multihop with OpenVPN Tunnels on OPNsense



Check if your provider supports this. Perfect Privacy is known to support at least 4 Tunnel. 

Build Instructions

``` bash
git clone https://github.com/opnsense/plugins
git clone https://github.com/ddowse/opnsense-multihop plugins/security/openvpn-multihop
cd plugins/security/openvpn-multihop
make package
```

Install Instructions

Copy the Package from the work/pkg directory to your local testing opnsense and run

``` bash
pkg install os-openvpn-multihop-$VERSION.txz
```

You can also control the tunnel cascade on the shell like this:

```bash
configctl multihop [stop|start|status]
```

You are welcome to open issues (code/errors) or improve this plugin. 


The inital idea for VPN Multihopping Plugin was created by a customer who wants to remain anonymous.
The customer also provided some funds to me to realise his idea for him and the opnsense/vpn community as well. 

Thank you!. 


# Technical Information

1. The Plugin will extract the VPNID and creates a list and stores that information in  `/usr/local/etc/multihop.conf`.
2. The Shellscript `/usr/local/opnsense/scripts/OPNsense/Multihop/multihop.sh` will be executed when the Service triggers 
`configd`.   
2.2 The Shellscript will read the list of VPNID's from its own conf file.   
2.3 Get's the `server_addr` field by using `pluginclt` of the next VPNID in the list and parse it with `jq`   
2.4 The `server_addr` is passed to the `--route-up` script. This adds the GW of the OpenVPN Tunnel to the routing table for `server_addr`. The Shellscript skips `--route-up` on the last VPNID.   

The OPNsense OpenVPN Client Configuration is not touched. Altough VPN Clients that are used for mutlihopping should be disabled in OpenVPN->Client or they will 
startup on reboot as this is the default. There is no autostart after reboot yet. 

You will also have  to take care of the NAT and Filter settings. Some examples can be found in my other repo [pfSense-pkg-openvpn-multihop](https://github.com/ddowse/pfSense-pkg-openvpn-multihop). 
 
