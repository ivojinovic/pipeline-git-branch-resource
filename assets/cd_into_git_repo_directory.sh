#!/usr/bin/env bash

REPO_URL=$1
DIRECTORY=$2

if [ -d $DIRECTORY ]; then
  cd $DIRECTORY
  git fetch
  git reset --hard FETCH_HEAD
else
  git clone $REPO_URL $DIRECTORY
  cd $DIRECTORY
fi
