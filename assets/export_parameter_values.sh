export_parameter_values() {
    PAYLOAD=$1

    #########
    # App /
    #########
    export PARAM_OLD_REF=$(jq -r '.version.ref // ""' < $payload)
    # TODO: source param should be 'app', not 'project'
    export PARAM_APP_GIT_URI=$(jq -r '.source.project_git_uri // ""' < $PAYLOAD)
    export PARAM_APP_STATIC_GROUPS="master unmerged-branches-template unmerged-branches-updater unmerged-branches"

    export CONST_APP_GIT_DIR=$TMPDIR/git-resource-repo-cache-1
    export CONST_APP_GROUP_CHECK_OUTPUT_FILE=/opt/resource/pipeline_has_correct_groups.out
    #########
    # / App
    #########

    #########
    # Pipelines project /
    #########
    # TODO: This needs to be a parameter
    export PARAM_PIPELINES_GIT_URI=ssh://git@stash.zipcar.com:7999/sav/pipelines.git
    # TODO: This needs to be a parameter
    export PARAM_PIPELINES_BRANCH=dynamic-dev-branches

    export CONST_PIPELINES_GIT_DIR=$TMPDIR/git-resource-repo-cache-2
    #########
    # / Pipelines project
    #########

}