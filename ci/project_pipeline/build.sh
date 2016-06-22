#!/usr/bin/env bash

set -e

p_start_file=$1
p_resources_file=$2
p_jobs_file=$3
merge_file=$4

cat $p_start_file $p_resources_file > $merge_file
printf "\n" >> $merge_file

count=0
for var in "$@"
do
    count=`expr $count + 1`
    if [ "$count" -gt "4" ] ; then
        sed 's~master~'"$var"'~g' $p_resources_file >> $merge_file
        printf "\n" >> $merge_file
    fi
done

printf "jobs:\n" >> $merge_file
printf "\n" >> $merge_file

cat $p_jobs_file >> $merge_file
printf "\n" >> $merge_file

count=0
for var in "$@"
do
    count=`expr $count + 1`
    if [ "$count" -gt "4" ] ; then
        sed 's~master~'"$var"'~g' $p_jobs_file >> $merge_file
        printf "\n" >> $merge_file
    fi
done

