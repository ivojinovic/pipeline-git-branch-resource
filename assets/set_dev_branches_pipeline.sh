#!/usr/bin/env bash

# cleanup
rm *.yaml

set -e

CONCOURSE_TARGET=$1
ORIGINAL_PIPELINE_NAME=$2
NEW_PIPELINE_SUFFIX=$3
LOCAL_OR_CONCOURSE=$4
TEMPLATE_TOKEN=$5
TEMPLATE_GROUP=$6
BRANCH_LIST_PARAMS_INDEX=7

if [ "$LOCAL_OR_CONCOURSE" == "LOCAL" ] ; then
    COMMAND_PREFIX=./../assets
else
    COMMAND_PREFIX=/opt/resource
fi

# Get the original pipeline
fly -t $CONCOURSE_TARGET get-pipeline -p $ORIGINAL_PIPELINE_NAME > original_pipeline.yaml

######
# START - Create branch template - the main group, the branch group, and the branch lane (jobs, resource types, and resources)
######

# Get a list of jobs that have this token in their name, so they can be placed in the main group
spruce json original_pipeline.yaml | \
    jq --arg TEMPLATE_GROUP $TEMPLATE_GROUP '{"groups": [.["groups"][] | select(.name | contains($TEMPLATE_GROUP))]}' | \
    jq '{"jobs": .["groups"][0].jobs}' |
    json2yaml > job_list_for_main_group_template.yaml

# Get the original pipeline
fly -t $CONCOURSE_TARGET get-pipeline -p $ORIGINAL_PIPELINE_NAME > original_pipeline.yaml

# Get all the jobs, resource types, and resources for jobs that have this token in their name
"$COMMAND_PREFIX"/get_lane_for_token.sh \
    original_pipeline.yaml \
    $TEMPLATE_TOKEN \
    lane_for_"$TEMPLATE_TOKEN".yaml

# Get the job group for the template lane
"$COMMAND_PREFIX"/get_group_for_token.sh \
    original_pipeline.yaml \
    $TEMPLATE_GROUP \
    $TEMPLATE_TOKEN \
    group_for_"$TEMPLATE_TOKEN".yaml

# Merge the lane and the group
spruce merge \
    lane_for_"$TEMPLATE_TOKEN".yaml group_for_"$TEMPLATE_TOKEN".yaml > \
    jobs_resources_and_group_template.yaml

######
# END - Create branch template - the main group, the branch group, and the branch lane (jobs, resource types, and resources)
######

#####
# START - Use the jobs/resources/group template (and main group template) for each one of the branches passed in
#####
VAR_COUNT=0
FIRST_BRANCH=true
for VAR in "$@"
do
    # Skip the non-branch name parameters
    VAR_COUNT=`expr $VAR_COUNT + 1`
    if [ "$VAR_COUNT" -lt "$BRANCH_LIST_PARAMS_INDEX" ] ; then
        continue
    fi

    # Can't use slashes in job names
    BRANCH_NAME_UNSLASHED=`echo $VAR | sed -e "s/\//-/g"`

    # Get branch name into the jobs/resources/group template
    sed 's~'"$TEMPLATE_TOKEN"'~'"$BRANCH_NAME_UNSLASHED"'~g' jobs_resources_and_group_template.yaml > jobs_resources_and_group_pipeline.yaml
    printf "\n" >> jobs_resources_and_group_pipeline.yaml

    # Get branch name into the list of jobs for the main group
    sed 's~'"$TEMPLATE_TOKEN"'~'"$BRANCH_NAME_UNSLASHED"'~g' job_list_for_main_group_template.yaml > job_list_for_main_group_pipeline.yaml
    printf "\n" >> job_list_for_main_group_pipeline.yaml

    # now add the branch pipeline to the pipeline of all branches
    if [ $FIRST_BRANCH == true ] ; then
        FIRST_BRANCH=false
        echo "Starting with $BRANCH_NAME_UNSLASHED"
        spruce merge jobs_resources_and_group_pipeline.yaml > all_branches_jobs_resources_and_group_pipeline.yaml
        # do the same for the main group section
        spruce merge job_list_for_main_group_pipeline.yaml > all_branches_job_list_for_main_group_pipeline.yaml
    else
        echo "Adding Branch $BRANCH_NAME_UNSLASHED"
        spruce merge all_branches_jobs_resources_and_group_pipeline.yaml jobs_resources_and_group_pipeline.yaml >> all_branches_jobs_resources_and_group_pipeline.yaml
        # do the same for the main group section
        spruce merge all_branches_job_list_for_main_group_pipeline.yaml job_list_for_main_group_pipeline.yaml >> all_branches_job_list_for_main_group_pipeline.yaml
    fi
done
#####
# END - Use the jobs/resources/group template (and main group template) for each one of the branches passed in
#####

####
# Combine main group pipeline and jobs/resources/types/groups pipeline
####

# Prepare the final main group section
printf "name: $ORIGINAL_PIPELINE_NAME\n" > final_main_group_section.yaml
printf "jobs:\n" >> final_main_group_section.yaml
# Prepare the main group pipeline we created
sed 's~jobs:~~g' all_branches_job_list_for_main_group_pipeline.yaml > all_branches_job_list_for_main_group_array.yaml
# Add it to the final main group section
cat all_branches_job_list_for_main_group_array.yaml >> final_main_group_section.yaml
# Wrap the section into a group
spruce json final_main_group_section.yaml | jq '{"groups": [.]}' | json2yaml > final_main_group.yaml

# Finally, merge the jobs/resources/group pipeline and the main group
spruce merge final_main_group.yaml all_branches_jobs_resources_and_group_pipeline.yaml  > new_pipeline.yaml

if [ "$LOCAL_OR_CONCOURSE" == "LOCAL" ] ; then
    fly -t $CONCOURSE_TARGET set-pipeline -p "$ORIGINAL_PIPELINE_NAME$NEW_PIPELINE_SUFFIX" -c new_pipeline.yaml
fi

if [ "$LOCAL_OR_CONCOURSE" == "CONCOURSE" ] ; then
    echo y | fly -t $CONCOURSE_TARGET set-pipeline -p "$ORIGINAL_PIPELINE_NAME$NEW_PIPELINE_SUFFIX" -c new_pipeline.yaml  > /dev/null
fi

# cleanup
rm *.yaml
