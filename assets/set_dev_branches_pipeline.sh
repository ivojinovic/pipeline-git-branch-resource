#!/usr/bin/env bash

set -e

CONCOURSE_TARGET=$1
ORIGINAL_PIPELINE_NAME=$2
NEW_PIPELINE_SUFFIX=$3

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
    json2yaml > dev_group.yaml
sed 's~dev~DEVBRANCH~g' dev_group.yaml > DEVBRANCH_groups_pipeline.yaml
spruce merge DEVBRANCH_jobs_pipeline.yaml DEVBRANCH_groups_pipeline.yaml > DEVBRANCH_pipeline.yaml

#####
# Create the main group template
#####
spruce json original_pipeline.yaml | \
    jq '{"groups": [.["groups"][] | select(.name | contains("dev"))]}' | \
    jq '{"jobs": .["groups"][0].jobs}' |
    json2yaml > dev_group_for_main.yaml
sed 's~dev~'"$ORIGINAL_PIPELINE_NAME"'~g' dev_group_for_main.yaml > DEVBRANCH_main_group.yaml


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
    if [ "$VAR_COUNT" -lt "4" ] ; then
        continue
    fi

    ####
    # For each branch name, get the DEVBRANCH pipeline, and then replace the word "DEVBRANCH" with that branch name
    ####
    BRANCH_NAME_UNSLASHED=`echo $VAR | sed -e "s/\//-/g"`
    sed 's~DEVBRANCH~'"$BRANCH_NAME_UNSLASHED"'~g' DEVBRANCH_pipeline.yaml > branch_name_pipeline.yaml
    printf "\n" >> branch_name_pipeline.yaml

    ####
    # For each branch name, get the DEVBRANCH main group pipeline, and then replace the word "DEVBRANCH" with that branch name
    ####
    sed 's~DEVBRANCH~'"$BRANCH_NAME_UNSLASHED"'~g' DEVBRANCH_main_group.yaml > branch_name_main_group.yaml
    printf "\n" >> branch_name_main_group.yaml

    ####
    # now add the branch pipeline to the pipeline of all branches
    ####
    if [ $FIRST_BRANCH == true ] ; then
        echo "Starting with $BRANCH_NAME_UNSLASHED"
        spruce merge branch_name_pipeline.yaml > branches_pipeline.yaml
        # do the same for the main group section
        spruce merge branch_name_main_group.yaml > branches_main_group.yaml
        FIRST_BRANCH=false
    else
        echo "Adding Branch $BRANCH_NAME_UNSLASHED"
        spruce merge branches_pipeline.yaml branch_name_pipeline.yaml >> branches_pipeline.yaml
        # do the same for the main group section
        spruce merge branches_main_group.yaml branch_name_main_group.yaml >> branches_main_group.yaml
    fi

    # cleanup
    rm branch_name_pipeline.yaml
done

####
# Add the main group to the pipeline
####
sed 's~jobs:~~g' branches_main_group.yaml > branches_main_group_jobs_array.yaml
printf "name: $ORIGINAL_PIPELINE_NAME\n" > branches_main_group_section.yaml
printf "jobs:\n" >> branches_main_group_section.yaml
cat branches_main_group_jobs_array.yaml >> branches_main_group_section.yaml
spruce json branches_main_group_section.yaml | jq '{"groups": [.]}' | json2yaml > branches_main_group_pipeline.yaml

spruce merge branches_main_group_pipeline.yaml branches_pipeline.yaml  > branches_pipeline_final.yaml

# cleanup
rm original_pipeline.yaml
rm DEVBRANCH_pipeline.yaml
rm DEVBRANCH_main_group.yaml
rm DEVBRANCH_jobs_pipeline.yaml
rm DEVBRANCH_groups_pipeline.yaml
rm dev_group.yaml
rm dev_group_for_main.yaml
rm branch_name_main_group.yaml
rm branches_main_group.yaml
rm branches_main_group_jobs_array.yaml
rm branches_main_group_pipeline.yaml
rm branches_main_group_section.yaml
rm branches_pipeline.yaml

echo y | fly -t $CONCOURSE_TARGET set-pipeline -p "$ORIGINAL_PIPELINE_NAME$NEW_PIPELINE_SUFFIX" -c branches_pipeline_final.yaml  > /dev/null

rm branches_pipeline_final.yaml
