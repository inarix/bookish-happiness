#!/bin/bash
# File              : .github_action_deploy.sh
# Author            : Alexandre Saison <alexandre.saison@inarix.com>
# Date              : 27.01.2021
# Last Modified Date: 08.02.2021
# Last Modified By  : Alexandre Saison <alexandre.saison@inarix.com>

export $(grep -v '^#' .env | xargs)

APPLICATION_NAME="${NUTSHELL_MODEL_SERVING_NAME}-${WORKER_ENV}"
MODEL_NAME="${NUTSHELL_MODEL_SERVING_NAME}"
MODEL_VERSION="${NUTSHELL_MODEL_VERSION}"
THREAD_TS=`./.sendSlackMessage.sh "Deploy model $NUTSHELL_MODEL_SERVING_NAME with version $MODEL_VERSION"`
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
