export_parameter_values() {
    PAYLOAD=$1
    export PARAM_APP_GIT_URI=$(jq -r '.source.project_git_uri // ""' < $PAYLOAD)
}