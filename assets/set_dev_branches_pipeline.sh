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

# Get the full lanes for the templates
get_lane_for_group_name original_pipeline.yaml $PARAM_APP_DEV_TEMPLATE_GROUP lane_for_dev_template.yaml
get_lane_for_group_name original_pipeline.yaml $PARAM_APP_HOT_TEMPLATE_GROUP lane_for_hot_template.yaml

# Use the template for each one of the branches passed in
if [ -n "${APP_DEV_BRANCHES}" ]; then
    get_jobs_list_for_group original_pipeline.yaml $PARAM_APP_DEV_TEMPLATE_GROUP job_list_for_dev_template.yaml
    process_template_for_each_branch lane_for_dev_template.yaml job_list_for_dev_template.yaml "$APP_DEV_BRANCHES" $PARAM_APP_DEV_TEMPLATE_GROUP full_tabs_for_each_dev_branch.yaml job_list_for_all_dev_branches.yaml
    get_group_for_group_name job_list_for_all_dev_branches.yaml $PARAM_APP_DEV_ALL_BRANCHES_GROUP group_for_all_dev_branches.yaml
    GROUP_FOR_ALL_DEV_BRANCHES_FILE="group_for_all_dev_branches.yaml"
    DEV_FULL_TAB_FILE="full_tabs_for_each_dev_branch.yaml"
    APP_ALL_BRANCHES="$APP_DEV_BRANCHES"
fi
if [ -n "${APP_HOT_BRANCHES}" ]; then
    get_jobs_list_for_group original_pipeline.yaml $PARAM_APP_HOT_TEMPLATE_GROUP job_list_for_hot_template.yaml
    process_template_for_each_branch lane_for_hot_template.yaml job_list_for_hot_template.yaml "$APP_HOT_BRANCHES" $PARAM_APP_HOT_TEMPLATE_GROUP full_tabs_for_each_hot_branch.yaml job_list_for_all_hot_branches.yaml
    HOT_FULL_TAB_FILE="full_tabs_for_each_hot_branch.yaml"
    if [ -n "${APP_ALL_BRANCHES}" ]; then
        APP_ALL_BRANCHES="$APP_ALL_BRANCHES $APP_HOT_BRANCHES"
    else
        APP_ALL_BRANCHES="$APP_HOT_BRANCHES"
    fi
fi

get_lane_for_group_name original_pipeline.yaml $PARAM_APP_MASTER_GROUP lane_for_master.yaml
get_lane_for_group_name original_pipeline.yaml $PARAM_APP_UPDATER_GROUP lane_for_updater_start.yaml

UPDATED_BRANCH_LIST_FILE=param_branch_list.yaml
get_branch_list_into_updater_param "$APP_ALL_BRANCHES" $UPDATED_BRANCH_LIST_FILE
spruce merge lane_for_updater_start.yaml $UPDATED_BRANCH_LIST_FILE > lane_for_updater.yaml

STATIC_LANE_FILES="lane_for_master.yaml lane_for_updater.yaml lane_for_dev_template.yaml lane_for_hot_template.yaml"
DYNAMIC_FULL_TAB_FILES="$DEV_FULL_TAB_FILE $HOT_FULL_TAB_FILE"
STATIC_LANES_AND_DYNAMIC_TABS_FILES="$STATIC_LANE_FILES $DYNAMIC_FULL_TAB_FILES"

# Finally, merge all the tabs together
spruce merge $STATIC_LANES_AND_DYNAMIC_TABS_FILES > static_lanes_and_dynamic_tabs.yaml

# Get the group (job list) for each tabs
get_group_by_name original_pipeline.yaml $PARAM_APP_MASTER_GROUP group_for_master.yaml
get_group_by_name original_pipeline.yaml $PARAM_APP_UPDATER_GROUP group_for_updater.yaml

spruce merge group_for_master.yaml group_for_updater.yaml $GROUP_FOR_ALL_DEV_BRANCHES_FILE static_lanes_and_dynamic_tabs.yaml > expanded_pipeline.yaml

if [ "$LOCAL_OR_CONCOURSE" == "LOCAL" ] ; then
    fly -t $CONCOURSE_TARGET set-pipeline -p $PARAM_APP_PIPELINE_NAME -c expanded_pipeline.yaml
fi

if [ "$LOCAL_OR_CONCOURSE" == "CONCOURSE" ] ; then
    echo y | fly -t $CONCOURSE_TARGET set-pipeline -p $PARAM_APP_PIPELINE_NAME -c expanded_pipeline.yaml  > /dev/null
fi

# cleanup
rm *.yaml
