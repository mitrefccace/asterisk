#!/bin/bash

# Author       : Connor McCann
# Project      : PJPROJECT Build For Asterisk ACEDirect
# Date         : 06 Mar 2018
# Purpose      : To rebuild Asterisk using a custom PJSIP stack 
#                which implements a patch to sip_inv.c that ultimately
#                removes the REFER method from the Allow header during
#                outbound INVITES.


function show_instructions {
                echo
                echo "+-------------------------------------------------------------------------------------------------+"
                echo "+ Run this script if you would like to:                                                           +"
                echo "+                      1. Apply patches to Pjproject source code and rebuild into Asterisk        +"
                echo "+                                                                                                 +"
                echo "+                                                                                                 +"
                echo "+ ./update_asterisk.sh [Optional_Flags]                                                           +"
                echo "+                                                                                                 +"
                echo "+            --help        : Optional : Displays these program instructions                       +"
		echo "+            --no-build    : Optional : Opts not to build the Asterisk source code                +"
		echo "+            --ast-version : Optional : Specifies the next arg is the version of Asterisk         +"
		echo "+            --pj-version  : Optional : Specifies the next arg is the version of PJ-Project       +"		
		echo "+            --clean       : Optional : Removes build artifacts and directories                   +"
                echo "+-------------------------------------------------------------------------------------------------+"
                echo
}

function error_check_args {
	# vars
	build=true
	clean=false
	astVersion="15.3.0-rc1"
	pjVersion="2.7.1"
	done=false

	while [ !done ]
	do

		case "$1" in
			--help)
				show_instructions
				exit 0
				;;
			--no-build)
				build=false
				;;
			--ast-version)
				case "$2" in
					"") print_message "Error" "--ast-version flag must include a value" 
						exit 1;;
					# We need to add this case in the event that $2 is another flag
					--*) print_message "Error" "--ast-version flag must include a value"
						exit 1;;
					*) astVersion=$2; shift 2 ;;
				esac ;;
			--pj-version)
				case "$2" in
					"") print_message "Error" "--pj-version flag must include a value" 
						exit 1;;
					--*) print_message "Error" "--pj-version flag must include a value"
						exit 1;;
					*) pjVersion=$2; shift 2 ;;
				esac ;;
			--clean)
				clean=true
				;;
			--) done=true; break ;;
			*)
				print_message "Error" "unkown argument: try running './build_pjproject.sh --help' for more information  ---> exiting program"
				exit 1
		esac
	done

	# notify user of params to be used, then call the main function
	print_message "Notify" "running build_pjproject.sh with the following  values:"
	echo "-----------------------------------" 
	echo "Asterisk Version   :  ${astVersion}"
	echo "PJ-Project Version :  ${pjVersion}"
	echo "Rebuild Asterisk   :  ${build}"
	echo "Remove Artifacts   :  ${clean}"
	echo "-----------------------------------"
	main $astVersion $pjVersion $build $clean
}


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

function main {
	# inputs
	astVersion=$1
	pjVersion=$2
	buildAst=$3
	removeArtifacts=$4
	
	# note our current dir location
	startPath=$(pwd)
	currDir=$(dirname $startPath)
	instLoc="/usr/src/"
	pjCustom="${pjVersion}-custom"
	
	# get the third party asterisk tarball for pjproject
	print_message "Notify" "pulling down the pjproject source code from github"
	git clone https://github.com/asterisk/third-party.git
	sleep 2

	# create the custom-build dir
	if [ ! -d "${instLoc}custom-build" ]; then
		print_message "Notify" "making the custom-build directory"
		mkdir "${instLoc}custom-build"
	fi

	# untar pjproject to /usr/src
	tar -xvjf ./third-party/pjproject/${pjVersion}/"pjproject-${pjVersion}.tar.bz2" -C "${instLoc}custom-build"
	sleep 1

	# rename dir to pjproject-${pjVersion} && apply the included patch
	mv "${instLoc}custom-build/pjproject-${pjVersion}" "${instLoc}custom-build/pjproject-${pjCustom}"

	# change the ownership of the directory to root
	chown -R root:root "${instLoc}custom-build/" 
	 
	# add the included header file in /usr/src/pjproject-${pjVersion}/pjsip/include/pjsip-ua/
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

	# create the new tarball from ${pjVersion}
	cd "${instLoc}custom-build"
	tar -cjvf "pjproject-${pjCustom}.tar.bz2" "./pjproject-${pjCustom}" 
	mv "pjproject-${pjCustom}.tar.bz2" "${instLoc}external-cache"

	# create the new md5 checksum on the above tarball
	cd "${instLoc}external-cache"
	md5sum "pjproject-${pjCustom}.tar.bz2" > "pjproject-${pjCustom}.md5"

	# move into asterisk-${astVersion}
	astPath=$(find / -type d -name "asterisk-${astVersion}")
	cd $astPath

	# change the asterisk-${astVersion}/third-party/versions.mak to ${pjVersion}
	print_message "Notify" "setting custom pjproject build version to ${pjCustom}"
	sed -i "s/PJPROJECT_VERSION = *.*/PJPROJECT_VERSION = ${pjCustom}/g" "${astPath}/third-party/versions.mak"

	# build
	if [ $buildAst == "true" ]; then
		./configure --with-externals-cache="${instLoc}external-cache"
		make 
		make install
		if [[ $? == "0" ]];then
			print_message "Success" "Asterisk ${astVersion} built successfully with custom pjproject version ${pjCustom}"
			make config
			ldconfig
			
		else
			print_message "Error" "failed to install Asterisk-${astVersion} with pjproject ${pjCustom}"
		fi
	fi

	# delete some of the build artiifacts
	cd $startPath
	if [ $removeArtifacts == "true" ]; then
		if [ -d "./third-party" ]; then 
			rm -rf "./third-party"
			if [ $? == "0" ]; then
				print_message "Success" "deleted ${startPath}/third-party"
			else
				print_message "Error" "failed to delete ${startPath}/third-party"
			fi
		fi
		if [ -d "${instLoc}custom-build" ]; then
			rm -rf "${instLoc}custom-build"
			if [ $? == "0" ]; then
				print_message "Success" "deleted aritifact ${instLoc}custom-build"
			else
				print_message "Error" "failed to delete ${instLoc}custom-build"
			fi
		fi
		if [ -d "${instLoc}external-cache" ]; then
			rm -rf "${instLoc}external-cache"
			if [ $? == "0" ]; then
				print_message "Success" "deleted aritifact ${instLoc}external-cache"
			else
				print_message "Error" "failed to delete ${instLoc}external-cache"
			fi
		fi
	fi

	# restart the Asterisk instance
	service asterisk restart
}

# main entry point
error_check_args $@

# EOF

