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
# TODO: Test code: REMOVE! | sed '/test-/!d'
ACTIVE_DEV_BRANCHES=$(git branch -r --no-merged | sed "s/origin\///" | sed '/test-/!d' | xargs)

export PARAM_APP_PIPELINE_NAME=jarvis_api_test
export PARAM_APP_DEV_BRANCHES_TEMPLATE_TOKEN=unmerged-branches-template
export PARAM_APP_UPDATER_TOKEN=update_unmerged_branches
export PARAM_APP_UPDATER_GROUP_NAME=unmerged-branches-updater
export PARAM_APP_UPDATER_GROUP_NAME_NEW=unmerged-branches

# Create a pipeline for them
cd $this_directory

./../assets/set_dev_branches_pipeline.sh $CONCOURSE_TARGET LOCAL $ACTIVE_DEV_BRANCHES
