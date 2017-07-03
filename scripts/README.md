# **Asterisk for ACE Direct Installation script**

The script in this directory will automate the installation and configuration of Asterisk for ACE Direct. This script has been developed for use on a CentOS 7.3.x server, and support for earlier versions are not guaranteed. It will perform the following:

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

- A note on the SSL certs: a CA-signed cert is not required to run ACE Direct; however, using the Asterisk self-signed certificate will require users to manually import the self-signed cert's ca.crt file into their browser. Otherwise, WebRTC will fail.


## Parameters

* <public_ip>: The external.public IP address of the Asterisk server
* <local_ip>: The private/local IP address of the Asterisk
* <stun_server>: STUN/TURN server address:port. We recommend building a dedicated STUN server, as public STUN servers can become congested and lead to higher latency for STUN/ICE. If you do not have one, a Google STUN server will be used in the config instead.
* <dial_in>: Dial-in number. If one is not provided, the string '12345' will be used instead to prevent the config files from failing to be parsed by Asterisk. You can replace this string in the future in extensions.conf if a dial-in number is acquired after installation.
* <crt_file>: CA cert file for server. Generated self-signed cert is used if none is provided.
* <crt_key>: Private key for CA cert

##Twilio

You can configure Twilio for use with Asterisk to route PSTN (i.e. non-VRS) calls to/from Asterisk. the extensions.conf and pjsip.conf files have configurations set for use with Twilio; however, they will not work unless you replace the <twilio_URI> placeholder in pjsip.conf with the Twilio termination URI of your SIP trunk. If it is not desired to use Twilio with ACE Direct, simply delete the sections of the dial-plan and SIP config that pertain to Asterisk. For more information on using Twilio with Asterisk, [download the Twilio docs](https://www.twilio.com/docs/documents/35/AsteriskTwilioSIPTrunkingv2_1.pdf).

##Identity Management

The pjsip.conf file defines user profiles that can be used to register to Asterisk. Each user profile has a password associated with it.
Before starting and using Asterisk, IT IS HIGHLY RECOMMENDED to change the passwords fo each user account that will be used, as well as removing the ones that won't be used. Each password attribute currently has the placeholder <password> set in it. This is not recommended,
however if you'd like each profile to have the same password you can execute the following:

```sh

$ sed -i -e 's/<password>/<the password you choose>/g' pjsip.conf

```

## Example usage


```sh

$ ./AD_asterisk_install.sh --public-ip 8.8.8.8 --local-ip 10.0.0.1 --stun-server stun4.l.google.com:19302 --dialin 12345 --crt-file "\/etc\/asterisk\/keys\/asterisk.crt" --crt-key "\/etc\/asterisk\/keys\/asterisk.key"

```

Note the format of the CA cert and key, namely using '\/' to represent directory structure and surrounding the entire parameter in double quotes. This format is important as the script uses the sed command to replace te placeholder values in the Asterisk config files.