#!/bin/bash

#This will stop the script if any of the commands fail
set -e

startPath=$(pwd)

#we need this to generate the self-signed Asterisk certs
PUBLIC_IP=''

#Asterisk version
AST_VERSION="15.3.0"

# Config file
INPUT=.config

# install location for source code and dependencies
instLoc=/usr/src/

#Hostname command suggestion
HOST_SUGG="You can use 'sudo hostnamectl set-hostname <hostname>' to set the hostname."

#Param to be set if Amazon Linux is detected
AMZN=''

#File to be touched if Amazon Linux is detected
RH_RELEASE=/etc/redhat-release

print_message() {
        # first argument is the type of message
        # (Error, Notify, Warning, Success)
        colorCode="sgr0"
        case $1 in
                Error)
                        colorCode=1
                        ;;
                Notify)
                        colorCode=3
                        ;;
                Success)
                        colorCode=2
                        ;;
        esac

        # second argument is the message string
        tput setaf $colorCode; printf "${1} -- "
        tput sgr0;             printf "${2}\n"
}

error_public_ip()
{
echo "ERROR: a proper public IP address was not found in .config"
echo "Please enter a valid IP address into .config and try again."
exit 1
}

# fail if the script is not run as root
# Source: http://www.cyberciti.biz/tips/shell-root-user-check-script.html
if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root" 1>&2
   exit 1
fi

if [ ! -f $INPUT ]; then
                print_message "Error" "$INPUT file not found. Please create the $INPUT and try again. Refer the the README for more info."
                exit 1
fi

# Retreive the public IP from the .config. If it wasn't loaded, fail the script.
IFS=","
TMP_FILE=/tmp/public_ip
# modify each file from the configuration file
echo "============================================================"
	while read tag files value
        do
		if [ "$tag" == "<public_ip>" ]; then
			echo "$value" > $TMP_FILE
			PUBLIC_IP=$(grep -o '[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}' $TMP_FILE 2>/dev/null) || :
			rm -f $TMP_FILE
			if [ "$PUBLIC_IP" == "" ]; then
        			print_message "Error" "a proper public IP address was not supplied in .config"
        			exit 1
			fi
		fi
	
        done < $INPUT


while true
do
	case "$1" in
		--docker-mode)
			DOCKER_MODE=true
			shift;;
		"") break;;
                *)
	                print_message "Error" "unkown argument  ---> exiting program"
                        exit 1
        esac
done

# If DOCKER_MODE is enabled, these will append flags to build_pjproject and 
# update_asterisk to prevent functionality that is needed when asterisk
# is running during Docker builds
if [ -n "$DOCKER_MODE" ]; then
	echo "DOCKER MODE ENABLED"
	BUILD_PJ_ARG="--no-restart"
	UPDATE_AST_ARG="--no-db"
else
	UPDATE_AST_ARG="--config --restart"
fi

#check for IPv6 and SElinux (skipped in DOCKER MODE)

if [ -z "$DOCKER_MODE" ]; then

	DISABLED="disabled"
	SESTATUS=$(sestatus | head -1 | awk '{print $3}')
	IPV6=$(cat /proc/net/if_inet6)

	if [ $SESTATUS != $DISABLED ]
	then
		echo "ERROR: SELinux must be disabled before running Asterisk. Disable SELinux, reboot the server, and try again."
		exit 1
	fi

	if [ -n "$IPV6" ]
	then
		echo "ERROR: IPv6 must be disabled before installing Asterisk. See README.md for more information. Disable IPv6 then try again"
		exit 1
	fi

	#check hostname and fail if not set
	HOSTNAME=$(hostname -f)
	if [ -z $HOSTNAME ]
	then
		echo "ERROR: no hostname set on this server. Set the hostname, then re run the script."
		echo $HOST_SUGG
		exit 1
	fi

	#ask user to validate hostname
	echo "The hostname of this server is currently $HOSTNAME. Is this the hostname you want to use with Asterisk? (y/n)"
	read response
	if [ $response == "n" ]
		then
		echo "Exiting. Set the hostname, then rerun the script."
		echo $HOST_SUGG
		exit 0
	fi

	# prompt user to update packages
	echo "It is recommended to update the packages in your system. Proceed? (y/n)"
	read response2

	if [ $response2 == "y" ]
	then
		echo "Executing yum update"
		yum -y update
	fi

fi

