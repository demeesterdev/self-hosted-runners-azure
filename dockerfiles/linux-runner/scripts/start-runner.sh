#!/bin/bash

GH_TOKEN=$GH_TOKEN
GH_ORGANIZATION=$GH_ORGANIZATION
GH_REPOSITORY=$GH_REPOSITORY

RUNNER_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
RUNNER_NAME="dockerNode-${RUNNER_SUFFIX}"

if [ -z "$GH_TOKEN" ]; then
    echo "No token specified in environment variable GH_TOKEN. pass token with appriopriate permissions"
    exit 22
fi

if [ -n "$GH_ORGANIZATION" ] && [ -z "$GH_REPOSITORY" ]; then
    echo "registering runner with GH organisation ${GH_ORGANIZATION}"
    TOKEN_API_URL="https://api.github.com/orgs/${GH_ORGANIZATION}/actions/runners/registration-token"
    RUNNER_REGISTRATION_LOCATION="https://github.com/${GH_ORGANIZATION}"
elif [ -n "$GH_ORGANIZATION" ] && [ -n "$GH_REPOSITORY" ]; then
    echo "registering runner with GH repository ${GH_ORGANIZATION}/${GH_REPOSITORY}"
    TOKEN_API_URL="https://api.github.com/repos/${GH_ORGANIZATION}/${GH_REPOSITORY}/actions/runners/registration-token"
    RUNNER_REGISTRATION_LOCATION="https://github.com/${GH_ORGANIZATION}/${GH_REPOSITORY}"
else
    echo "No valid registration location found. specify either GH_ORGANIZATION or GH_ORGANIZATION and GH_REPOSITORY to dictate the registration location."
    exit 22
fi


REG_TOKEN=$(curl -sX POST -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${GH_TOKEN}" "${TOKEN_API_URL}" | jq .token --raw-output)

cd /home/runner/actions-runner
echo "starting runner"
echo ""
echo "./config.sh --unattended --url ${RUNNER_REGISTRATION_LOCATION} --token ****** --name ${RUNNER_NAME} --ephemeral --disableupdate"
./config.sh --unattended --url ${RUNNER_REGISTRATION_LOCATION} --token ${REG_TOKEN} --name ${RUNNER_NAME} --ephemeral --disableupdate

cleanup() {
    echo "Removing runner..."
    ./config.sh remove --unattended --token ${REG_TOKEN}
}

trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

./run.sh & wait $!