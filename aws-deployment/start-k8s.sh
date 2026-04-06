#!/bin/bash
. ./setenv.sh

BUCKET_NAME="${PROFILE}-${CONSULTANT_NAME}"
EXISTING_BUCKET="$(aws s3 ls --profile "${PROFILE}" | grep "${BUCKET_NAME}")"
if test -z "${EXISTING_BUCKET}"
then
    aws s3 mb "s3://${BUCKET_NAME}" --profile "${PROFILE}" 
fi

echo "Stackname=${STACKNAME}"
echo "Deploy started at $(date +%H:%M:%S), it will take about 15 minutes to finish"

aws cloudformation deploy --stack-name "${STACKNAME}" --template-file "./cloudformation.yaml" --parameter-overrides ConsultantName="${CONSULTANT_NAME}" --capabilities "CAPABILITY_NAMED_IAM" --s3-bucket "${BUCKET_NAME}" --profile "${PROFILE}"

IDS="$(aws cloudformation describe-stacks --stack-name ${STACKNAME} --profile "${PROFILE}")"
ID_CONTROL="$(echo ${IDS} | jq '.Stacks[0].Outputs[] | select(.OutputKey=="ControlNodeId") | .OutputValue' | awk -F'"' '{print $2}')"
ID_WORKER="$(echo ${IDS} | jq '.Stacks[0].Outputs[] | select(.OutputKey=="WorkerNodeId") | .OutputValue' | awk -F'"' '{print $2}')"

echo "---"
echo "ID of docker node: ${ID_CONTROL}"
echo "ID of control node: ${ID_CONTROL}"
echo "ID of worker node: ${ID_WORKER}"
echo ""
echo "Command to log on to the control node:"
echo "   aws ssm start-session --target ${ID_CONTROL} --profile ${PROFILE}"
echo ""
echo "On the control node use the following commands to go to the right account:"
echo "   sudo -i"
echo "   su - ${CONSULTANT_NAME}"

