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

* In pjsip.conf, each extension has a placeholder for the password used to register to the extension (typically \"\<password\>\"). These placeholders should be updated with the passwords chosen by each agent corresponding to the respective extension. The passwords for the WebRTC extensions should all be the same.
* In manager.conf, the password for the AMI interface should be changed as well.
* Each agent should have an entry at the end of agents.conf. The \"fullname\" attribute for each agent is optional. Currently, agents.conf has four agent entries which correspond to the default agent extensions, and should be updated as needed.   


## Docker (OLD)

The Dockerfile can be used to build a Docker image for Asterisk. If you are behind a proxy server When building the image, you must pass the proxy URL as a build argument, like so:

```sh
docker build -t asterisk --build-arg http_proxy=<proxy url>
```

When running the image in a container, there are a set of environment variables that must be set. In addition, you must have a MySQL and STUN instance (whether in containers or not) available.

```sh
docker run --name asterisk -p 5060:5060 -p 5060:5060/udp 5553:53/udp -p 8090:443 -p 5038:5038 -p 10000-10010:10000-10010 -e PUBLIC_IP=<public ip address> -e SUTN_ADDR=<stun address> MYSQL_DB=<mysql address> MYSQL_TABLE=<mysql cdr table> MYSQL_USER=<mysql user> MYSQL_PASS=<mysql password> -v <SSL cert file>:/etc/asterisk/keys/star.pem -v <SSL key file>:/etc/asterisk/keys/star.key asterisk
```


## Docker (NEW)   

### Docker Installation for CentOS   

1. Install Docker for CentOS Community Edition (CE). A link to installation
instructions can be found [here](https://docs.docker.com/install/linux/docker-ce/centos/).
1. Configure Docker to support a corporate network proxy if required,
instructions can be found [here](https://docs.docker.com/config/daemon/systemd/#httphttps-proxy).
1. Verify that MySQL has been configured with database to support call detail
records, the schema is defined in the `dat/acedirectdefault.sql` file. The server
credentials will be required below for Asterisk call logging.
1. Verify that a key and cert are available, they should be placed in a location
accessible by the Asterisk container (default is `./volumes/secrets/keys`).

The following files must be edited to include system-specific information.

* `asterisk/docker-compose.yml` - Contains the container parameters to support
port and volume mapping
* `asterisk/.env` - Contains environment variables that will be used by the container
* `scripts/.config.sample` - Contains parameters that will be updated in the Asterisk
configuration files

Update the hostname and domain name in the `docker-compose.yml` file. The volumes
parameters map directories between the container and the Docker host filesystem.
In the configuration file below, the `./volumes/logs` directory on the Docker host
is mapped to `/var/log/asterisk` in the container, and `./volumes/secrets/keys` is
mapped to `/etc/asterisk/keys` in the Docker container.

An example of the `docker-compose.yml` file is shown below:

```
version: "2"
services:
    asterisk:
        env_file: .env
        image: "docker-asterisk:v1"
        hostname: "ENTER HOSTNAME HERE"
        domainname: "ENTER DOMAIN NAME HERE"
        build:
            dockerfile: Dockerfile
            context: .
            args:
            - https_proxy=${https_proxy}
            - http_proxy=${http_proxy}
        ports:
        - "443:443/tcp"
        - "5060:5060/udp"
        - "5060:5060/tcp"
        - "5038:5038/tcp"
        - "10000-10100:10000-10100/udp"
        restart: "no"
        volumes:
        - ./volumes/logs:/var/log/asterisk
        - ./volumes/secrets/keys:/etc/asterisk/keys
```
Update the parameters in the `asterisk/.env file`. The `asterisk/.env` file
contains environment variables that will be set inside the container.

An example of the .env file is shown below:

```                                                       
http_proxy=http://<http proxy hostname>:<port>
https_proxy=http://<https proxy hostname>:<port>
no_proxy=docker host hostname, IP address of AD server
HOSTNAME=docker host hostname
FQDN=<docker host fully qualified domain name>
LOCAL_IP=private IP address
PUBLIC_IP=public IP address
```

The `scripts/.config.sample` is a template file that contains parameters
required for the Asterisk configuration and the values provided will be
inserted into the `/etc/asterisk` configuration files.

The format of the file is:

`<tag name>,config file 1|config file 2,replacement value`

The config file parameters identify the `/etc/asterisk` configuration files that
will be updated with the `replacement value` field.

An example of the `.config.sample` file shown below:

```
<hostname>,pjsip.conf,HOSTNAME,
<local_ip>,pjsip.conf,192.168.0.1,
<public_ip>,pjsip.conf,8.8.8.8,
<kamailio_local_ip>,pjsip.conf,192.168.0.21,
<stun_server>,rtp.conf|res_stun_monitor.conf,stun.example.com,
<crt_file>,pjsip.conf|http.conf,\/etc\/asterisk\/keys\/asterisk.pem,
<crt_key>,pjsip.conf|http.conf,\/etc\/asterisk\/keys\/asterisk.key,
<cdr_host>,/etc/odbc.ini,db_hostname,
<cdr_db>,/etc/odbc.ini,database,
<cdr_table>,cdr_adaptive_odbc.conf|cdr_odbc.conf,table,
<cdr_user>,res_odbc.conf|/etc/odbc.ini,asterisk,
<cdr_pass>,res_odbc.conf|/etc/odbc.ini,somePass,
```

Make a copy of the `scripts/.config.sample` file and name it `scripts/.config`.
Update with the values for your local configuration.

Note - the `<crt_file>` and `<crt_key>` values must match
the names of the cert and key stored in the `./volumes/secrets/keys` directory.

## Docker Commands
Once the configuration files have been updated, we can build the Docker container.

To build the container (this will take several minutes):
```
cd asterisk
sudo docker-compose up -d --force-recreate --build
```

To check the status of running containers:

`sudo docker ps -a`

To attach to a running container:

`sudo docker ps -a` - this will display the container Builds

`sudo docker exec -it <container ID> /bin/bash`

To start an existing container:

`sudo docker-compose up --detach`

Copying data from the container to the host:

`sudo docker cp <container name>:/<container path to file> .`
