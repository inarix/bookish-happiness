#!/bin/bash
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
export APPLICATION_NAME=$(echo "mt-$MODEL_NAME" | awk '{print tolower($0)}')
export REPOSITORY=$(echo "$GITHUB_REPOSITORY" | cut -d "/" -f2)

function fromEnvToJson {
  python -c "
import json
import sys
with open('.env', 'r') as f:
    content = f.readlines()
content = [x.strip().split('=') for x in content if '=' in x]
print(json.dumps(dict(content)))"
}

function waitForHealthy {
  python -c '
import os
import requests
import time
name = os.environ.get("APPLICATION_NAME")
token = os.environ.get("ARGOCD_TOKEN")
endpoint = os.environ.get("ARGOCD_ENTRYPOINT")
max_retry = int(os.environ.get("INPUT_MAXRETRY", "10"))
tts = int(os.environ.get("INPUT_TTS", "5"))
headers = {"Authorization": f"Bearer {token}"}
print(f"tts={tts} max_retry={max_retry}")
while True and max_retry > 0:
  res = requests.get(f"{endpoint}/{name}", headers=headers)
  if res.status_code != 200:
    print(f"error: Status code != 200, {res.status_code}")
    raise SystemExit(1)
  payload = res.json()
  if "status" in payload and "health" in payload["status"] and "status" in payload["status"]["health"]:
    status = payload["status"]["health"]["status"]
    if status == "Healthy":
      raise SystemExit(0)
    elif status == "Missing" or status == "Degraded":
      print(f"Health status error: {status} then retry {max_retry}")
      max_retry -= 1
    elif status != "Progressing":
      print(f"Health status error: {status}")
      raise SystemExit(1)
  else:
    print("Invalid payload returned from ArgoCD")
    raise SystemExit(1)
  time.sleep(tts)
  '
}

