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
      rm -Rf $DIRECTORY
    fi
    git clone $REPO_URL $DIRECTORY
}

pipeline_has_correct_groups() {
    STATIC_GROUPS=$1
    OUTPUT_FILE=$2
    APP_DEV_BRANCHES=$3
    APP_HOT_BRANCHES=$4

    echo "true" > $OUTPUT_FILE

    LOC_CONCOURSE_TARGET=savannah
    echo -e "$PARAM_CONCOURSE_USERNAME\n$PARAM_CONCOURSE_PASSWORD\n" | fly -t $LOC_CONCOURSE_TARGET login --concourse-url $PARAM_CONCOURSE_URL

    fly -t $LOC_CONCOURSE_TARGET get-pipeline -p $PARAM_APP_PIPELINE_NAME > current_pipeline.yaml
    CURRENT_PIPELINE_GROUPS=$(spruce json current_pipeline.yaml | jq '.["groups"][].name' | xargs)

    EXPECTED_PIPELINE_GROUPS_RAW="$STATIC_GROUPS"
    if [ -n "${APP_DEV_BRANCHES}" ]; then
        EXPECTED_PIPELINE_GROUPS_RAW="$STATIC_GROUPS $PARAM_APP_DEV_ALL_BRANCHES_GROUP $APP_DEV_BRANCHES"
    fi
    if [ -n "${APP_HOT_BRANCHES}" ]; then
        EXPECTED_PIPELINE_GROUPS_RAW="$EXPECTED_PIPELINE_GROUPS_RAW $PARAM_APP_HOT_ALL_BRANCHES_GROUP $APP_HOT_BRANCHES"
    fi

    EXPECTED_PIPELINE_GROUPS=`echo $EXPECTED_PIPELINE_GROUPS_RAW | sed -e "s/\//-/g"`

    # Debug code
    if [ -n "${PARAM_APP_REQUESTBIN}" ]; then
        curl -X POST -d "CURRENT_PIPELINE_GROUPS=$CURRENT_PIPELINE_GROUPS&EXPECTED_PIPELINE_GROUPS=$EXPECTED_PIPELINE_GROUPS" http://requestb.in/$PARAM_APP_REQUESTBIN
    fi

    if [ "$CURRENT_PIPELINE_GROUPS" != "$EXPECTED_PIPELINE_GROUPS" ] ; then
        echo "false" > $OUTPUT_FILE
    fi
}

get_group_for_all_branches() {
    INPUT_FILE=$1
    APP_ALL_BRANCHES_GROUP=$2
    OUTPUT_FILE=$3

    printf "name: $APP_ALL_BRANCHES_GROUP\njobs:\n" > group_node_for_all_branches.yaml
    sed 's~jobs:~~g' $INPUT_FILE >> group_node_for_all_branches.yaml
    spruce json group_node_for_all_branches.yaml | jq '{"groups": [.]}' | json2yaml > $OUTPUT_FILE
}

process_template_for_each_branch() {
    FULL_TAB_FOR_TEMPLATE_FILE=$1
    JOB_LIST_FOR_TEMPLATE_FILE=$2
    APP_BRANCHES=$3
    APP_TEMPLATE_GROUP=$4
    FULL_TABS_FOR_EACH_BRANCH_FILE=$5
    JOB_LIST_FOR_ALL_BRANCHES_FILE=$6

    IFS=' ' read -r -a APP_BRANCHES_ARRAY <<< "$APP_BRANCHES"

    FIRST_BRANCH=true
    for BRANCH_NAME in "${APP_BRANCHES_ARRAY[@]}"
    do
        # Can't use slashes in job names
        BRANCH_NAME_UNSLASHED=`echo $BRANCH_NAME | sed -e "s/\//-/g"`

        # Get branch name into the jobs/resources/group template
        sed 's~'"$APP_TEMPLATE_GROUP"'~'"$BRANCH_NAME_UNSLASHED"'~g' $FULL_TAB_FOR_TEMPLATE_FILE > full_tab_for_branch.yaml
        printf "\n" >> full_tab_for_branch.yaml

        # Get branch name into the list of jobs for the main group
        sed 's~'"$APP_TEMPLATE_GROUP"'~'"$BRANCH_NAME_UNSLASHED"'~g' $JOB_LIST_FOR_TEMPLATE_FILE > job_list_for_this_branch.yaml
        printf "\n" >> job_list_for_this_branch.yaml

        # now add the branch pipeline to the pipeline of all branches
        if [ $FIRST_BRANCH == true ] ; then
            FIRST_BRANCH=false
            echo "Starting with $BRANCH_NAME_UNSLASHED"
            spruce merge full_tab_for_branch.yaml > $FULL_TABS_FOR_EACH_BRANCH_FILE
            # do the same for the main group section
            spruce merge job_list_for_this_branch.yaml > $JOB_LIST_FOR_ALL_BRANCHES_FILE
        else
            echo "Adding Branch $BRANCH_NAME_UNSLASHED"
            spruce merge $FULL_TABS_FOR_EACH_BRANCH_FILE full_tab_for_branch.yaml >> $FULL_TABS_FOR_EACH_BRANCH_FILE
            # do the same for the main group section
            spruce merge $JOB_LIST_FOR_ALL_BRANCHES_FILE job_list_for_this_branch.yaml >> $JOB_LIST_FOR_ALL_BRANCHES_FILE
        fi
    done
}