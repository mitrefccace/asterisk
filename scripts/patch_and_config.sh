#!/bin/bash

#----------------------------------------------------------------------------
# Author   : Connor McCann
# Project  : Ace Direct Asterisk Configuration 
# Date     : 18 Jan 2018
# Purpose  : To automate patches and the installation of Asterisk configuration 
#            files on various Ace Direct servers.
#----------------------------------------------------------------------------

function show_instructions {
		echo
		echo "+-------------------------------------------------------------------------------------------------+"
		echo "+ Run this script if:                                                                             +"
		echo "+                      1. You would like to apply patches to Asterisk source code                 +"
		echo "+                      2. You would like to install the configuration files to /etc/asterisk/     +"
		echo "+                                                                                                 +"
		echo "+                                                                                                 +"
		echo "+ ./patch_and_config.sh [Required_Flag] [Optional_Flag]                                           +"
		echo "+                                                                                                 +"
		echo "+            --help     : Optional : Displays these program instructions                          +"
		echo "+            --patch    : Required : Applies patch files to source code                           +"
		echo "+            --config   : Required : Copies configuration files into /etc/asterisk/               +"
		echo "+            --version  : Required : Specifies which version of Asterisk to look for              +"
		echo "+            --no-build : Optional : Opts not to build the source code                            +"
		echo "+            --restart  : Optional : Restarts Asterisk                                            +"
		echo "+            --cli      : Optional : Launches Asterisk CLI upon completion                        +"
		echo "+            --dialin   : Optional : Takes phone number as next argument                          +"
		echo "+-------------------------------------------------------------------------------------------------+"
		echo
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

function error_check_args {
        # handle no arguments
        if [[ $@ == "" ]]; then
                print_message "Error" "try running './patch_and_config.sh --help' for more information  ---> exiting program"
                exit 1
        fi

        # parse all of the input arguments
	patch=false
	config=false
	build=true
	restartArg=false
        cliArg=false
	nextIsNum=false
	nextIsVersion=false
        phoneNum=""	
	version=""

	for arg in $@
        do
		if [[ $nextIsNum == "true" ]]; then
			phoneNum=$arg
			nextIsNum=false
			continue
		elif [[ $nextIsVersion == "true" ]]; then
			version=$arg
			nextIsVersion=false
			continue
		fi
		
		case $arg in
                        --help)
                                show_instructions
                                exit 0
                                ;;
                        --patch)
				patch=true
				;;
			--config)
				config=true
				;;
			--version)
				nextIsVersion=true
				;;
			--no-build)
				build=false
				;;
			--restart)
                                restartArg=true
                                ;;
                        --cli)
                                cliArg=true
                                ;;
			--dialin)
				nextIsNum=true
				;;
                        *)
                                print_message "Error" "unkown argument: try running './patch_and_config.sh --help' for more information  ---> exiting program"
                                exit 1
                esac
        done
	
	# initialize the asterisk database with business hours
	init_ast_db
	
	# run patchfunction 
	if [[ $patch == "true" ]]; then
		apply_asterisk_patches $build $version	
	fi

	# run installation function
        if [[ $config == "true" ]]; then
		install_configs $phoneNum
	fi
	
	# handle any remaingin arg commands
	execute_args $restartArg $cliArg 

}

function error_check_time {
	# check the length
	strLength=$(echo -n $1 | wc -m)
	if [[ $strLength != 5 ]]; then
		echo "fail"
	# check for ':' format
	elif [[ $1 == *":"* ]]; then
		re='^[0-9]+$'
		hour=$(echo $1 | cut -d ':' -f 1)
		min=$(echo $1 | cut -d ':' -f 2)
		# check the hour
		if ! [[ $hour =~ $re ]]; then
			echo "fail"
		# check the minutes
		elif ! [[ $min =~ $re ]]; then
			echo "fail"
		else
			echo "pass"
		fi
	else
		echo "fail"
	fi	
}

function error_check_num {
	# check that the entered value is of 10 digits in length
	strLength=$(echo -n $1 | wc -m)
	re='^[0-9]+$'
	if [[ ${strLength} != 10 ]]; then
		echo "fail"	
	elif ! [[ $1 =~ $re ]]; then
		echo "fail" 
	else
		# alert user we are accepting the number
		echo "pass"
	fi
}

