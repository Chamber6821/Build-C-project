#!/bin/bash

SCRIPT_FOLDER=$(dirname "$(readlink -e "$0")")
mkdir -p Release source obj .project/log
cp -n ${SCRIPT_FOLDER}/options options
