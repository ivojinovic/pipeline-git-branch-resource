export_parameter_values() {
    PAYLOAD=$1

    #########
    # Concourse /
    #########
    export PARAM_CONCOURSE_URL=$(jq -r '.source.concourse_url // ""' < $PAYLOAD)
    export PARAM_CONCOURSE_USERNAME=$(jq -r '.source.concourse_username // ""' < $PAYLOAD)
    export PARAM_CONCOURSE_PASSWORD=$(jq -r '.source.concourse_password // ""' < $PAYLOAD)
    #########
    # / Concourse
    #########

    #########
    # App /
    #########
    export PARAM_OLD_REF=$(jq -r '.version.ref // ""' < $payload)
    export PARAM_APP_GIT_URI=$(jq -r '.source.app_git_uri // ""' < $PAYLOAD)
    export PARAM_APP_PIPELINE_NAME=$(jq -r '.source.app_pipeline_name // ""' < $PAYLOAD)

    export PARAM_APP_MASTER_GROUP=$(jq -r '.source.group_master // ""' < $PAYLOAD)
    export PARAM_APP_UPDATER_GROUP=$(jq -r '.source.group_updater // ""' < $PAYLOAD)

    PARAM_APP_DEV_TEMPLATE_GROUP_1=$(jq -r '.source.group_dev_template_1 // ""' < $PAYLOAD)
    PARAM_APP_DEV_TEMPLATE_GROUP_2=$(jq -r '.source.group_dev_template_2 // ""' < $PAYLOAD)
    export PARAM_APP_DEV_TEMPLATE_GROUP="$PARAM_APP_DEV_TEMPLATE_GROUP_1""$PARAM_APP_DEV_TEMPLATE_GROUP_2"
    export PARAM_APP_DEV_ALL_BRANCHES_GROUP=$(jq -r '.source.group_dev_all // ""' < $PAYLOAD)
    export PARAM_APP_DEV_BRANCH_FILTER=$(jq -r '.source.dev_branches_filter // ""' < $PAYLOAD)

    PARAM_APP_HOT_TEMPLATE_GROUP_1=$(jq -r '.source.group_hot_template_1 // ""' < $PAYLOAD)
    PARAM_APP_HOT_TEMPLATE_GROUP_2=$(jq -r '.source.group_hot_template_2 // ""' < $PAYLOAD)
    export PARAM_APP_HOT_TEMPLATE_GROUP="$PARAM_APP_HOT_TEMPLATE_GROUP_1""$PARAM_APP_HOT_TEMPLATE_GROUP_2"
    export PARAM_APP_HOT_ALL_BRANCHES_GROUP=$(jq -r '.source.group_hot_all // ""' < $PAYLOAD)
    export PARAM_APP_HOT_BRANCH_FILTER=$(jq -r '.source.hot_branches_filter // ""' < $PAYLOAD)

    export PARAM_APP_STATIC_GROUPS="$PARAM_APP_MASTER_GROUP $PARAM_APP_DEV_TEMPLATE_GROUP $PARAM_APP_HOT_TEMPLATE_GROUP $PARAM_APP_UPDATER_GROUP"

    export PARAM_APP_REQUESTBIN=$(jq -r '.source.requestbin // ""' < $PAYLOAD)
    export PARAM_APP_OVERRIDE=$(jq -r '.source.override // ""' < $PAYLOAD)

    export CONST_APP_GIT_DIR=$TMPDIR/git-resource-repo-cache-1
    export CONST_APP_GROUP_CHECK_OUTPUT_FILE=/opt/resource/pipeline_has_correct_groups.out
    #########
    # / App
    #########

    #########
    # Pipelines project /
    #########
    export PARAM_PIPELINES_BW_VERSION=$(jq -r '.source.branch_watcher_version // ""' < $PAYLOAD)
    export PARAM_PIPELINES_BRANCH=$(jq -r '.source.pipelines_branch // ""' < $PAYLOAD)

    export CONST_PIPELINES_GIT_DIR=$TMPDIR/git-resource-repo-cache-2
    #########
    # / Pipelines project
    #########

}