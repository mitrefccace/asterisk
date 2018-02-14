# Asterisk for Ace Direct

### Purpose
-----------
This repository contains all of the necessary files and scripts required to create and track the 
most stable version of Asterisk and PJSIP. The configuration files are the primary source of 
modifcation to the server and should be adjusted (external media address, local address, phone number) 
for each new server instance and then placed within __/etc/asterisk/__. Additionally, patch files have 
been included and can be applied if desired. An installation script has been included to assist with this process.

### Content
-----------
The __root__ directory contains the following:
- Asterisk configuration files
- Installation script (configs)

The __./patches__ directory contains the following:
- Asterisk patch files
- Installation script (patches)

### Installation Instructions
----------------------------------
1. Clone this repo to the destination. 
2. Move into __asterisk-ace-direct/__.
3. Execute `sudo su` 
4. Execute one of the following commands:  

|                 Command                                            | Purpose                                                                                  |
| -------------------------------------------------------------------| -----------------------------------------------------------------------------------------|
| `$ ./update_asterisk.sh --help`                                   | Provides instructions                                                                    |
| `$ ./update_asterisk.sh --version 15.1.2 --patch --build`         | Applies patches to asterisk-15.1.2 source code and then rebuilds it                      |
| `$ ./update_asterisk.sh --config --dialin 8003671294`             | Installs the configuration files using the provided phone number                         |
| `$ ./update_asterisk.sh --patch --build --config --restart --cli` | Applies the patches, rebuilds the source, restarts Asterisk and starts the CLI           |

### Configuration Files
-----------------------------------------
##### Variables
* The __external_media_address__ parameter within __pjsip.conf__ requires modification. 
This script utilizes the machine's hostname to determine the external IP address. If
this value is null, it will query the user to input the proper domain name.
* The __local_net__ parameter will be set using the __ifconfig__ tool. 
* The phone number for the server must be modified within __extensions.conf__. 
This can be supplied with the __--dialin__ flag. Otherwise, it quereis the Asterisk
databse for the dialin number. If this value is null or has not been configured, then the 
user will be asked to enter the phone number before proceeding. 
* Additionally, everytime this program is run, it will check that the Asterisk DB contains 
entries for the dialin number and both the start and end times for the call center. If any 
of the values are null, the user will be queried. 

##### Error Checking
* The domian name is checked to make sure the __dig__ command can resolve the address. 
If not, it returns an error. 
* The phone number is validated by checking that it is composed of only numbers [0-9] 
and contains only 10 total digits. If not, it returns an error.
* The start and end times are evaluated to make sure they are in the proper ##:## format.

##### File Modifications
* These are made by executing sed commands to perform a search and replace on the files.
* The modifications are made within a temporary directory so that the original files are 
not altered. 

##### Clean Up
* The modified files are first copied into __/etc/asterisk/__.
* Then the temporary directory is removed.
* If the __--restart__ option is selected, Asterisk will be restarted. 
* If the __--cli__ option is selected, the Command Line Interface for Asterisk will launch. 

### Patch Files
----------------------------------

##### Input
* Very little user input is required. At most, it queries the user to make sure they wish to 
continue with a particular step. If the patch has already been applied then answer [n] for __no__ 
so that the reverse patch is not applied. If you do not specify the Asterisk version number when 
running, then you will be prompted for this information. 

##### Process
* The script functions by determining which files to patch by searching for the __asterisk-ace-direct__ 
repo in the file system.
* Once there, it reads patch files such as __foo.c.patch__ within the patch directory and searches for the 
__foo.c__ source file within the __Asterisk-x.x.x__ directory. If the file is not found, it will alert the user. 
* After the patches have been applied with the __patch__ command, the Asterisk source code may be recompiled 
using the __make__ commands. Just add the __--build__ to execute these commands and build 
the project after applying the patches.

