# **Asterisk for ACE Direct Installation script**

The AD_asterisk_install.sh script in this directory will automate the installation and configuration of Asterisk for ACE Direct. This script has been developed for use on a CentOS 7.3.x (and newer) server, and support for earlier versions is not guaranteed. It will perform the following:

* Checks for SElinux and IPv6. Script fails if either are detected
* Include default parameters for STUN server, dial-in, and SSL certs if none are provided
* Install Asterisk and pjproject with dependencies
* Optional ‘yum update’ action (will prompt user to confirm)
* Generate self-signed SSL certs for Asterisk. User will be prompted to enter passphrase for SSL keys
* Download ACE Direct-specific configs and media files from GitHub and place them in proper directories
* Replaces placeholders with params passed to script


## Prerequisites

The Asterisk for ACE Direct configuration assumes the following:

* SELinux and IPv6 are disabled. If the script detects either of these two items, it will exit.
* The Asterisk server has a public and local IPv4 address. These are mandatory and the script will also fail without these two parameters.
* A hostname has been set on the server. If not hostname has been set, the script will fail.
* A "dial-in" number which has been registered in iTRS and/or a SIP trunk provider (such as Twilio) (optional)
* An SSL cert file, acquired from a trusted certificate authority, for the domain of your server. This is necessary for WebRTC functionality as major browsers will drop connections to the Asterisk server if it's cert is not trusted.

--------------------------------------------

## Configuration

There is a CSV file in this directory called .config.sample, which serves as a placeholder for custom Asterisk configs. It's structure is as follows:

``` sh
<tag for variable in config file>,<file_1>|<file_2>|<file_n>,<value>,
```

Before executing the install script, you MUST modify this file with the values for your environment, then change the name of the script to .config. Below is a list of each current parameter in the config file:

|    Tag              |              Usage                                                                  |
|--------------------:|------------------------------------------------------------------------------------:|
| <hostname>          | The domain name associated with the server.                                         |
| <local_ip>          | The private/local IP address of the Asterisk.                                       |
| <public_ip>         | The external.public IP address of the Asterisk server.                              |
| <stun_server>       | STUN/TURN server address:port. We recommend building a dedicated STUN server, as public STUN servers can become congested and lead to higher latency for STUN/ICE. If you do not have one, a Google STUN server will be used in the config instead.|                                  
| <crt_file>          | CA cert file for server. Generated self-signed cert is used if none is provided.    |
| <crt_key>           | Private key for CA cert.                                                            |
| <cdr_host>          | URI for the MySQL database.                                                         |
| <cdr_db>            | The name of the database to use.                                                    |
| <cdr_table>         | MySQL Table name used for CDR.                                                      |
| <cdr_user>          | MySQL username used by Asterisk to write CDR records.                               |
| <cdr_pass>          | Password for above MySQL username.                                                  |

(Note: the OS will need additional configurations to enable Asterisk to connect to MySQL. See the docs directory in the main ACE Direct repo for more info.)

--------------------------------------------

## Twilio

You can configure Twilio for use with Asterisk to route PSTN (i.e. non-VRS) calls to/from Asterisk. the extensions.conf and pjsip.conf files have configurations set for use with Twilio; however, they will not work unless you replace the <twilio_URI> placeholder in pjsip.conf with the Twilio termination URI of your SIP trunk. If it is not desired to use Twilio with ACE Direct, simply delete the sections of the dial-plan and SIP config that pertain to Asterisk. For more information on using Twilio with Asterisk, [download the Twilio docs](https://www.twilio.com/docs/documents/35/AsteriskTwilioSIPTrunkingv2_1.pdf).


--------------------------------------------

## update_asterisk.sh Instructions
1. Clone this repo to the destination. 
2. Move into __asterisk__.
3. Execute `sudo su` 
4. Modify values within .config 
5. Execute script  

## Asterisk Database Initialization 
* Each time this update script is run, it will check that the Asterisk service is running. 
If it is not, the installation will be canceled. 
* However, if the __--no-db__ flag is used, then this service check will not be performed and the Asterisk internal 
database will not be checked for the following values : (GLOBAL DIALIN, BUSINESS_HOURS START, BUSINESS_HOURS END, BUSINESS_HOURS ACTIVE). 
* If any of these values are missing in the DB, the user will be prompted for information.
* If the entered value is not accepted, then the user will be re-prompted. 
* If the dialin flag is specified, then the DB value for this field will be modified. 
## Media files
* If the __--media__ file flag is used as an argument, then all of the media files within this repository 
will be copied into /var/lib/asterisk/sounds.

## Configuration files
##### .config
* This is a comma separated value file which contains file modification instructions
for some of the tracked configuration files. 
* The line format is <place_holder>,file_1|file_2|...|file_n,value.
* Each file will be modifed so the place holder within it is replaced with the included value.
##### Error checking
* The server's hostname is checked to make sure the __dig__ command can resolve the domain to an IPV4 address. 
If not, it returns an error. 
* The dialin number is validated by checking that it is composed of only numbers [0-9] 
and contains only 10 total digits. If not, it returns an error.
* The start and end times are evaluated to make sure they are in the proper ##:## format.
If not, it will loop untill the user enters a proper value for the Asterisk DB.
##### File modifications
* These are made by executing sed commands to perform a search and replace on the files.
* The status of each file modification and placement will be visible in the script output. 

## Patch files

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

## Example usage

```sh
$ ./update_asterisk.sh --version 15.3.0 --patch --config --dialin 7032935641 --media --backup --restart --cli

```
* The example above will look for the asterisk-15.3.0 repository so that it can apply the patch files then rebuild
the source. Afterwards, it will handle the replacement of the configuration files and media files after creating backups of each directory, set the dialin value in the Asterisk 
database to 7032935641, restart, and launch the Asterisk CLI.

--------------------------------------------

## Build PJPROJECT
The purpose of this script is to rebuild the Asterisk source code with a custom version of PJSIP which implements a patch that removes the REFER method 
from the Allow Header for outbound SIP/SDP INVITES. To do this, the script accomplishes the following:
* The correct version of PJPROJECT is pulled down from the Asterisk third-party repository.
* This is then uncompressed and the patch to sip_inv.c (found in patches/pjproject/2.7.1/) is applied. 
* This source code is then packaged back into a .bz2 file and placed within an external-cache folder in /usr/src.
* This directory must also contain the md5 checksum file for the .bz2 source code in order for it to be verified during the Asterisk ./configure process.  
* Once these two files have been provisioned, Asterisk can be configured with the --with-externals-cache flag pointing to to our two new resources in /usr/src/external-cache
* Asterisk is then built as usual and restarted to complete the installation process.

## Example Usage

This will rebuild the Asterisk 15.3.0 source code with our custom patched version of PjProject 2.7.1. The __--clean__ flag will remove some of the build artifacts and temporary directories created by the script.

``` sh
$ ./build_pjproject.sh --ast-version 15.3.0 --pj-version 2.7.1 --clean
```

If you would like to use the default values, run the following command:

``` sh
$ ./build_pjproject.sh
```

Then it will assume the following values:

|         Flag        |          Value           |
|--------------------:|-------------------------:|
Asterisk Version      |  15.3.0
PJ-Project Version    |  2.7.1
Rebuild Asterisk      |  true
Remove Artifacts      |  false
