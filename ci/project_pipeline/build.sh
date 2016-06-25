#!/usr/bin/env bash

set -e

# Get the original pipeline
fly -t savannah get-pipeline -p jarvis_api > original_pipeline.yaml

# Remove all jobs from it, except the the master jobs
# Creating "master only" pipeline
spruce json original_pipeline.yaml | jq '{"jobs": [.["jobs"][] | select(.name | contains("master"))], "resource_types": .["resource_types"], "resources": .["resources"]}' | json2yaml > master_pipeline.yaml

# Go through each branch name passed in
first=true
for var in "$@"
do
    # first, add the "master only" pipeline
    if [ $first == true ] ; then
        echo "Start with master"
        spruce merge master_pipeline.yaml > branches_pipeline.yaml
    fi
    first=false

    # create a branch copy of the "master only", and in this copy, replace all references to master with references to a branch
    # BUT ... prevent any ignore_branches: master from getting overwritten
    sed 's~ignore_branches: master~ignore_branches: mobster~g' master_pipeline.yaml > working_copy1.yaml
    branch_name_unslashed=`echo $var | sed -e "s/\//-/g"`
    sed 's~master~'"$branch_name_unslashed"'~g' working_copy1.yaml > working_copy2.yaml
    sed 's~ignore_branches: mobster~ignore_branches: master~g' working_copy2.yaml > $branch_name_unslashed.yaml
    printf "\n" >> $branch_name_unslashed.yaml

    # now add it
    echo "Add $branch_name_unslashed"
    spruce merge branches_pipeline.yaml $branch_name_unslashed.yaml >> branches_pipeline.yaml

    rm $branch_name_unslashed.yaml
    rm working_copy1.yaml
    rm working_copy2.yaml
done

rm original_pipeline.yaml
rm master_pipeline.yaml

# set the branches version
fly -t savannah set-pipeline -p jarvis_api_branches -c branches_pipeline.yaml

#cat $p_start_file $p_resources_file > $merge_file
#printf "\n" >> $merge_file
#
#count=0
#for var in "$@"
#do
#    count=`expr $count + 1`
#    if [ "$count" -gt "4" ] ; then
#        NOSLASH=`echo $var | sed -e "s/\//-/g"`
#        sed 's~name: master~name: '"$NOSLASH"'~g;s~branch: master~branch: '"$var"'~g' $p_resources_file >> $merge_file
#        printf "\n" >> $merge_file
#    fi
#done
#
#printf "jobs:\n" >> $merge_file
#printf "\n" >> $merge_file
#
#cat $p_jobs_file >> $merge_file
#printf "\n" >> $merge_file
#
#count=0
#for var in "$@"
#do
#    count=`expr $count + 1`
#    if [ "$count" -gt "4" ] ; then
#        NOSLASH=`echo $var | sed -e "s/\//-/g"`
#        sed 's~master~'"$NOSLASH"'~g' $p_jobs_file >> $merge_file
#        printf "\n" >> $merge_file
#    fi
#done
#
