###############################
#
#Example use:
# ./AD_asterisk_install.sh --public-ip 54.242.111.146 --local-ip 172.21.1.86 --stun-server newstun.task3acrdemo.com:3478 --dialin 12345 --crt-file #"\/etc\/asterisk\/keys\/asterisk.crt" --crt-key "\/etc\/asterisk\/keys\/asterisk.key"
###############################

#!/bin/bash

#This will stop the script if any of the commands fail
set -e

#set variable names
PUBLIC_IP=''
LOCAL_IP=''
DIALIN=''
STUN_SERVER=''
CRT_FILE=''
CRT_KEY=''

#default STUN will be set to Google
GOOGLE='stun4.l.google.com:19302'

#Asterisk version
AST_VERSION=14.6.0

#Hostname command suggestion
HOST_SUGG="You can use 'sudo hostnamectl set-hostname <hostname>' to set the hostname."

print_args()
{

echo "Required params: --public-ip, --local-ip" >&2
echo "Aborting" >&2
exit 1

} >&2

#check for empty params
if [ $# -eq 0 ]
  then
    echo "No arguments supplied"
    print_args
    exit 1
fi


# read the options
TEMP=`getopt -o a:: -l public-ip:,local-ip:,dialin:,stun-server:,crt-file:,crt-key: -n '$0' -- "$@"`
eval set -- "$TEMP"

#evaluate options
while true
do
        case "$1" in
        --public-ip)
                case $2 in
                        "") print_args ;;
                        *) PUBLIC_IP=$2; shift 2 ;;
                esac ;;
        --local-ip)
                case "$2" in
                        "") print_args ;;
                        *) LOCAL_IP=$2; shift 2 ;;
                esac ;;
        --dialin)
                case "$2" in
                        "") echo "WARNING: no dial-in number specified. Using 1234567890 as a placeholder to prevent failed config parsing."
                        DIALIN='1234567890'; shift 2;;
                        *) DIALIN=$2; shift 2 ;;
                esac ;;
        --stun-server)
                case "$2" in
                        "") echo "WARNING: no STUN server specified. Using Google STUN address at $GOOGLE."
                        STUN_SERVER=$GOOGLE; shift 2;;
                        *) STUN_SERVER=$2; shift 2 ;;
                esac ;;
        --crt-file)
                case "$2" in
                        "") echo "WARNING: no SSL/TLS certificate specified. Using to-be-generated self-signed Asterisk certificate."
                        CRT_FILE="//etc//asterisk//keys//asterisk.crt"; shift 2;;
                        *) CRT_FILE=$2; shift 2 ;;
                esac ;;
        --crt-key)
                case "$2" in
                        "") CRT_KEY="//etc//asterisk//keys//asterisk.key"; shift 2;;
                        *) CRT_KEY=$2; shift 2 ;;
                esac ;;
        --) shift ; break ;;
        *) echo "Error parsing args"; print_args;;
    esac
done

# set defaults for non-required options

if [ -z $STUN_SERVER ]
then
    echo "WARNING: no STUN server specified. Using Google STUN address at $GOOGLE."
    STUN_SERVER=$GOOGLE
fi

if [ -z $DIALIN ]
then
    echo "WARNING: no dial-in number specified. Using 1234567890 as a placeholder to prevent failed config parsing."
    DIALIN='1234567890'
fi

if [ -z $CRT_FILE ]
then
    echo "WARNING: no SSL/TLS certificate specified. Using to-be-generated self-signed Asterisk certificate."
    CRT_FILE="\/etc\/asterisk\/keys\/asterisk.crt"
fi

if [ -z $CRT_KEY ]
then
    CRT_KEY="\/etc\/asterisk\/keys\/asterisk.key"
fi


#check for IPv6 and SElinux

DISABLED="disabled"
SESTATUS=$(sestatus | grep "Current mode" | awk '{print $3}')
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

# installing pre-requisite packages
echo "Installing pre-requisite packages for Asterisk and PJPROJECT"
yum -y install -y epel-release bzip2 dmidecode gcc-c++ ncurses-devel libxml2-devel make wget netstat telnet vim zip unzip openssl-devel newt-devel kernel-devel libuuid-devel gtk2-devel jansson-devel binutils-devel git libsrtp libsrtp-devel unixODBC unixODBC-devel libtool-ltdl libtool-ltdl-devel mysql-connector-odbc tcpdump

