#!/bin/bash

# get the third party asterisk tarball for pjproject
source /etc/environment
git clone https://github.com/asterisk/third-party.git

# creat the custom-build dir
if [ ! -d /usr/src/custom-build ]; then
	mkdir /usr/src/custom-build
fi

# untar the version 2.6 project to /usr/src
tar -xjvf ./third-party/pjproject/2.6/pjproject-2.6.tar.bz2 -C /usr/src/custom-build
rm -rf ./third-party

# rename dir to pjproject-2.6.1 && apply the included patch
mv /usr/src/custom-build/pjproject-2.6 /usr/src/custom-build/pjproject-2.6.1
 
# add the included header file in /usr/src/pjproject-2.6.1/pjsip/include/pjsip-ua/
cp ../include/pjproject/sip_config.h /usr/src/custom-build/pjproject-2.6.1/pjsip/include/pjsip-ua/

# apply the patch to the source code
patch /usr/src/custom-build/pjproject-2.6.1/pjsip/src/pjsip-ua/sip_inv.c ../patches/pjproject/2.6/sip_inv.c.patch

# creat the new cache dir
if [ ! -d /usr/src/external-cache ]; then
	mkdir /usr/src/external-cache
fi

# create the new tarball from 2.6.1
tar -cjvf /usr/src/external-cache/pjproject-2.6.1.tar.bz2 /usr/src/custom-build/pjproject-2.6.1 

# create the new md5 checksum on the above tarball
md5sum /usr/src/external-cache/pjproject-2.6.1.tar.bz2 > /usr/src/external-cache/pjproject-2.6.1.md5

# move into asterisk 15.1.2 

# change the asterisk-15.1.2/third-party/pjproject/source/version.mak to 2.6.1

# configure --with-externals-cache=/usr/src/cache

# make, make install, ldconfig, restart

# EOF
