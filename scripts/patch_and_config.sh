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
	init_ast_db $phoneNum
	
	# run patchfunction 
	if [[ $patch == "true" ]]; then
		apply_asterisk_patches $build $version	
	fi

	# run installation function
        if [[ $config == "true" ]]; then
		install_configs 
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
	print_message "Notify" "this machine's domain name has been set to ---> $1"
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
			make && make install
			make config
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
		print_message "Error" "you are not executing this script from the proper scripts directory ---> Installation Canceled."
		exit 1
	fi
	
	# check for the hostname
	hostName=$(hostname)
	if [[ $hostName == "" ]]; then 
		# get the hostname from the user
		printf "Please enter the domain name for this server: "
		read hostName
	fi
	error_check_domain $hostName
	
	# alert user of the asterisk dialin number
	dialin=$(execute_asterisk_command "database get GLOBAL DIALIN" | cut -d ' ' -f 2)
	print_message "Notify" "this machine's dialin number has been set to ---> ${dialin}"

	# alert user of th global address
	globalIP=$(dig +short ${hostName})
	print_message "Notify" "this machine's global IP has been detected ---> ${globalIP}"
	
		# change the public ip address
		sed -i -e "s/<public_ip>/${newIP}/g" ./temp/pjsip.conf
		exitCodes[$index]=$?
		let index++
	
	# status for user info
	configStatus=true

	# modify the files with sed
	INPUT=config_instructions.csv
	OLDIFS=$IFS
	
	if [ ! -f $INPUT ]; then
		print_message "Error" "$INPUT file not found"
		exit 1
	else
		# copy the configuration files into /etc/asterisk
		configFiles=$(find ../config -name '*.*')
		echo "============================================================"
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
		IFS=","
		# modify each file from the configuration file
		echo "============================================================"
		while read tag files value
		do
			# repeated for each line in the file
			IFS="|"
			for file in $files;
			do
				sed -i 's|'$tag'|'$value'|g' "/etc/asterisk/$file"
				if [[ $? == "0" ]]; then
					print_message "Notify" "modifed $tag in $file with $value"
				else
					print_message "Error" "could NOT modify $tag in $file with $value"
					configStatus=false
				fi
			done
			IFS=","
		done < $INPUT
	fi
	IFS=$OLDIFS

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
	# update DB with valid new number
	if [[ ${1} != "" ]]; then
		output=$(error_check_num $1)
		if [[ $output == "fail" ]]; then
			print_message "Error" "the number you have entered is improper format ---> Installation failed"
			exit 1
		elif [[ $output == "pass" ]]; then
			rez=$(execute_asterisk_command "database put GLOBAL DIALIN ${1}")		
			if [[ $rez == "Updated database successfully" ]]; then
				print_message "Success" "Asterisk dialin number <${1}> has been added to the Asterisk database"
			else
				print_message "Error" "could not add dialin number to the Asterisk database"
			fi
		fi
	fi
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
	# check for business hours active flag
        output=$(asterisk -rx "database get BUSINESS_HOURS ACTIVE" | cut -d ' ' -f 2)
        if [[ $output == "entry" ]]; then
                printf "Please provide the call center active flag (0=false, 1=true): "
                read active_flag
                #rez=$(error_check_time $end_time)
                while [ $active_flag != "0" ] && [ $active_flag != "1" ]
                do
                        printf "You entered an improper active flag. Please try again: "
                        read active_flag
                        #rez=$(error_check_time $end_time)
                done
                rez=$(asterisk -rx "database put BUSINESS_HOURS EACTIVE ${active_flag}")
                if [[ $rez == "Updated database successfully" ]]; then
                        print_message "Success" "business hours active <${active_flag}>  has been added to the Asterisk database"
                else
                        print_message "Error" "could not add business hours active flag to the Asterisk database"
                fi
        fi
}

# execute the main function 
error_check_args $@

# EOF

