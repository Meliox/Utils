#!/bin/bash
version="0.2"
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
#
# As a default setting to programs send 3 magic packets incase one is lost. Can be changed
# below
# Use waittime to wait X seconds before finishing program as PC takes some time to start
#settings
quiet="false"
packets="3"
waitTime="0"


#### code below
program=("wakeonlan")
function install {
	for i in "${program[@]}"; do
		if [[ -z $(builtin type -p $i) ]]; then
			echo -e "\e[00;31mERROR: \"$i\" is not installed\e[00m"
			read -p "Do you want to install it? (y/n)?  :  "
			if [[ "$REPLY" == "y" ]]; then
				sudo apt-get -y install $i
				if [[ $? -eq 1 ]]; then
					echo "INFO: Could not install program using sudo."
					echo "You have to install \"$i\" manually using root, typing \"su root\"; \"apt-get install $i\""
					exit 0
				fi
			else
				echo -e "\e[00;31mScript will not work without... exiting\e[00m"; echo ""
				exit 0
			fi
		fi
	done
}

function uninstall {
	echo "The following will be removed: ${program[@]}"
	read -p " Do you want to remove all or one by one(y/n)? "
	if [[ "$REPLY" == "y" ]]; then
		for i in "${program[@]}"; do
			sudo apt-get -y remove $i &> /dev/null
		done
			echo -e "\e[00;32m [REMOVED]\e[00m"
	else
		for i in "${program[@]}"; do
			if builtin type -p $i &>/dev/null; then
				echo -n "Removing $i ..."
				read -p " Do you want to remove it(y/n)? "
				if [[ "$REPLY" == "y" ]]; then
					sudo apt-get -y remove $i &> /dev/null
					echo -e "\e[00;32m [REMOVED]\e[00m"
				else
					echo -e "\e[00;33m [KEPT]\e[00m"
				fi
			fi
		done
	fi
	echo ""
	echo "Removal complete!"
	echo ""
	exit 0
}

function wake {
	if [[ -z $ip ]] && [[ -z $port ]]; then
		wakeonlan $mac &> /dev/null
	elif [[ -z $port ]] && [[ -n $ip ]]; then
		wakeonlan -i $ip $mac &> /dev/null
	else
		wakeonlan -i $ip -p $port $mac &> /dev/null
	fi
}

function sendwol {
	if [[ -n $port ]]; then
		echo "INFO: Sending wakeup to ip=$ip, mac=$mac, port=$port UDP"
	else
		echo "INFO: Sending wakeup to ip=$ip, mac=$mac, port=9 UDP"
	fi
	#send 3 times
	c=0
	while [[ $c -lt $packets ]]; do
		wake
		sleep 1
		let c++
	done
	# wait
	if [[ $waitTime != 0 ]]; then
		sleep $waitTime
	fi
}

function show_help {
	echo "Options"
	echo "--mac=<MAC adress> format 00:00:00:00:00:00"
	echo "--ip=<ip adress> format 00.00.00.00"
	echo "--port=<port> format 0000"
	echo
	exit 0
}

if [[ $quiet == "true" ]]; then
	exec > /dev/null 2>&1
elif [[ $quiet != "true" ]] && [[ $verbose == 1 ]]; then
	set -x
elif [[ $quiet == "true" ]] && [[ $verbose == 1 ]]; then
	echo -e "\e[00;31mERROR: Verbose and silent can't be used at the same time\e[00m"
	exit 0
fi

echo
echo -e "\e[00;34mWake on lan script - $version\e[00m"
echo

# make sure everthing is installed
install

if (($# < 1 )); then echo -e "\e[00;31mERROR: No option specified\e[00m"; show_help; exit 0; fi
while :
do
	case "$1" in
		--macadr ) verbose=1; shift;;
		--quiet) quiet=true; shift;;
		--mac=* ) mac=${1#--mac=}; shift;;
		--ip=* ) ip=${1#--ip=}; shift;;
		--port=* ) port=${1#--port=}; shift;;
		--uninstall ) uninstall; shift;;
		--help ) show_help; shift;;
		-* ) echo -e "\e[00;31mInvalid option: $@\e[00m"; echo ""; exit 0;;
		* ) break ;;
		--) shift; break;;
	esac
done

if [[ -z $mac ]]; then
	echo -e "\e[00;31mScript should at least be called with --mac=<MAC-ADDRESS>\e[00m"
	echo -e "\e[00;31mScript will not work without... exiting\e[00m"
	echo ""
	exit 1
fi
sendwol
echo -e "\e[00;32mINFO: WOL send to $ip\e[00m"
echo
exit 0
