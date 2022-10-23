###################################################################################################
### Owner       : Amul Sharma 
### Description : This script will perform the post-tasks after patches were instlled 
### Date        : 22/12/2020
### Version     : 1.0
###
####################################################################################################
#!/usr/bin/sh
DAT=`date +%d-%m-%Y-%T`
Srv=`uname -n`
POSTPATCHDIR=/tmp/postpatch
cd /tmp
if [ ! -d ${POSTPATCHDIR} ]
then
  mkdir ${POSTPATCHDIR}
fi
Logfile=${POSTPATCHDIR}/postpatch.log.$DAT
echo "Post check start date $DAT" >>${Logfile} 2>&1
#################################Check the uptime if server is rebooted or not post patching##########################

echo "Chek the system uptime..."
uptime | grep -i days  >> ${Logfile} 2>&1 
if [ $? -eq 0 ]
then
   Days=`uptime | awk '{print $3,$4}' | sed 's/,//'`
   echo "System is up since $Days" | tee -a ${Logfile} 2>&1
   ANSWER="n"
   echo "" | tee -a ${Logfile} 2>&1
   echo -n "Do you want to reboot [y,(n)]: " | tee -a ${Logfile} 2>&1
   read ANSWER
   if [ "${ANSWER}" = "y" -o "${ANSWER}" = "Y" ]; then
   echo "Task: rebooting the system .... Please run the script $0 again once the system is up .." | tee -a ${Logfile} 2>&1
   echo " " | tee -a ${Logfile} 2>&1
   sleep 15
   reboot
   else
   echo "ERROR: Will exit now !" | tee -a ${Logfile} 2>&1
   echo " " | tee -a ${Logfile} 2>&1
   exit 1
   fi
else
    Uptm=`uptime | awk '{print $3}' | sed 's/,//'`
    echo "Task: System is up since $Uptm hours" | tee -a ${Logfile} 2>&1
    echo " " | tee -a ${Logfile} 2>&1
fi

############################################### Check and verify the kernel Version ###########################
echo "Checking the kernel Version " | tee -a ${Logfile} 2>&1
echo "Please enter the expected Kernel version post patch" | tee -a ${Logfile} 2>&1
read expected
#expected=4.12.14-122.51-default
received=$(uname -r)
min=$(echo -e $expected"\n"$received|sort -V|head -n 1)
if [ "$min" = "$expected" ];then
       echo "Task: Installed Kernakl Version $received is Fine" | tee -a ${Logfile} 2>&1
       echo " " | tee -a ${Logfile} 2>&1
      
else
       echo "ERROR == Please check and update the Patches" | tee -a ${Logfile} 2>&1
       echo " " | tee -a ${Logfile} 2>&1
fi


###############################Check the NFS filesystems###################################
echo "Checking the NFS filesystems ..." | tee -a ${Logfile} 2>&1
timeout 4s df  &> /dev/null 
if [ $? -eq 0 ]
then
   echo "TASK: NFS shares are working fine" | tee -a ${Logfile} 2>&1
   echo " " | tee -a ${Logfile} 2>&1
else 
   cat /etc/auto.direct | grep -v "#" | awk '{print $1}' > ${POSTPATCHDIR}/share
   #cat /etc/fstab | grep -v "#" | egrep -i "nfs|cifs" >> ${POSTPATCHDIR}/share
   echo "Unmounting the shares .... " | tee -a ${Logfile} 2>&1
   for i in `echo ${${POSTPATCHDIR}/share}`
   do
    umount -f $i | tee -a ${Logfile} 2>&1
    sleep 2
    umount -f $i | tee -a ${Logfile} 2>&1
    done
    timeout 4s df  &> /dev/null 
    if [ $? -eq 0 ]
    then
    echo "Task: NFS shares are working fine" | tee -a ${Logfile} 2>&1
    echo " " | tee -a ${Logfile} 2>&1
    else 
    echo "ERROR: Pls check the shares" | tee -a ${Logfile} 2>&1
    echo " " | tee -a ${Logfile} 2>&1
    exit 2
fi
fi
############################################### Check last updated patches with timestamps  ###########################################
echo "Checking For the last patch installation date" | tee -a ${Logfile} 2>&1
a=`date |awk '{print $1,$2,$3}'`
b=`rpm -qa --last | head | tail -1 | awk '{print $2,$3,$4}'`
ts1=`date -d"${a}" +%Y%m%d%H%M%S`
ts2=`date -d"${b}" +%Y%m%d%H%M%S`
if [ $ts1 -eq $ts2 ]
then
 echo "Task: Patches were insatalled today" | tee -a ${Logfile} 2>&1
 echo " " | tee -a ${Logfile} 2>&1
else 
 echo "ERROR: Please check and update the system.Patches were installed on $b" | tee -a ${Logfile} 2>&1
 echo " " | tee -a ${Logfile} 2>&1
 exit 2
