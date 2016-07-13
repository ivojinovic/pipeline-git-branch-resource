#!/usr/bin/env bash

set -e

CONCOURSE_TARGET=$1
ORIGINAL_PIPELINE_NAME=$2

#####
# Get the original pipeline
#####
fly -t $CONCOURSE_TARGET get-pipeline -p $ORIGINAL_PIPELINE_NAME > original_pipeline.yaml

#####
# Remove all jobs from it, except the the DEVBRANCH jobs, thus creating "DEVBRANCH jobs only" pipeline
#####
spruce json original_pipeline.yaml | \
    jq '{"jobs": [.["jobs"][] | select(.name | contains("DEVBRANCH"))], "resource_types": .["resource_types"], "resources": .["resources"]}' | \
    json2yaml > DEVBRANCH_jobs_pipeline.yaml

#####
# Add the DEVBRANCH group to that
#####
spruce json original_pipeline.yaml | \
    jq '{"groups": [.["groups"][] | select(.name | contains("dev"))]}' | \
    json2yaml > dev_groups.yaml
sed 's~dev~DEVBRANCH~g' dev_groups.yaml > DEVBRANCH_groups.yaml
spruce merge DEVBRANCH_jobs_pipeline.yaml DEVBRANCH_groups.yaml > DEVBRANCH_pipeline.yaml


#####
# Now, turn all things DEVBRANCH into actual branches, as passed in
#####
VAR_COUNT=0
FIRST_BRANCH=true
for VAR in "$@"
do
    ####
    # Skip the first two vars to get to the branch name vars
    ####
    VAR_COUNT=`expr $VAR_COUNT + 1`
    if [ "$VAR_COUNT" -lt "3" ] ; then
        continue
    fi

    ####
    # For each branch name, get the DEVBRANCH pipeline, and then replace the word "DEVBRANCH" with that branch name
    ####
    BRANCH_NAME_UNSLASHED=`echo $VAR | sed -e "s/\//-/g"`
    sed 's~DEVBRANCH~'"$BRANCH_NAME_UNSLASHED"'~g' DEVBRANCH_pipeline.yaml > $branch_name_pipeline.yaml
    printf "\n" >> $branch_name_pipeline.yaml

    ####
    # now add the brnach pipeline to the pipeline of all branches
    ####
    if [ $FIRST_BRANCH == true ] ; then
        echo "Starting with $BRANCH_NAME_UNSLASHED"
        spruce merge $branch_name_pipeline.yaml > branches_pipeline.yaml
        FIRST_BRANCH=false
    else
        echo "Adding Branch $BRANCH_NAME_UNSLASHED"
        spruce merge branches_pipeline.yaml $branch_name_pipeline.yaml >> branches_pipeline.yaml
    fi

    # cleanup
    rm $branch_name_pipeline.yaml
done

# cleanup
rm original_pipeline.yaml
rm DEVBRANCH_pipeline.yaml
rm DEVBRANCH_jobs_pipeline.yaml
rm DEVBRANCH_groups.yaml
rm dev_groups.yaml

#echo y |
fly -t $CONCOURSE_TARGET set-pipeline -p "$ORIGINAL_PIPELINE_NAME"_dev -c branches_pipeline.yaml

rm branches_pipeline.yaml
