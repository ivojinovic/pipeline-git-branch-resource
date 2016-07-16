#!/usr/bin/env bash

set -e

INPUT_FILE_NAME=$1
ORIGINAL_GROUP_NAME=$2
WORK_GROUP_NAME=$3
OUTPUT_FILE_NAME=$4

#####
# Get the group by name (as set in the original pipeline)
#####
spruce json $INPUT_FILE_NAME | \
    jq --arg ORIGINAL_GROUP_NAME $ORIGINAL_GROUP_NAME \
    '{
        "groups":
                [
                    .["groups"][] | select(.name | contains($ORIGINAL_GROUP_NAME))
                ]
     }' | \
    json2yaml > group_for_"$ORIGINAL_GROUP_NAME"_0.yaml
# _0 above is for the sace where ORIGINAL_GROUP_NAME and WORK_GROUP_NAME are the same

#####
# Change that name to the name that the new pipeline generating code can understand (the "template token" name)
#####
sed 's~name: "'"$ORIGINAL_GROUP_NAME"'"~name: "'"$WORK_GROUP_NAME"'"~g' group_for_"$ORIGINAL_GROUP_NAME"_0.yaml > $OUTPUT_FILE_NAME
