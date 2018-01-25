#!/bin/bash

# note our current dir location
currPath=$(pwd)
instLoc="/usr/src/"
version="15.1.2"

# get the third party asterisk tarball for pjproject
source /etc/environment
git clone https://github.com/asterisk/third-party.git

# create the custom-build dir
if [ ! -d "${instLoc}custom-build" ]; then
	mkdir "${instLoc}custom-build"
fi

# untar the version 2.6 project to /usr/src
tar -xjvf ./third-party/pjproject/2.6/pjproject-2.6.tar.bz2 -C "${instLoc}custom-build"
rm -rf ./third-party

# rename dir to pjproject-2.6.1 && apply the included patch
mv "${instLoc}custom-build/pjproject-2.6" "${instLoc}custom-build/pjproject-2.6.1"
 
# add the included header file in /usr/src/pjproject-2.6.1/pjsip/include/pjsip-ua/
cp ../include/pjproject/sip_config.h "${instLoc}custom-build/pjproject-2.6.1/pjsip/include/pjsip-ua/"

# apply the patch to the source code
patch "${instLoc}custom-build/pjproject-2.6.1/pjsip/src/pjsip-ua/sip_inv.c" ../patches/pjproject/2.6/sip_inv.c.patch

# creat the new cache dir
if [ ! -d "${instLoc}external-cache" ]; then
	mkdir "${instLoc}external-cache"
fi

# create the new tarball from 2.6.1
tar -cjvf "${instLoc}external-cache/pjproject-2.6.1.tar.bz2" "${instLoc}custom-build/pjproject-2.6.1" 

# create the new md5 checksum on the above tarball
md5sum "${instLoc}external-cache/pjproject-2.6.1.tar.bz2" > "${instLoc}external-cache/pjproject-2.6.1.md5"

# move into asterisk 15.1.2 
astPath=$(find / -type d -name "asterisk-${version}")
cd $astPath

# change the asterisk-15.1.2/third-party/pjproject/source/version.mak to 2.6.1

#./configure --with-externals-cache="${instLoc}external-cache"
#make 
#make install
#ldconfig

# EOF
