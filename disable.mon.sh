###################################################################################################
### Owner       : Amul Sharma (amr.acn.admin)
### Description : This script will disble the custom monitoring
### Date        : 12/01/2020
### Version     : 1.0
###
####################################################################################################
#!/usr/bin/sh
DAT=`date +%Y-%m-%d-%T`
ScriptName=`basename $0`
LockFile=/tmp/${ScriptName}.lock
if [ -s ${LockFile} ]
then
        procno=`cat ${LockFile}`
        res=`ps -fp ${procno} | grep ${ScriptName} | grep -cv grep`
        if [ "${res}" != "0" ]
        then
                LogMesg "Script already started with process no ${procno}"
                exit 0
                #Exit code 1 = Script already running
        fi
fi
echo $$ >${LockFile}
if [ -f /tmp/pre_patch/servers ]
then 
cp /usr/local/bin/file_name /tmp/pre_patch/file_name.$DAT
for sys in `cat /tmp/pre_patch/servers`
do
    grep -i $sys /usr/local/bin/file_name | grep -i patch 
    if [ $? -ne 0 ]
    then 
    perl -p -i -e "s/^/#PATCH#/ if /$sys/" /usr/local/bin/file_name
    else 
    echo "Server $sys is already commented" 
    fi
done
fi
if [ -f /tmp/pre_patch/pkg ]
then
cp /usr/local/bin/file_name.hana /tmp/pre_patch/file_name.hana.$DAT
for PKG in `cat /tmp/pre_patch/pkg`
do
    grep -i $PKG /usr/local/bin/file_name.hana | grep -i patch
    if [ $? -ne 0 ]
    then
        perl -p -i -e "s/^/#PATCH#/ if /$PKG/" /usr/local/bin/file_name.hana 
    else
    echo "Pkg $PKG is already commented"
    fi
done
fi
rm /tmp/pre_patch/servers
rm /tmp/pre_patch/pkg
rm ${LockFile}

