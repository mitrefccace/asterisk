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
#       $1: Number to lookup. Input should be in a form like: 1234567890
#       $2: modes as described above ["simple"|"full"]
#
# Example dial-plan execution:
#	same => n,AGI(itrslookup.sh,${EXTEN},"simple")
#
#
# Provider URIs (one line required per provider)
PROVIDER="PROVIDER-FQDN-HERE"
PROVIDER2="PROVIDER2-FQDN-HERE"

# IP of lookup server
ITRSIP="IP HERE"

PHONENUM=$1

# if +1 was added to beginning of number, cut that off from the beginning of the string

if [ `echo $PHONENUM | cut -b -2` == "+1" ]; then
        PHONENUM=`echo $PHONENUM | cut -b 3-`
	PHONENUM=$(echo ${PHONENUM%%@})
        # set the $EXTEN variable in Asterisk
        echo "SET VARIABLE EXTEN $PHONENUM"
elif [ `echo $PHONENUM | cut -b -1` == "1" ]; then
        PHONENUM=`echo $PHONENUM | cut -b 2-`
	PHONENUM=$(echo ${PHONENUM%%@})
        # set the $EXTEN variable in Asterisk
        echo "SET VARIABLE EXTEN $PHONENUM"
fi


timestamp=$(date +"%r")
cdate=$(date)
echo "" 2>&1|tee -a itrs.log
echo "Calling" 2>&1|tee -a itrs.log
echo "Call Time:$cdate" 2>&1|tee -a itrs.log
echo $PHONENUM 2>&1|tee -a itrs.log

# combine phone number with .1 suffix
REVPHONENUM="`echo $PHONENUM|rev|sed 's/\(.\)/\1./g'`"
ONE=1
COMBINED=$REVPHONENUM$ONE

# add processing for `call forwarding` like of behavior, will return 
SIPURI1="`dig @$ITRSIP in naptr $COMBINED.itrs.us | grep "CNAME"| awk NR==1 | cut -f3`"
echo "SIPURI1:$SIPURI1" 2>&1|tee -a itrs.log

# Add capability of priority sorting and selection of the top result in multiple records --cchow_20180717
if [ -z $SIPURI1 ]; then
	SIPURI2="`dig @$ITRSIP in naptr $COMBINED.itrs.us | grep "E2U+sip"|head| sort -n -k5 | awk NR==1 | cut -f2 -d\@| cut -f1 -d\!`"
else
	SIPURI2="`dig @$ITRSIP in naptr $SIPURI1 | grep "E2U+sip"|head| sort -n -k5 | awk NR==1 | cut -f2 -d\@| cut -f1 -d\!`"
fi
echo "SIPURI2:$SIPURI2" 2>&1|tee -a itrs.log

if [ "$2" == "simple" ]; then
        echo "SET VARIABLE sipuri $SIPURI2"
        exit 0
fi

# Add priority sorting and choosing the top result in multiple NAPTR records (AWS Route53)
#SIPURI3="`host -t NAPTR $SIPURI2 | sort -n -k2 | grep tcp | awk NR==1 | awk '{ print $NF }'`"
#echo "SIPURI3 is $SIPURI3" 2>&1|tee -a itrs.log

#: <<'BLOCK_COMMENT'
i="0"
while [ $i -lt 4 ]
do
   SIPURI3="`host -t NAPTR $SIPURI2 | sort -n -k2 | grep tcp | awk NR==1 | awk '{ print $NF }'`"
   if [ ! -z $SIPURI3 ]; then
      echo "SIPURI3:$SIPURI3" 2>&1|tee -a itrs.log
      break
   fi
   echo "SIPURI2 used for SIPURI3:$SIPURI2"  2>&1|tee -a itrs.log
   echo "SIPURI3:$SIPURI3 => SIPURI3 is null, trying again" 2>&1|tee -a itrs.log
   i=$[$i+1]
done
if [ $i == 4 ]; then
   echo "Null SIPURI3(tried 4 times)=> Trying SIPURI2:5060"  2>&1|tee -a itrs.log
   #if no NAPTR record exists for the SIP URI, we'll try to place a SIP call using port 5060
   if [ ! -z $SIPURI2 ]; then
      echo "SET VARIABLE uri $SIPURI2:5060"
      SIPURI3="`host -t NAPTR $uri | sort -n -k2 | grep tcp | awk NR==1 | awk '{ print $NF }'`"
      if [ -z $SIPURI3 ]; then
         echo "Null SIPURI3=> Exiting"  2>&1|tee -a itrs.log
         exit 0
      fi
   else
      echo "Null SIPURI3 and SIPURI2=> Exiting"  2>&1|tee -a itrs.log
      exit 0
   fi
fi
#BLOCK_COMMENT


# Add capability of priority sorting (normal use case that picks the higher priority record) and selection of th top result in multiple record
#SIPURI4="`host -t SRV $SIPURI3 | sort -n -k2 | awk NR==1`"
#: <<'BLOCK_COMMENT'
i="0"
while [ $i -lt 4 ]
do
   SIPURI4="`host -t SRV $SIPURI3 | sort -n -k2 | awk NR==1`"
   if [[ ! -z "$SIPURI4" ]]; then
      if [[ "$SIPURI4" == *"SRV record"* ]]; then
         break
      fi
   fi
   echo "SIPURI4:$SIPURI4 => SIPURI4 is Invalid, trying again" 2>&1|tee -a itrs.log
   i=$[$i+1]
done
if [ $i == 4 ]; then
   echo "Null SIPURI4 is Invalid=> Exiting"  2>&1|tee -a itrs.log
   exit 0
fi
#BLOCK_COMMENT
echo "SIPURI4:$SIPURI4" 2>&1|tee -a itrs.log
SIPPORT="`echo $SIPURI4| cut -f7 -d\ `"

SIPHOST="`echo $SIPURI4| cut -f8 -d\ |rev|cut -c 2-|rev`"

# Loop through provider URIs, and set the Asterisk variable on the one that matches
# the current phone number being queried
echo "SIPHOST:$SIPHOST" 2>&1|tee -a itrs.log
if [[ $SIPHOST == $PROVIDER ]]; then
        echo "SET VARIABLE endpoint PROVIDER"
elif [[ $SIPHOST == $PROVIDER2 ]]; then
        echo "SET VARIABLE endpoint PROVIDER2"
#elif [[ $SIPHOST == $LIN ]]; then
#        echo "SET VARIABLE endpoint LIN"
fi

#echo $SIPHOST
echo "HOST is $SIPHOST"
echo "Port is $SIPPORT"
echo "SET VARIABLE uri $SIPHOST:$SIPPORT"
