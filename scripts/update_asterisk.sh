#!/bin/bash

#----------------------------------------------------------------------------
# Author   : Connor McCann
# Project  : Ace Direct Asterisk Configuration 
# Date     : 31 Jan 2018
# Purpose  : To automate patches and the installation of Asterisk configuration 
#            files on various Ace Direct servers.
#----------------------------------------------------------------------------

function show_instructions {
		echo
		echo "+-------------------------------------------------------------------------------------------------+"
		echo "+ Run this script if you would like to:                                                           +"
		echo "+                      1. Apply patches to Asterisk source code                                   +"
		echo "+                      2. Install the configuration files to /etc/asterisk/                       +"
		echo "+                      3. Install the media files to /var/lib/asterisk/sounds                     +"
		echo "+                                                                                                 +"
		echo "+                                                                                                 +"
		echo "+ ./update_asterisk.sh [Optional_Flags]                                                           +"
		echo "+                                                                                                 +"
		echo "+            --help     : Optional : Displays these program instructions                          +"
		echo "+            --patch    : Optional : Applies patch files to source code                           +"
		echo "+            --config   : Optional : Copies configuration files into /etc/asterisk/               +"
		echo "+            --media    : Optional : Copies media files into /var/lib/asterisk/sounds             +"
		echo "+            --backup   : Optional : Copies direcotry files to backup directory before installing +"
		echo "+            --no-db    : Optional : Prevents the script from checking DB values                  +"
		echo "+            --version  : Optional : Specifies which version of Asterisk to look for              +"
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
                print_message "Error" "try running './update_asterisk.sh --help' for more information  ---> exiting program"
                exit 1
        fi

        # parse all of the input arguments
	patch=false
	config=false
	backup=false
	db=true
	build=true
	media=false
	restartArg=false
        cliArg=false
        phoneNum=""	
	version=""
	done= false

	while [ !done ]
        do
		case "$1" in
                        --help)
                                show_instructions
                                exit 0
                                ;;
                        --patch)
				patch=true
				shift
				;;
			--config)
				config=true
				shift
				;;
			--backup)
				backup=true
				shift
				;;
			--no-db)
				db=false
				shift
				;;
			--media)
				media=true
				shift
				;;
			--version)
				case "$2" in
					"") print_message "Error" "--version flag must be followed by a version number" 
					    exit 1 ;;
					--*) print_message "Error" "--version flag must be followed by a version number"
					     exit 1 ;;
					*) version=$2; shift 2 ;;
				esac ;;
			--no-build)
				build=false
				shift
				;;
			--restart)
                                restartArg=true
				shift
                                ;;
                        --cli)
                                cliArg=true
				shift
                                ;;
			--dialin)
				case "$2" in
					"") print_message "Error" "dialin flag must be followed by a version number" 
					    exit 1 ;;
					--*) print_message "Error" "dialin flag must be followed by a version number"
					     exit 1 ;;
					*) phoneNum=$2; shift 2 ;;
				esac ;;
			"") done=true; break;;
                        *)
                                print_message "Error" "unkown argument: try running './update_asterisk.sh --help' for more information  ---> exiting program"
                                exit 1
                esac
        done

	# print setting to user
	echo "---------------------------------"
	echo "patch    : ${patch}"
	echo "config   : ${config}"
	echo "media    : ${media}"
	echo "backup   : ${backup}"
	echo "no-db    : ${db}"
	echo "version  : ${version}"
	echo "no-build : ${build}"
	echo "restart  : ${restartArg}"
	echo "cli      : ${cliArg}"
	echo "dialin   : ${phoneNum}"
	echo "---------------------------------"

	# check_ast_status, then initialize the 
	# asterisk database with business hours
	if [[ $db == "true" ]] || [[ $phoneNum != "" ]]; then
		check_ast_status
		init_ast_db $phoneNum
	fi
	# run patch function 
	if [[ $patch == "true" ]]; then
		apply_asterisk_patches $build $version	
	fi
	# run installation function
        if [[ $config == "true" ]]; then
		install_configs $backup 
	fi
	if [[ $media == "true" ]]; then
		install_media $backup
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
		versionNum="15.3.0-rc1"
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

