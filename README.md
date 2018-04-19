# **Asterisk for ACE Direct Project**

This repository is to be used in conjunction with the documentation for the ACE Direct project (found on the project's [main page](https://github.com/FCC/ACEDirect/tree/master/docs)). The two directories contain configuration and media files to be used with this version of Asterisk. Please read this entire document before installing Asterisk for ACE Direct.

## Prerequisites

The Asterisk for ACE Direct configuration assumes the following:

* The Asterisk server has a public and local IP address
* A "dial-in" number which has been registered in iTRS and/or a SIP trunk provider (such as Twilio)
* An SSL cert file, acquired from a trusted certificate authority, for the domain of your server. This is necessary for WebRTC functionality as major browsers will drop connections to the Asterisk server if it's cert is not trusted.

## Automation

Within the 'scripts' directory, there are scripts that will automate the installation of PJSIP and Asterisk, as well as 
pull down the configuration and media files from this repository and move them into their appropriate locations.  View the README in the 'scripts'
directory for more information. It is HIGHLY recommended to use the install and update scripts to manage Asterisk for ACE Direct, as manual installations are officially unsupported by the ACE Direct project.

## Jenkins CI/CD Service
This repository has been setup and linked to our Jenkins EC2 instance within AWS. This allows us to leverage BitBucket WebHook plugins which can automatically detect when a new Pull request (PR) has been created. When a new PR is generated, the source branch will undergo a Jenkins build. This build or Pipeline will execute the following:
1. Executes the Jenkinsfile (located in the root of this repository)
2. Pulls down the latest source code from the originating branch 
3. Builds the Docker Image using the Dockerfile (located in the root of this repository)
4. Launches this Image as a containerized instance of Asterisk 
5. Executes the Unit Test for Asterisk 
6. Posts the Test results back to BitBucket

If the Build and Test stages of the Jenkins Pipeline pass successfully, then the status indicator next to the last commit of the PR will be green. If it failed any of the stages, the icon will be red. The PR should only be approved and merged if it has been marked green by Jenkins. 

**DISCLAIMER** -- *This Docker Image for Asterisk is NOT production ready and should ONLY be used within the Jenkins Pipeline.*

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


