#!/bin/bash
>/tmp/myfun.log
myfun()
{
	DAT=`date +%D`
	HST=`uname -n`
	echo "$DAT $HST $1" >> /tmp/myfun.log
}
myfun "HI Amul"
myfun $*
cat /tmp/myfun.log
