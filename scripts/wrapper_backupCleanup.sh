#!/bin/bash
#Author: Fikris Technologies
#Purpose: Syncs data-dump and transaction-log backup directories to S3,
#         then deletes the local copies once the sync has completed.
#         Run as the sybase SID user (via aws_ase_backupCleanup.sh).

#SID absorb
SID=`echo $SYBASE | cut -c9-11`
echo $SID 2>&1

#variable define

## Configure this for your organization before use. It is intentionally
## NOT a real bucket name in this public release - see README.md.
S3_BUCKET_PREFIX="${S3_BUCKET_PREFIX:-your-company-ase-backup-enterprise}"

# Determining Relevant S3 Backup Bucket Based on First Letter in TENANT_NAME Variable ##
SID_FIRST_LETTER="$(printf '%s' "${SID}" | cut -c1)"
echo "Received value '${SID}'"
echo "First lettes '${SID_FIRST_LETTER}'"
if [ "${SID_FIRST_LETTER}"  = P ]; then
                S3_BUCKET_NAME="${S3_BUCKET_PREFIX}-prod"
                                echo "Source system is Production, syncing backups to: ${S3_BUCKET_NAME}"
                                else
                                                S3_BUCKET_NAME="${S3_BUCKET_PREFIX}-nonprod"
                                                        echo "Source system is Non-Production, syncing backups to: ${S3_BUCKET_NAME}"
                                                        fi


                                                        ## Sync Backups to S3 Before Cleanup ##
                                                        echo "Performing S3 sync on /dbbackup01/${SID}/backups/ to ${S3_BUCKET_NAME}..."

                                                        aws s3 sync /dbbackup01/${SID}/backups/ s3://${S3_BUCKET_NAME}/backup/${SID}/usr/sap/${SID}/SYS/global/syb/backup/ASE_${SID}/

                                                        #cleanup command for data dumps
                                                        find /dbbackup01/${SID}/backups/ -mtime +0 -exec rm {} \; -print


                                                        #sync log backups before cleanup
                                                        echo "Performing S3 sync on /dbbackup01/${SID}/log_archives/ to ${S3_BUCKET_NAME}..."

                                                        aws s3 sync /dbbackup01/${SID}/log_archives/ s3://${S3_BUCKET_NAME}/backup/${SID}/usr/sap/${SID}/SYS/global/syb/backup/ASE_${SID}/

                                                        #cleanup comand for transaction logs
                                                        find /dbbackup01/${SID}/log_archives/ -mtime +0 -exec rm {} \; -print

                                                        exit 0
                                                        
