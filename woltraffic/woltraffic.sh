#!/bin/sh
# Wol script to wake up server on internet traffic on ASUS routers, but can probably be used for others/servers as well.
# This script is intended for people, who want to wake up their server when someone tries to access a port on the server.
# The script listen on a specific port and will respond to any request, so a port scan will wake up your web server every time.
# Old script and for routersetup see: https://github.com/RMerl/asuswrt-merlin/wiki/WOL-Script-Wake-Up-Your-Webserver-On-Internet-Traffic
# Briefly enable JFFS partition, copy script, chmod +x script and add to services-start, go to firewall and set logged packets
# to ACCEPTED
# Script has been rewritten for plex purposes to use a ip whitelist to only allow static ips or ip-ranges to use WOL

INTERVAL=5					# how often to look for access in seconds (only newest entry is used)
NUMP=3  					# number of times ip should respond before sending WOL
TARGET=192.168.1.1				# ip adress of server to wake
PORT=32400					# port to listen to
LEN=60						# packet lenght. Leave empty if not needed
IFACE=br0					# network interface
MAC=12:34:56:78:90:AB				# mac adress of server to wake
WOL=/usr/bin/ether-wake				# path to wakeonlan program
LOGFILE="~/ether-wake.log"			# logfile
WHITELIST="*.*.*.*"		 		# format xxx.xxx.xxx.xxx. Separate ips by ":". Use * for wildcards. Use "*.*.*.*" to allow all ips

################## CODE BELOW ########

OLD=""

checkip(){
proceed="false"
old_ifs=$IFS
IFS=:
for ip in $WHITELIST; do
	IFS=$old_ifs
	i=1
	true=0
	while [ $i -le 4 ]; do
		# skip asterix
		if [[ "`echo "$ip" | cut -d'.' -f$i`" == "*" ]]; then
			let true++
			let i++
			continue
		fi
		if [[ "`echo "$ip" | cut -d'.' -f$i`" -eq "`echo $SRC | cut -d'.' -f$i`" ]]; then
			let true++
			let i++
			continue
		fi
		# no number match, continue to next whitelist ip
		break
	done
	if [[ $true -eq 4 ]]; then
		# ip match whitelist, stop looping
		proceed="true"
		break
	fi
done
IFS=$Old_ifs
if [[ $proceed != "true" ]]; then
	OLD=$NEW
	echo "NOWAKE $SRC not in whitelist at `date`" >> $LOGFILE
	continue
fi
}

while sleep $INTERVAL;do
	if [[ -n $LEN ]]; then
		NEW=`dmesg | awk '/ACCEPT/ && /DST='"$TARGET"'/ && /LEN='"$LEN"'/ && /DPT='"$PORT"'/ {print }' | tail -1`
	else
		NEW=`dmesg | awk '/ACCEPT/ && /DST='"$TARGET"'/ && /DPT='"$PORT"'/ {print }' | tail -1`
	fi
	SRC=`echo $NEW | awk -F'[=| ]' '{print $7}'`
	DPORT=`echo $NEW | awk -F'[=| ]' '{print $26}'`
	PROTO=`echo $NEW | awk -F'[=| ]' '{print $22}'`
	ILEN=`echo $NEW | awk -F'[=| ]' '{print $21}'`
	PACKAGE=`echo $NEW | awk -F'[=| ]' '{print $39}'`

	if [ "$NEW" != "" -a "$NEW" != "$OLD" ]; then
		# confirm ip is in whitelist
		checkip

		if ping -qc $NUMP $TARGET >/dev/null; then
			echo "NOWAKE $TARGET was accessed by $SRC, port $DPORT, protocol $PROTO and is already alive at" `date` #>> $LOGFILE
		else
			echo "WAKE $TARGET requested by $SRC, len $ILEN, port $DPORT, protocol $PROTO, package $PACKAGE at" `date`>> $LOGFILE
			$WOL -i $IFACE $MAC
			sleep 5
		fi
	OLD=$NEW
	fi
done 
