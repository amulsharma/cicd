###################################################################################################
### Owner       : Amul Sharma 
### Description : This script will perform the pre-tasks before installing the patches
### Date        : 22/12/2020
### Version     : 1.0
###
####################################################################################################
#!/usr/bin/sh
DAT=`date +%d-%m-%Y-%T`
Srv=`uname -n`

PREPATCHDIR=/tmp/prepatch
cd /tmp
if [ ! -d ${PREPATCHDIR} ]
then
  mkdir ${PREPATCHDIR}
fi
Logfile=/tmp/prepatch/prepatch.log.$DAT
echo "Pre check start date $DAT" >>${Logfile}

##################################### Collect Pre-Artifacts ###############################
echo "Collecting the PRE-Artifacts ...." 
df -k > ${PREPATCHDIR}/df.out
RES=$?
     if [ $RES -ne 0 ]
     then
      echo "DF is failed " | tee -a ${Logfile} 2>&1
     fi
ip -s address > ${PREPATCHDIR}/ip_interface.out
RES1=$?
     if [ $RES1 -ne 0 ]
     then
      echo "Netstat in is failed " | tee -a ${Logfile} 2>&1
     fi
ip route > ${PREPATCHDIR}/ip_route.out
RES2=$?
     if [ $RES2 -ne 0 ]
     then
      echo "Netstat rn is failed " | tee -a ${Logfile} 2>&1
     fi

rpm -qa > ${PREPATCHDIR}/rpmqa.out
RES3=$?
     if [ $RES3 -ne 0 ]
     then
      echo "Rpm qa  is failed " | tee -a ${Logfile} 2>&1
     fi

ps -ef > ${PREPATCHDIR}/process.out
RES4=$?
     if [ $RES4 -ne 0 ]
     then
      echo "Process out  is failed " | tee -a ${Logfile} 2>&1
     fi

cp /etc/pam.d/common-auth-pc ${PREPATCHDIR}/common-auth-pc
RES5=$?
     if [ $RES5 -ne 0 ]
     then
      echo "Common - auth copy  is failed " | tee -a ${Logfile} 2>&1
     fi

cp /etc/services ${PREPATCHDIR}/services
RES6=$?
     if [ $RES6 -ne 0 ]
     then
      echo "Services file copy is failed " | tee -a ${Logfile} 2>&1
     fi
if [[ "$RES" == "$RES1" && "$RES1" == "$RES2" && "$RES2" == "$RES3" && "$RES3" == "$RES4" && "$RES4" == "$RES5" && "$RES5" == "$RES6" ]]
then  
  echo "TASK :Pre-Artifacts are collected successfully" | tee -a ${Logfile} 2>&1 
else 
  echo "ERROR: Pre-Artifacts collection is failed" | tee -a ${Logfile} 2>&1
  exit 2
fi

###############Disable Custom Monitoring for server and packages##########################

#Comment and Uncomment the servers
if [ -x /opt/cmcluster/bin/cmviewcl ]
then 
   echo " " | tee -a ${Logfile} 2>&1
   echo "Disabling the custom monitoring ...." | tee -a ${Logfile} 2>&1
   /opt/cmcluster/bin/cmviewcl > ${PREPATCHDIR}/cmviewcl_before_patch
   Pkg=`/opt/cmcluster/bin/cmviewcl | egrep -i $Srv | egrep -i "enable|disable" | awk '{print $1}'` 
   /usr/local/bin/sudo -u bb ssh <Jump_server> 'echo '"${Srv}"' >>/tmp/pre_patch/servers ' >>${Logfile}  2>&1
   Res=$?
   for i in `echo $Pkg` 
   do 
   /usr/local/bin/sudo -u bb ssh <Jump_server> 'echo '"${Pkg}"' >>/tmp/pre_patch/pkg' &> /dev/null
   done
   Res1=$?
   if [ $Res -eq 0 -a $Res1 -eq 0 ]
   then
     echo "TASK  :Added the servers and Pkgs name to the files in <Jump_server>  " | tee -a ${Logfile} 2>&1 
     echo " " | tee -a ${Logfile} 2>&1
     /usr/local/bin/sudo -u bb ssh <Jump_server> "/usr/bin/sudo /usr/local/bin/disable_monitoring.sh" 
     if [ $? -eq 0 ]
     then 
     echo "Task: Custom monitoring has been disabled successfully" | tee -a ${Logfile} 2>&1  
     echo " " | tee -a ${Logfile} 2>&1
     else "Error : Custom montoring is not disabled, Pls check" | tee -a ${Logfile} 2>&1
     exit 2
     fi
   elif [ $Res -ne 0 ]
   then 
     echo "ERROR: Server is not added in <Jump_server> file, Pls check" | tee -a ${Logfile} 2>&1
     echo " " | tee -a ${Logfile} 2>&1
     exit 2
   elif [ $Res1 -ne 0 ] 
   then
      echo "ERROR: Package is not added in <Jump_server> file" | tee -a ${Logfile} 2>&1
      echo " " | tee -a ${Logfile} 2>&1
      exit 2
   else 
      echo "ERROR: Custom montoring is not disabled. Please check" | tee -a ${Logfile} 2>&1
      echo " " | tee -a ${Logfile} 2>&1
     exit 2
    fi
