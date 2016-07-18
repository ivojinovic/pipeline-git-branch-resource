#!/usr/bin/env bash

PAYLOAD=$1
ACTIVE_DEV_BRANCHES=$2

CONCOURSE_TARGET=savannah
/opt/resource/log_in_to_concourse.sh $CONCOURSE_TARGET $PAYLOAD

ORIGINAL_PIPELINE_NAME=$(jq -r '.source.project_pipeline // ""' < $PAYLOAD)
fly -t $CONCOURSE_TARGET get-pipeline -p $ORIGINAL_PIPELINE_NAME > current_pipeline.yaml

CURRENT_PIPELINE_GROUPS=$(spruce json current_pipeline.yaml | jq '.["groups"][].name' | xargs)
EXPECTED_PIPELINE_GROUPS="master unmerged-branches-template unmerged-branches-updater unmerged-branches $ACTIVE_DEV_BRANCHES"

curl -X POST -d "CURRENT_PIPELINE_GROUPS=$CURRENT_PIPELINE_GROUPS&EXPECTED_PIPELINE_GROUPS=$EXPECTED_PIPELINE_GROUPS" http://requestb.in/11iyz2d1

if [ "$CURRENT_PIPELINE_GROUPS" == "$EXPECTED_PIPELINE_GROUPS" ] ; then
    echo "true" > /opt/resource/pipeline_has_correct_groups.out
else
    echo "false" > /opt/resource/pipeline_has_correct_groups.out
fi