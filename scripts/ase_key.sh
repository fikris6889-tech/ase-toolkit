#!/bin/bash
#Author: Fikris Technologies
#Purpose: Seeds the SAP ASE credential store (aseuserstore) with a DBA
#         login so that every other script in this toolkit can connect
#         via `isql -k DBA` without a plaintext password anywhere on
#         disk or in shell history.
#
#SECURITY NOTE: The original internal version of this script had the
#ASE login password hardcoded on the "aseuserstore set" line below.
#That has been removed for this public release. The script now PROMPTS
#for the password at runtime instead, so no credential ever gets
#committed to source control. See README.md and docs/CASE_STUDY.md for
#the full story on why this was changed and how to harden it further
#(e.g. sourcing the password from a secrets manager instead of a prompt).

trap '{ echo "Caught SIGINT, as you have pressed ctrl+c, exiting from the script" ;  exit 1; }' INT
user=`whoami`
if [ $user != 'root' ];then
echo "Please execute the script via root user"
exit 1
fi

DATE="$(date '+%Y%m%d-%H%M%S1')"
sid=`df -h | grep '/sybase/' | awk '{print $NF}' | cut -d / -f3 | head -1`
SID=`echo ${sid} | tr "[A-Z]" "[a-z]"`
sid_first_letter=`df -h | grep '/sybase/' | awk '{print $NF}' | cut -d / -f3 | head -1 | cut -c1`
host=`hostname`


# Reset
Color_Off='\033[0m'       # Text Reset
# Bold High Intensity
BIGreen='\033[1;92m'      # Green
BIYellow='\033[1;93m'     # Yellow

# ASE login used to seed the credential store. Override by exporting
# ASE_LOGIN before running the script if your site uses a different login.
ASE_LOGIN="${ASE_LOGIN:-sapsa}"

# Prompt for the password at runtime instead of storing it in the script.
echo -e "${BIYellow}Enter the password for ASE login '${ASE_LOGIN}' on system ${sid}:${Color_Off}"
read -s -p "Password: " ASE_PASSWORD
echo " "
if [ -z "$ASE_PASSWORD" ]; then
echo "No password entered, exiting."
exit 1
fi

#Creating a test sql file to check the viability of Key

file="/tmp/test_"$DATE"_key.sql"

echo "select name,dbid from master..sysdatabases" > $file
echo "go" >> $file


#Setting Key
echo " "
echo -e "${BIYellow}======== Setting the Key in $sid System  ======== ${Color_Off}"
sudo su - syb$SID -c "aseuserstore set DBA '$host 4901' $ASE_LOGIN '$ASE_PASSWORD'"

# Drop the password out of this shell's memory as soon as it has been used
unset ASE_PASSWORD

echo " "
echo -e "${BIGreen} Key is Set ${Color_Off}"


sudo su - syb$SID -c "aseuserstore list"


#Checking Accessibilty of Key
echo " "

echo -e "${BIGreen}Below is a sample output from the newley set Key ${Color_Off}"
echo " "
sudo su - syb$SID -c "isql -k DBA -X -w999 -i /tmp/test_"$DATE"_key.sql "

#Removal of test File

rm -rf $file
