# **Asterisk for ACE Connect Lite Project**

This repository is to be used in conjunction with the documentation for Ace Connect Lite (found [here](https://github.com/mitrefccace/aceconnectlite-public/blob/master/docs/ACE-Connect-Lite-Proof-of-Concept-for-PR-10-28-2016-Final.pdf), specifically section 3.2). The two directories contain configuration files for Asterisk, as well as the media files used for this version of Asterisk.

## Prerequisites

The Asterisk for ACE Connect Lite configuration assumes the following:

* A SIP trunk has been created and points to the Asterisk server
* At least two ten-digit numbers have been provisioned, registered to a PSTN, and registered in iTRS
* A "dial-around" number has been registered in iTRS

## Download/Configure

Once Asterisk has been installed on a server, pull down the repo and switch to the 'ACL' branch:


```
$ git clone ssh://git@github.com/mitrefccace/asterisk.git
$ cd asterisk
$ git checkout ACL
```

Then modify the following elements in the following files:

* sip.conf:
    * <public_ip>: The external.public IP address of the Asterisk server
    * <local_ip>: The private/local IP address of the Asterisk 
    * <phone_1>/<phone_2>: Ten-digit phone numbers of registered ACE Connect Lite users
    * <sip_trunk_host>: Domain name of the SIP trunk being used to route calls to Asterisk server
	* <dial_around_num>: Dial around number
	* <stun_server>: STUN/TURN server address:port
* extensions.conf:
	* <dial_around_num>: Dial around number
	* <phone_1>/<phone_2>: Ten-digit phone numbers of registered ACE Connect Lite users
    
Once the values have been modified, move the files over to /etc/asterisk:

```
$ cd asterisk-configs
$ cp -rf * /etc/asterisk
```

Then, move the media files into /var/lib/asterisk/sounds:

```
$ cd ../asterisk-videos-audios/sounds
$ cp -rf * /var/lib/asterisk/sounds
```

Finally, restart Asterisk:

```
$ service asterisk restart
```

## Automation

There is a script in this repo, within the 'script' directory, that will automate the installation of Asterisk, as well as 
pull down the configs and media files from this repo and move them to the appropriate locations. Be sure to follow the instructions
at the beginning of the script before executing it. The command to run the script is below, with the paramaters as described above (the
parameters are not required; however, not using them will require some manual configuration before using Asterisk):

```
$ ./ACL_asterisk_install_script.sh <public_ip> <local_ip> <dial_around_num> <phone_1> <phone_2> <stun_server> <sip_trunk_host>
```