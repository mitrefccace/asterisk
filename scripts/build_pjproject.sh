#!/bin/bash

# note our current dir location
startPath=$(pwd)
instLoc="/usr/src/"
astVersion="15.1.2"
pjVersion="2.6.1"

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
source /etc/environment
print_message "Notify" "pulling down the pjproject source code from github"
git clone https://github.com/asterisk/third-party.git
sleep 2

# create the custom-build dir
if [ ! -d "${instLoc}custom-build" ]; then
	print_message "Notify" "making the custom-build directory"
	mkdir "${instLoc}custom-build"
fi

# untar the version 2.6 project to /usr/src
tar -xvjf ./third-party/pjproject/2.6/pjproject-2.6.tar.bz2 -C "${instLoc}custom-build"
sleep 1

# rename dir to pjproject-2.6.1 && apply the included patch
mv "${instLoc}custom-build/pjproject-2.6" "${instLoc}custom-build/pjproject-${pjVersion}"
 
# add the included header file in /usr/src/pjproject-2.6.1/pjsip/include/pjsip-ua/
print_message "Notify" "adding sip_config.h to pjproject"
cp ../include/pjproject/sip_config.h "${instLoc}custom-build/pjproject-${pjVersion}/pjsip/include/pjsip-ua/"

# apply the patch to the source code
print_message "Notify" "applying patch to sip_inv.c"
patch "${instLoc}custom-build/pjproject-${pjVersion}/pjsip/src/pjsip-ua/sip_inv.c" ../patches/pjproject/2.6/sip_inv.c.patch

# creat the new cache dir
if [ ! -d "${instLoc}external-cache" ]; then
	print_message "Notify" "making the external-cache directory"
	mkdir "${instLoc}external-cache"
fi

# create the new tarball from 2.6.1
cd "${instLoc}custom-build"
tar -cjvf "pjproject-${pjVersion}.tar.bz2" "./pjproject-${pjVersion}" 
mv "pjproject-${pjVersion}.tar.bz2" "${instLoc}external-cache"

# create the new md5 checksum on the above tarball
cd "${instLoc}external-cache"
md5sum "pjproject-${pjVersion}.tar.bz2" > "pjproject-${pjVersion}.md5"

# move into asterisk 15.1.2 
astPath=$(find / -type d -name "asterisk-${astVersion}")
cd $astPath

# change the asterisk-15.1.2/third-party/versions.mak to 2.6.1
print_message "Notify" "setting custom pjproject build version to ${pjVersion}"
sed -i "s/PJPROJECT_VERSION = 2.6.*/PJPROJECT_VERSION = ${pjVersion}/g" "${astPath}/third-party/versions.mak"

# build
./configure --with-externals-cache="${instLoc}external-cache"
make 
make install
if [[ $? == "0" ]];then
	print_message "Success" "Asterisk ${astVersion} built successfully with custom pjproject version ${pjVersion}"
	cd $startPath
	rm -rf ./third-party
else
	print_message "Error" "failed to install Asterisk-${astVersion} with pjproject ${pjVersion}"
fi

ldconfig

# EOF

