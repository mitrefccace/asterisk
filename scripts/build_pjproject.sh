#!/bin/bash

# Author       : Connor McCann
# Project      : PJPROJECT Build For Asterisk ACEDirect
# Date         : 06 Mar 2018
# Purpose      : To rebuild Asterisk using a custom PJSIP stack 
#                which implements a patch to sip_inv.c that ultimately
#                removes the REFER method from the Allow header during
#                outbound INVITES.
#
#
# Instructions : The only thing which needs to be adjusted in this script are
#                the following two lines. Please set the Asterisk and PJPROJECT
#                versions to the exact string that is used for the repo names.

# Change these values 
##############################################
astVersion="15.3.0-rc1"
pjVersion="2.7.1"
#############################################
 
# note our current dir location
startPath=$(pwd)
currDir=$(dirname $startPath)
instLoc="/usr/src/"
pjCustom="${pjVersion}-custom"

function print_message {
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

# get the third party asterisk tarball for pjproject
print_message "Notify" "pulling down the pjproject source code from github"
git clone https://github.com/asterisk/third-party.git
sleep 2

# create the custom-build dir
if [ ! -d "${instLoc}custom-build" ]; then
	print_message "Notify" "making the custom-build directory"
	mkdir "${instLoc}custom-build"
fi

# untar the version 2.6 project to /usr/src
tar -xvjf ./third-party/pjproject/${pjVersion}/"pjproject-${pjVersion}.tar.bz2" -C "${instLoc}custom-build"
sleep 1

# rename dir to pjproject-2.6.1 && apply the included patch
mv "${instLoc}custom-build/pjproject-${pjVersion}" "${instLoc}custom-build/pjproject-${pjCustom}"

# change the ownership of the directory to root
chown -R root:root "${instLoc}custom-build/" 
 
# add the included header file in /usr/src/pjproject-2.6.1/pjsip/include/pjsip-ua/
print_message "Notify" "adding sip_config.h to pjproject"
cp "${currDir}/include/pjproject/sip_config.h" "${instLoc}custom-build/pjproject-${pjCustom}/pjsip/include/pjsip-ua/"

# apply the patch to the source code
print_message "Notify" "applying patch to sip_inv.c"
patch "${instLoc}custom-build/pjproject-${pjCustom}/pjsip/src/pjsip-ua/sip_inv.c" "${currDir}/patches/pjproject/${pjVersion}/sip_inv.c.patch"

# creat the new cache dir
if [ ! -d "${instLoc}external-cache" ]; then
	print_message "Notify" "making the external-cache directory"
	mkdir "${instLoc}external-cache"
fi

# create the new tarball from 2.6.1
cd "${instLoc}custom-build"
tar -cjvf "pjproject-${pjCustom}.tar.bz2" "./pjproject-${pjCustom}" 
mv "pjproject-${pjCustom}.tar.bz2" "${instLoc}external-cache"

# create the new md5 checksum on the above tarball
cd "${instLoc}external-cache"
md5sum "pjproject-${pjCustom}.tar.bz2" > "pjproject-${pjCustom}.md5"

# move into asterisk 15.1.2 
astPath=$(find / -type d -name "asterisk-${astVersion}")
cd $astPath

# change the asterisk-15.1.2/third-party/versions.mak to 2.6.1
print_message "Notify" "setting custom pjproject build version to ${pjCustom}"
sed -i "s/PJPROJECT_VERSION = *.*/PJPROJECT_VERSION = ${pjCustom}/g" "${astPath}/third-party/versions.mak"

# build
./configure --with-externals-cache="${instLoc}external-cache"
make 
make install
if [[ $? == "0" ]];then
	print_message "Success" "Asterisk ${astVersion} built successfully with custom pjproject version ${pjCustom}"
	make config
	ldconfig
	# clean up
	cd $startPath
	rm -rf ./third-party
else
	print_message "Error" "failed to install Asterisk-${astVersion} with pjproject ${pjCustom}"
fi

# restart the Asterisk instance
service asterisk restart

# EOF