fi

#############################Check if the patches were installed ###################################
echo "Checking if any patch is available post update" | tee -a ${Logfile} 2>&1
if [ -x /usr/bin/zypper ]
then 
/usr/bin/zypper update --dry-run  | egrep -i "Nothing to do" >>${Logfile} 2>&1
if [ $? -eq 0 ]
then 
  echo "Task: There is no patch to be installed" | tee -a ${Logfile} 2>&1
  echo " " | tee -a ${Logfile} 2>&1
else 
  echo "ERROR: Please check and install the pending patches" | tee -a ${Logfile} 2>&1
  echo " " | tee -a ${Logfile} 2>&1
  exit 2
fi
fi

if [ -x /usr/bin/yum ]
then
/usr/bin/yum update -n | grep -i "No Packages marked for Update" | tee -a ${Logfile} 2>&1
if [ $? -eq 0 ]
then
  echo "Task: There is no patch to be installed" | tee -a ${Logfile} 2>&1
  echo " " | tee -a ${Logfile} 2>&1
else
  echo "Error: Please check and install the pending patches" | tee -a ${Logfile} 2>&1
  echo " " | tee -a ${Logfile} 2>&1
  exit 2
fi
fi

######################################### Stop the services ##########################################
echo "Checking for unnessery services... " | tee -a ${Logfile} 2>&1
for i in fstrim fstrim.timer jetty.service jetty-sgmgr dp-telemetry.service 
do
systemctl is-active $i &> /dev/null 
if [ $? -eq 0 ]
then
   systemctl stop $i  &> /dev/null 
   if [ $? -eq 0 ]
   then 
      systemctl disable $i  &> /dev/null 
     if [ $? -eq 0 ]
     then
       echo "ERROR: Service $i has been stopped and disbaled successfully" | tee -a ${Logfile} 2>&1
     else 
       echo "ERROR: Service $i is failed to disabled" | tee -a ${Logfile} 2>&1
     fi
    else 
      echo "ERROR: Service $i is failed to stop" | tee -a ${Logfile} 2>&1
   fi
else
   echo "Service $i is not active, No action required" >> ${Logfile} 
fi
done 
echo "Task: Service check is completed..." | tee -a ${Logfile} 2>&1
echo " " | tee -a ${Logfile} 2>&1


######################### Enable Multi Kernel upgrade ###########################################
echo "Enablinig the Multi Kernel" | tee -a ${Logfile} 2>&1
cp /etc/zypp/zypp.conf ${POSTPATCHDIR}/zypp.conf.$DAT
sed -i "/^#multiversion \= provides:multiversion/s/^#//g" /etc/zypp/zypp.conf
if [ $? -eq 0 ]
then 
echo "TASK: Multi Kernel upgrade is enabled" | tee -a ${Logfile} 2>&1
echo " " | tee -a ${Logfile} 2>&1
else 
echo "ERROR: Multi Kernel upgrade is not enabled pls check" | tee -a ${Logfile} 2>&1
echo " " | tee -a ${Logfile} 2>&1
fi

##################################### Compliance check  #######################################
echo "Compliance check" | tee -a ${Logfile} 2>&1
a=`/usr/local/bin/audit_script.sh  | grep -iv pass | grep -i fail` 
if [ $? -eq 0 ]
then
   echo "ERROR: Compliance check is failed for $a" | tee -a ${Logfile} 2>&1
   echo " " | tee -a ${Logfile} 2>&1
else
   echo "TASK: Compliance check is completed successfully" | tee -a ${Logfile} 2>&1
   echo " " | tee -a ${Logfile} 2>&1
fi


###################################### Grub config file check script ########################
echo "Executing the Grub check script ..." | tee -a ${Logfile} 2>&1
if [ -f /usr/local/bin/check_has_file_changed.sh ]
then
    /usr/local/bin/check_has_file_changed.sh >>${Logfile} 
    if [ $? -eq 0 ]
    then
       echo "TASK: Script Grub check script is executed successfully" | tee -a ${Logfile} 2>&1
       echo " " | tee -a ${Logfile} 2>&1
    else
       echo "ERROR: Script Grub check script is failed, Please check" | tee -a ${Logfile} 2>&1
       echo " " | tee -a ${Logfile} 2>&1
    fi
else
   echo "ERROR: Script check_has_file_changed.sh is not present in server, Please check" | tee -a ${Logfile} 2>&1
   echo " " | tee -a ${Logfile} 2>&1
fi


####################################### Start the packages #####################

