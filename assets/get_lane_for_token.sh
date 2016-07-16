#!/usr/bin/env bash

set -e

INPUT_FILE_NAME=$1
JOBS_NAMES_KEY=$2
OUTPUT_FILE_NAME=$3

#####
# Create a file with all the jobs, resource types, and resources for jobs that have this key in their name
#####
spruce json $INPUT_FILE_NAME | \
    jq --arg JOBS_NAMES_KEY $JOBS_NAMES_KEY \
    '{
        "jobs":
                [
                    .["jobs"][] | select(.name | contains($JOBS_NAMES_KEY))
                ],
        "resource_types":
                .["resource_types"],
        "resources":
                .["resources"]}' | \
    json2yaml > $OUTPUT_FILE_NAME
