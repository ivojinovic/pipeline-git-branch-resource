#!/usr/bin/env bash

set -e

PIPELINE_NAME=$1

echo $PIPELINE_NAME

# Get the original pipeline
fly -t savannah get-pipeline -p $PIPELINE_NAME > original_pipeline.yaml

# Remove all jobs from it, except the the DEVBRANCH jobs
# Creating "DEVBRANCH only" pipeline
spruce json original_pipeline.yaml | jq '{"jobs": [.["jobs"][] | select(.name | contains("DEVBRANCH"))], "resource_types": .["resource_types"], "resources": .["resources"]}' | json2yaml > DEVBRANCH_pipeline_0.yaml

spruce json original_pipeline.yaml | jq '{"groups": [.["groups"][] | select(.name | contains("dev"))]}' | json2yaml > dev_groups.yaml
sed 's~dev~DEVBRANCH~g' dev_groups.yaml > DEVBRANCH_groups.yaml

spruce merge DEVBRANCH_pipeline_0.yaml DEVBRANCH_groups.yaml > DEVBRANCH_pipeline.yaml

# Go through each branch name passed in
count=1
#page_count=0
file_is_blank=true
first_var=true
for var in "$@"
do
    if [ $first_var == true ] ; then
        first_var=false
        continue
    fi
    # create a branch copy of the "DEVBRANCH only", and in this copy, replace all references to DEVBRANCH with references to a branch
    # BUT ... prevent any ignore_branches: DEVBRANCH from getting overwritten
    sed 's~ignore_branches: DEVBRANCH~ignore_branches: mobster~g' DEVBRANCH_pipeline.yaml > working_copy1.yaml
    branch_name_unslashed=`echo $var | sed -e "s/\//-/g"`
    sed 's~DEVBRANCH~'"$branch_name_unslashed"'~g' working_copy1.yaml > working_copy2.yaml
    sed 's~ignore_branches: mobster~ignore_branches: DEVBRANCH~g' working_copy2.yaml > $branch_name_unslashed.yaml
    printf "\n" >> $branch_name_unslashed.yaml

    # now add it
    if [ $file_is_blank == true ] ; then
        echo "New Page with $branch_name_unslashed"
        spruce merge $branch_name_unslashed.yaml > branches_pipeline.yaml
        file_is_blank=false
    else
        echo "Adding Branch $branch_name_unslashed"
        spruce merge branches_pipeline.yaml $branch_name_unslashed.yaml >> branches_pipeline.yaml
    fi
    count=`expr $count + 1`

    rm $branch_name_unslashed.yaml
    rm working_copy1.yaml
    rm working_copy2.yaml
done

rm original_pipeline.yaml
rm DEVBRANCH_pipeline.yaml
rm DEVBRANCH_pipeline_0.yaml
rm DEVBRANCH_groups.yaml
rm dev_groups.yaml

echo $PIPELINE_NAME

fly -t savannah set-pipeline -p jarvis_api_ddb_dev -c branches_pipeline.yaml

rm branches_pipeline.yaml
