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

echo "[$(date +"%m/%d/%y %T")] sourcing functions.sh"
source ./functions.sh
if [[ $? == 1 ]]
then
    echo "Failed sourcing functions.sh"
    exit 1
fi

echo "[$(date +"%m/%d/%y %T")] Deploying model $MODEL_VERSION"
echo "[$(date +"%m/%d/%y %T")] Importing every .env variable from model"


# Creation of local variables
APPLICATION_NAME="${NUTSHELL_MODEL_SERVING_NAME}-${WORKER_ENV}"
MODEL_NAME="${NUTSHELL_MODEL_SERVING_NAME}"
MODEL_VERSION="${NUTSHELL_MODEL_VERSION}"
THREAD_TS=$(./sendSlackMessage.sh "MODEL_DEPLOYMENT" "Deploy model $NUTSHELL_MODEL_SERVING_NAME with version $MODEL_VERSION")

# Script starts now !
if hasError $(createApplicationSpec)
then
    echo "[$(date +"%m/%d/%y %T")] Creation of application specs succeed!"
    ./.sendSlackMessage.sh "Application has been created and will now be synced on ${ARGOCD_ENTRYPOINT}/${APPLICATION_NAME}" $THREAD_TS
    
    if hasError $(syncApplicationSpec)
    then
        echo "[$(date +"%m/%d/%y %T")] An error occured during applicaion sync!"
        exit 1
    fi
    echo "[$(date +"%m/%d/%y %T")] Application sync succeed!"
    ./.sendSlackMessage.sh "Model deployment of ${NUTSHELL_MODEL_SERVING_NAME} version:${MODEL_VERSION}" $THREAD_TS

    echo "::set-output name=modelVersion::'$MODEL_VERSION'"
    echo "::set-output name=modelName::'$MODEL_NAME'"
    echo "[$(date +"%m/%d/%y %T")] Removing generated data.json!"
    rm data.json
else
    echo "[$(date +"%m/%d/%y %T")] An error occured when creating application specs!"
    ./.sendSlackMessage.sh "Application had a error during deployment"
    rm data.json
    exit 1
fi
