#!/usr/bin/env bash

export PROJECT_NAME=jarvis_api

this_directory=`pwd`

cd ~/concourse/git/test/
if [ -d "$PROJECT_NAME" ]; then
    rm -Rf $PROJECT_NAME
fi
git clone ssh://git@stash.zipcar.com:7999/cheet/$PROJECT_NAME.git
cd $PROJECT_NAME

ACTIVE_BRANCHES=$(git branch -r --no-merged | sed '/logger/d' | sed '/test-data/d' | sed "s/origin\///" | xargs)

cd $this_directory
./build.sh savannah jarvis_api_ddb $ACTIVE_BRANCHES