function error_check_domain {
	# make sure that the entered domain name will resolve
	ip=$(dig +short	${1})
	if [[ $ip == "" ]]; then
		print_message "Error" "the domain you have entered does not resolve ---> Installation failed"
		exit 1	
	fi
	
	# alert the user we are accepting the domain name
	print_message "Notify" "$1 will now be used within pjsip.conf"
}

function find_dir {
	# make sure asterisk-ace-direct repo is present
        echo $1
	dirs_string=$(find / -type d -name $1)
	read -a AD <<<$dirs_string
        
	if [[ $AD == "" ]]; then
                print_message "Error" "please clone asterisk-ace-direct repository first ---> exiting program"
                exit 1
        fi
        num_AD=$(find / -type d -name 'asterisk*' | wc -l)

        # handle multiple dirs
        if [[ $num_AD > 1 ]]; then
                print_message "Notify" "several directories have been found..."
                let index=0

                for dir in ${AD[@]}
                do
                        echo "$index : $dir"
                        let index++
                done

                # accept user input for row/dir number
                printf "Please select which row number is the proper directory (0-indexed): "
                read index

                # make sure the user entered a number
                re='^[0-9]+$'
                while ! [[ $index =~ $re ]];
                do
                        printf "Incorrect value...please select which row number is the proper directory (0-indexed):\t"
                        read index
                done
                
		AD=${AD[$index]}
		print_message "Notify" "selecting ${AD}"
		
		# return 
		echo $AD
        fi
}

function apply_asterisk_patches {
        # check that we are in the proper directory 
	currentPath=$(pwd)
	currentDir=$(basename $currentPath)
        if ! [[ $currentDir == "scripts" ]]; then
		print_message "Error" "you are nto executing this script from the proper scripts directoty ---> Installation failed."
		exit 1
	else
		AD=$(dirname $currentPath)
	fi
	# find the location of Asterisk 15.1.2
        versionNum=$2
	if [[ $versionNum == "" ]]; then
		#printf "Please enter an Asterisk version number: "
		#read versionNum
		versionNum="15.1.2"
	fi

	asteriskPath=$(find / -type d -name "asterisk-${versionNum}")
	#dirName="asterisk-${versionNum}"
	#asteriskPath=$(find_dir $dirName)
	if [[ $asteriskPath == "" ]]; then
		print_message "Error" "did not find that version of Asterisk anywhere ---> exiting program"
		exit 1
	else
        	print_message "Notify" "found asterisk directory : ${asteriskPath}"
	fi
	
        # loop over each patch in the patch directory 
        patches=$(find ${AD} -wholename "*/${versionNum}/*.patch")
	
        # handle null patches
        if [[ $patches == "" ]]; then
                print_message "Error" "did not find any patch files ---> exiting program"
                exit 1
        fi

        for patch in $patches
        do
                # determine the name of the file to be patched
                patchFileName=$(basename $patch)
                sourceFileName=${patchFileName:0:-6}

                # find the file to be patched within Asterisk 15.1.2 
                # this may be an array if there are several files
                fullSourceFilePaths=$(find ${asteriskPath} -name ${sourceFileName})

                # handle source file(s) not found
                if [[ $fullSourceFilePaths == "" ]]; then
                        print_message "Error" "did not find ${sourceFileName} ---> exiting program"
                        exit 1
                fi

                for fullSourceFilePath in $fullSourceFilePaths
                do
                        sourceFilePath=$(dirname ${fullSourceFilePath})
                        print_message "Notify" "found ${sourceFileName} in ${sourceFilePath}"

                        # apply the patch
                        originalFile=$fullSourceFilePath
                        patch $originalFile $patch
                done
        done

        # alert user of patch completion 
        print_message "Success" "patches have been applied"

        # rebuild source
        if [[ $1 == "true" ]]; then
                printf "Continue building Asterisk from source (yes/no)? : "
                read userResp

                if [[ $userResp == "yes" ]] || [[ $userResp == "y" ]]; then
                        # configure 
                        print_message "Notify" "moving to ${asteriskPath}"
                        cd $asteriskPath
                        # make
                        source /etc/environment
			make && make install
			ldconfig
			# move back into the AD repo
			print_message "Notify" "moving back into ${AD}/scripts"
			cd "$AD/scripts"
                else
                        # handle no 
                        print_message "Notify" "aborting the build process ---> Pacthes applied but source not built"
                fi
        fi
}

