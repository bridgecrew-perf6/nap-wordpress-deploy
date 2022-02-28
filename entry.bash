#!/bin/bash

DATA_DIR=$(pwd)

INSTANCE=$(hostname)
ENV_FILE=.env
CFG_FILE=setting.cfg # From tar.gz package
CONTAINERS_LOG_DIR=/var/lib/docker/containers

set -o allexport; source "${CFG_FILE}"; set +o allexport

sudo cat << EOF > ${ENV_FILE}
DATA_DIR=${DATA_DIR}
INSTANCE=${INSTANCE}
GROUP=wordpress
CONTAINERS_LOG_DIR=${CONTAINERS_LOG_DIR}
EOF

load_secret_secret () {
    # Get secret from Secret Manager then create env variable and append them to .env file
    SECRET_NAME=$1

    gcloud secrets versions access latest --secret="${SECRET_NAME}" > ${SECRET_NAME}.txt
    echo "" >> ${SECRET_NAME}.txt #Added new line
    
    while read LINE; do
        TXT=$(echo ${LINE} | tr -d '[:space:]') #trim

        KEY=$(echo ${TXT} | perl -ne 'if (/(.+)=(.+)/) { print $1 }')
        VAL=$(echo ${TXT} | perl -ne 'if (/(.+)=(.+)/) { print $2 }')

        echo "${KEY}=${VAL}" >> .env
        eval "export ${KEY}=${VAL}"
    done <${SECRET_NAME}.txt
    
    rm ${SECRET_NAME}.txt
}

shutdown_if_error () {    
    EXITED_COUNT=$(docker ps -a | grep 'Exited' | wc -l)

    if [ $EXITED_COUNT -gt 0 ]; then
        sudo docker-compose down
    fi
}

load_secret_secret "${SECRET_MANAGER_NAME}"

echo "" >> .env
sudo cat ${CFG_FILE} >> .env

sudo mkdir -p ${DATA_DIR}/wp

# This case might happen from GCE shutdown for some reasons & containers remain in the "Existed" state!!!!
shutdown_if_error
sudo docker-compose up -d
