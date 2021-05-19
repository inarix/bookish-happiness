#!/bin/bash
# File              : .github_action_deploy.sh
# Author            : Alexandre Saison <alexandre.saison@inarix.com>
# Date              : 27.01.2021
# Last Modified Date: 08.02.2021
# Last Modified By  : Alexandre Saison <alexandre.saison@inarix.com>



CURL_RESPONSE=`curl -L -X POST "${ARGOCD_ENTRYPOINT}" \
 -s \
 -H 'Content-Type: application/json' \
 -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
 -d @./data.json`

JSON_RESPONSE=${$CURL_RESPONSE | jq .error}

if [[ ! -z $JSON_RESPONSE ]]
then
    ./.sendSlackMessage.sh "Application has been created and will now be synced on ${ARGOCD_ENTRYPOINT}/${APPLICATION_NAME}" $THREAD_TS
    
    curl -L -X POST "${ARGOCD_ENTRYPOINT}/${APPLICATION_NAME}/sync" \
    -s \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${ARGOCD_TOKEN}" 

    ./.sendSlackMessage.sh "Model deployment of ${NUTSHELL_MODEL_SERVING_NAME} version:${MODEL_VERSION}" $THREAD_TS
    ./.sendSlackMessage.sh "Registering $APPLICATION_NAME to Inarix API" $THREAD_TS
    rm data.json
else
    ./.sendSlackMessage.sh "Application had a error during deployment"
    rm data.json
fi