# installing pre-requisite packages
echo "Installing pre-requisite packages for Asterisk and PJPROJECT"
yum -y install --skip-broken epel-release bzip2 dmidecode gcc-c++ ncurses-devel libxml2-devel make wget net-tools telnet vim zip unzip openssl-devel newt-devel kernel-devel libuuid-devel gtk2-devel jansson-devel binutils-devel git libsrtp libsrtp-devel unixODBC unixODBC-devel libtool-ltdl libtool-ltdl-devel mysql-connector-odbc tcpdump patch sqlite bind-utils

if [ $(grep "Red Hat" /etc/redhat-release) ]
then
	echo "RedHat has been detected, manually installing libjansson and libsrtp-devel"
	cd $instLoc
	# Manually install libjansson
	wget http://www.digip.org/jansson/releases/jansson-2.11.tar.gz 
	tar zxf jansson-2.11.tar.gz && cd jansson-2.11
	./configure
	make && make install

	cd $instLoc
	# Manually install libstrp-devel
	wget http://mirror.centos.org/centos/7/os/x86_64/Packages/libsrtp-devel-1.4.4-10.20101004cvs.el7.x86_64.rpm
	yum localinstall --nogpgcheck libsrtp-devel-1.4.4-10.20101004cvs.el7.x86_64.rpm -y
fi

# For Amazon Linux, we need to mock the /etc/redhat-release file
# so that the install_prereq and configure scripts install/check
# for the proper system packages. This works because Amazon Linux
# is a RHEL derivative.
if [ $(grep "Amazon Linux" /etc/system-release) ]
then
	echo "Amazon Linux has been detected, touching /etc/redhat-release file."
	AMZN=true
	touch $RH_RELEASE
fi


#download Asterisk
cd $instLoc
wget http://downloads.asterisk.org/pub/telephony/asterisk/old-releases/asterisk-$AST_VERSION.tar.gz
tar -zxf asterisk-$AST_VERSION.tar.gz && cd asterisk-$AST_VERSION

#remove RPM version of pjproject from pre-requisites install script
sed -i -e 's/pjproject-devel //' contrib/scripts/install_prereq
./contrib/scripts/install_prereq install

#install PJSIP and asterisk

cd $startPath
# Apply custom Asterisk patches, then apply custom PJPROJECT patch and install PJ and Asterisk
./update_asterisk.sh --patch --no-build --no-db
./build_pjproject.sh --clean $BUILD_PJ_ARG

#run ldconfig so that Asterisk finds PJPROJECT packages
echo “/usr/local/lib” > /etc/ld.so.conf.d/usr_local.conf
/sbin/ldconfig

# If we're NOT in Docker mode, we'll use the Asterisk-provided cert generation script,
# which prompts the user to enter a custom passphrase for the root private key.
# Otherwise, these certs will be generated in docker-entrypoint.sh
if [ -z "$DOCKER_MODE" ]; then

	echo "Generating the Asterisk self-signed certificates. You will be prompted to enter a password or passphrase for the private key."
	sleep 2

	#generate TLS certificates
	/usr/src/asterisk-$AST_VERSION/contrib/scripts/ast_tls_cert -C $PUBLIC_IP -O "ACE Direct" -d /etc/asterisk/keys
fi

repo=$(dirname $startPath)
cd $repo

#copy iTRS lookup script to agi-bin and make it executable
mkdir -p /var/lib/asterisk/agi-bin
yes | cp -rf scripts/itrslookup.sh /var/lib/asterisk/agi-bin
chmod +x /var/lib/asterisk/agi-bin/itrslookup.sh

#modify configs with named params and populate AstDB if
#not in DOCKER_MODE

cd $startPath
./update_asterisk.sh --media $UPDATE_AST_ARG

if [ $AMZN == "true" ]
then
	rm -f $RH_RELEASE
fi

echo ""
echo "NOTE: the user passwords in pjsip.conf and the Asterisk Manager Interface"
echo "manager password in manager.conf should be updated before starting Asterisk."
echo "Otherwise, the defaults will be used. Once the passwords have been updated,"
echo "Run 'service asterisk restart' to apply the changes."
echo "View the conf files in /etc/asterisk for more info."
echo ""
echo ""
echo "     _    ____ _____   ____ ___ ____  _____ ____ _____ "
echo "    / \  / ___| ____| |  _ \_ _|  _ \| ____/ ___|_   _|"
echo "   / _ \| |   |  _|   | | | | || |_) |  _|| |     | |  "
echo "  / ___ \ |___| |___  | |_| | ||  _ <| |__| |___  | |  "
echo " /_/   \_\____|_____| |____/___|_| \_\_____\____| |_|  "
echo ""
echo "Installation is complete. When ready, run 'asterisk -rvvvvvvcg' to start the Asterisk console."
