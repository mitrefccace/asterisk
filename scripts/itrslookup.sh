#!/bin/bash
#
# Asterisk AGI script to perform lookups. Two modes:
#       -"simple": perform NAPTR dig in iTRS and return result.
#                  Used to confirm if number is a VRS number.
#       -"full": perform all three steps for a VRS call:
#               1. dig in NAPTR lookup
#               2. NAPTR lookup in regular DNS
#               3. SRV lookup in regular DNS
# Params:
#       $1: Number to lookup. Input should be in a form like: 7272022137
#       $2: modes as described above ["simple"|"full"]
#
# Example dial-plan execution:
#	same => n,AGI(itrslookup.sh,${EXTEN},"simple")
#
# Authors: Joe Gruessing and Said Masoud
#

# provider URIs
CONVO="sbc.sip.convorelay.net"
PURPLE="vrs-bgw.prod.purple.us"
GLOBAL="globalvrs.tv"
SORENSON="p.ci.svrs.net"
SORENSON2="p2.ci.svrs.net"
SORENSONQA="p.ci-qa-a.svrs.net"
ZVRS="sbc.prod.champvrs.com"

ITRSIP="156.154.59.67"
PHONENUM=$1

# if +1 was added to beginning of number, cut that off from the beginning of the string

if [ `echo $PHONENUM | cut -b -2` == "+1" ]; then
        PHONENUM=`echo $PHONENUM | cut -b 3-`
        # set the $EXTEN variable in Asterisk
        echo "SET VARIABLE EXTEN $PHONENUM"
fi

echo $PHONENUM

# combine phone number with .1 suffix
REVPHONENUM="`echo $PHONENUM|rev|sed 's/\(.\)/\1./g'`"
ONE=1
COMBINED=$REVPHONENUM$ONE

SIPURI="`dig @$ITRSIP in naptr $COMBINED.itrs.us | grep "E2U+sip"|head| cut -f2 -d\@|cut -f1 -d\!`"
#SIPURI2="`host -t NAPTR $SIPURI| cut -f10 -d\ `"

if [ "$2" == "simple" ]; then
        echo "SET VARIABLE sipuri $SIPURI"
        exit 0
fi


SIPURI2="`host -t NAPTR $SIPURI|grep tcp|awk '{ print $NF }'`"
echo "SIP URI is $SIPURI"

#if no NAPTR record exists for the SIP URI, we'll try to place a SIP call using port 5060
if [ -z $SIPURI2 ]; then
        echo "SET VARIABLE uri $SIPURI:5060"
        exit 0
fi

#exit 0
SIPURI3="`host -t SRV $SIPURI2`"
SIPPORT="`echo $SIPURI3| cut -f7 -d\ `"

# Sorensen sometimes uses 50060 as their port. Since that's not open for us, we'll use 5060

if [ "$SIPPORT" == "50060" ]; then
        SIPPORT="5060"
fi


SIPHOST="`echo $SIPURI3| cut -f8 -d\ |rev|cut -c 2-|rev`"

#loop through provider URIs, and set the Asterisk variable on the one that matches
#the current phone number being queried

if [ $SIPHOST == $CONVO ]; then
        echo "SET VARIABLE endpoint Convo"
elif [ $SIPHOST == $PURPLE ]; then
        echo "SET VARIABLE endpoint Purple"
elif [ $SIPHOST == $GLOBAL ]; then
        echo "SET VARIABLE endpoint Global"
elif [ $SIPHOST == $SORENSON ]; then
        echo "SET VARIABLE endpoint Sorenson"
elif [ $SIPHOST == $SORENSON2 ]; then
        echo "SET VARIABLE endpoint Sorenson"
elif [ $SIPHOST == $SORENSONQA ]; then
        echo "SET VARIABLE endpoint Sorenson"
elif [ $SIPHOST == $ZVRS ]; then
        echo "SET VARIABLE endpoint ZVRS"
fi


echo "port is $SIPPORT"
echo "SET VARIABLE uri $SIPHOST:$SIPPORT"
