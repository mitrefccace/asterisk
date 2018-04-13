#!/bin/bash

# Because we need to start Asterisk to set the AstDB, and we can'the
# do that during build time, we need to use an entrypoint
# script to start Asterisk, set the AstDB then reload the
# dialplan to have the AstDB values take effect.

# When we're not in CI mode, the below envt vars must be passed
# to the container at run time.
if [ -z $CI_MODE ]; then
        echo "CI mode NOT detected, setting .config via run-time envt variables."
        cd /root/asterisk-codev/scripts
        LOCAL_IP=$(hostname -I) | awk '{print $1}'
        HOSTNAME=$(hostname)
        sed -i -e "s/hostname/$HOSTNAME/g" .config.sample
        sed -i -e "s/192.168.0.1/$LOCAL_IP/g" .config.sample
        sed -i -e "s/8.8.8.8/$PUBLIC_IP/g" .config.sample
        sed -i -e "s/stun.example.com/$STUN_ADDR/g" .config.sample
        sed -i -e "s/hostname/$MYSQL_HOST/g" .config.sample
        sed -i -e "s/database/$MYSQL_DB/g" .config.sample
        sed -i -e "s/table/$MYSQL_TABLE/g" .config.sample
        sed -i -e "s/asterisk/$MYSQL_USER/g" .config.sample
        sed -i -e "s/somePass/$MYSQL_PASS/g" .config.sample
        mv .config.sample .config
        ./update_asterisk.sh --config --no-db
fi

asterisk
sleep 5
asterisk -rx "database put GLOBAL DIALIN 1234567890"
asterisk -rx "database put BUSINESS_HOURS START 00:00"
asterisk -rx "database put BUSINESS_HOURS END 00:00"
asterisk -rx "database put BUSINESS_HOURS ACTIVE 0"
asterisk -rx "dialplan reload"
asterisk -rx "core stop now"
asterisk -f
