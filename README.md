# Heavy TESTING do not use, yet! 

# opnsense-multihop
Multihop with OpenVPN Tunnels on OPNsense

For testing purpose. Advanced Users only. Check if your provider supports this. 
Perfect Privacy is known to support at least 4 Tunnel. 

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

The VPN Clients that are used for mutlihopping should be disabled in OpenVPN->Client or they will 
startup on reboot as this is the default. There is no autostart after reboot yet. You will also have 
to take care of the NAT and Filter settings. Some examples can be found in my other repo [pfSense-pkg-openvpn-multihop](https://github.com/ddowse/pfSense-pkg-openvpn-multihop). 

You can also control the tunnel cascade on the shell like this:

```bash
configctl multihop [stop|start|status]
```

You are welcome to open issues (code/errors) or improve this plugin. 


The inital idea for VPN Multihopping Plugin was created by a customer who wants to remain anonymous.
The customer also provided some funds to me to realise his idea for him and the opnsense/vpn community as well. 

Thank you!. 
