#!/usr/bin/env bash

CONCOURSE_TARGET=$1

CONCOURSE_USERNAME=$(jq -r '.source.concourse_username // ""' < $payload)
CONCOURSE_PASSWORD=$(jq -r '.source.concourse_password // ""' < $payload)
CONCOURSE_URL=$(jq -r '.source.concourse_url // ""' < $payload)

echo -e "$CONCOURSE_USERNAME\n$CONCOURSE_PASSWORD\n" | fly -t $CONCOURSE_TARGET login --concourse-url $CONCOURSE_URL