function install_configs {
	# check that we are in the proper directory 
	AD=$(pwd)
	current_dir=$(basename $AD)
        if ! [[ $current_dir == "scripts" ]]; then
		print_message "Error" "you are nto executing this script from the proper scripts directoty ---> Installation failed."
		exit 1
	fi
	# check for the hostname
	hostName=$(hostname)
	if [[ $hostName == "" ]]; then 
		# get the hostname from the user
		printf "Please enter the domain name for this server:\t"
		read hostName
	fi
	error_check_domain $hostName
	# the new information
	newNum=$1
	if [[ $newNum  == "" ]]; then
		# try to query asterisk db for call center phone number
		newNum=$(execute_asterisk_command "database get GLOBAL DIALIN" | cut -d ' ' -f 2)
	fi
	output=$(error_check_num $newNum)
	if [[ $output == "fail" ]]; then
		print_message "Error" "the number you have entered is improper format ---> Installation failed"
		exit 1
	elif [[ $output == "pass" ]]; then
		print_message "Notify" "${newNum} will now be used within extenstions.conf"
	fi

	newIP=$(dig +short ${hostName})
	# WARNING -- the following line could pose a problem to 'dual-homed' servers
	newLocalNet=$(ifconfig | grep inet -m 1 | cut -d ' ' -f 10)

	if [[ ${newIP} != "" ]] && [[ ${newLocalNet} != "" ]]; then
		# status for user info
		configStatus=true
	
		# create an array to hold exit codes
		declare -a exitCodes
		let index=0

		# modify the files with sed
		mkdir temp
		cp ../config/pjsip.conf ./temp
		cp ../config/rtp.conf ./temp
		cp ../config/res_stun_monitor.conf ./temp
		cp ../config/http.conf ./temp

		# change the public ip address
		sed -i -e "s/<public_ip>/${newIP}/g" ./temp/pjsip.conf
		exitCodes[$index]=$?
		let index++
	
		# change the local ip address
		sed -i -e "s/<local_ip>/${newLocalNet}/g" ./temp/pjsip.conf
		exitCodes[$index]=$?
		let index++
		
		# change stun server
		stun="stun.task3acrdemo.com"
		sed -i -e "s/<stun_server>/$stun/g" ./temp/rtp.conf ./temp/res_stun_monitor.conf
		exitCodes[$index]=$?
		let index++
		
		# change the cert file
		certPath="\/etc\/asterisk\/keys\/star.pem"
		sed -i -e "s/<crt_file>/$certPath/g" ./temp/pjsip.conf ./temp/http.conf
		exitCodes[$index]=$?
		let index++
		
		#change the cert key
		keyPath="\/etc\/asterisk\/keys\/star.key"
		sed -i -e "s/<crt_key>/$keyPath/g" ./temp/pjsip.conf ./temp/http.conf
		exitCodes[$index]=$?
		let index++
		
		# alert user if mods to pjsip.conf were successfull
		problem=false
		for code in ${exitCodes[@]}
		do
			if [[ $code == "1" ]]; then
				problem=true
				configStatus=false
				break
			fi
		done

		if [[ $problem == "true" ]]; then
			print_message "Error" "there was a problem modifying pjsip.conf"
			configStatus=false
		else
			print_message "Notify" "modified pjsip.conf successfully"
		fi

		# change the phone number associated with Asterisk for inbound calls from provider devices
		#sed -i "s/[0-9]\{10\}/${newNum}/g" ./temp/extensions.conf 
		
		# alert user if mods to extensions.conf were successfull
		#if [[ $? == 0 ]]; then
		#	print_message "Notify" "modified extensions.conf successfully"
		#else
		#	print_message "Error" "there was a problem modifying extensions.conf"
		#	configStatus=false
		#fi
	else
		# handle the error
		print_message "Error" "could not resolve IP address ---> Installation failed"
		exit 1
	fi

	# replace the asterisk config files
	cp ./temp/pjsip.conf /etc/asterisk
	cp ./temp/rtp.conf /etc/asterisk
	cp ./temp/res_stun_monitor.conf /etc/asterisk
	cp ./temp/http.conf /etc/asterisk
	#cp ./temp/extensions.conf /etc/asterisk/

	if [[ $? == 0 ]]; then
		print_message "Notify" "copied ./config/pjsip.conf ---> /etc/asterisk/"
		print_message "Notify" "copied ./config/rtp.conf ---> /etc/asterisk/"
		print_message "Notify" "copied ./config/res_stun_monitor.conf ---> /etc/asterisk/"
		print_message "Notify" "copied ./config/http.conf ---> /etc/asterisk/"
		echo "============================================================================="
		#print_message "Notify" "copied ./configs/extensions.conf ---> /etc/asterisk/"
	else
		configStatus=false
	fi

	# replace the rest of the configuration files
	configFiles=$(find ../ -name '*.conf' -and -not -name 'pjsip.conf'\
					      -and -not -name 'rtp.conf'\
					      -and -not -name 'res_stun_monitor.conf'\
					      -and -not -name 'http.conf')
	for file in $configFiles
	do
		cp $file /etc/asterisk/
		if [[ $? == 0 ]]; then
			print_message "Notify" "copied ${file} ---> /etc/asterisk/"
		else
			print_message "Error" "failed to copy ${file} ---> /etc/asterisk/"
			configStatus=false
		fi
	done
	
	# clean up
	rm -rf ./temp

	# setup complete
	if [[ $configStatus == "true" ]]; then
		print_message "Success"  "Configuration complete"
	else
		print_message "Error" "failed to install configuration files"
	fi
}	