if [ -x /opt/cmcluster/bin/cmviewcl ]
then
Pkg=`/opt/cmcluster/bin/cmviewcl |  egrep -i "halted|failed" |grep -v "SCS"| awk '{print $1}'`
echo "Starting the package ..." | tee -a ${Logfile} 2>&1
for i in `echo $Pkg`
do
/opt/cmcluster/bin/cmmodpkg -e -n $Srv $i  &> /dev/null 
/opt/cmcluster/bin/cmrunpkg -n $Srv $i  &> /dev/null 
   if [ $? -eq 0 ]
   then
   echo "Package $i is  successfully" >> ${Logfile} 2>&1
   /opt/cmcluster/bin/cmmodpkg -e $i  &> /dev/null 
   else
   echo "ERROR: Pls check and start the package $i" | tee -a ${Logfile} 2>&1
   echo " " | tee -a ${Logfile} 2>&1
   exit 2
   fi
done
/opt/cmcluster/bin/cmviewcl | grep -i $Srv | egrep -i "halted|failed"  &> /dev/null 
 if [ $? -eq 0 ]
   then
    echo "ERROR: Package is still down, Pls check" | tee -a ${Logfile} 2>&1
    echo " " | tee -a ${Logfile} 2>&1
    exit 2
    else
    echo "Task : All the packages are started successfully" | tee -a ${Logfile} 2>&1
    echo " " | tee -a ${Logfile} 2>&1
 fi
###################################################### Enable custorm monitoring #######################
   echo "Enabling the custom monitoring..." | tee -a ${Logfile} 2>&1
   /usr/local/bin/sudo -u bb ssh <Jump_server> 'echo '"${Srv}"' >>/tmp/post_patch/servers' >>${Logfile}  2>&1 
   Res=$?
   for i in `echo $Pkg`
   do
   /usr/local/bin/sudo -u bb ssh <Jump_server> 'echo '"${Pkg}"' >>/tmp/post_patch/pkg' >>${Logfile}  2>&1
   done
   Res1=$?
   if [ $Res -eq 0 -a $Res1 -eq 0 ]
   then
     echo "TASK  :Added the servers and Pkgs name to the files in <Jump_server> " | tee -a ${Logfile} 2>&1
     echo " " | tee -a ${Logfile} 2>&1
     /usr/local/bin/sudo -u bb ssh <Jump_server> "/usr/bin/sudo /usr/local/bin/enable_monitoring.sh"
     if [ $? -eq 0 ]
     then
     echo "Task: Custom monitoring has been enabled successfully" | tee -a ${Logfile} 2>&1
     echo " " | tee -a ${Logfile} 2>&1
     else "Error : Custom montoring is not enabled, Pls check" | tee -a ${Logfile} 2>&1
     exit 2
     fi 
   elif [ $Res -ne 0 ]
   then
     echo "ERROR: Server is not added in <Jump_server> file, Pls check" | tee -a ${Logfile} 2>&1
     echo " " | tee -a ${Logfile} 2>&1
   elif [ $Res1 -ne 0 ]
   then
      echo "ERROR: Package is not added in <Jump_server> file " | tee -a ${Logfile} 2>&1
      echo " " | tee -a ${Logfile} 2>&1
      exit 2
   else
      echo "ERROR: Custom montoring is not enabled. Please check" | tee -a ${Logfile} 2>&1
      echo " " | tee -a ${Logfile} 2>&1
     exit 2
    fi


########################################### Standalone System ########################################

else
   echo " " | tee -a ${Logfile} 2>&1
   echo "Enabling the custom monitoring of standalone system ..." | tee -a ${Logfile} 2>&1
   /usr/local/bin/sudo -u bb ssh <Jump_server> 'echo '"${Srv}"' >>/tmp/post_patch/servers' >>${Logfile}  2>&1    
    if [ $? -eq 0 ]
      then
        echo "TASK: Added the server name to the files in <Jump_server>" | tee -a ${Logfile} 2>&1
        echo " " | tee -a ${Logfile} 2>&1
        /usr/local/bin/sudo -u bb ssh <Jump_server> "/usr/bin/sudo /usr/local/bin/enable_monitoring.sh"
        if [ $? -eq 0 ]
        then
        echo "Task: Custom monitoring has been enabled successfully" | tee -a ${Logfile} 2>&1
        echo " " | tee -a ${Logfile} 2>&1
        else "Error : Custom montoring is not enabled, Pls check" | tee -a ${Logfile} 2>&1
        exit 2
        fi 
   else
        echo "ERROR: Server is not added in <Jump_server> file, Pls check" | tee -a ${Logfile} 2>&1
        echo " " | tee -a ${Logfile} 2>&1
        exit 2
   fi


fi


################################Check in Suse manager if the server is patched ########################
echo " " | tee -a ${Logfile} 2>&1
echo "TASK: Pls check the server status in suse manager and it must be green" | tee -a ${Logfile} 2>&1
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

echo "##################################### Post check script is completed ###################" | tee -a ${Logfile} 2>&1

