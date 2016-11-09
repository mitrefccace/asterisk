###############################
#Before running this script, make sure the public/private key-pair for Git
#have been added to /root/.ssh/ and their permissions are 600
###############################

#!/bin/bash

#This will stop the script if any of the commands fail
set -e

yum -y update
yum -y install -y epel-release bzip2 dmidecode gcc-c++ ncurses-devel libxml2-devel make wget openssl-devel newt-devel kernel-devel sqlite-devel libuuid-devel gtk2-devel jansson-devel binutils-devel git

#install PJSIP
cd /usr/src
wget http://www.pjsip.org/release/2.3/pjproject-2.3.tar.bz2
tar -jxf pjproject-2.3.tar.bz2
cd pjproject-2.3
./configure CFLAGS="-DNDEBUG -DPJ_HAS_IPV6=1" --prefix=/usr --libdir=/usr/lib64 --enable-shared --disable-video --disable-sound --disable-opencore-amr

make dep
make
make install
ldconfig
ldconfig -p | grep pj

#install asterisk

cd /usr/src
wget http://downloads.asterisk.org/pub/telephony/certified-asterisk/asterisk-certified-13.8-current.tar.gz
tar -zxf asterisk-certified-13.8-current.tar.gz
cd asterisk-certified-13.8-cert2

./configure --libdir=/usr/lib64
make && make install && make samples
make config
service asterisk start

#add git repo domain name to known_hosts so RSA fingerprint prompt does not pause script
ssh-keyscan github.com >> ~/.ssh/known_hosts

# pull down confi/media files and add to /etc/asterisk and /var/lib/asterisk/sounds, respectively
cd ~
git clone https://github.com/mitrefccace/asterisk.git
cd asterisk
git checkout AD
yes | cp -rf asterisk-configs/* /etc/asterisk
yes | cp -rf asterisk-videos-audios/sounds/* /var/lib/asterisk/sounds/

cd /etc/asterisk

sed -i -e "s/<public_ip>/$1/g" pjsip.conf
sed -i -e "s/<local_ip>/$2/g" pjsip.conf
sed -i -e "s/<dialin>/$3/g" extensions.conf pjsip.conf
sed -i -e "s/<stun_server>/$4/g" rtp.conf
sed -i -e "s/<public_key>/$5/g" http.conf
sed -i -e "s/<private_key>/$6/g" http.conf

service asterisk restart
