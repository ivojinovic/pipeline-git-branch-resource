#!/usr/bin/env bash

# cleanup
rm *.yaml

set -e

CONCOURSE_TARGET=$1
ORIGINAL_PIPELINE_NAME=$2
LOCAL_OR_CONCOURSE=$3
TEMPLATE_TOKEN=$4
DEV_BRANCHES_GROUP_NAME=$5
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
get_group_for_token original_pipeline.yaml $DEV_BRANCHES_GROUP_NAME $TEMPLATE_TOKEN group_for_template.yaml
# TODO: 'unmerged-branches-updater' here needs to be a parameter
get_group_for_token original_pipeline.yaml unmerged-branches-updater unmerged-branches-updater group_for_updater.yaml

# Merge the lane and the group for each tab
spruce merge lane_for_master.yaml group_for_master.yaml > full_tab_for_master.yaml
spruce merge lane_for_template.yaml group_for_template.yaml > full_tab_for_template.yaml
spruce merge lane_for_updater.yaml group_for_updater.yaml > full_tab_for_updater.yaml

# TODO: So, the term 'dev' comes from pipelines project... should go with that everywhere instead of 'unmerged branches'
# Get a list of jobs placed in the dev branches template
spruce json original_pipeline.yaml | \
    jq --arg DEV_BRANCHES_GROUP_NAME $DEV_BRANCHES_GROUP_NAME '{"groups": [.["groups"][] | select(.name | contains($DEV_BRANCHES_GROUP_NAME))]}' | \
    jq '{"jobs": .["groups"][0].jobs}' |
    json2yaml > job_list_for_dev_template.yaml

#####
# START - Use the template for each one of the branches passed in
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
    sed 's~'"$TEMPLATE_TOKEN"'~'"$BRANCH_NAME_UNSLASHED"'~g' job_list_for_dev_template.yaml > job_list_for_this_dev_branch.yaml
    printf "\n" >> job_list_for_this_dev_branch.yaml

    # now add the branch pipeline to the pipeline of all branches
    if [ $FIRST_BRANCH == true ] ; then
        FIRST_BRANCH=false
        echo "Starting with $BRANCH_NAME_UNSLASHED"
        spruce merge full_tab_for_branch.yaml > full_tabs_for_each_dev_branch.yaml
        # do the same for the main group section
        spruce merge job_list_for_this_dev_branch.yaml > job_list_for_all_dev_branches.yaml
    else
        echo "Adding Branch $BRANCH_NAME_UNSLASHED"
        spruce merge full_tabs_for_each_dev_branch.yaml full_tab_for_branch.yaml >> full_tabs_for_each_dev_branch.yaml
        # do the same for the main group section
        spruce merge job_list_for_all_dev_branches.yaml job_list_for_this_dev_branch.yaml >> job_list_for_all_dev_branches.yaml
    fi
done
#####
# END - Use the template for each one of the branches passed in
#####

# Prepare the group node for unmerged branches
printf "name: unmerged-branches\n" > group_node_for_all_dev_branches.yaml
printf "jobs:\n" >> group_node_for_all_dev_branches.yaml
# Prepare the main group pipeline we created
sed 's~jobs:~~g' job_list_for_all_dev_branches.yaml > job_list_for_all_dev_branches_clean.yaml
# Add it to the group node
cat job_list_for_all_dev_branches_clean.yaml >> group_node_for_all_dev_branches.yaml
# Wrap the node into a group
spruce json group_node_for_all_dev_branches.yaml | jq '{"groups": [.]}' | json2yaml > group_for_all_dev_branches.yaml

# Finally, merge all the tabs together
spruce merge \
    full_tab_for_master.yaml \
    full_tab_for_template.yaml \
    full_tab_for_updater.yaml \
    group_for_all_dev_branches.yaml \
    full_tabs_for_each_dev_branch.yaml > expanded_pipeline.yaml

if [ "$LOCAL_OR_CONCOURSE" == "LOCAL" ] ; then
    fly -t $CONCOURSE_TARGET set-pipeline -p "$ORIGINAL_PIPELINE_NAME$NEW_PIPELINE_SUFFIX" -c expanded_pipeline.yaml
fi

if [ "$LOCAL_OR_CONCOURSE" == "CONCOURSE" ] ; then
    echo y | fly -t $CONCOURSE_TARGET set-pipeline -p "$ORIGINAL_PIPELINE_NAME$NEW_PIPELINE_SUFFIX" -c expanded_pipeline.yaml  > /dev/null
fi

# cleanup
rm *.yaml
