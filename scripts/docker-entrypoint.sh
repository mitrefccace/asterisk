#!/bin/bash

# Because we need to start Asterisk to set the AstDB, and we can'the
# do that during build time, we need to use an entrypoint
# script to start Asterisk, set the AstDB then reload the
# dialplan to have the AstDB values take effect.

asterisk
sleep 5
asterisk -rx "database put GLOBAL DIALIN 1234567890"
asterisk -rx "database put BUSINESS_HOURS START 00:00"
asterisk -rx "database put BUSINESS_HOURS END 00:00"
asterisk -rx "database put BUSINESS_HOURS ACTIVE 0"
asterisk -rx "dialplan reload"
asterisk -rvvvvvvvvcg