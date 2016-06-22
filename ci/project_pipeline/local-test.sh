#!/usr/bin/env bash

export GIT_KEY=`cat git_key`

export PROJECT_GIT_URI=ssh://git@stash.zipcar.com:7999/cheet/pipeline-test-app.git
export PROJECT_DOCKER_REPO=docker.zipcar.io/app/pipeline_test_app
export PROJECT_NAME=pipeline_test_app
export PIPELINE_NAME=pta_branches

new_branch_list=$(git ls-remote $PROJECT_GIT_URI | cut -d$'\t' -f2 | sed '/master/d' | sed '/HEAD/d' | sed "s/^refs\/heads\///" | xargs)

./build.sh pipeline_start.yaml pipeline_resources.yaml pipeline_jobs.yaml merge.yaml $new_branch_list
spruce merge merge.yaml > deploy.yaml
sed -i.bak 's/|-/|/g' deploy.yaml

# clean up
#rm deploy.yaml.bak
#rm merge.yaml

echo $PIPELINE_NAME

echo y | fly -t savannah set-pipeline -p $PIPELINE_NAME -c deploy.yaml
