#!/usr/bin/env bash

CONCOURSE_TARGET=savannah
APP_NAME=pipeline-test-app
APP_GIT_URI=ssh://git@stash.zipcar.com:7999/cheet/pipeline-test-app.git

source ./../assets/branches_common.sh

this_directory=`pwd`

# Get the list of active dev branches
export CONST_APP_GIT_DIR=~/concourse/git/test/pipeline-test-app
cd $CONST_APP_GIT_DIR
if [ -d "$APP_NAME" ]; then
    rm -Rf $APP_NAME
fi
git clone $APP_GIT_URI
cd $APP_NAME

export PARAM_APP_PIPELINE_NAME=pipeline-test-app
export PARAM_APP_MASTER_GROUP=master
export PARAM_APP_UPDATER_GROUP=updater

export PARAM_APP_DEV_TEMPLATE_GROUP=dev-template
export PARAM_APP_DEV_ALL_BRANCHES_GROUP=dev-all
export PARAM_APP_DEV_BRANCH_FILTER='sed /hotfix-/d'

export PARAM_APP_HOT_TEMPLATE_GROUP=hot-template
export PARAM_APP_HOT_BRANCH_FILTER='sed /hotfix-/!d'
export PARAM_APP_SLAHES_OK_FLAG=-slashes-ok

LOC_APP_DEV_BRANCHES_FILE=app_dev_branches.out
get_branch_list "$PARAM_APP_DEV_BRANCH_FILTER" $LOC_APP_DEV_BRANCHES_FILE
LOC_APP_DEV_BRANCHES=`cat $LOC_APP_DEV_BRANCHES_FILE`

LOC_APP_HOT_BRANCHES_FILE=app_hot_branches.out
get_branch_list "$PARAM_APP_HOT_BRANCH_FILTER" $LOC_APP_HOT_BRANCHES_FILE
LOC_APP_HOT_BRANCHES=`cat $LOC_APP_HOT_BRANCHES_FILE`

# Create a pipeline for them
cd $this_directory

./../assets/set_dev_branches_pipeline.sh $CONCOURSE_TARGET LOCAL "$LOC_APP_DEV_BRANCHES" "$LOC_APP_HOT_BRANCHES"
