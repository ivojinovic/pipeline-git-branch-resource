#!/usr/bin/env bash

PAYLOAD=$1
STATIC_GROUPS=$2
ACTIVE_DEV_BRANCHES=$3
OUTPUT_FILE=$4

CONCOURSE_TARGET=savannah
/opt/resource/log_in_to_concourse.sh $CONCOURSE_TARGET $PAYLOAD

# TODO: Change 'project' to 'app'
ORIGINAL_PIPELINE_NAME=$(jq -r '.source.project_pipeline // ""' < $PAYLOAD)
fly -t $CONCOURSE_TARGET get-pipeline -p $ORIGINAL_PIPELINE_NAME > current_pipeline.yaml
CURRENT_PIPELINE_GROUPS=$(spruce json current_pipeline.yaml | jq '.["groups"][].name' | xargs)

EXPECTED_PIPELINE_GROUPS="$STATIC_GROUPS $ACTIVE_DEV_BRANCHES"

# Debug code
#curl -X POST -d "CURRENT_PIPELINE_GROUPS=$CURRENT_PIPELINE_GROUPS&EXPECTED_PIPELINE_GROUPS=$EXPECTED_PIPELINE_GROUPS" http://requestb.in/11iyz2d1

if [ "$CURRENT_PIPELINE_GROUPS" == "$EXPECTED_PIPELINE_GROUPS" ] ; then
    echo "true" > $OUTPUT_FILE
else
    echo "false" > $OUTPUT_FILE
fi