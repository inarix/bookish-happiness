#!/bin/bash
# File              : functions.sh
# Author            : Alexandre Saison <alexandre.saison@inarix.com>
# Date              : 19.05.2021
# Last Modified Date: 19.05.2021
# Last Modified By  : Alexandre Saison <alexandre.saison@inarix.com>

function fetchEnvVariables() {
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
    elif [[ -z $MODEL_VERSION ]]
    then
        echo "MODEL_VERSION env variable is not set !"
        exit 1
    elif [[ -z $MODEL_NAME ]]
    then
        echo "MODEL_NAME env variable is not set !"
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
