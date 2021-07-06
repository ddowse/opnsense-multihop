# openvpn-multihop
Multihop with OpenVPN Tunnels on OPNsense

---

Check if your provider supports this. [Perfect Privacy](https://www.perfect-privacy.com/en/features/multi-hop-vpn) is known to support at least 4 Tunnel.   


# Build Instructions

``` bash
git clone https://github.com/opnsense/plugins
git clone https://github.com/ddowse/opnsense-multihop plugins/security/openvpn-multihop
cd plugins/security/openvpn-multihop
make package
```

# Install Instructions

Fetch the current pre-release from this repo and install it like this

``` bash
pkg add https://github.com/ddowse/opnsense-multihop/releases/download/Latest/os-openvpn-multihop-1.0.txz
```

# Usage

![General Tab](screen2.png)



![Clients Tab](screen1.png)

You can also control the tunnel cascade on the shell like this:

```bash
configctl multihop [stop|start|status]
```

Check your IP

```bash
curl -s https://checkip.perfect-privacy.com/json | jq 
``` 

---

# Some simple technical background Information

1. The Plugin will extract the VPNID and creates a list and stores that information in  `/usr/local/etc/multihop.conf`.
1. The Shellscript `/usr/local/opnsense/scripts/OPNsense/Multihop/multihop.sh` will be executed when the service API triggers `configd`.

   1. The Shellscript will read the list of VPNID's from its own conf file.   
   1. Get's the `server_addr` field  of the next VPNID int the list by using `pluginclt` and parse it with `jq`   
   1. The correct `server_addr` is passed to the `--route-up` script. This adds the GW of the current OpenVPN Tunnel to the routing table for `server_addr`. The  Shellscript skips `--route-up` on the last VPNID and set the routing options from the clients settings.

2. The static route for the first tunnel is needed to prevent a network traffic loop. 

The OPNsense OpenVPN Client Configuration is not touched. Altough VPN Clients that are used for mutlihopping should be disabled in OpenVPN->Client or they will 
startup on reboot, too - as this is the default.


You **may** also **want** take care of *NAT and Filter settings*.   
Some examples can be found in my other repo [pfSense-pkg-openvpn-multihop](https://github.com/ddowse/pfSense-pkg-openvpn-multihop). 

---

You are welcome to open issues (code/errors) or improve this plugin. It might be a good idea to mix VPN providers and report your results if you want.

---

This Plugin was done as Freelance Job for a customer who wants to remain anonymous.   
Thanks to her/him this Plugin is now available to the open-source community. Thank you!. ❤️

---

As I am a Freelancer, do not hesitate to contact me via my E-Mail if you have a need for individual Plugins or Bugfixes. 

