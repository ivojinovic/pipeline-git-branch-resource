#!/usr/bin/env bash

PAYLOAD=$1
STATIC_GROUPS=$2
ACTIVE_DEV_BRANCHES=$3
OUTPUT_FILE=$4

echo "true" > $OUTPUT_FILE

CONCOURSE_TARGET=savannah
/opt/resource/log_in_to_concourse.sh $CONCOURSE_TARGET $PAYLOAD

# TODO: Change 'project' to 'app'
ORIGINAL_PIPELINE_NAME=$(jq -r '.source.project_pipeline // ""' < $PAYLOAD)
fly -t $CONCOURSE_TARGET get-pipeline -p $ORIGINAL_PIPELINE_NAME > current_pipeline.yaml
CURRENT_PIPELINE_GROUPS=$(spruce json current_pipeline.yaml | jq '.["groups"][].name' | xargs)

EXPECTED_PIPELINE_GROUPS="$STATIC_GROUPS $ACTIVE_DEV_BRANCHES"
EXPECTED_PIPELINE_GROUPS_TRIMMED=$(echo "$EXPECTED_PIPELINE_GROUPS" | sed 's/ //g')

# Debug code
curl -X POST -d "CURRENT_PIPELINE_GROUPS=$CURRENT_PIPELINE_GROUPS&EXPECTED_PIPELINE_GROUPS_TRIMMED=$EXPECTED_PIPELINE_GROUPS_TRIMMED" http://requestb.in/19bcmhc1

if [ "$CURRENT_PIPELINE_GROUPS" != "$EXPECTED_PIPELINE_GROUPS_TRIMMED" ] ; then
    echo "false" > $OUTPUT_FILE
fi