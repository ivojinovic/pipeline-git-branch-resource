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

    export PARAM_APP_MASTER_GROUP_NAME=$(jq -r '.source.group_name_master // ""' < $PAYLOAD)

    PARAM_APP_DEV_TEMPLATE_GROUP_1=$(jq -r '.source.group_dev_template_1 // ""' < $PAYLOAD)
    PARAM_APP_DEV_TEMPLATE_GROUP_2=$(jq -r '.source.group_dev_template_2 // ""' < $PAYLOAD)
    export PARAM_APP_DEV_TEMPLATE_GROUP="$PARAM_APP_DEV_TEMPLATE_GROUP_1""$PARAM_APP_DEV_TEMPLATE_GROUP_2"
    export PARAM_APP_UPDATER_GROUP_NAME=$(jq -r '.source.group_dev_updater // ""' < $PAYLOAD)
    export PARAM_APP_ALL_DEV_BRANCHES_GROUP_NAME=$(jq -r '.source.group_dev_all // ""' < $PAYLOAD)
    export PARAM_APP_BRANCH_FILTER=$(jq -r '.source.dev_branches_filter // ""' < $PAYLOAD)

    export PARAM_APP_STATIC_GROUPS="$PARAM_APP_MASTER_GROUP_NAME $PARAM_APP_DEV_TEMPLATE_GROUP $PARAM_APP_UPDATER_GROUP_NAME $PARAM_APP_ALL_DEV_BRANCHES_GROUP_NAME"

    export CONST_APP_GIT_DIR=$TMPDIR/git-resource-repo-cache-1
    export CONST_APP_GROUP_CHECK_OUTPUT_FILE=/opt/resource/pipeline_has_correct_groups.out
    #########
    # / App
    #########

    #########
    # Pipelines project /
    #########
    export PARAM_PIPELINES_GIT_URI=$(jq -r '.source.pipelines_git_uri // ""' < $PAYLOAD)
    export PARAM_PIPELINES_BRANCH=$(jq -r '.source.pipelines_branch // ""' < $PAYLOAD)

    export CONST_PIPELINES_GIT_DIR=$TMPDIR/git-resource-repo-cache-2
    #########
    # / Pipelines project
    #########

}