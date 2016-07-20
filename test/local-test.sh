#!/usr/bin/env bash

CONCOURSE_TARGET=savannah
PROJECT_NAME=jarvis_api
PROJECT_GIT_URI=ssh://git@stash.zipcar.com:7999/cheet/jarvis_api.git

this_directory=`pwd`

# Get the list of active dev branches
cd ~/concourse/git/test/
if [ -d "$PROJECT_NAME" ]; then
    rm -Rf $PROJECT_NAME
fi
git clone $PROJECT_GIT_URI
cd $PROJECT_NAME

export PARAM_APP_PIPELINE_NAME=jarvis_api_test
export PARAM_APP_MASTER_TOKEN=master
export PARAM_APP_DEV_BRANCHES_TEMPLATE_TOKEN=unmerged-branches-template
export PARAM_APP_UPDATER_GROUP_NAME=unmerged-branches-updater
export PARAM_APP_ALL_DEV_BRANCHES_GROUP_NAME=unmerged-branches
export PARAM_APP_BRANCH_FILTER_PIPE='sed /test-/!d'

LOC_APP_DEV_BRANCHES=$(git branch -r --no-merged | sed "s/origin\///" | $PARAM_APP_BRANCH_FILTER_PIPE | xargs)

# Create a pipeline for them
cd $this_directory

./../assets/set_dev_branches_pipeline.sh $CONCOURSE_TARGET LOCAL $LOC_APP_DEV_BRANCHES
