get_lane_for_token() {
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