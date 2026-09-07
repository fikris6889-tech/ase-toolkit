#!/bin/bash
#Author: Fikris Technologies
#Last Modified: June ,2022

#Run using adm user
if [ $UID == 0 ];then
echo "Please login via sidadm user" 2>&1
exit 1
fi

SID=`echo $SYBASE | cut -c9-11`
echo $SID 2>&1

function log_bkp {
echo "Taking log backup" 2>&1
isql -k DBA -X <<EOF
exec saptools..sp_dumptrans @sapdb_name = $SID
go
EOF

echo "log backup finished successfully" 2>&1
}

#Checking if sp_dumptrans is present or not


check=`isql -k DBA -X -i '/usr/sap/ASE_SCRIPTS/wrapper/dumptranscheck.sql'`
if [ "$check" = "1" ] ; then
        echo "sp_dumptrans is present, proceeding with the backup"
        log_bkp

        else
                echo "sp_dumptrans is not present,installing it and then backup will run"

                isql -k DBA -X -i '/usr/sap/ASE_SCRIPTS/sp_dumptrans.sql'

                log_bkp

                fi

                exit 0
                
