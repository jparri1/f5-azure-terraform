#!/bin/bash

# BIG-IPS ONBOARD SCRIPT

LOG_FILE=${onboard_log}

if [ ! -e $LOG_FILE ]
then
     touch $LOG_FILE
     exec &>>$LOG_FILE
else
    #if file exists, exit as only want to run once
    exit
fi

exec 1>$LOG_FILE 2>&1

# CHECK TO SEE NETWORK IS READY
CNT=0
while true
do
  STATUS=$(curl -s -k -I example.com | grep HTTP)
  if [[ $STATUS == *"200"* ]]; then
    echo "Got 200! VE is Ready!"
    break
  elif [ $CNT -le 6 ]; then
    echo "Status code: $STATUS  Not done yet..."
    CNT=$[$CNT+1]
  else
    echo "GIVE UP..."
    break
  fi
  sleep 10
done

### DOWNLOAD ONBOARDING PKGS
# Could be pre-packaged or hosted internally

admin_username='${uname}'
admin_password='${upassword}'
CREDS=admin:$admin_password
DO_URL='${DO_onboard_URL}'
DO_FN=$(basename "$DO_URL")
AS3_URL='${AS3_URL}'
AS3_FN=$(basename "$AS3_URL")

echo -e "\n"$(date) "Download Declarative Onboarding Pkg"
curl -L -o /var/tmp/$DO_FN $DO_URL -k
sleep 30
echo -e "\n"$(date) "Download AS3 Pkg"
curl -L -o /var/tmp/$AS3_FN $AS3_URL -k


# Install Declarative Onboarding Pkg
DATA="{\"operation\":\"INSTALL\",\"packageFilePath\":\"/var/tmp/$DO_FN\"}"
echo -e "\n"$(date) "Install DO Pkg"
curl https://localhost/mgmt/shared/iapp/package-management-tasks -u $CREDS -d $DATA -k
sleep 30
# Install AS3 Pkg
DATA="{\"operation\":\"INSTALL\",\"packageFilePath\":\"/var/tmp/$AS3_FN\"}"
echo -e "\n"$(date) "Install AS3 Pkg"
curl https://localhost/mgmt/shared/iapp/package-management-tasks -u $CREDS -d $DATA -k
sleep 30
sudo bigstart restart restnoded
sudo bigstart restart restnoded
sudo bigstart restart restnoded
sudo bigstart restart restnoded
sudo bigstart restart restnoded
# Check DO Ready
CNT=0
while true
do
  STATUS=$(curl -s -I https://localhost/mgmt/shared/declarative-onboarding/info -u azureuser:Default12345 -k | grep HTTP)
  if [[ $STATUS == *"200"* ]]; then
    echo "Got 200! Declarative Onboarding is Ready!"
    break
  elif [ $CNT -le 6 ]; then
    echo "Status code: $STATUS  DO Not done yet..."
    CNT=$[$CNT+6]
  else
    echo "GIVE UP..."
    break
  fi
  sleep 10
done

# Check AS3 Ready
CNT=0
while true
do
  STATUS=$(curl -s -I https://localhost/mgmt/shared/appsvcs/info -u azureuser:Default12345 -k | grep HTTP)
  if [[ $STATUS == *"200"* ]]; then
    echo "Got 200! AS3 is Ready!"
    break
  elif [ $CNT -le 6 ]; then
    echo "Status code: $STATUS  AS3 Not done yet..."
    CNT=$[$CNT+6]
  else
    echo "GIVE UP..."
    break
  fi
  sleep 10
done

