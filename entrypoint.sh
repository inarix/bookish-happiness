echo "[${date}] sourcing functions.sh"
source functions.sh
if [[ $? == 1 ]]
then
    echo "Failed sourcing functions.sh"
    exit 1
fi

echo "[${date}] Deploying model $MODEL_VERSION"
echo "[${date}] Importing every .env variable from model"
export $(grep -v '^#' .env | xargs)
if [[ $? == 1 ]]
then
    echo "[${date}] An error occured during import .env variables"
    exit 1
fi

# Creation of local variables
APPLICATION_NAME="${NUTSHELL_MODEL_SERVING_NAME}-${WORKER_ENV}"
MODEL_NAME="${NUTSHELL_MODEL_SERVING_NAME}"
MODEL_VERSION="${NUTSHELL_MODEL_VERSION}"
THREAD_TS=$(./.sendSlackMessage.sh "Deploy model $NUTSHELL_MODEL_SERVING_NAME with version $MODEL_VERSION")

# Script starts now !
if hasError $(createApplicationSpec)
then
    echo "[${date}] Creation of application specs succeed!"
    ./.sendSlackMessage.sh "Application has been created and will now be synced on ${ARGOCD_ENTRYPOINT}/${APPLICATION_NAME}" $THREAD_TS
    
    if hasError $(syncApplicationSpec)
    then
        echo "[${date}] An error occured during applicaion sync!"
        exit 1
    fi
    echo "[${date}] Application sync succeed!"
    ./.sendSlackMessage.sh "Model deployment of ${NUTSHELL_MODEL_SERVING_NAME} version:${MODEL_VERSION}" $THREAD_TS

    echo "::set-output name=modelVersion::'$MODEL_VERSION'"
    echo "::set-output name=modelName::'$MODEL_NAME'"
    echo "[${date}] Removing generated data.json!"
    rm data.json
else
    echo "[${date}] An error occured when creating application specs!"
    ./.sendSlackMessage.sh "Application had a error during deployment"
    rm data.json
    exit 1
fi
