#!/usr/bin/env bash

# cleanup
rm *.yaml

set -e

CONCOURSE_TARGET=$1
LOCAL_OR_CONCOURSE=$2
BRANCH_LIST_PARAMS_INDEX=3

if [ "$LOCAL_OR_CONCOURSE" == "LOCAL" ] ; then
    source ./../assets/branches_common.sh
else
    source /opt/resource/branches_common.sh
fi

# Get the original pipeline
fly -t $CONCOURSE_TARGET get-pipeline -p $PARAM_APP_PIPELINE_NAME > original_pipeline.yaml

# Get the full lane for each tab
get_lane_for_token original_pipeline.yaml $PARAM_APP_MASTER_TOKEN lane_for_master.yaml
get_lane_for_token original_pipeline.yaml $PARAM_APP_DEV_BRANCHES_TEMPLATE_TOKEN lane_for_template.yaml
get_lane_for_token original_pipeline.yaml $PARAM_APP_UPDATER_TOKEN lane_for_updater.yaml

# Get the group (job list) for each tabs
get_group_by_name original_pipeline.yaml $PARAM_APP_MASTER_TOKEN group_for_master.yaml
get_group_by_name original_pipeline.yaml $PARAM_APP_DEV_BRANCHES_TEMPLATE_TOKEN group_for_template.yaml
get_group_by_name original_pipeline.yaml $PARAM_APP_UPDATER_GROUP_NAME group_for_updater.yaml

# Merge the lane and the group for each tab
spruce merge lane_for_master.yaml group_for_master.yaml > full_tab_for_master.yaml
spruce merge lane_for_template.yaml group_for_template.yaml > full_tab_for_template.yaml
spruce merge lane_for_updater.yaml group_for_updater.yaml > full_tab_for_updater.yaml

# Get a list of jobs placed in the dev branches template
get_jobs_list_for_group original_pipeline.yaml $PARAM_APP_DEV_BRANCHES_TEMPLATE_TOKEN job_list_for_dev_template.yaml

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
    sed 's~'"$PARAM_APP_DEV_BRANCHES_TEMPLATE_TOKEN"'~'"$BRANCH_NAME_UNSLASHED"'~g' full_tab_for_template.yaml > full_tab_for_branch.yaml
    printf "\n" >> full_tab_for_branch.yaml

    # Get branch name into the list of jobs for the main group
    sed 's~'"$PARAM_APP_DEV_BRANCHES_TEMPLATE_TOKEN"'~'"$BRANCH_NAME_UNSLASHED"'~g' job_list_for_dev_template.yaml > job_list_for_this_dev_branch.yaml
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

get_group_for_all_dev_branches job_list_for_all_dev_branches.yaml group_for_all_dev_branches.yaml

# Finally, merge all the tabs together
spruce merge \
    full_tab_for_master.yaml \
    full_tab_for_template.yaml \
    full_tab_for_updater.yaml \
    group_for_all_dev_branches.yaml \
    full_tabs_for_each_dev_branch.yaml > expanded_pipeline.yaml

if [ "$LOCAL_OR_CONCOURSE" == "LOCAL" ] ; then
    fly -t $CONCOURSE_TARGET set-pipeline -p $PARAM_APP_PIPELINE_NAME -c expanded_pipeline.yaml
fi

if [ "$LOCAL_OR_CONCOURSE" == "CONCOURSE" ] ; then
    echo y | fly -t $CONCOURSE_TARGET set-pipeline -p $PARAM_APP_PIPELINE_NAME -c expanded_pipeline.yaml  > /dev/null
fi

# cleanup
rm *.yaml
