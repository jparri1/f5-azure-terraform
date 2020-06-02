#!/bin/bash

# backend ONBOARD SCRIPT

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

sleep 30
sudo mkdir -p /etc/nginx/api_conf.d
sudo mkdir -p /etc/node-rest
sudo mkdir -p /etc/nginx/ssl/keys
sudo mkdir -p /etc/nginx/ssl/certs
sudo cp "/var/tmp/conf/warehouse_api_simple.conf" /etc/nginx/api_conf.d/warehouse_api_simple.conf
sudo cp "/var/tmp/conf/api_backends.conf" /etc/nginx/api_backends.conf
sudo cp "/var/tmp/conf/api_gateway.conf" /etc/nginx/api_gateway.conf
sudo cp "/var/tmp/conf/api_json_errors.conf" /etc/nginx/api_json_errors.conf 
sudo cp "/var/tmp/conf/nginx.conf" /etc/nginx/nginx.conf
sudo cp "/var/tmp/conf/jwk.json" /etc/nginx/jwk.json
sudo cp "/var/tmp/conf/test.crt" /etc/nginx/ssl/certs/test.crt
sudo cp "/var/tmp/conf/test.key" /etc/nginx/ssl/keys/test.key
cd /etc/node-rest
sudo cp "/var/tmp/conf/index.js" /etc/node-rest/
curl -sL https://deb.nodesource.com/setup_10.x | sudo -E bash -
sudo apt install -y nodejs
sudo npm install express --save
sudo npm install nodemon -g
sudo systemctl restart nginx
sleep 10
sudo npm install pm2@latest -g
sudo pm2 start index.js
sudo pm2 startup systemd
sudo pm2 save


