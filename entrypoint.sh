#!/bin/bash 
# File              : entrypoint.sh
# Author            : Alexandre Saison <alexandre.saison@inarix.com>
# Date              : 25.05.2021
# Last Modified Date: 01.06.2021
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
export REPOSITORY=$(echo "$GITHUB_REPOSITORY" | cut -d "/" -f2)

# 2. Declaring functions
function registerModel {
  THREAD_TS=$1
  
  local REGISTER_RESPONSE=""
  
  if [[ $WORKER_ENV == "staging" ]]
  then
    echo "{ \"templateId\": $MODEL_TEMPLATE_ID, \"branchSlug\": \"$WORKER_ENV\", \"version\": \"${NUTSHELL_MODEL_VERSION}-staging\", \"dockerImageUri\": \"eu.gcr.io/$GOOGLE_PROJECT_ID/$REPOSITORY:${NUTSHELL_MODEL_VERSION}-staging\", \"metadata\": {}}" > modelDeploymentPayload.json
    REGISTER_RESPONSE=$(curl -s -L -X POST -H "Authorization: Bearer ${STAGING_API_TOKEN}" -H "Content-Type: application/json" -d @./modelDeploymentPayload.json https://staging.api.inarix.com/imodels/model-instance)
  else
    echo "{ \"templateId\": $MODEL_TEMPLATE_ID, \"branchSlug\": \"$WORKER_ENV\", \"version\": \"$NUTSHELL_MODEL_VERSION\", \"dockerImageUri\": \"eu.gcr.io/$GOOGLE_PROJECT_ID/$REPOSITORY:$NUTSHELL_MODEL_VERSION\", \"metadata\": {}}" > modelDeploymentPayload.json
    REGISTER_RESPONSE=$(curl -s -L -X POST -H "Authorization: Bearer ${PRODUCTION_API_TOKEN}" -H "Content-Type: application/json" -d @./modelDeploymentPayload.json https://api.inarix.com/imodels/model-instance)
  fi

  RESPONSE_CODE=$(echo "$REGISTER_RESPONSE" | jq -e .code )
  
  if [[ $RESPONSE_CODE == 1 || $RESPONSE_CODE != 201 ]]
  then
    # <@USVDXF4KS> is Me (Alexandre Saison)
    sendSlackMessage "MODEL_DEPLOYMENT" "Failed registered on Inarix API! <@USVDXF4KS> please check the Github Action"  > /dev/null
    exit 1
  else
    # <@UNT6EB562> is Artemis User
    echo"$(echo $REGISTER_RESPONSE | jq .id)"
    sendSlackMessage "MODEL_DEPLOYMENT"  "Succefully registered on Inarix API! You'll be soon able to launch Argo Workflow" > /dev/null
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

  local VERSION="${MODEL_VERSION:1}"

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
                    { "name": "image.imageName", "value": "$REPOSITORY" },
                    { "name": "image.version", "value": "$VERSION" },
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
    RESPONSE=$(curl -L -X POST "${ARGOCD_ENTRYPOINT}/${APPLICATION_NAME}/sync" -H "Content-Type: application/json" -H "Authorization: Bearer ${ARGOCD_TOKEN}") 
    echo $CURL_RESPONSE
}

function createApplicationSpec() {
    generateApplicationSpec
    CURL_RESPONSE=$(curl -L -X POST "${ARGOCD_ENTRYPOINT}" -H 'Content-Type: application/json' -H "Authorization: Bearer ${ARGOCD_TOKEN}" -d @./data.json)
    echo $CURL_RESPONSE
}

# 3. Script starts now

echo "[$(date +"%m/%d/%y %T")] checking functions.sh"
checkEnvVariables

echo "[$(date +"%m/%d/%y %T")] Deploying model $REPOSITORY:$MODEL_VERSION"
echo "[$(date +"%m/%d/%y %T")] Importing every .env variable from model"

THREAD_TS=$(sendSlackMessage "MODEL_DEPLOYMENT" "Deploy model $NUTSHELL_MODEL_SERVING_NAME with version $MODEL_VERSION")
CREATE_RESPONSE=$(createApplicationSpec)

if [[ $? == 1 ]]
then
    sendSlackMessage "MODEL_DEPLOYMENT" "$APPLICATION_NAME had a error when creating ApplicatinSpec: $CREATE_RESPONSE" $THREAD_TS
    exit 1
fi

HAS_ERROR=$(echo $CREATE_RESPONSE | jq .error )

if [[ -n $HAS_ERROR ]]
then
    echo "[$(date +"%m/%d/%y %T")] Creation of application specs succeed!"
    sendSlackMessage "MODEL_DEPLOYMENT" "Application has been created and will now be synced on ${ARGOCD_ENTRYPOINT}/${APPLICATION_NAME}"
    SYNC_RESPONSE=$(syncApplicationSpec)
    HAS_ERROR=$(echo $SYNC_RESPONSE | jq -e .error )
    
    if [[ $HAS_ERROR == 1 ]]
    then
        echo "[$(date +"%m/%d/%y %T")] An error occured during $APPLICATION_NAME sync! Error: $HAS_ERROR"
        exit 1
    fi
    echo "[$(date +"%m/%d/%y %T")] Application sync succeed!"

    MODEL_INSTANCE_ID=$(registerModel $THREAD_TS)

    echo "::set-output name=modelInstanceId::'${MODEL_INSTANCE_ID}'"
    echo "[$(date +"%m/%d/%y %T")] Removing generated data.json!"
    rm data.json
else
    echo "[$(date +"%m/%d/%y %T")] An error occured when creating application specs! Error: $CREATE_RESPONSE"
    sendSlackMessage "MODEL_DEPLOYMENT" "$APPLICATIN_NAME had a error during deployment: $CREATE_RESPONSE"
    rm data.json
    exit 1
fi