# 2. Declaring functions
function registerModel {
  local THREAD_TS=$1
  
  local REGISTER_RESPONSE=""
  local metadata=$(fromEnvToJson | jq '. + { ci : {source: "Github Action"} }')
  
  if [[ $WORKER_ENV == "staging" ]]
  then
    echo "{ \"templateId\": $MODEL_TEMPLATE_ID, \"branchSlug\": \"$WORKER_ENV\", \"version\": \"${NUTSHELL_MODEL_VERSION}-staging\", \"dockerImageUri\": \"eu.gcr.io/$GOOGLE_PROJECT_ID/$REPOSITORY:${NUTSHELL_MODEL_VERSION}-staging\",\"isDeployed\": true, \"metadata\": $metadata}" > modelDeploymentPayload.json
    REGISTER_RESPONSE=$(curl -L -X POST -H "Authorization: Bearer ${STAGING_API_TOKEN}" -H "Content-Type: application/json" -d @./modelDeploymentPayload.json https://staging.api.inarix.com/imodels/model-instance)
  else
    echo "{ \"templateId\": $MODEL_TEMPLATE_ID, \"branchSlug\": \"$WORKER_ENV\", \"version\": \"$NUTSHELL_MODEL_VERSION\", \"dockerImageUri\": \"eu.gcr.io/$GOOGLE_PROJECT_ID/$REPOSITORY:$NUTSHELL_MODEL_VERSION\",\"isDeployed\": true,\"metadata\": $metadata}" > modelDeploymentPayload.json
    REGISTER_RESPONSE=$(curl -L -X POST -H "Authorization: Bearer ${PRODUCTION_API_TOKEN}" -H "Content-Type: application/json" -d @./modelDeploymentPayload.json https://api.inarix.com/imodels/model-instance)
  fi

  local RESPONSE_CODE=$(echo $REGISTER_RESPONSE | jq -r .code )
  local MODEL_VERSION_ID=$(echo $REGISTER_RESPONSE | jq -r .id)
  
  if [[ "${MODEL_VERSION_ID}" = "null" ]]
  then
    # <@USVDXF4KS> is Me (Alexandre Saison)
    sendSlackMessage "MODEL_DEPLOYMENT" "Failed registered on Inarix API! <@USVDXF4KS> GithubAction response=$RESPONSE_CODE" $THREAD_TS > /dev/null
    sendSlackMessage "MODEL_DEPLOYMENT" "Error: $(echo $REGISTER_RESPONSE | jq )" $THREAD_TS > /dev/null
    echo "[ERROR] Error > $REGISTER_RESPONSE"
    echo "[ERROR] Error > $(echo $REGISTER_RESPONSE | jq )"
    exit 1
    return -1
  else
    # <@UNT6EB562> is Artemis User
    echo "$MODEL_VERSION_ID"
    sendSlackMessage "MODEL_DEPLOYMENT"  "Succefully registered new model version of $REPOSITORY (model instance=$MODEL_VERSION_ID) on $WORKER_ENV environment" $THREAD_TS > /dev/null
  fi

}

function sendSlackMessage {
  MESSAGE_TITLE=$1
  MESSAGE_PAYLOAD=$2
  IS_REPLY=$3

  if [[ -n $IS_REPLY ]]
  then
    echo -n "{ \"channel\": \"$SLACK_CHANNEL_ID\", \"text\": \"[$MESSAGE_TITLE] : $MESSAGE_PAYLOAD\", \"thread_ts\": \"$IS_REPLY\" }" > payload.json

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
      echo -n "{ \"channel\": \"$SLACK_CHANNEL_ID\", \"text\": \"[$MESSAGE_TITLE] : $MESSAGE_PAYLOAD\" }" > payload.json

      #Stores the response of the CURL request
      RESPONSE=$(curl -d @./payload.json -X POST -H "Content-Type: application/json" -H "Authorization: Bearer ${SLACK_API_TOKEN}" https://slack.com/api/chat.postMessage)

      #Use the jq linux command to simply get access to the ts value for the object response from $RESPONSE
      THREAD_TS=$(echo "$RESPONSE" | jq -r .ts)

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
  local VERSION="${MODEL_VERSION:1}"

  if [[ $WORKER_ENV == "staging" ]]
  then
    NODE_SELECTOR="$NODE_SELECTOR-$WORKER_ENV"
    MODEL_NAME="${MODEL_NAME}-staging"
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
                    { "name": "credentials.api.hostname", "value": "$INARIX_HOSTNAME" },
                    { "name": "credentials.api.username", "value": "$INARIX_USERNAME" },
                    { "name": "credentials.api.password", "value": "$INARIX_PASSWORD" },
                    { "name": "credentials.aws.accessKey", "value": "$AWS_ACCESS_KEY_ID" },
                    { "name": "credentials.aws.secretKey", "value": "$AWS_SECRET_ACCESS_KEY" },
                    { "name": "image.imageName", "value": "$REPOSITORY" },
                    { "name": "image.version", "value": "$VERSION" },
                    { "name": "model.modelName", "value": "$MODEL_NAME" },
                    { "name": "model.nutshellName", "value": "$MODEL_NAME" },
                    { "name": "model.servingMode", "value": "$NUTSHELL_MODE" },
                    { "name": "model.templateSlug", "value": "$LABEL_TEMPLATE_SLUG" },
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
    RESPONSE=$(curl -L -X POST "${ARGOCD_ENTRYPOINT}/${APPLICATION_NAME}/sync" -H "Content-Type: application/json" -H "Authorization: Bearer ${ARGOCD_TOKEN}") 
    echo $CURL_RESPONSE
}

function createApplicationSpec() {
    generateApplicationSpec
    CURL_RESPONSE=$(curl -L -X POST "${ARGOCD_ENTRYPOINT}" -H 'Content-Type: application/json' -H "Authorization: Bearer ${ARGOCD_TOKEN}" -d @./data.json)
    echo $CURL_RESPONSE
}

# 3. Script starts now

echo "::group::Check env variables"
checkEnvVariables
echo "[$(date +"%m/%d/%y %T")] Importing every .env variable from model"
echo "::endgroup::"

echo "[$(date +"%m/%d/%y %T")] Deploying model $REPOSITORY:$MODEL_VERSION"

THREAD_TS=$(sendSlackMessage "MODEL_DEPLOYMENT" "Deploy model $NUTSHELL_MODEL_SERVING_NAME with version $MODEL_VERSION")
CREATE_RESPONSE=$(createApplicationSpec)

if [[ $? == 1 ]]
then
    sendSlackMessage "MODEL_DEPLOYMENT" "$APPLICATION_NAME had a error when creating ApplicatinSpec: $CREATE_RESPONSE" $THREAD_TS
    exit 1
fi

HAS_ERROR=$(echo $CREATE_RESPONSE | jq -e .error )

if [[ -n $HAS_ERROR ]]
then
    echo "::group::ArgoCD ${APPLICATION_NAME} creation"
    echo "[$(date +"%m/%d/%y %T")] Creation of application specs succeed!"
    sendSlackMessage "MODEL_DEPLOYMENT" "Application has been created and will now be synced on ${ARGOCD_ENTRYPOINT}/${APPLICATION_NAME}" $THREAD_TS
    SYNC_RESPONSE=$(syncApplicationSpec)
    HAS_ERROR=$(echo $SYNC_RESPONSE | jq -e .error )

    if [[ $HAS_ERROR == 1 ]]
    then
        echo "[$(date +"%m/%d/%y %T")] An error occured during $APPLICATION_NAME sync! Error: $HAS_ERROR" $THREAD_TS
        exit 1
    fi

    echo "[$(date +"%m/%d/%y %T")] Waiting for ${APPLICATION_NAME} to be Healthy!"
    # WAIT FOR SYNC TO START ! (AVOID STATUS MISSING !!)
    sleep 2
    waitForHealthy
    
    if [[ $? == 1 ]]
    then
      echo "[$(date +"%m/%d/%y %T")] Application creation failed!"
      exit 1
    else 
      echo "[$(date +"%m/%d/%y %T")] Application sync succeed!"
    fi
    echo "::endgroup::"
    
    echo "::group::Model registration"
    MODEL_INSTANCE_ID=$(registerModel $THREAD_TS)
    if [[ $MODEL_INSTANCE_ID == "-1" ]]
    then
      sendSlackMessage "MODEL DEPLOYMENT" "An error occured when registering model" $THREAD_TS
      exit 1
    fi
    echo "::set-output name=modelInstanceId::${MODEL_INSTANCE_ID}"
    rm data.json
    exit 0
    echo "::endgroup::"
else
    echo "[$(date +"%m/%d/%y %T")] An error occured when creating application specs! Error: $CREATE_RESPONSE"
    sendSlackMessage "MODEL_DEPLOYMENT" "$APPLICATION_NAME had a error during deployment: $CREATE_RESPONSE" $THREAD_TS
    rm data.json
    exit 1
fi
