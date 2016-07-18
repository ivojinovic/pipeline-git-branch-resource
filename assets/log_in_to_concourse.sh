#!/usr/bin/env bash

CONCOURSE_TARGET=$1
PAYLOAD=$2

CONCOURSE_USERNAME=$(jq -r '.source.concourse_username // ""' < $PAYLOAD)
CONCOURSE_PASSWORD=$(jq -r '.source.concourse_password // ""' < $PAYLOAD)
CONCOURSE_URL=$(jq -r '.source.concourse_url // ""' < $PAYLOAD)

echo -e "$CONCOURSE_USERNAME\n$CONCOURSE_PASSWORD\n" | fly -t $CONCOURSE_TARGET login --concourse-url $CONCOURSE_URL
