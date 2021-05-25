#!/bin/bash 
# File              : entrypoint.sh
# Author            : Alexandre Saison <alexandre.saison@inarix.com>
# Date              : 25.05.2021
# Last Modified Date: 25.05.2021
# Last Modified By  : Alexandre Saison <alexandre.saison@inarix.com>
if [[ -f .env ]]
then
  export $(grep -v '^#' .env | xargs)
  echo "[$(date +"%m/%d/%y %T")] Exported all env variables"
else 
  echo "[$(date +"%m/%d/%y %T")] An error occured during import .env variables"
  exit 1
fi

# 1. Creation of local variables
export MODEL_NAME="${NUTSHELL_MODEL_SERVING_NAME}"
export MODEL_VERSION="${NUTSHELL_MODEL_VERSION}"
export APPLICATION_NAME="$WORKER_ENV-mt-$MODEL_NAME"

env

# 2. Declaring functions
function sendSlackMessage() {
MESSAGE_TITLE=$1
MESSAGE_PAYLOAD=$2
IS_REPLY=$3

if [[ -n $IS_REPLY ]]
then
cat >./payload.json <<EOF
{
"channel": "$SLACK_CHANNEL_ID",
"text": "[$MESSAGE_TITLE] : $MESSAGE_PAYLOAD",
"thread_ts": "$IS_REPLY"
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

#Returns the actual THREAD_TS stored as third argument of this script
echo $IS_REPLY
rm payload.json
else
cat >./payload.json <<EOF 
{
"channel": "$SLACK_CHANNEL_ID",
"text": "[${MESSAGE_TITLE}] : $MESSAGE_PAYLOAD"
}
EOF

    #Stores the response of the CURL request
    RESPONSE=$(curl -d @./payload.json \
         -X POST \
         -s \
         --silent \
         -H "Content-Type: application/json" \
         -H "Authorization: Bearer ${SLACK_API_TOKEN}" \
         https://slack.com/api/chat.postMessage)

    #Use the jq linux command to simply get access to the ts value for the object response from $RESPONSE
    THREAD_TS=$(echo "$RESPONSE" | jq .ts)

    #Return script value as the THREAD_TS for future responses
    echo $THREAD_TS
    rm payload.json
    fi
}

function checkEnvVariables() {
    if [[ -z $WORKER_ENV ]]
    then 
        echo "WORKER env variable is not set ! (Required to push to ArgoCD)"
        exit 1
    elif [[ -z $NUTSHELL_MODEL_SERVING_NAME ]]
    then
        echo "NUTSHELL_MODEL_SERVING_NAME env variable is not set !"
        exit 1
    elif [[ -z $NUTSHELL_MODEL_VERSION ]]
    then
        echo "NUTSHELL_MODEL_VERSION env variable is not set !"
        exit 1
    elif [[ -z $MODEL_HELM_CHART_VERSION ]]
    then
        echo "MODEL_HELM_CHART_VERSION env variable is not set ! (Required to push to ArgoCD)"
        exit 1
    elif [[ -z $MODEL_HELM_CHART_VERSION ]]
    then
        echo "MODEL_HELM_CHART_VERSION env variable is not set ! (Required to push to ArgoCD)"
        exit 1
    elif [[ -z $DD_API_KEY ]]
    then
        echo "DD_API_KEY env variable is not set ! (Required to push to ArgoCD)"
        exit 1
    elif [[ -z $DD_APP_KEY ]]
    then
        echo "DD_APP_KEY env variable is not set ! (Required to push to ArgoCD)"
        exit 1
    elif [[ -z $INARIX_PASSWORD ]]
    then
        echo "INARIX_PASSWORD env variable is not set ! (Required to push to ArgoCD)"
        exit 1
    elif [[ -z $INARIX_USERNAME ]]
    then
        echo "INARIX_USERNAME env variable is not set ! (Required to push to ArgoCD)"
        exit 1
    elif [[ -z $AWS_ACCESS_KEY_ID ]]
    then
        echo "AWS_ACCESS_KEY_ID env variable is not set ! (Required to push to ArgoCD)"
        exit 1
    elif [[ -z $AWS_SECRET_ACCESS_KEY ]]
    then
        echo "AWS_SECRET_ACCESS_KEY env variable is not set ! (Required to push to ArgoCD)"
        exit 1
    elif [[ -z $NUTSHELL_MODEL_PATH ]]
    then
        echo "NUTSHELL_MODEL_PATH env variable is not set ! (Required to push to ArgoCD)"
        exit 1
    fi
}

function generateApplicationSpec() {
  
  local NODE_SELECTOR="nutshell"
  if [[ $WORKER_ENV == "staging" ]]
  then
    NODE_SELECTOR="$NODE_SELECTOR-$WORKER_ENV"
  fi

  cat > data.json <<EOF 
{ "metadata": { "name": "$APPLICATION_NAME", "namespace": "default" },
  "spec": { "source": {
            "repoURL": "https://charts.inarix.com",
            "targetRevision": "$MODEL_HELM_CHART_VERSION",
            "helm": {
                "parameters": [
                    { "name": "app.datadog.apiKey", "value": "$DD_API_KEY" },
                    { "name": "app.datadog.appKey", "value": "$DD_APP_KEY" },
                    { "name": "app.env", "value": "$WORKER_ENV" },
                    { "name": "credentials.api.password", "value": "$INARIX_PASSWORD" },
                    { "name": "credentials.api.username", "value": "$INARIX_USERNAME" },
                    { "name": "credentials.aws.accessKey", "value": "$AWS_ACCESS_KEY_ID" },
                    { "name": "credentials.aws.secretKey", "value": "$AWS_SECRET_ACCESS_KEY" },
                    { "name": "image.imageName", "value": "$MODEL_NAME" },
                    { "name": "image.version", "value": "$MODEL_VERSION" },
                    { "name": "model.modelName", "value": "$NUTSHELL_MODEL_SERVING_NAME" },
                    { "name": "model.nutshellName", "value": "$NUTSHELL_MODEL_SERVING_NAME" },
                    { "name": "model.servingMode", "value": "$NUTSHELL_MODE" },
                    { "name": "nodeSelector.name", "value": "$NODE_SELECTOR" },
                    { "name": "nutshell.fileLocationId", "value": "$NUTSHELL_WORKER_MODEL_FILE_LOC_ID" },
                    { "name": "nutshell.timeoutS", "value": "$NUTSHELL_WORKER_MODEL_PREDICT_TIMEOUT_S" },
                    { "name": "nutshell.worker.env", "value": "$WORKER_ENV" },
                    { "name": "model.path", "value": "$NUTSHELL_MODEL_PATH" }
                ]
            },
            "chart": "inarix-serving"
        },
        "destination": { "server": "https://34.91.136.161", "namespace": "$WORKER_ENV" },
        "project": "model-serving",
        "syncPolicy": {}
    }
}
EOF
}

function syncApplicationSpec() {
    RESPONSE=$(curl -L -X POST "${ARGOCD_ENTRYPOINT}/${APPLICATION_NAME}/sync" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${ARGOCD_TOKEN}")
    echo $CURL_RESPONSE
}

function createApplicationSpec() {
    generateApplicationSpec
    
    CURL_RESPONSE=$(curl -L -X POST "${ARGOCD_ENTRYPOINT}" \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
    -d @./data.json)
    echo $CURL_RESPONSE
}

# 3. Script starts now

echo "[$(date +"%m/%d/%y %T")] checking functions.sh"
checkEnvVariables

echo "[$(date +"%m/%d/%y %T")] Deploying model $MODEL_NAME:$MODEL_VERSION"
echo "[$(date +"%m/%d/%y %T")] Importing every .env variable from model"

THREAD_TS=$(sendSlackMessage "MODEL_DEPLOYMENT" "Deploy model $NUTSHELL_MODEL_SERVING_NAME with version $MODEL_VERSION")
CREATE_RESPONSE=$(createApplicationSpec)

if [[ $? == 1 ]]
then
    sendSlackMessage "MODEL_DEPLOYMENT" "Application had a error when creating ApplicatinSpec: $CREATE_RESPONSE" $THREAD_TS
    exit 1
fi

HAS_ERROR=$(echo $CREATE_RESPONSE | jq .error )
echo "CreateResponse=$CREATE_RESPONSE"

if [[ -n $HAS_ERROR ]]
then
    echo "[$(date +"%m/%d/%y %T")] Creation of application specs succeed!"
    sendSlackMessage "MODEL_DEPLOYMENT" "Application has been created and will now be synced on ${ARGOCD_ENTRYPOINT}/${APPLICATION_NAME}" $THREAD_TS
    SYNC_RESPONSE=$(syncApplicationSpec)
    HAS_ERROR=$(echo $SYNC_RESPONSE | jq .error )
    echo "SyncResponse=$HAS_ERROR"
    
    if [[ -n $HAS_ERROR ]]
    then
        echo "[$(date +"%m/%d/%y %T")] An error occured during applicaion sync! Error: $HAS_ERROR"
        exit 1
    fi
    echo "[$(date +"%m/%d/%y %T")] Application sync succeed!"
    sendSlackMessage "MODEL_DEPLOYMENT" "Model deployment of ${NUTSHELL_MODEL_SERVING_NAME} version:${MODEL_VERSION}" $THREAD_TS

    echo "::set-output name=modelVersion::'$MODEL_VERSION'"
    echo "::set-output name=modelName::'$MODEL_NAME'"
    echo "[$(date +"%m/%d/%y %T")] Removing generated data.json!"
    rm data.json
else
    echo "[$(date +"%m/%d/%y %T")] An error occured when creating application specs! Error: $CREATE_RESPONSE"
    sendSlackMessage "MODEL_DEPLOYMENT" "Application had a error during deployment: $CREATE_RESPONSE" $THREAD_TS
    rm data.json
    exit 1
fi
