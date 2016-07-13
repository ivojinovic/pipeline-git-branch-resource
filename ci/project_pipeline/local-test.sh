#!/usr/bin/env bash

export GIT_KEY=`cat git_key`

export PROJECT_GIT_URI=ssh://git@stash.zipcar.com:7999/cheet/pipeline-test-app.git
export PROJECT_DOCKER_REPO=docker.zipcar.io/app/pipeline_test_app
export PROJECT_NAME=jarvis_api
export PIPELINE_NAME=jarvis_api_branches

this_dir=`pwd`

cd ~/concourse/git/test/
DIRECTORY=jarvis_api
if [ -d "$DIRECTORY" ]; then
    rm -Rf jarvis_api
fi
git clone ssh://git@stash.zipcar.com:7999/cheet/jarvis_api.git
cd jarvis_api

new_branch_list=$(git branch -r --no-merged | sed '/logger/d' | sed '/test-data/d' | sed "s/origin\///" | xargs)

#substring=master
#if test "${new_branch_list#*$substring}" == "$new_branch_list"
#then
#    echo "add master"
#    new_branch_list=$new_branch_list" master"
#fi

echo $new_branch_list

cd $this_dir

#exit 0

# clean up
#rm deploy.yaml
#rm deploy.yaml.bak
#rm merge.yaml

echo $new_branch_list

./build.sh savannah jarvis_api_ddb $new_branch_list
#spruce merge merge.yaml > deploy.yaml
#sed -i.bak 's/|-/|/g' deploy.yaml

echo $PIPELINE_NAME

#echo y | fly -t savannah set-pipeline -p $PIPELINE_NAME -c deploy.yaml
