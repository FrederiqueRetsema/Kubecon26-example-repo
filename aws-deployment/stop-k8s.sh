#!/bin/bash
. ./setenv.sh

NAMES=$(aws cloudformation describe-stacks --profile "${PROFILE}" | jq '.Stacks[].StackName' | awk -F'"' '{print $2}' | grep "${STACKNAME}")

for NAME in ${NAMES}
do
  echo "Delete stack ${NAME}"
  aws cloudformation delete-stack --stack-name "${NAME}" --profile "${PROFILE}"
done
