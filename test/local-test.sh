#!/usr/bin/env bash

CONCOURSE_TARGET=savannah
APP_NAME=hotspot
APP_GIT_URI=ssh://git@stash.zipcar.com:7999/lm/hotspot.git

this_directory=`pwd`

# Get the list of active dev branches
cd ~/concourse/git/test/
if [ -d "$APP_NAME" ]; then
    rm -Rf $APP_NAME
fi
git clone $APP_GIT_URI
cd $APP_NAME

export PARAM_APP_PIPELINE_NAME=hotspot_new
export PARAM_APP_MASTER_GROUP=master
export PARAM_APP_UPDATER_GROUP=updater

export PARAM_APP_DEV_TEMPLATE_GROUP=dev-template
export PARAM_APP_DEV_ALL_BRANCHES_GROUP=dev
export PARAM_APP_DEV_BRANCH_FILTER='sed /hotfix-/d'

export PARAM_APP_HOT_TEMPLATE_GROUP=hot-template
export PARAM_APP_HOT_BRANCH_FILTER='sed /hotfix-/!d'
export PARAM_APP_SLAHES_OK_FLAG=-slashes-ok

if [ -n "${PARAM_APP_DEV_BRANCH_FILTER}" ]; then
    LOC_APP_DEV_BRANCHES=$(git branch -r --no-merged | sed "s/origin\///" | $PARAM_APP_DEV_BRANCH_FILTER | xargs)
else
    LOC_APP_DEV_BRANCHES=$(git branch -r --no-merged | sed "s/origin\///" | xargs)
fi
if [ -n "${PARAM_APP_HOT_BRANCH_FILTER}" ]; then
    LOC_APP_HOT_BRANCHES=$(git branch -r --no-merged | sed "s/origin\///" | $PARAM_APP_HOT_BRANCH_FILTER | xargs)
else
    LOC_APP_HOT_BRANCHES=$(git branch -r --no-merged | sed "s/origin\///" | xargs)
fi

# Create a pipeline for them
cd $this_directory

./../assets/set_dev_branches_pipeline.sh $CONCOURSE_TARGET LOCAL "$LOC_APP_DEV_BRANCHES" "$LOC_APP_HOT_BRANCHES"
