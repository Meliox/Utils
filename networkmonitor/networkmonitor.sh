#!/bin/sh
version="0.8"
# Network traffic monitor
# Purpose is to shut down computer or run a custom command if network traffic is below threshold due to low activity or a certain ip is not online

# The script can either monitor traffic from the netcard or use iptables. See below:
####
# Netcard:
# Do you want to monitor your netcard or the firewall? The netcard cannot see more traffic than
# allow by the bit of your system, i.e. 2^32 = 4gb. (32bit limit, 64bit goes to 2.3exabytes). A wrap has been used to
# fix this while using netcard, but total traffic cannot be seen for fast speeds. At low speeds the purpose of the
# script works. For correct transfer, a 64bit system is required, or one may simply use of iptables.
#
####
# Iptables
# Proper traffic count can be seen with iptables, but this requires to set op iptables rules like below
# Add monitor for INPUT and OUTPUT. REQUIRED!
# root@:~# iptables -N trafficMonitor_in
# root@:~# iptables -N trafficMonitor_out
# root@:~# iptables -I INPUT 1 -j trafficMonitor_in
# root@:~# iptables -I OUTPUT 1 -j trafficMonitor_out
#
# This assumes information is in third line like below. Edit line if this isn't the case.
# Example:
#	iptables -nx -vL INPUT
# Chain DEFAULT_INPUT (1 references)
    # pkts      bytes target     prot opt in     out     source               destination
 # 1590475 85601301 trafficMonitor_in  all  --  *      *       0.0.0.0/0            0.0.0.0/0

# Chain DEFAULT_OUTPUT (1 references)
    # pkts      bytes target     prot opt in     out     source               destination
  # 676941 10997095960 trafficMonitor_out  all  --  *      *       0.0.0.0/0            0.0.0.0/0

#
# See your output by iptables -nx -vL <OUTPUT|INPUT>. Data will be retrieved from bytes column
#
####
# Another option is to monitor if certain ips are online, enter those in hosts. This setting overwrites
# the minimum traffic threshold!

# USAGE
# Following argument can be used: start, stop, test. Execute script without arguments for more info.

#
# Settings below
#
threshold=10 		# MB per interval
monitor_time=4 		# mins per inverval
times=3 		# number of times it should be below threshold in each interval
lockfile="networkmonitor.lock"
log="networkmonitor.log"
debug="false"
debuglog="debug.log"
shutdown_command="poweroff"	#command to execute for shutdown
enable="false" 		# (false|true)

method="iptables" 	# iptables or netcard
interface="eth0" 	# only for netcard.

# only for iptables
iptableRulesNameIn="trafficMonitor_in"
iptableRulesNameOut="trafficMonitor_out"
add_iptables="true" # Will add rules on script start if they do not exists (false|true) add iptables -A INPUT -j ACCEPT and iptables -A OUTPUT -j ACCEPT to iptables upon script start. Requires sudo/root.

# Monitor ip hosts
hosts=""		# iphosts, seperate with :. Leave empty if not used. Format 192.168.1.1

################# CODE BELOW ################3

if [[ $debug == "true" ]]; then
	set -x
	echo >> $debuglog
	exec 2>> $debuglog
	echo "STARTING PID=$$"
fi

control_c() {
# run if user hits control-c
rm "$lockfile"
exit 0
}
trap control_c SIGINT

# Retrieve send bytes
printrxbytes(){
if [[ $method == "netcard" ]]; then
	ifconfig "$interface" | grep "RX bytes" | cut -d: -f2 | awk '{ print $1 }'
elif [[ $method == "iptables" ]]; then
	iptables -nx -vL | grep "$iptableRulesNameIn" |  awk '$1 ~ /^[0-9]+$/ { printf $2 }'
fi
}

# Retrieve transferred bytes
printtxbytes(){
if [[ $method == "netcard" ]]; then
	ifconfig "$interface" | grep "TX bytes" | cut -d: -f3 | awk '{ print $1 }'
elif [[ $method == "iptables" ]]; then
	iptables -nx -vL | grep "$iptableRulesNameOut" |  awk '$1 ~ /^[0-9]+$/ { printf $2 }'
fi
}
# Convert bytes to humanunits

