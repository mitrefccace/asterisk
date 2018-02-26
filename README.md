# **Asterisk for ACE Direct Project**

This repository is to be used in conjunction with the documentation for the ACE Direct project (found on the project's [main page](https://github.com/FCC/ACEDirect/tree/master/docs)). The two directories contain configuration files for Asterisk, as well as the media files used for this version of Asterisk. Please read this entire document before installing Asterisk for ACE Direct.

## Prerequisites

The Asterisk for ACE Direct configuration assumes the following:

* The Asterisk server has a public and local IP address
* A "dial-in" number which has been registered in iTRS and/or a SIP trunk provider (such as Twilio)
* An SSL cert file, acquired from a trusted certificate authority, for the domain of your server. This is necessary for WebRTC functionality as major browsers will drop connections to the Asterisk server if it's cert is not trusted.

## Automation

There is a script in this repo, within the 'scripts' directory, that will automate the installation of PJSIP and Asterisk, as well as 
pull down the configs and media files from this repo and move them to the appropriate locations.  View the README in the 'scripts'
directory for more information. It is HIGHLY recommended to use the script to install Asteris for ACE Direct, as manual installations
are officially unsupported by the ACE Direct project.

## Download/Configure

Once Asterisk and PJSIP has been installed on a server (see the "Automation" section below), pull down the repo containing the ACE Direct configs and media:


```sh

$ git clone <asterisk_repo_URL>
$ cd asterisk

```

Within the scripts directory, there is a hidden configuration file (.config) which contains place holder values to be used by Asterisk. 
This file is a CSV and is in the format place-holdr,file|file,value.
You will need to configure the default values on each line of this file for the Asterisk instance. 

Once the configurations have been implemented, run the following command to update Configuration files and media files:

```sh
sudo ./update_asterisk.sh --config --media --restart
```

## Modules

Some Asterisk modules have been enabled/disabled in the modules.conf file. Notable modules include:

* res_http_websocket.so: preloaded so that WebSocket connections for WebRTC will work
* res_musiconhold.so: loaded for music-on-hold capability for queues
* res_pjsip.so: loaded so PJSIP stack can be used
* chan_skinny.so: Skinny protocol for Cisco phones. Disabled because this causes Asterisk to listen to TCP connections on port 2000
* cel_pgsq.so: It appears that Asterisk v.14.4.0 and above tries to connect to PostgreSQL by default, and would cause error messages to be logged to the Asterisk console. Since ACE Direct uses MySQL, this module has been disbaled.
* chan_sip.so: disabled so PJSIP stack can be used
* cdr_odbc.so: For some reason, this module causes duplicate records to be written to the CDR database. Therefore, it is disabled. More info: https://stackoverflow.com/a/41740187/7057875

If you want/need any of these modules, feel free to modify the /etc/asterisk/modules.conf file.

## User-specific Configurations

There are some user-specific configurations that must be performed before using Asterisk:

* In pjsip.conf, each extension has a placeholder for the password used to register to the extension (typically "<password>"). These placeholders should be updated with the passwords chosen by each agent corresponding to the respective extension. The passwords for the WebRTC extensions should all be the same.
* In manager.conf, the password for the AMI interface should be changed as well.
* Each agent should have an entry at the end of agents.conf. The "fullname" attribute for each agent is optional. Currently, agents.conf has four agent entries which correspond to the default agent extensions, and should be updated as needed.