####################################### Check packages running and halt/Failover the package if required #####################

cmviewcl | grep -i $Srv | egrep -i "enable|disable" | grep -i scs &> /dev/null 
if [ $? -eq 0 ]
then
  echo "(A)SCS is running and do you wants to failover it to the secondry node" | tee -a ${Logfile} 2>&1
  ANSWER="n"
  echo " " | tee -a ${Logfile} 2>&1
  echo -n "Do you want to continue anyway [y,(n)]: " | tee -a ${Logfile} 2>&1
  read ANSWER
  if [ "${ANSWER}" = "y" -o "${ANSWER}" = "Y" ]; then
   /sapcd/UX_team/switch_ascs-ers.sh &> /dev/null
     if [ $? -ne 0 ]
     then
      echo "ERROR: (A)SCS failover is failed" | tee -a ${Logfile} 2>&1
      echo " " | tee -a ${Logfile} 2>&1
      exit 2
      fi
  else
  echo "ERROR: Will exit now !" | tee -a ${Logfile} 2>&1
  echo " "
  exit 1
  fi
fi
Pkg=`/opt/cmcluster/bin/cmviewcl | grep -i $Srv | egrep -i "enable|disable" |grep -v "SCS"| awk '{print $1}'`
echo " " | tee -a ${Logfile} 2>&1
echo "Halting the package $Pkg ..." | tee -a ${Logfile} 2>&1
for i in `echo $Pkg`
do
cmhaltpkg $i &> /dev/null
   if [ $? -eq 0 ]
   then
   echo "Package $i is halted successfully" >>${Logfile} 2>&1
   else
   echo "ERROR: Pls check and halt the package $i" | tee -a ${Logfile} 2>&1
   exit 1
   fi
done
/opt/cmcluster/bin/cmviewcl | grep -i $Srv | egrep -i "enable|disable" &> /dev/null
 if [ $? -eq 0 ]
   then
    echo " " | tee -a ${Logfile} 2>&1
    echo "ERROR: Package is still running" | tee -a ${Logfile} 2>&1
    exit 2
    else 
    echo "Task  :All the packages are halted successfully" | tee -a ${Logfile} 2>&1
    echo " " | tee -a ${Logfile} 2>&1
 fi

########################################### Standalone System ########################################

else 
   echo "Diasbling the custom monitoring of standalone system ..." | tee -a ${Logfile} 2>&1
   /usr/local/bin/sudo -u bb ssh <Jump_server> 'echo '"$Srv"' >>/tmp/pre_patch/servers' &> /dev/null
   if [ $? -eq 0 ]
      then 
        echo "Task: Server is Added in <Jump_server> " | tee -a ${Logfile} 2>&1 
        echo " " | tee -a ${Logfile} 2>&1
        /usr/local/bin/sudo -u bb ssh <Jump_server> "/usr/bin/sudo /usr/local/bin/disable_monitoring.sh"
        if [ $? -eq 0 ]
          then
          echo "Task: Custom monitoring has been disabled successfully" | tee -a ${Logfile} 2>&1
          echo " " | tee -a ${Logfile} 2>&1
          else "Error : Custom montoring is not disabled, Pls check and disble ..." | tee -a ${Logfile} 2>&1
          exit 2 
        fi
   else 
        echo "ERROR: Server is not Added in <Jump_server> file"   | tee -a ${Logfile} 2>&1
        echo " " | tee -a ${Logfile} 2>&1
        exit 2
   fi
fi

######################### Disable Multi Kernel upgrade ###########################################
echo "Disabling the multi Kernel ..."
cp /etc/zypp/zypp.conf ${PREPATCHDIR}/zypp.conf.$DAT
sed -i "/^multiversion \= provides:multiversion/s/^/#/g" /etc/zypp/zypp.conf
if [ $? -eq 0 ]
then
echo "Task: Multi Kernel upgrade is disabled" | tee -a ${Logfile} 2>&1
echo " "  | tee -a ${Logfile} 2>&1
else 
echo "ERROR: Multi Kernel upgrade is not disabled pls check" | tee -a ${Logfile} 2>&1
echo " " | tee -a ${Logfile} 2>&1
fi
echo " " | tee -a ${Logfile} 2>&1

######################### LVMETAD configuration ###########################################
echo "Checking the LVMETAD configuration" | tee -a ${Logfile} 2>&1
grep -iE "use_lvmetad = 0" /etc/lvm/lvm.conf &> /dev/null
if [ $? -eq 0 ]
then
echo "Task: Lvmetad is configured properly" | tee -a ${Logfile} 2>&1
echo " " | tee -a ${Logfile} 2>&1
else
echo "ERROR: Pls check and configure the LvmEtad,Pls don't reboot the system,it will not came up" | tee -a ${Logfile} 2>&1
echo " " | tee -a ${Logfile} 2>&1
fi
echo "###################### End of the Pre tasks #######################" | tee -a ${Logfile} 2>&1

