/* 
 * Project  : Asterisk for Ace Direct
 * Author   : Connor McCann
 * Date     : 23 Jan 2018
 * Purpose  : To set a flag which will remove the REFER method 
 * 	      from the allow header within the SDP of an 
 * 	      outbound INVITE offer.
 * Location : pjproject-2.x/pjsip/include/pjsip-ua/
 */ 

/* if set to 1 - REFER will be removed. 
 * if set to 0 - REFER will remain */
#define PJSIP_REMOVE_REFER		1

/* EOF */

