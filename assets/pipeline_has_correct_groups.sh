#!/usr/bin/env bash

STATIC_GROUPS=$1
APP_DEV_BRANCHES=$2
OUTPUT_FILE=$3

echo "true" > $OUTPUT_FILE

CONCOURSE_TARGET=savannah
echo -e "$PARAM_CONCOURSE_USERNAME\n$PARAM_CONCOURSE_PASSWORD\n" | fly -t $CONCOURSE_TARGET login --concourse-url $PARAM_CONCOURSE_URL

fly -t $CONCOURSE_TARGET get-pipeline -p $PARAM_APP_PIPELINE_NAME > current_pipeline.yaml
CURRENT_PIPELINE_GROUPS=$(spruce json current_pipeline.yaml | jq '.["groups"][].name' | xargs)

EXPECTED_PIPELINE_GROUPS="$STATIC_GROUPS"
if [ -n "${APP_DEV_BRANCHES}" ]; then
    EXPECTED_PIPELINE_GROUPS="$STATIC_GROUPS $APP_DEV_BRANCHES"
fi

# Debug code
curl -X POST -d "CURRENT_PIPELINE_GROUPS=$CURRENT_PIPELINE_GROUPS&EXPECTED_PIPELINE_GROUPS=$EXPECTED_PIPELINE_GROUPS" http://requestb.in/19bcmhc1

if [ "$CURRENT_PIPELINE_GROUPS" != "$EXPECTED_PIPELINE_GROUPS" ] ; then
    echo "false" > $OUTPUT_FILE
fi