#download Asterisk
cd /usr/src
wget http://downloads.asterisk.org/pub/telephony/asterisk/old-releases/asterisk-$AST_VERSION.tar.gz
tar -zxf asterisk-$AST_VERSION.tar.gz && cd asterisk*

#remove RPM version of pjproject from pre-requisites install script
sed -i -e 's/pjproject-devel //' contrib/scripts/install_prereq
./contrib/scripts/install_prereq install


#the following code modifications reverse the commits made below,
#and are needed to enable proper video RTP with provider devices.
#Commit: https://gerrit.asterisk.org/#/c/3899/
#Asterisk issue: https://issues.asterisk.org/jira/browse/ASTERISK-26554

#remove hard-coded sample rate
sed -i -e 's/.sample_rate = 1000,//g' main/codec_builtin.c
#remove timestamp from frame
sed -i -e '4975,4976d' res/res_rtp_asterisk.c
#update PJSIP_MAX_PCKT_LEN to aviod buffer overflow
sed -i -e 's/6000/12440/' third-party/pjproject/patches/config_site.h

#install PJSIP and asterisk

./configure --with-pjproject-bundled
make
make install
make config

#run ldconfig so that Asterisk finds PJPROJECT packages
echo “/usr/local/lib” > /etc/ld.so.conf.d/usr_local.conf
/sbin/ldconfig

echo "Generating the Asterisk self-signed certificates. You will be prompted to enter a password or passphrase for the private key."
sleep 2

#generate TIS certificates
./contrib/scripts/ast_tls_cert -C $PUBLIC_IP -O "ACE direct" -d /etc/asterisk/keys

# pull down confi/media files and add to /etc/asterisk and /var/lib/asterisk/sounds, respectively
cd ~
git clone https://github.com/mitrefccace/asterisk.git
cd asterisk
yes | cp -rf config/* /etc/asterisk
yes | cp -rf media/* /var/lib/asterisk/sounds/

#copy iTRS lookup script to agi-bin and make it executable
yes | cp -rf scripts/itrslookup.sh /var/lib/asterisk/agi-bin
chmod +x /var/lib/asterisk/agi-bin/itrslookup.sh

#modify configs with named params

cd /etc/asterisk

sed -i -e "s/<public_ip>/$PUBLIC_IP/g" pjsip.conf
sed -i -e "s/<local_ip>/$LOCAL_IP/g" pjsip.conf
sed -i -e "s/<dialin>/$DIALIN/g" extensions.conf pjsip.conf
sed -i -e "s/<stun_server>/$STUN_SERVER/g" rtp.conf
sed -i -e "s/<crt_file>/$CRT_FILE/g" http.conf pjsip.conf
sed -i -e "s/<crt_key>/$CRT_KEY/g" http.conf pjsip.conf
sed -i -e "s/<ss_cert>/\/etc\/asterisk\/keys\/asterisk.pem/g" pjsip.conf
sed -i -e "s/<ss_ca_crt>/\/etc\/asterisk\/keys\/ca.crt/g" pjsip.conf

echo ""
echo "NOTE: the user passwords in pjsip.conf and the Asterisk Manager Interface"
echo "manager password in manager.conf should be updated before starting Asterisk."
echo "Otherwise, the defaults will be used. View the conf files in /etc/asterisk"
echo "for more info."
echo ""
echo ""
echo "     _    ____ _____   ____ ___ ____  _____ ____ _____ "
echo "    / \  / ___| ____| |  _ \_ _|  _ \| ____/ ___|_   _|"
echo "   / _ \| |   |  _|   | | | | || |_) |  _|| |     | |  "
echo "  / ___ \ |___| |___  | |_| | ||  _ <| |__| |___  | |  "
echo " /_/   \_\____|_____| |____/___|_| \_\_____\____| |_|  "
echo ""
echo "Installation is complete. When ready, run 'service asterisk start' as root to start Asterisk."
