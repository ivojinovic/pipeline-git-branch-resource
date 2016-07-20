#!/usr/bin/env bash

CONCOURSE_TARGET=savannah
APP_NAME=jarvis_api
APP_GIT_URI=ssh://git@stash.zipcar.com:7999/cheet/jarvis_api.git

this_directory=`pwd`

# Get the list of active dev branches
cd ~/concourse/git/test/
if [ -d "$APP_NAME" ]; then
    rm -Rf $APP_NAME
fi
git clone $APP_GIT_URI
cd $APP_NAME

export PARAM_APP_PIPELINE_NAME=jarvis_api_test
export PARAM_APP_MASTER_GROUP=master
export PARAM_APP_DEV_TEMPLATE_GROUP=dev-template
export PARAM_APP_DEV_UPDATER_GROUP=dev-updater
export PARAM_APP_DEV_ALL_BRANCHES_GROUP=dev-all
export PARAM_APP_DEV_BRANCH_FILTER='sed /test-/!d'

if [ -n "${PARAM_APP_DEV_BRANCH_FILTER}" ]; then
    LOC_APP_DEV_BRANCHES=$(git branch -r --no-merged | sed "s/origin\///" | $PARAM_APP_DEV_BRANCH_FILTER | xargs)
else
    LOC_APP_DEV_BRANCHES=$(git branch -r --no-merged | sed "s/origin\///" | xargs)
fi

# Create a pipeline for them
cd $this_directory

./../assets/set_dev_branches_pipeline.sh $CONCOURSE_TARGET LOCAL $LOC_APP_DEV_BRANCHES