function execute_args {
	# restart asterisk so the changes are in effect
	if [[ $1 == "true" ]]; then
		service asterisk restart
	fi

	# start the CLI interface
	if [[ $2 == "true" ]]; then
		sleep 2
		asterisk -rvvvvvvvc
	fi
}

function execute_asterisk_command {
	output=$(sudo asterisk -rx "${1}")	
	echo $output
}

function init_ast_db {
	# check for the dialin number
	output=$(asterisk -rx "database get GLOBAL DIALIN" | cut -d ' ' -f 2)
	if [[ $output == "entry" ]]; then
		printf "Please provide the call center dialin number: "
		read dialin
		rez=$(error_check_num $dialin)
		while [ $rez == "fail" ]
		do
			printf "You entered an improper dialin number. Please try again: "
			read dialin
			rez=$(error_check_num $dialin)
		done
		rez=$(asterisk -rx "database put GLOBAL DIALIN ${dialin}")
		if [[ $rez == "Updated database successfully" ]]; then
			print_message "Success" "Asterisk dialin number <${dialin}> has been added to the Asterisk database"
		else
			print_message "Error" "could not add dialin number to the Asterisk database"
		fi 
	elif [[ $output == "" ]]; then
		print_message "Error" "asterisk service is down ---> Installation failed."
		exit 1
	fi
	
	# check for business hours start time
	output=$(asterisk -rx "database get BUSINESS_HOURS START" | cut -d ' ' -f 2)
	if [[ $output == "entry" ]]; then
		printf "Please provide the call center start time: "
		read start_time
		rez=$(error_check_time $start_time)
		while [ $rez == "fail" ]
		do
			printf "You entered an improper start time. Please try again: "
			read start_time
			rez=$(error_check_time $start_time)
		done
		rez=$(asterisk -rx "database put BUSINESS_HOURS START ${start_time}")
		if [[ $rez == "Updated database successfully" ]]; then
			print_message "Success" "business hours start time <${start_time}> has been added to the Asterisk database"
		else
			print_message "Error" "could not add business hours start time to the Asterisk database"
		fi 
	fi 
	# check for business hours end time
	output=$(asterisk -rx "database get BUSINESS_HOURS END" | cut -d ' ' -f 2)
	if [[ $output == "entry" ]]; then
		printf "Please provide the call center end time: "
		read end_time
		rez=$(error_check_time $end_time)
		while [ $rez == "fail" ]
		do
			printf "You entered an improper end time. Please try again: "
			read end_time
			rez=$(error_check_time $end_time)
		done
		rez=$(asterisk -rx "database put BUSINESS_HOURS END ${end_time}")
		if [[ $rez == "Updated database successfully" ]]; then
			print_message "Success" "business hours end time <${end_time}>  has been added to the Asterisk database"
		else
			print_message "Error" "could not add business hours end time to the Asterisk database"
		fi 
	fi
}

# execute the main function 
error_check_args $@

# EOF

