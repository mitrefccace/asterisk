###############################
#Before running this script, make sure the public/private key-pair for Git
#have been added to /root/.ssh/ and their permissions are 600
###############################

#!/bin/bash

#This will stop the script if any of the commands fail
set -e

#optional
yum -y update
yum -y install -y epel-release bzip2 dmidecode gcc-c++ ncurses-devel libxml2-devel make wget openssl-devel newt-devel kernel-devel sqlite-devel libuuid-devel gtk2-devel jansson-devel binutils-devel git

#download Asterisk
cd /usr/src
wget http://downloads.asterisk.org/pub/telephony/asterisk/releases/asterisk-14.2.1.tar.gz
tar -zxf asterisk-14.2.1.tar.gz && cd asterisk-14.2.1

#install pre-requisites
./contrib/scripts/install_prereq

#install PJSIP and asterisk

./configure --with-pjproject-bundled
make && make install && make samples
make config
service asterisk start

#add git repo domain name to known_hosts so RSA fingerprint prompt does not pause script
ssh-keyscan github.com >> ~/.ssh/known_hosts

# pull down confi/media files and add to /etc/asterisk and /var/lib/asterisk/sounds, respectively
cd ~
git clone $9
cd asterisk
git checkout AD
yes | cp -rf asterisk-configs/* /etc/asterisk
yes | cp -rf asterisk-videos-audios/sounds/* /var/lib/asterisk/sounds/

cd /etc/asterisk

sed -i -e "s/<public_ip>/$1/g" pjsip.conf
sed -i -e "s/<local_ip>/$2/g" pjsip.conf
sed -i -e "s/<dialin>/$3/g" extensions.conf pjsip.conf
sed -i -e "s/<stun_server>/$4/g" rtp.conf
sed -i -e "s/<crt_file>/$5/g" http.conf
sed -i -e "s/<crt_key>/$6/g" http.conf
sed -i -e "s/<ss_crt>/$7/g" pjsip.conf
sed -i -e "s/<ss_ca_crt>/$8/g" pjsip.conf

service asterisk restart
