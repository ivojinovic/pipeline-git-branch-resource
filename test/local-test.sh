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

# Create a pipeline for them
cd $this_directory

ORIGINAL_PIPELINE_NAME=jarvis_api_test
NEW_PIPELINE_SUFFIX=_dev
TEMPLATE_TOKEN=branches-template
TEMPLATE_GROUP=template-for_dev
PROMPT_TO_FLY=PROMPT

./../assets/set_dev_branches_pipeline.sh \
    $CONCOURSE_TARGET \
    $ORIGINAL_PIPELINE_NAME \
    $NEW_PIPELINE_SUFFIX \
    $PROMPT_TO_FLY \
    $TEMPLATE_TOKEN \
    $TEMPLATE_GROUP \
    $ACTIVE_DEV_BRANCHES
