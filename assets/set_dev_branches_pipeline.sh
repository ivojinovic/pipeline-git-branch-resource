#!/usr/bin/env bash

# cleanup
rm *.yaml

set -e

CONCOURSE_TARGET=$1
LOCAL_OR_CONCOURSE=$2
APP_DEV_BRANCHES=$3
APP_HOT_BRANCHES=$4

if [ "$LOCAL_OR_CONCOURSE" == "LOCAL" ] ; then
    source ./../assets/branches_common.sh
else
    source /opt/resource/branches_common.sh
fi

# Get the original pipeline
fly -t $CONCOURSE_TARGET get-pipeline -p $PARAM_APP_PIPELINE_NAME > original_pipeline.yaml

# Get the full lane for each tab
get_lane_for_group_name original_pipeline.yaml $PARAM_APP_MASTER_GROUP lane_for_master.yaml
get_lane_for_group_name original_pipeline.yaml $PARAM_APP_DEV_TEMPLATE_GROUP lane_for_dev_template.yaml
get_lane_for_group_name original_pipeline.yaml $PARAM_APP_HOT_TEMPLATE_GROUP lane_for_hot_template.yaml
get_lane_for_group_name original_pipeline.yaml $PARAM_APP_UPDATER_GROUP lane_for_updater.yaml

# Get the group (job list) for each tabs
get_group_by_name original_pipeline.yaml $PARAM_APP_MASTER_GROUP group_for_master.yaml
get_group_by_name original_pipeline.yaml $PARAM_APP_UPDATER_GROUP group_for_updater.yaml

# Merge the lane and the group for each tab
spruce merge lane_for_master.yaml group_for_master.yaml > full_tab_for_master.yaml
spruce merge lane_for_updater.yaml group_for_updater.yaml > full_tab_for_updater.yaml

# Get a list of jobs placed in the dev branches template
get_jobs_list_for_group original_pipeline.yaml $PARAM_APP_DEV_TEMPLATE_GROUP job_list_for_dev_template.yaml
get_jobs_list_for_group original_pipeline.yaml $PARAM_APP_HOT_TEMPLATE_GROUP job_list_for_hot_template.yaml

# Use the template for each one of the branches passed in
if [ -n "${APP_DEV_BRANCHES}" ]; then
    process_template_for_each_branch lane_for_dev_template.yaml job_list_for_dev_template.yaml "$APP_DEV_BRANCHES" $PARAM_APP_DEV_TEMPLATE_GROUP full_tabs_for_each_dev_branch.yaml job_list_for_all_dev_branches.yaml
    get_group_for_group_name job_list_for_all_dev_branches.yaml $PARAM_APP_DEV_ALL_BRANCHES_GROUP group_for_all_dev_branches.yaml
    PIPELINE_MERGE_FILE_DEV_BRANCHES_FILES="group_for_all_dev_branches.yaml full_tabs_for_each_dev_branch.yaml"
fi
if [ -n "${APP_HOT_BRANCHES}" ]; then
    process_template_for_each_branch lane_for_hot_template.yaml job_list_for_hot_template.yaml "$APP_HOT_BRANCHES" $PARAM_APP_HOT_TEMPLATE_GROUP full_tabs_for_each_hot_branch.yaml job_list_for_all_hot_branches.yaml
    get_group_for_group_name job_list_for_all_hot_branches.yaml $PARAM_APP_HOT_ALL_BRANCHES_GROUP group_for_all_hot_branches.yaml
    PIPELINE_MERGE_FILE_HOT_BRANCHES_FILES="group_for_all_hot_branches.yaml full_tabs_for_each_hot_branch.yaml"
fi

PIPELINE_MERGE_FILES="full_tab_for_master.yaml lane_for_dev_template.yaml lane_for_hot_template.yaml full_tab_for_updater.yaml"
PIPELINE_MERGE_FILES="$PIPELINE_MERGE_FILES $PIPELINE_MERGE_FILE_DEV_BRANCHES_FILES $PIPELINE_MERGE_FILE_HOT_BRANCHES_FILES"

# Finally, merge all the tabs together
spruce merge $PIPELINE_MERGE_FILES > expanded_pipeline.yaml

if [ "$LOCAL_OR_CONCOURSE" == "LOCAL" ] ; then
    fly -t $CONCOURSE_TARGET set-pipeline -p $PARAM_APP_PIPELINE_NAME -c expanded_pipeline.yaml
fi

if [ "$LOCAL_OR_CONCOURSE" == "CONCOURSE" ] ; then
    echo y | fly -t $CONCOURSE_TARGET set-pipeline -p $PARAM_APP_PIPELINE_NAME -c expanded_pipeline.yaml  > /dev/null
fi

# cleanup
rm *.yaml
