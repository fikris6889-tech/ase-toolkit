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

function bkp {
echo "Taking master backup" 2>&1
isql -k DBA  -X <<EOF
use master
exec saptools..sp_dumpdb @sapdb_name = master
go
EOF

echo "master backup completed successfully" 2>&1

echo "Taking $SID backup...."
isql -k DBA -X <<EOF
exec saptools..sp_dumpdb @sapdb_name = $SID
go
EOF
}


#Checking if sp_dumpdb is present or not


check=`isql -k DBA -X -i '/usr/sap/ASE_SCRIPTS/wrapper/dumpdbcheck.sql'`
if [ "$check" = "1" ] ; then
        echo "sp_dumpdb is present, proceeding with the backup"
        bkp

        else
                echo "sp_dumpdb is not present,installing it and then backup will run"

                isql -k DBA -X -i '/usr/sap/ASE_SCRIPTS/sp_dumpdb.sql'

                bkp

                fi

                exit 0
                