bytestohuman(){
local multiplier="0"
local number="$1"
while [[ "$number" -ge 1024 ]] ; do
	multiplier=$(($multiplier+1))
	number=$(($number/1024))
done
echo "$number"
}

# Convert bytes to humanunits
bytestohumanunit(){
local multiplier="0"
local number="$1"
while [[ "$number" -ge 1024 ]]; do
	multiplier=$(($multiplier+1))
	number=$(($number/1024))
done
case "$multiplier" in
	1)
	unit="Kb"
	;;
	2)
	unit="Mb"
	;;
	3)
	unit="Gb"
	;;
	4)
	unit="Tb"
	;;
	*)
	unit="b"
	;;
esac
echo "$unit"
}

# Print traffic result for manual monitoring infinite 
printresults(){
local counter=30000
while [[ "$counter" -ge 0 ]]; do
	counter=$(($counter - 1))
	if [[ "$rxbytes" ]]; then
		oldrxbytes="$rxbytes"
		oldtxbytes="$txbytes"
	fi
	rxbytes=$(printrxbytes)
	txbytes=$(printtxbytes)
	if [[ "$oldrxbytes" -gt 0 -a "$rxbytes" -gt 0 -a "$oldtxbytes" -gt 0 -a "$txbytes" -gt 0 ]]; then
		echo "RXbytes = $(bytestohuman $(($rxbytes - $oldrxbytes))) $(bytestohumanunit $(($rxbytes - $oldrxbytes)))	TXbytes = $(bytestohuman $(($txbytes - $oldtxbytes))) $(bytestohumanunit $(($txbytes - $oldtxbytes)))"
	else
		echo "Monitoring $interface every 5 seconds. (RXbyte total = N/A TXbytes total = N/A"
	fi
	sleep 5
done
}

# Convert bytes to megabytes
bytestomegabyts(){
	number=$(($1/1024))
	echo $number
}

# Shutdown logic
shutdowntimer(){
# Write startup message
echo "Networking monitor $version"
echo ""
echo "Monitoring networkcard=$interface for traffic."
if [[ -n $hosts ]]; then
	echo "Monitoring for online hosts: $hosts"
fi
echo "Settings: Threshold=$threshold MB. Interval $monitor_time mins. Treshold $times times."
echo
low_times=0
while :; do
	# first check if any online ip's
	checkip
	# only if the one ip is online reset counter and skip traffic calculation
	if  [[ $iponline == "yes" ]]; then
		echo "Online hosts found: $ipfound"
		low_times=0
	else
		if [[ "$rxbytes" ]]; then
			oldrxbytes="$rxbytes"
			oldtxbytes="$txbytes"
		fi
		rxbytes=$(printrxbytes)
		txbytes=$(printtxbytes)
		if [[ "$oldrxbytes" -gt 0 -a "$rxbytes" -gt 0 -a "$oldtxbytes" -gt 0 -a "$txbytes" -gt 0 ]]; then
			rxunit=$(bytestohumanunit $(($rxbytes - $oldrxbytes)))
			rxbytes_diff=$(bytestohuman $(($rxbytes - $oldrxbytes)))
			txunit=$(bytestohumanunit $(($txbytes - $oldtxbytes)))
			txbytes_diff=$(bytestohuman $(($txbytes - $oldtxbytes)))

			# wrap around 2^32 count limit on 32bit systems. Reseting counter if lower!
			if [[ $rxbytes -lt $oldrxbytes ]] || [[ $txbytes -lt $oldtxbytes ]]; then
				low_times=0
				if [[ $rxbytes_diff -gt 0 ]] && [[ $txbytes_diff -gt 0 ]]; then
					echo "too high traffic.. RXbytes = adaptor reset N/A TXbytes = adaptor reset N/A"
				elif [[ $rxbytes_diff -gt 0 ]] && [[ $txbytes_diff -lt 0 ]]; then
					 echo "too high traffic.. RXbytes = $rxbytes_diff $rxunit TXbytes = adaptor reset N/A"
				elif [[ $rxbytes_diff -lt 0 ]] && [[ $txbytes_diff -gt 0 ]]; then
					 echo "too high traffic.. RXbytes = adaptor reset N/A TXbytes = $txbytes_diff $txunit"
				fi
				sleep $(( $monitor_time * 60 ))
				continue
			fi
			# low activty counter
			if [[ $rxunit == "Mb" -o $rxunit == "Kb" -o $rxunit == "b" ]] && [[ $txunit == "Mb" -o $txunit == "Kb" -o $txunit == "b" ]]; then
				if [[ $rxbytes_diff -gt "$threshold" -a $rxunit == "Mb" ]] || [[ $txbytes_diff -gt "$threshold" -a $txunit == "Mb" ]]; then
					# Too much traffic
					low_times=0
					echo "too high traffic.. RXbytes = $rxbytes_diff $rxunit TXbytes = $txbytes_diff $txunit"
					sleep $(( $monitor_time * 60 ))
					continue
				fi
				let low_times++
				echo "too low traffic, $low_times times.. RXbytes = $rxbytes_diff $rxunit TXbytes = $txbytes_diff $txunit"
				if [[ $low_times -eq $times  ]]; then
					echo "time for shutdown"
					rm "$lockfile"
					echo "$(date): No network activity, shutting down.!" >> "$log"
					if [[ $enable == "true" ]]; then
						eval "$shutdown_command"
					fi
					exit 0
				fi
			else
				low_times=0
				echo "too high traffic.. RXbytes = $rxbytes_diff $rxunit TXbytes = $txbytes_diff $txunit"
				sleep $(( $monitor_time * 60 ))
				continue
			fi
		fi
	fi
	sleep $(( $monitor_time * 60 ))
done
}

