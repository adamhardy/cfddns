#!/usr/bin/env bash
# author: jacob@systemctl.uk
# Update a Cloudflare record via it's API

# Variables
logFile=cfddns.log
currentHost=$(hostname)
currentDate=$(date +%d/%m/%y)
currentTime=$(date +%H:%M)
currentExtIp=$(curl --silent https://ipv4.icanhazip.com)
cfAuthEmail=''
cfApiKey=''
cfZoneId=''
cfZoneName=''
cfRecordName=''
cfRecordId=''
slackURL=''

# Functions
cf_get_record_content () {
  curl --silent -X GET "https://api.cloudflare.com/client/v4/zones/${cfZoneId}/dns_records?name=${cfRecordName}" \
     -H "X-Auth-Email: ${cfAuthEmail}" \
     -H "X-Auth-Key: ${cfApiKey}" \
     -H "Content-Type: application/json" | python -m json.tool | grep 'content' | sed 's/"content"://g' | sed 's/,//g' | sed 's/"//g' | sed 's/ //g'
}

cf_update_record_content () {
  curl --silent -X PUT "https://api.cloudflare.com/client/v4/zones/${cfZoneId}/dns_records/${cfRecordId}" \
     -H "X-Auth-Email: ${cfAuthEmail}" \
     -H "X-Auth-Key: ${cfApiKey}" \
     -H "Content-Type: application/json" \
     --data '{"id":"'${cfRecordId}'","type":"A","name":"'${cfRecordName}'","content":"'${currentExtIp}'","zone_id":"'${cfZoneId}'","zone_name":"'${cfZoneName}'","data":{}}' | python -m json.tool \
     | grep 'success' | sed 's/"success"://g' | sed 's/,//g' | sed 's/"//g' | sed 's/ //g'
}

slack_update () {
  logContent=$(cat ${logFile})
  curl --silent -X POST -H 'Content-type: application/json' \
     --data '{"text": "```'"$logContent"'```"}' ${slackURL}
}
# Set record content from function cf_get_record_content
cfRecordContent=$(cf_get_record_content)

printf "=== Cloudflare Updater runlog for %s at %s %s ===\n" $cfRecordName $currentTime $currentDate > $logFile
printf "The current external IP of this system (%s) is %s\n" $currentHost $currentExtIp >> $logFile
printf "Cloudflare has %s as the record for %s\n" $cfRecordContent $cfRecordName >> $logFile

# Compare the current Cloudflare and current external
if [[ "${currentExtIp}" == "${cfRecordContent}" ]]; then
  recordMatch=1
else
  recordMatch=0
fi

if [[ "${recordMatch}" -eq "1" ]]; then
  printf "Records match - nothing to do\n" >> $logFile
else
  printf "Records don't match - Invoking cf_update_record_content\n" >> $logFile
  cfRecordUpdate=$(cf_update_record_content)
  if [[ "${cfRecordUpdate}" == "true" ]]; then
    cfRecordContentUpdated=$(cf_get_record_content)
    printf "Record for %s successfully updated to %s" $cfRecordName $cfRecordContentUpdated >> $logFile
  else
    printf "Something went wrong. I know this isn't a very useful error. ¯\_(ツ)_/¯\n"
  fi
fi

slack_update
