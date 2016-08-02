#!/usr/bin/env bash

CONCOURSE_TARGET=savannah
APP_NAME=grails
#APP_GIT_URI=ssh://git@stash.zipcar.com:7999/lm/grails.git
#export CONST_APP_GIT_DIR=~/concourse/git/test/grails
export PARAM_APP_PIPELINE_NAME=grails
export PARAM_BRANCHES_FROM_DAYS_AGO=10

export PARAM_CONCOURSE_URL=http://192.168.72.209/
export PARAM_CONCOURSE_USERNAME=savannah
export PARAM_CONCOURSE_PASSWORD=$1

source branches_common.sh

echo -e "$PARAM_CONCOURSE_USERNAME\n$PARAM_CONCOURSE_PASSWORD\n" | fly -t $CONCOURSE_TARGET login --concourse-url $PARAM_CONCOURSE_URL

#this_directory=`pwd`
#
## Get the list of active dev branches
#cd ~/concourse/git/test
#if [ -d "$APP_NAME" ]; then
#    pushd .
#    cd $APP_NAME
#    git fetch --prune
#    git reset --hard FETCH_HEAD
#    popd
#else
#    git clone $APP_GIT_URI
#fi
#cd $APP_NAME

export PARAM_APP_MASTER_GROUP=master
export PARAM_APP_UPDATER_GROUP=updater

export PARAM_APP_DEV_TEMPLATE_GROUP=dev-template
export PARAM_APP_DEV_ALL_BRANCHES_GROUP=dev-all
export PARAM_APP_DEV_BRANCH_FILTER='sed /hotfix-/d'

export PARAM_APP_HOT_TEMPLATE_GROUP=hot-template
export PARAM_APP_HOT_BRANCH_FILTER='sed /hotfix-/!d'
export PARAM_APP_SLAHES_OK_FLAG=-slashes-ok

#LOC_APP_DEV_BRANCHES_FILE=app_dev_branches.out
#get_branch_list "$PARAM_APP_DEV_BRANCH_FILTER" $LOC_APP_DEV_BRANCHES_FILE
#LOC_APP_DEV_BRANCHES=`cat $LOC_APP_DEV_BRANCHES_FILE`
#
#LOC_APP_HOT_BRANCHES_FILE=app_hot_branches.out
#get_branch_list "$PARAM_APP_HOT_BRANCH_FILTER" $LOC_APP_HOT_BRANCHES_FILE
#LOC_APP_HOT_BRANCHES=`cat $LOC_APP_HOT_BRANCHES_FILE`

# Create a pipeline for them
#cd $this_directory

LOC_APP_DEV_BRANCHES="core-243-delete-car-group core-38-lists-0-items dev feature/core-243-delete-car-group feature/core306-su-user-image feature/filter-community-JUNGLE-897 fix/end-ride-odometer_CORE-280 fix/pretty-print-json_CORE-238 fix/remove-hotspot-contact_CORE-157 fix/rename-user-to-driver fix/ride-distance-zero_CORE-340 milestone-1-report_ZC-629 six-eight-extraction six-nine-extraction zc-501 zc-504 zc-506"

./set_dev_branches_pipeline.sh $CONCOURSE_TARGET DOCKER "$LOC_APP_DEV_BRANCHES" "$LOC_APP_HOT_BRANCHES"
