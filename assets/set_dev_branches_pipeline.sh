#!/usr/bin/env bash

# cleanup
rm *.yaml

set -e

CONCOURSE_TARGET=$1
ORIGINAL_PIPELINE_NAME=$2
LOCAL_OR_CONCOURSE=$3
TEMPLATE_TOKEN=$4
TEMPLATE_GROUP=$5
BRANCH_LIST_PARAMS_INDEX=6

if [ "$LOCAL_OR_CONCOURSE" == "LOCAL" ] ; then
    source ./../assets/branches_common.sh
else
    source /opt/resource/branches_common.sh
fi

# Get the original pipeline
fly -t $CONCOURSE_TARGET get-pipeline -p $ORIGINAL_PIPELINE_NAME > original_pipeline.yaml

# Get the full lane for each tab
get_lane_for_token original_pipeline.yaml master lane_for_master.yaml
get_lane_for_token original_pipeline.yaml $TEMPLATE_TOKEN lane_for_template.yaml
# TODO: 'update_unmerged_branches' here needs to be a parameter
get_lane_for_token original_pipeline.yaml update_unmerged_branches lane_for_updater.yaml

# Get the group (job list) for each tabs
get_group_for_token original_pipeline.yaml master master group_for_master.yaml
get_group_for_token original_pipeline.yaml $TEMPLATE_GROUP $TEMPLATE_TOKEN group_for_template.yaml
# TODO: 'unmerged-branches-updater' here needs to be a parameter
get_group_for_token original_pipeline.yaml unmerged-branches-updater unmerged-branches-updater group_for_updater.yaml

# Merge the lane and the group for each tab
spruce merge lane_for_master.yaml group_for_master.yaml > full_tab_for_master.yaml
spruce merge lane_for_template.yaml group_for_template.yaml > full_tab_for_template.yaml
spruce merge lane_for_updater.yaml group_for_updater.yaml > full_tab_for_updater.yaml

# Get a list of jobs placed in the template group
spruce json original_pipeline.yaml | \
    jq --arg TEMPLATE_GROUP $TEMPLATE_GROUP '{"groups": [.["groups"][] | select(.name | contains($TEMPLATE_GROUP))]}' | \
    jq '{"jobs": .["groups"][0].jobs}' |
    json2yaml > job_list_for_template.yaml

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
    sed 's~'"$TEMPLATE_TOKEN"'~'"$BRANCH_NAME_UNSLASHED"'~g' full_tab_for_template.yaml > full_tab_for_branch.yaml
    printf "\n" >> full_tab_for_branch.yaml

    # Get branch name into the list of jobs for the main group
    sed 's~'"$TEMPLATE_TOKEN"'~'"$BRANCH_NAME_UNSLASHED"'~g' job_list_for_template.yaml > job_list_for_branch.yaml
    printf "\n" >> job_list_for_branch.yaml

    # now add the branch pipeline to the pipeline of all branches
    if [ $FIRST_BRANCH == true ] ; then
        FIRST_BRANCH=false
        echo "Starting with $BRANCH_NAME_UNSLASHED"
        spruce merge full_tab_for_branch.yaml > full_tab_for_all_branches.yaml
        # do the same for the main group section
        spruce merge job_list_for_branch.yaml > job_list_for_all_branches.yaml
    else
        echo "Adding Branch $BRANCH_NAME_UNSLASHED"
        spruce merge full_tab_for_all_branches.yaml full_tab_for_branch.yaml >> full_tab_for_all_branches.yaml
        # do the same for the main group section
        spruce merge job_list_for_all_branches.yaml job_list_for_branch.yaml >> job_list_for_all_branches.yaml
    fi
done
#####
# END - Use the jobs/resources/group template (and main group template) for each one of the branches passed in
#####

####
# Combine main group pipeline and jobs/resources/types/groups pipeline
####

# Prepare the final main group section
printf "name: unmerged-branches\n" > unmerged_branches_group_section.yaml
printf "jobs:\n" >> unmerged_branches_group_section.yaml
# Prepare the main group pipeline we created
sed 's~jobs:~~g' job_list_for_all_branches.yaml > all_branches_job_list_for_main_group_array.yaml
# Add it to the final main group section
cat all_branches_job_list_for_main_group_array.yaml >> unmerged_branches_group_section.yaml
# Wrap the section into a group
spruce json unmerged_branches_group_section.yaml | jq '{"groups": [.]}' | json2yaml > unmerged_branches_group.yaml

# Finally, merge the jobs/resources/group pipeline and the main group
spruce merge \
    full_tab_for_master.yaml \
    full_tab_for_template.yaml \
    full_tab_for_updater.yaml \
    unmerged_branches_group.yaml \
    full_tab_for_all_branches.yaml > new_pipeline.yaml

if [ "$LOCAL_OR_CONCOURSE" == "LOCAL" ] ; then
    fly -t $CONCOURSE_TARGET set-pipeline -p "$ORIGINAL_PIPELINE_NAME$NEW_PIPELINE_SUFFIX" -c new_pipeline.yaml
fi

if [ "$LOCAL_OR_CONCOURSE" == "CONCOURSE" ] ; then
    echo y | fly -t $CONCOURSE_TARGET set-pipeline -p "$ORIGINAL_PIPELINE_NAME$NEW_PIPELINE_SUFFIX" -c new_pipeline.yaml  > /dev/null
fi

# cleanup
rm *.yaml
