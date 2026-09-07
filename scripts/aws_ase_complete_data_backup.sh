#!/bin/bash
#Author: Fikris Technologies
#Purpose: Root-level entry point invoked by cron/scheduler; switches to
#         the sybase SID user and runs the full database backup wrapper.
DATE="$(date '+%Y%m%d-%H%M%S1')"
sid=`df -h | grep '/sybase/' | awk '{print $NF}' | cut -d / -f3 | head -1`
SID=`echo ${sid} | tr "[A-Z]" "[a-z]"`


sudo su - syb$SID -c " /usr/sap/ASE_SCRIPTS/wrapper/wrapper_complete_data_backup.sh "