function install_media {
	# first arg corresponds with backup flag
	backup=$1

	# check that we are in the proper directory 
	AD=$(pwd)
	current_dir=$(basename $AD)
        if ! [[ $current_dir == "scripts" ]]; then
		print_message "Error" "you are not executing this script from the proper scripts directory ---> Installation Canceled."
		exit 1
	fi

	mediaFiles=$(find ../media -name '*.*')
	mediaDir=/var/lib/asterisk/sounds
	mediaStatus=true

	# make a backup of the sounds media directory if specified 
	if [ $backup == "true" ]; then
		make_backup $mediaDir
	fi

	echo "============================================================"
	for file in $mediaFiles
	do
		yes | cp -rf $file $mediaDir 2>/dev/null
		if [[ $? == "0" ]]; then
			print_message "Notify" "copied ${file} ---> $mediaDir"
		else
			mediaStatus=false
			print_message "Error" "failed to copy ${file} ---> $mediaDir"
		fi
	done

	# setup complete
	if [[ $mediaStatus == "true" ]]; then
		print_message "Success"  "Media file apply complete"
	else
		print_message "Error" "failed to apply media files"
	fi
}

function install_configs {
	# backup var passed in as arg 1
	backup=$1
	
	# check that we are in the proper directory 
	AD=$(pwd)
	current_dir=$(basename $AD)
        if ! [[ $current_dir == "scripts" ]]; then
		print_message "Error" "you are not executing this script from the proper scripts directory ---> Installation Canceled."
		exit 1
	fi
	
	# alert user of the asterisk dialin number
	dialin=$(execute_asterisk_command "database get GLOBAL DIALIN" | cut -d ' ' -f 2)
	rez=$(error_check_num $dialin)
	if [ $rez == "pass" ]; then
		print_message "Notify" "this machine's dialin number has been detected ---> ${dialin}"
	else
		print_message "Error" "the Asterisk database does not contain a dialin number ---> Installation Canceled"
		exit 1
	fi
	
	# move odbc.ini.sample to /etc. 
	# TODO: Doing this manually for now, maybe we can make this dynamic?
	cp odbc.ini.sample /etc/odbc.ini
	print_message "Notify" "copied odbc.ini.sample ---> /etc/odbc.ini"

	# make a backup of the configuration files if desired
	if [ $backup == "true" ]; then
		make_backup "/etc/asterisk"
	fi

	# status for user info
	configStatus=true

	# modify the files with sed
	INPUT=.config
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

			if [[ $? == "0" ]]; then
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
				# If the file variable has a full path associated with it,
				# this statement will evaluate to true
				if [ $( dirname $file) != "." ]; then
					sed -i 's|'$tag'|'$value'|g' "$file"
				else
					sed -i 's|'$tag'|'$value'|g' "/etc/asterisk/$file"
				fi
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

function make_backup {
        # this method should work with full file paths and not relative ones
        # the only input argument will be the directory you wish to backup
        # thus a directory will have to be created within it to store all the files
        parent_dir=$(dirname $1)
	dir=$(basename $1)
        backup_dir="${parent_dir}/${dir}_backup"
        if [ ! -d $backup_dir ]; then
                mkdir $backup_dir
		print_message "Notify" "Creating backup directory ${backup_dir}"
        else
                rm -rf "$backup_dir/*"
		print_message "Notify" "Deleting contents of ${backup_dir}"
        fi
        # copy the files into backup
        cp -rf $1 $backup_dir
	if [ $? == "0" ]; then
		print_message "Success" "Backup files copied into $backup_dir"
	else
		print_message "Error" "Failed to copy files into $backup_dir ---> Exiting program ..."
		exit 1
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
	output=$(execute_asterisk_command "database get GLOBAL DIALIN" | cut -d ' ' -f 2)
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
	output=$(execute_asterisk_command "database get BUSINESS_HOURS START" | cut -d ' ' -f 2)
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
	output=$(execute_asterisk_command "database get BUSINESS_HOURS END" | cut -d ' ' -f 2)
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
        output=$(execute_asterisk_command "database get BUSINESS_HOURS ACTIVE" | cut -d ' ' -f 2)
        if [[ $output == "entry" ]]; then
                printf "Please provide the business hours active flag (0=not enforced, 1=enforced, 2=business closed): "
                read active_flag
                while [ $active_flag != "0" ] && [ $active_flag != "1" ] && [ $active_flag != "2" ] 
                do
                        printf "You entered an improper active flag. Please try again: "
                        read active_flag
                done
                rez=$(asterisk -rx "database put BUSINESS_HOURS ACTIVE ${active_flag}")
                if [[ $rez == "Updated database successfully" ]]; then
                        print_message "Success" "business hours active <${active_flag}>  has been added to the Asterisk database"
                else
                        print_message "Error" "could not add business hours active flag to the Asterisk database"
                fi
        fi
}

function check_ast_status {
	rez=$(service asterisk status | grep Active | cut -d ':' -f2 | cut -d ' ' -f2)
	if [[ $rez != "active" ]]; then
		print_message "Error" "Asterisk service is unreachable ---> Installation canceled"
		exit 1
	fi
}

# execute the main function 
error_check_args $@

# EOF

