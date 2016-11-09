# **Asterisk for ACE Connect Lite Project**

This repository is to be used in conjunction with the documentation for Ace Direct (found [here](https://github.com/mitrefccace/acedirect-public/blob/master/docs/ACE-Direct-Platform-Release-Doc-for-PR-Final-11-04-2016.pdf)). The two directories contain configuration files for Asterisk, as well as the media files used for this version of Asterisk.

## Prerequisites

The Asterisk for ACE Direct configuration assumes the following:

* A public/private key combination has been created for the Asterisk server
* A "dial-in" number has been registered in iTRS

## Download/Configure

Once Asterisk and PJSIP has been installed on a server, pull down the repo and switch to the 'ACL' branch:


```
$ git clone ssh://git@github.com/mitrefccace/asterisk.git
$ cd asterisk
$ git checkout AD
```

Then modify the following elements in the following files:

* pjsip.conf:
    * <public_ip>: The external.public IP address of the Asterisk server
    * <local_ip>: The private/local IP address of the Asterisk 
	* <dial_in>: Dial-in number
* extensions.conf:
	* <dial_in>: Dial-in number
* http.conf:
    * <public_key>: Public key for Asterick server
    * <private_key>: Private key for Asterisk server 
* rtp.conf:
	* <stun_server>: STUN/TURN server address:port
    
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

There is a script in this repo, within the 'script' directory, that will automate the installation of PJSIP and Asterisk, as well as 
pull down the configs and media files from this repo and move them to the appropriate locations. Be sure to follow the instructions
at the beginning of the script before executing it. The command to run the script is below, with the paramaters as described above (the
parameters are not required; however, not using them will require some manual configuration before using Asterisk):

```
$ ./AD_asterisk_install_script.sh <public_ip> <local_ip> <dial_in>  <stun_server> <public_key> <private_key>
```