# Manage lockfile
lockfile(){
if [[ -f "$lockfile" ]]; then
	mypid_script=$(sed -n 1p "$lockfile")
	kill -0 $mypid_script
	if [[ $? -eq 1 ]]; then
		echo "Network monitor is not running"
		rm "$lockfile"
		echo $$ > "$lockfile"
	else
		echo "Network monitor is already running. Exiting..."
		exit 1
	fi
else
	echo $$ > "$lockfile"
fi
if [[ $add_iptables == "true" ]] && [[ $method == "iptables" ]]; then
	iptables_add
fi
}

# Monitor ip's
checkip(){
ipfound=""
iponline="no" # assume none is online
old_ifs=$IFS
IFS=:
for ip in $hosts ; do
	IFS=$old_ifs
	ping "$ip" -w 2 &> /dev/null
	if [[ $? -eq 0 ]]; then
		iponline="yes"
		ipfound="$ip"
		break
	else
		iponline="no"
	fi
done
IFS=$Old_ifs
}

# Populate iptables, so that we can get traffic information
iptables_add(){
	if [[ "$(id -u)" != "0" ]]; then
		echo "To add entries to iptables, this script must be run as root"
		exit 1
	fi
	# verify that rules exits, else create them
	local var=$(iptables --list-rules | grep "\-A.*$iptableRulesNameIn")
	if [[ -z "$var" ]]; then
		iptables -N "$iptableRulesNameIn"
		iptables -I INPUT 1 -j "$iptableRulesNameIn"
	fi
	local var=$(iptables --list-rules | grep "\-A.*$iptableRulesNameOut")
	if [[ -z "$var" ]]; then
		iptables -N "$iptableRulesNameOut"
		iptables -I OUTPUT 1 -j "$iptableRulesNameOut"
	fi
}

case $1 in
	start)
	lockfile
	shutdowntimer
	;;
	test)
		printresults
		exit 0
	;;
	stop)
	if [[ -f "$lockfile" ]]; then
		mypid_script=$(sed -n 1p "$lockfile")
		kill -9 $mypid_script
		rm "$lockfile"
	else
		echo "Not running"
	fi
	exit 0
	;;
	*)
	echo "Usage:"
	echo " start to execute"
	echo " stop to terminate running process"
	echo " test to monitor network activity for debug purposes"
esac
