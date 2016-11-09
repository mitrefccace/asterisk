###############################
#Before running this script, make sure the public/private key-pair for Git
#have been added to /root/.ssh/ and their permissions are 600
###############################

#!/bin/bash

#This will stop the script in case any of the commands fail
set -e

yum -y update
yum -y install -y epel-release bzip2 dmidecode gcc-c++ ncurses-devel libxml2-devel make wget openssl-devel newt-devel kernel-devel sqlite-devel libuuid-devel gtk2-devel jansson-devel binutils-devel git

#install asterisk

cd /usr/src
wget http://downloads.asterisk.org/pub/telephony/asterisk/asterisk-13.11.2.tar.gz
tar -zxf asterisk-13.11.2.tar.gz
cd asterisk-13.11.2

./configure --libdir=/usr/lib64
make && make install && make samples
make config
service asterisk start

#add git repo domain name to known_hosts so RSA fingerprint prompt does not pause script
ssh-keyscan github.com >> ~/.ssh/known_hosts

# pull down config files and add to /etc/asterisk
git clone https://github.com/mitrefccace/asterisk.git
cd asterisk
git checkout ACL
yes | cp -rf asterisk-configs/* /etc/asterisk
yes | cp -rf asterisk-videos-audios/sounds/* /var/lib/asterisk/sounds/

cd /etc/asterisk

sed -i -e "s/<public_ip>/$1/g" sip.conf
sed -i -e "s/<local_ip>/$2/g" sip.conf
sed -i -e "s/<dial_around_num>/$3/g" extensions.conf sip.conf
sed -i -e "s/<phone_1>/$4/g" extensions.conf sip.conf
sed -i -e "s/<phone_2>/$5/g" extensions.conf sip.conf
sed -i -e "s/<stun_server>/$6/g" sip.conf
sed -i -e "s/<sip_trunk_host>/$7/g" sip.conf

service asterisk restart
