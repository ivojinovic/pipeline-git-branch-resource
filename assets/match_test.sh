#!/usr/bin/env bash

BRANCH_NAME_FOR_GROUP="rename-user-to-driver"
BRANCH_NAME_REG_EX='(CORE|core|ZC|zc|JUNGLE|jungle)-*[0-9]+'
echo "Try matching"
echo "-${BRANCH_NAME_FOR_GROUP}-"
echo "$BRANCH_NAME_REG_EX"
[[ ${BRANCH_NAME_FOR_GROUP} =~ $BRANCH_NAME_REG_EX ]]
echo "Get match length"
BASH_REMATCH_LENGTH=${#BASH_REMATCH}
echo $BASH_REMATCH_LENGTH
