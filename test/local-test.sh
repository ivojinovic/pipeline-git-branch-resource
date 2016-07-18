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
ACTIVE_DEV_BRANCHES=$(git branch -r --no-merged | sed "s/origin\///" | xargs)

# TODO: Fix this
ACTIVE_DEV_BRANCHES=test-1

ORIGINAL_PIPELINE_NAME=jarvis_api_test

#-----------------
# This is "check" code, not "in"!!!
# We now have all the active branches from git
# We need to check that against the branches we currently have in this pipeline
# Here is the list of all groups in the pipeline
fly -t $CONCOURSE_TARGET get-pipeline -p $ORIGINAL_PIPELINE_NAME > current_pipeline.yaml
CURRENT_PIPELINE_GROUPS=$(spruce json current_pipeline.yaml | jq '.["groups"][].name' | xargs)
EXPECTED_PIPELINE_GROUPS="master unmerged-branches-template unmerged-branches-updater $ACTIVE_DEV_BRANCHES"
if [ "$CURRENT_PIPELINE_GROUPS" != "$EXPECTED_PIPELINE_GROUPS" ] ; then
    TIMESTAMP=$(date +%s)
fi
#-----------------
#exit 0


# Create a pipeline for them
cd $this_directory

TEMPLATE_TOKEN=unmerged-branches-template
TEMPLATE_GROUP=unmerged-branches-template
LOCAL_OR_CONCOURSE=LOCAL

./../assets/set_dev_branches_pipeline.sh \
    $CONCOURSE_TARGET \
    $ORIGINAL_PIPELINE_NAME \
    $LOCAL_OR_CONCOURSE \
    $TEMPLATE_TOKEN \
    $TEMPLATE_GROUP \
    $ACTIVE_DEV_BRANCHES
