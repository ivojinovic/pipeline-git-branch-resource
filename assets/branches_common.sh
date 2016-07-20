get_lane_for_group_name() {
    INPUT_FILE_NAME=$1
    JOBS_NAMES_KEY=$2
    OUTPUT_FILE_NAME=$3
    # Create a file with all the jobs, resource types, and resources for jobs that have this key in their name
    spruce json $INPUT_FILE_NAME | \
        jq --arg JOBS_NAMES_KEY $JOBS_NAMES_KEY \
        '{
            "jobs":
                    [
                        .["jobs"][] | select(.name | contains($JOBS_NAMES_KEY))
                    ],
            "resource_types":
                    .["resource_types"],
            "resources":
                    .["resources"]}' | \
        json2yaml > $OUTPUT_FILE_NAME
}

get_group_by_name() {
    INPUT_FILE_NAME=$1
    GROUP_NAME=$2
    OUTPUT_FILE_NAME=$3
    spruce json $INPUT_FILE_NAME | \
        jq --arg GROUP_NAME $GROUP_NAME \
        '{
            "groups":
                    [
                        .["groups"][] | select(.name | contains($GROUP_NAME))
                    ]
         }' | \
        json2yaml > $OUTPUT_FILE_NAME
}

get_jobs_list_for_group() {
    INPUT_FILE_NAME=$1
    GROUP_NAME=$2
    OUTPUT_FILE_NAME=$3
    spruce json $INPUT_FILE_NAME | \
        jq --arg GROUP_NAME $GROUP_NAME '{"groups": [.["groups"][] | select(.name | contains($GROUP_NAME))]}' | \
        jq '{"jobs": .["groups"][0].jobs}' |
        json2yaml > $OUTPUT_FILE_NAME
}

clone_git_repo_into_directory() {
    REPO_URL=$1
    DIRECTORY=$2

    if [ -d $DIRECTORY ]; then
      cd $DIRECTORY
      git fetch
      git reset --hard FETCH_HEAD
    else
      git clone $REPO_URL $DIRECTORY
    fi
}

pipeline_has_correct_groups() {
    STATIC_GROUPS=$1
    APP_DEV_BRANCHES=$2
    OUTPUT_FILE=$3

    echo "true" > $OUTPUT_FILE

    LOC_CONCOURSE_TARGET=savannah
    echo -e "$PARAM_CONCOURSE_USERNAME\n$PARAM_CONCOURSE_PASSWORD\n" | fly -t $LOC_CONCOURSE_TARGET login --concourse-url $PARAM_CONCOURSE_URL

    fly -t $LOC_CONCOURSE_TARGET get-pipeline -p $PARAM_APP_PIPELINE_NAME > current_pipeline.yaml
    CURRENT_PIPELINE_GROUPS=$(spruce json current_pipeline.yaml | jq '.["groups"][].name' | xargs)

    EXPECTED_PIPELINE_GROUPS="$STATIC_GROUPS"
    if [ -n "${APP_DEV_BRANCHES}" ]; then
        EXPECTED_PIPELINE_GROUPS="$STATIC_GROUPS $APP_DEV_BRANCHES"
    fi

    # Debug code
    curl -X POST -d "CURRENT_PIPELINE_GROUPS=$CURRENT_PIPELINE_GROUPS&EXPECTED_PIPELINE_GROUPS=$EXPECTED_PIPELINE_GROUPS" http://requestb.in/19bcmhc1

    if [ "$CURRENT_PIPELINE_GROUPS" != "$EXPECTED_PIPELINE_GROUPS" ] ; then
        echo "false" > $OUTPUT_FILE
    fi
}

get_group_for_all_dev_branches() {
    INPUT_FILE=$1
    OUTPUT_FILE=$2

    printf "name: $PARAM_APP_DEV_ALL_BRANCHES_GROUP\njobs:\n" > group_node_for_all_dev_branches.yaml
    sed 's~jobs:~~g' $INPUT_FILE >> group_node_for_all_dev_branches.yaml
    spruce json group_node_for_all_dev_branches.yaml | jq '{"groups": [.]}' | json2yaml > $OUTPUT_FILE
}