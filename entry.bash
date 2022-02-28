#!/bin/bash

DATA_DIR=$(pwd)

INSTANCE=$(hostname)
ENV_FILE=.env
CFG_FILE=setting.cfg # From tar.gz package
PROMETHEUS_CFG=${DATA_DIR}/configs/prometheus.yaml
CONTAINERS_LOG_DIR=/var/lib/docker/containers

TOKENS=(${INSTANCE//-/ }) # Split string
GROUP="${TOKENS[0]}"
REGION="${TOKENS[1]}-${TOKENS[2]}"
ZONE="${TOKENS[1]}-${TOKENS[2]}-${TOKENS[3]}"

sudo cat << EOF > ${ENV_FILE}
DATA_DIR=${DATA_DIR}
INSTANCE=${INSTANCE}
REGION=${REGION}
ZONE=${ZONE}
INSTANCE=${INSTANCE}
GROUP=${GROUP}
CONTAINERS_LOG_DIR=${CONTAINERS_LOG_DIR}
EOF

load_secret_secret () {
    # Get secret from Secret Manager then create env variable and append them to .env file
    SECRET_NAME=$1

    gcloud secrets versions access latest --secret="${SECRET_NAME}" | grep -v -E '{|}' > ${SECRET_NAME}.txt
    while read LINE; do
        TXT=$(echo ${LINE} | tr -d '[:space:]') #trim

        KEY=$(echo ${TXT} | perl -ne 'if (/\"(.+)\"\s*:\s*\"(.+)\"/) { print $1 }')
        VAL=$(echo ${TXT} | perl -ne 'if (/\"(.+)\"\s*:\s*\"(.+)\"/) { print $2 }')

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

load_secret_secret "cortex-basic-authen"
load_secret_secret "loki-basic-authen"


set -o allexport; source "${CFG_FILE}"; set +o allexport
sed -i "s#__CORTEX_DOMAIN__#${CORTEX_DOMAIN}#g" ${PROMETHEUS_CFG}
sed -i "s#__CORTEX_AUTH_USER__#${CORTEX_AUTH_USER}#g" ${PROMETHEUS_CFG}
sed -i "s#__CORTEX_AUTH_PASSWORD__#${CORTEX_AUTH_PASSWORD}#g" ${PROMETHEUS_CFG}

echo "" >> .env
sudo cat ${CFG_FILE} >> .env

sudo mkdir -p ${DATA_DIR}/nginx
sudo mkdir -p ${DATA_DIR}/prometheus
sudo mkdir -p ${DATA_DIR}/promtail

sudo cat << EOF > ${DATA_DIR}/nginx/index.html
<html>
    <h1>Instance [${INSTANCE}]</h1>
    <h1>Group [${GROUP}]</h1>
    <h1>Zone [${ZONE}]</h1>
    <h1>Region [${REGION}]</h1>
</html>
EOF

# This case might happen from GCE shutdown for some reasons & containers remain in the "Existed" state!!!!
shutdown_if_error

sudo docker-compose up -d
