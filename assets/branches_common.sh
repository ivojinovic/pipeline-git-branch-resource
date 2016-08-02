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
        jq --arg GROUP_NAME $GROUP_NAME \
        '{
            "jobs":
                    [
                        [.["jobs"][] | select(.name | contains($GROUP_NAME))][].name
                    ]
         }' | \
        json2yaml > $OUTPUT_FILE_NAME
}

fetch_or_clone_git_repo_into_directory() {
    REPO_URL=$1
    DIRECTORY=$2

    if [ -d $DIRECTORY ]; then
        if [ -n "${PARAM_APP_REQUESTBIN}" ]; then
            curl -X POST -d "F_OR_C=FETCH" http://requestb.in/$PARAM_APP_REQUESTBIN
        fi
        pushd .
        cd $DIRECTORY
        git fetch --prune
        git reset --hard FETCH_HEAD
        popd
    else
        if [ -n "${PARAM_APP_REQUESTBIN}" ]; then
            curl -X POST -d "F_OR_C=CLONE" http://requestb.in/$PARAM_APP_REQUESTBIN
        fi
        git clone $REPO_URL $DIRECTORY
    fi
}

updater_job_in_progress() {
    OUTPUT_FILE=$1

    echo "false" > $OUTPUT_FILE

    LOC_CONCOURSE_TARGET=savannah
    echo -e "$PARAM_CONCOURSE_USERNAME\n$PARAM_CONCOURSE_PASSWORD\n" | fly -t $LOC_CONCOURSE_TARGET login --concourse-url $PARAM_CONCOURSE_URL

    # Get job status log
    fly -t $LOC_CONCOURSE_TARGET builds -j $PARAM_APP_PIPELINE_NAME/$PARAM_APP_UPDATER_GROUP > $PARAM_APP_PIPELINE_NAME.$PARAM_APP_UPDATER_GROUP.txt

    # Get job current status
    JOB_LINE=$(head -n 1 $PARAM_APP_PIPELINE_NAME.$PARAM_APP_UPDATER_GROUP.txt)
    JOB_STATUS=$(echo $JOB_LINE | cut -d " " -f 4)

    if [ "$JOB_STATUS" == "started" ] ; then
        echo "true" > $OUTPUT_FILE
    else
        echo "false" > $OUTPUT_FILE
    fi
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
    CURRENT_DYNAMIC_PIPELINE_GROUPS=$(spruce json current_pipeline.yaml | jq '.["jobs"][] | select(.name | contains("updater")).plan[2].config.params.PARAM_BRANCH_LIST' | xargs)
    CURRENT_DYNAMIC_PIPELINE_GROUPS_UNSLASHED=`echo $CURRENT_DYNAMIC_PIPELINE_GROUPS | sed -e "s/\//-/g"`
    CURRENT_PIPELINE_GROUPS="$STATIC_GROUPS $PARAM_APP_DEV_ALL_BRANCHES_GROUP $CURRENT_DYNAMIC_PIPELINE_GROUPS_UNSLASHED"

    EXPECTED_PIPELINE_GROUPS_RAW="$STATIC_GROUPS"
    if [ -n "${APP_DEV_BRANCHES}" ]; then
        EXPECTED_PIPELINE_GROUPS_RAW="$STATIC_GROUPS $PARAM_APP_DEV_ALL_BRANCHES_GROUP $APP_DEV_BRANCHES"
    fi
    if [ -n "${APP_HOT_BRANCHES}" ]; then
        EXPECTED_PIPELINE_GROUPS_RAW="$EXPECTED_PIPELINE_GROUPS_RAW $APP_HOT_BRANCHES"
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

get_group_for_group_name() {
    INPUT_FILE=$1
    GROUP_NAME=$2
    OUTPUT_FILE=$3

    printf "name: $GROUP_NAME\njobs:\n" > group_node.yaml
    sed 's~jobs:~~g' $INPUT_FILE >> group_node.yaml
    spruce json group_node.yaml | jq '{"groups": [.]}' | json2yaml > $OUTPUT_FILE
}

get_branch_list_into_updater_param() {
    BRANCH_LIST=$1
    OUTPUT_FILE=$2

    printf "PARAM_BRANCH_LIST: $BRANCH_LIST" > param_branch_list_start.yaml
    spruce json param_branch_list_start.yaml | \
        jq '{"params":.}' | \
        jq '{"config":.}' | \
        jq '{"plan":[{"get" : "update-script"}, {"get" : "new-branches-watcher", trigger: true}, .]}' | \
        jq '{"jobs":[.]}' | \
        json2yaml > $OUTPUT_FILE
}

process_template_for_each_branch() {
    LANE_FOR_TEMPLATE_FILE=$1
    JOB_LIST_FOR_TEMPLATE_FILE=$2
    APP_BRANCHES=$3
    APP_TEMPLATE_GROUP=$4
    FULL_TABS_FOR_EACH_BRANCH_FILE=$5
    JOB_LIST_FOR_ALL_BRANCHES_FILE=$6

    APP_BRANCHES_LENGTH=${#APP_BRANCHES}

    IFS=' ' read -r -a APP_BRANCHES_ARRAY <<< "$APP_BRANCHES"

    FIRST_BRANCH=true
    for BRANCH_NAME in "${APP_BRANCHES_ARRAY[@]}"
    do
        # Can't use slashes in job names
        BRANCH_NAME_UNSLASHED=`echo $BRANCH_NAME | sed -e "s/\//-/g"`

        # Get branch name into the jobs/resources/group template
        sed 's~'"$APP_TEMPLATE_GROUP$PARAM_APP_SLAHES_OK_FLAG"'~'"$BRANCH_NAME"'~g' $LANE_FOR_TEMPLATE_FILE > lane_for_this_branch_with_slashes.yaml
        sed 's~'"$APP_TEMPLATE_GROUP"'~'"$BRANCH_NAME_UNSLASHED"'~g' lane_for_this_branch_with_slashes.yaml > lane_for_this_branch.yaml
        printf "\n" >> lane_for_this_branch.yaml

        # Get branch name into the list of jobs for the main group
        sed 's~'"$APP_TEMPLATE_GROUP"'~'"$BRANCH_NAME_UNSLASHED"'~g' $JOB_LIST_FOR_TEMPLATE_FILE > job_list_for_this_branch.yaml
        printf "\n" >> job_list_for_this_branch.yaml

        if [ "$APP_BRANCHES_LENGTH" -gt "1" ]; then
            # We need to hanle wrapping of group names
            # 1st, shorten some common prefixes and suffixes
            BRANCH_NAME_FOR_GROUP_1=${BRANCH_NAME_UNSLASHED/feature-/""}
            BRANCH_NAME_FOR_GROUP_2=${BRANCH_NAME_FOR_GROUP_1/fix-/""}
            BRANCH_NAME_FOR_GROUP=${BRANCH_NAME_FOR_GROUP_2/extraction/ext}
            echo $BRANCH_NAME_FOR_GROUP
            BRANCH_NAME_FOR_GROUP_LENGTH=${#BRANCH_NAME_FOR_GROUP}
            if [ "$BRANCH_NAME_FOR_GROUP_LENGTH" -gt "13" ]; then
                echo "Only shorten them if they are longer than 13 chars"
                BRANCH_NAME_REG_EX='(CORE|core|ZC|zc|JUNGLE|jungle)-*[0-9]+'
                echo "Try matching"
                echo "-${BRANCH_NAME_FOR_GROUP}-"
                echo "$BRANCH_NAME_REG_EX"
                [[ ${BRANCH_NAME_FOR_GROUP} =~ $BRANCH_NAME_REG_EX ]]
                echo "Get match length"
                BASH_REMATCH_LENGTH=${#BASH_REMATCH}
                echo "Check match length"
                if [ "$BASH_REMATCH_LENGTH" -gt "0" ]; then
                    echo "Match found"
                    if [ "${ALL_GROUP_NAMES/$BASH_REMATCH}" = "$ALL_GROUP_NAMES" ]; then
                        echo "Show only the JIRA ID where possible, and handle IDs used in more than 1 branch name"
                        GROUP_NAME=${BASH_REMATCH}
                    else
                        echo "Show just 1st 13 characters - 1"
                        GROUP_NAME="${BRANCH_NAME_FOR_GROUP:0:13}"
                    fi
                else
                    echo "Show just 1st 13 characters - 2"
                    GROUP_NAME="${BRANCH_NAME_FOR_GROUP:0:13}"
                fi
            else
                GROUP_NAME="${BRANCH_NAME_FOR_GROUP}"
            fi
        else
             GROUP_NAME="$BRANCH_NAME_FOR_GROUP"
        fi
        echo "---"
        echo "Final group name $GROUP_NAME"
        echo "---"
        ALL_GROUP_NAMES="${ALL_GROUP_NAMES}${GROUP_NAME}"
        echo "$ALL_GROUP_NAMES"

        spruce merge job_list_for_this_branch.yaml > job_array_for_this_branch.yaml
        get_group_for_group_name job_array_for_this_branch.yaml $GROUP_NAME group_for_this_branch.yaml

        # now add the branch pipeline to the pipeline of all branches
        if [ $FIRST_BRANCH == true ] ; then
            FIRST_BRANCH=false
            echo "Starting with $BRANCH_NAME_UNSLASHED"
            spruce merge lane_for_this_branch.yaml group_for_this_branch.yaml > $FULL_TABS_FOR_EACH_BRANCH_FILE
            # do the same for the main group section
            spruce merge job_list_for_this_branch.yaml > $JOB_LIST_FOR_ALL_BRANCHES_FILE
        else
            echo "Adding Branch $BRANCH_NAME_UNSLASHED"
            spruce merge $FULL_TABS_FOR_EACH_BRANCH_FILE lane_for_this_branch.yaml group_for_this_branch.yaml >> $FULL_TABS_FOR_EACH_BRANCH_FILE
            # do the same for the main group section
            spruce merge $JOB_LIST_FOR_ALL_BRANCHES_FILE job_list_for_this_branch.yaml >> $JOB_LIST_FOR_ALL_BRANCHES_FILE
        fi
    done
}

get_branch_list() {
    BRANCH_FILTER=$1
    OUTPUT_FILE=$2

    RECENT_UNMERGED_BRANCHES=""

    CUTOFF_DATE="1984-1-1"
    if [ -n "${PARAM_BRANCHES_FROM_DAYS_AGO}" ]; then
        CUTOFF_DATE=`[ "$(uname)" = Linux ] && date -d "-${PARAM_BRANCHES_FROM_DAYS_AGO} days" +"%Y"-"%m"-"%d" || date -v-${PARAM_BRANCHES_FROM_DAYS_AGO}d +"%Y"-"%m"-"%d"`
    fi

    cd $CONST_APP_GIT_DIR
    for UNMERGED_BRANCH in `git branch -r --no-merged`;do
        RECENT_UNMERGED_BRANCH=`git log --after="${CUTOFF_DATE}" --format="%ci" $UNMERGED_BRANCH | head -n 1`
        if [ -n "${RECENT_UNMERGED_BRANCH}" ]; then
            if [ -n "${BRANCH_FILTER}" ]; then
                RECENT_UNMERGED_BRANCHES="${RECENT_UNMERGED_BRANCHES} `echo ${UNMERGED_BRANCH} | sed 's/origin\///' | ${BRANCH_FILTER}`"
            else
                RECENT_UNMERGED_BRANCHES="${RECENT_UNMERGED_BRANCHES} `echo ${UNMERGED_BRANCH} | sed 's/origin\///'`"
            fi
        fi
    done

    echo "$RECENT_UNMERGED_BRANCHES" | xargs > $OUTPUT_FILE
}

match_test() {
    BRANCH_NAME_FOR_GROUP="rename-user-to-driver"
    BRANCH_NAME_REG_EX='(CORE|core|ZC|zc|JUNGLE|jungle)-*[0-9]+'
    echo "Try matching"
    echo "-${BRANCH_NAME_FOR_GROUP}-"
    echo "$BRANCH_NAME_REG_EX"
    [[ ${BRANCH_NAME_FOR_GROUP} =~ $BRANCH_NAME_REG_EX ]]
    echo "Get match length"
    BASH_REMATCH_LENGTH=${#BASH_REMATCH}
    echo $BASH_REMATCH_LENGTH
}