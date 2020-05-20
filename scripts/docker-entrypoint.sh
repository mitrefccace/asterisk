#!/bin/bash

# Because we need to start Asterisk to set the AstDB, and we can'the
# do that during build time, we need to use an entrypoint
# script to start Asterisk, set the AstDB then reload the
# dialplan to have the AstDB values take effect.

# When we're not in CI mode, the below envt vars must be passed
# to the container at run time.

cd /root/asterisk-ad/scripts

# We need to run this regardless of CI_MODE
./update_asterisk.sh --config --no-db

asterisk
sleep 5
asterisk -rx "database put GLOBAL DIALIN 1234567890"
asterisk -rx "database put BUSINESS_HOURS START 00:00"
asterisk -rx "database put BUSINESS_HOURS END 00:00"
asterisk -rx "database put BUSINESS_HOURS ACTIVE 0"
asterisk -rx "dialplan reload"
asterisk -rx "core stop now"
asterisk -f
