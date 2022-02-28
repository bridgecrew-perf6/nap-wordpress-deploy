#!/bin/bash

CI_COMMIT_BRANCH=$1

APP="wp"
SETTING_FILE="setting-${CI_COMMIT_BRANCH}.cfg"
CFG_FILE=setting.cfg

cp ${SETTING_FILE} ${CFG_FILE}

set -o allexport; source "${SETTING_FILE}"; set +o allexport

tar -cvf ${APP}.tar entry.bash docker-compose.yaml ${CFG_FILE} configs
gzip ${APP}.tar

echo "Copying file [${APP}.tar.gz] to [${GCS_BUCKET}] ..."
gsutil cp ${APP}.tar.gz ${GCS_BUCKET}
