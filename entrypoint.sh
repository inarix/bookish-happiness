#!/bin/bash 
# File              : entrypoint.sh
# Author            : Alexandre Saison <alexandre.saison@inarix.com>
# Date              : 19.05.2021
# Last Modified Date: 20.05.2021
# Last Modified By  : Alexandre Saison <alexandre.saison@inarix.com>


if [[ -f .env ]]
then
  export $(grep -v '^#' .env | xargs)
  echo "[$(date +"%m/%d/%y %T")] Exported all env variables"
else 
  echo "[$(date +"%m/%d/%y %T")] An error occured during import .env variables"
  exit 1
fi

echo "[$(date +"%m/%d/%y %T")] checking functions.sh"

# Creation of local variables
APPLICATION_NAME="${NUTSHELL_MODEL_SERVING_NAME}-${WORKER_ENV}"
MODEL_NAME="${NUTSHELL_MODEL_SERVING_NAME}"
MODEL_VERSION="${NUTSHELL_MODEL_VERSION}"

checkEnvVariables

## FUNCTIONS
function checkEnvVariables() {
    if [[ -z $WORKER_ENV ]]
    then 
        echo "WORKER env variable is not set !"
        exit 1
    elif [[ -z $NUTSHELL_MODEL_SERVING_NAME ]]
    then
        echo "NUTSHELL_MODEL_SERVING_NAME env variable is not set !"
        exit 1
    elif [[ -z $NUTSHELL_MODEL_VERSION ]]
    then
        echo "NUTSHELL_MODEL_VERSION env variable is not set !"
        exit 1
    elif [[ -z $NUTSHELL_MODEL_PATH ]]
    then
        echo "NUTSHELL_MODEL_PATH env variable is not set !"
        exit 1
    fi
}

function generateApplicationSpec() {
cat >./data.json <<EOF
{
    "metadata": {
        "name": "$APPLICATION_NAME",
        "namespace": "default"
    },
    "spec": {
        "source": {
            "repoURL": "https://charts.inarix.com",
            "targetRevision": "$MODEL_HELM_CHART_VERSION",
            "helm": {
                "parameters": [
                    {
                        "name": "app.datadog.apiKey",
                        "value": "$DD_API_KEY"
                    },
                    {
                        "name": "app.datadog.appKey",
                        "value": "$DD_APP_KEY"
                    },
                    {
                        "name": "app.workerEnv",
                        "value": "$WORKER_ENV"
                    },
                    {
                        "name": "credentials.api.password",
                        "value": "$INARIX_PASSWORD"
                    },
                    {
                        "name": "credentials.api.username",
                        "value": "$INARIX_USERNAME"
                    },
                    {
                        "name": "credentials.aws.accessKey",
                        "value": "$AWS_ACCESS_KEY_ID"
                    },
                    {
                        "name": "credentials.aws.secretKey",
                        "value": "$AWS_SECRET_ACCESS_KEY"
                    },
                    {
                        "name": "image.imageName",
                        "value": "$MODEL_NAME"
                    },
                    {
                        "name": "image.version",
                        "value": "$MODEL_VERSION"
                    },
                    {
                        "name": "model.modelName",
                        "value": "$NUTSHELL_MODEL_SERVING_NAME"
                    },
                    {
                        "name": "model.nutshellName",
                        "value": "$NUTSHELL_MODEL_SERVING_NAME"
                    },
                    {
                        "name":"nodeSelector.name",
                        "value": "serving-$WORKER_ENV"
                    },
                    {
                        "name": "model.path",
                        "value": "$NUTSHELL_MODEL_PATH"
                    }
                ]
            },
            "chart": "inarix-serving"
        },
        "destination": {
            "server": "https://34.91.136.161",
            "namespace": "$WORKER_ENV"
        },
        "project": "model-serving",
        "syncPolicy": {}
    }
}
EOF
}

function syncApplicationSpec() {
    curl -L -X POST "${ARGOCD_ENTRYPOINT}/${APPLICATION_NAME}/sync" \
    -s \
    -H 'Content-Type: application/json' \
    -H "Authorization: Bearer ${ARGOCD_TOKEN}" 
}

function createApplicationSpec() {
    CURL_RESPONSE=$(curl -L -X POST "${ARGOCD_ENTRYPOINT}" \
     -s \
     -H 'Content-Type: application/json' \
     -H "Authorization: Bearer ${ARGOCD_TOKEN}" \
     -d @./data.json)
     echo $CURL_RESPONSE
}

function hasError() {
    if [[ -z $1 ]]
    then
        echo "Usage: hasError CURL_RESPONSE"
        exit 1
    fi
    ! [ ! -z $1 ]
}
echo "[$(date +"%m/%d/%y %T")] Deploying model $MODEL_VERSION"
echo "[$(date +"%m/%d/%y %T")] Importing every .env variable from model"


THREAD_TS=$(./sendSlackMessage.sh "MODEL_DEPLOYMENT" "Deploy model $NUTSHELL_MODEL_SERVING_NAME with version $MODEL_VERSION")

# Script starts now !
if hasError $(createApplicationSpec)
then
    echo "[$(date +"%m/%d/%y %T")] Creation of application specs succeed!"
    ./sendSlackMessage.sh "Application has been created and will now be synced on ${ARGOCD_ENTRYPOINT}/${APPLICATION_NAME}" $THREAD_TS
    
    if hasError $(syncApplicationSpec)
    then
        echo "[$(date +"%m/%d/%y %T")] An error occured during applicaion sync!"
        exit 1
    fi
    echo "[$(date +"%m/%d/%y %T")] Application sync succeed!"
    ./sendSlackMessage.sh "Model deployment of ${NUTSHELL_MODEL_SERVING_NAME} version:${MODEL_VERSION}" $THREAD_TS

    echo "::set-output name=modelVersion::'$MODEL_VERSION'"
    echo "::set-output name=modelName::'$MODEL_NAME'"
    echo "[$(date +"%m/%d/%y %T")] Removing generated data.json!"
    rm data.json
else
    echo "[$(date +"%m/%d/%y %T")] An error occured when creating application specs!"
    ./sendSlackMessage.sh "Application had a error during deployment"
    rm data.json
    exit 1
fi
