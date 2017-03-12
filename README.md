# Utils
A small collection of my personal utilities

If you find this tool helpful, a small donation is appreciated, [![Donate](https://www.paypalobjects.com/en_US/i/btn/btn_donate_LG.gif)](https://www.paypal.com/cgi-bin/webscr?cmd=_s-xclick&hosted_button_id=K8XPMSEBERH3W).

## ddns
```sh
# Custom DDNS (dynamic DNS) for the no-ip.com service for asuswrt-merlin
# The scripts works in a double NAT setup and single NAT setup, and will automatically detect the configuration
```
Link: https://github.com/Meliox/Utils/blob/master/ddns-start/ddns-start
For more info see here: https://www.snbforums.com/threads/double-nat-custom-ddns-script.34431/

## Wakeonlan
A simple shell to Wake Up nas devices / home servers
```bash
# A simple shell to Wake Up nas devices / home servers
# Should be called with --ip="<IP-ADDRESS>" --macadr="<MAC-ADDRESS>" --port"<PORT>"
# ONLY <MAC-ADDRESS> is mandatory(on lan you mostlikely only need this)
# Remember to verify that the server supports wakeonlan
#     type: ethtool eth0 and if "Supports Wake-on: g" i present
#     you're good to go. Else type ethtool -s eth0 wol g to activate
#     and see again. If line is ok, you're good to go, else not working.
#     eth0 is the network interface, you might have others
# Example bash wakeonlan.sh -i "10.0.0.1" "30:11:32:08:15:74"
#
# Online WOL. Most routers forget the clients after a few minutes and that's why online wol
# rarely works. On my asus router you can hardcore the ip (static ofc.) with the mac adress
# with telnet/ssh like arp -s 192.168.0.1 00:30:c1:5e:68:74. And then after portforwarding
# it should work
Link: https://github.com/Meliox/Utils/blob/master/wakeonlan/wakeonlan.sh

```
## Network Monitor
```sh
# Network traffic monitor
# Purpose is to shut down computer or run a custom command if network traffic is below threshold due to low activity or a certain ip is not online

# The script can either monitor traffic from the netcard or use iptables. See below:
####
# Netcard:
# Do you want to monitor your netcard or the firewall? The netcard cannot see more traffic than
# allow by the bit of your system, i.e. 2^32 = 4gb. (32bit limit, 64bit goes to 2.3exabytes). A wrap has been used to
# fix this while using netcard, but total traffic cannot be seen for fast speeds. At low speeds the purpose of the
# script works. For correct transfer, a 64bit system is required, or one may simply use of iptables.
```
Link: https://github.com/Meliox/Utils/blob/master/networkmonitor/networkmonitor.sh

## woltraffic
```sh
# Wol script to wake up server on internet traffic on ASUS routers, but can probably be used for others/servers as well.
# This script is intended for people, who want to wake up their server when someone tries to access a port on the server.
# The script listen on a specific port and will respond to any request, so a port scan will wake up your web server every time.
# Old script and for routersetup see: https://github.com/RMerl/asuswrt-merlin/wiki/WOL-Script-Wake-Up-Your-Webserver-On-Internet-Traffic
# Briefly enable JFFS partition, copy script, chmod +x script and add to services-start, go to firewall and set logged packets
# to ACCEPTED
# Script has been rewritten for plex purposes to use a ip whitelist to only allow static ips or ip-ranges to use WOL
```
Link: https://github.com/Meliox/Utils/blob/master/woltraffic/woltraffic.sh
