#!/bin/bash
# File              : sendSlackMessage.sh
# Author            : Alexandre Saison <alexandre.saison@inarix.com>
# Date              : 05.02.2021
# Last Modified Date: 19.05.2021
# Last Modified By  : Alexandre Saison <alexandre.saison@inarix.com>
if [[ -f .env ]]
then
  export $(grep -v '^#' .env | xargs)
fi

MESSAGE_TITLE=$1
MESSAGE_PAYLOAD=$2
IS_REPLY=$3

if [[ -n $IS_REPLY ]]
then

cat >./payload.json <<EOF
{
  "channel": "$SLACK_CHANNEL_ID",
  "text": "[${MESSAGE_TITLE}] : $MESSAGE_PAYLOAD",
  "thread_ts": $IS_REPLY
}
EOF

#Send a simple CURL request to send the message
curl -d @./payload.json \
     -X POST \
     -s \
     --silent \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${SLACK_API_TOKEN}" \
     https://slack.com/api/chat.postMessage

#Returns the actual THREAD_TS stored as second argument of this script
echo $IS_REPLY
else

cat >./payload.json <<EOF
{
  "channel": "$SLACK_CHANNEL_ID",
  "text": "[${MESSAGE_TITLE}] : $MESSAGE_PAYLOAD"
}
EOF

#Stores the response of the CURL request
RESPONSE=`curl -d @./payload.json \
     -X POST \
     -s \
     --silent \
     -H "Content-Type: application/json" \
     -H "Authorization: Bearer ${SLACK_API_TOKEN}" \
     https://slack.com/api/chat.postMessage`

#Use the jq linux command to simply get access to the ts value for the object response from $RESPONSE
THREAD_TS=`echo "$RESPONSE" | jq .ts`

#Return script value as the THREAD_TS for future responses
echo $THREAD_TS

fi
