#!/usr/bin/env bash

export GIT_KEY=`cat git_key`

export PROJECT_GIT_URI=ssh://git@stash.zipcar.com:7999/cheet/pipeline-test-app.git
export PROJECT_DOCKER_REPO=docker.zipcar.io/app/pipeline_test_app
export PROJECT_NAME=jarvis_api
export PIPELINE_NAME=jarvis_api_branches

this_dir=`pwd`

cd ~/git/jarvis_api

new_branch_list=$(git branch -r --no-merged | sed "s/origin\///" | xargs)

cd $this_dir

# clean up
#rm deploy.yaml
#rm deploy.yaml.bak
#rm merge.yaml

echo $new_branch_list

./build.sh $new_branch_list
#spruce merge merge.yaml > deploy.yaml
#sed -i.bak 's/|-/|/g' deploy.yaml

echo $PIPELINE_NAME

#echo y | fly -t savannah set-pipeline -p $PIPELINE_NAME -c deploy.yaml
