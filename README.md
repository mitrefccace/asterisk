# **Asterisk for ACE Connect Lite Project**

This repository is to be used in conjunction with the documentation for Ace Connect Lite (found at <URL>), specifically section 3.2. The two directories contain configuration files for Asterisk, as well as the media files used for this version of Asterisk.

## Prerequisites

The Asterisk for ACE Connect Lite configurationa assumes the following:
* A SIP trunk has been created and points to the Asterisk server
* Two ten-digit numbers have been provisioned, registered to a PSTN, and registered in iTRS
* A "dial-around" number has been registered in iTRS

## Download/Install

Once Asterisk has been installed on a server, pull down the repo:


```Linux Kernel Mode
$ git clone ssh://git@git.codev.mitre.org/acrdemo/aceconnectlite-public.git
$ cd aceconnectlite-public/asterisk
```

Then modify the following elements in the following files:
* sip.conf:
    * <public_ip>: The external.public IP address of the Asterisk server
    * <local_ip>: The private/local IP address of the Asterisk 
    * <phone_1>/<phone_2>: Ten-digit phone numbers of registered ACE Connect Lite users
    * <sip_trunk_host>: Domain name of the SIP trunk being used to route calls to Asterisk server
* extensions.conf:
	* <dial_around_num>: Dial around number
    
Once the values have been modified, move the files over to /etc/asterisk:

```Linux Kernel Mode
$ cp -rf * /etc/asterisk
```

Then, move the media files into /var/lib/asterisk/sounds:

```Linux Kernel Mode
$ cd ../asterisk-videos-audios
$ cp -rf * /var/lib/asterisk/sounds
```

Finally, restart Asterisk:

```Linux Kernel Mode
$ service asterisk restart
```
