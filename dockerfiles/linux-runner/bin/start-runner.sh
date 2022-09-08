#!/usr/bin/env bash

# Authentication information
# 2 methods of authentication
# user -> pass PAT in GH_TOKEN
# github app -> pass app_id and private key in GH_APP_ID and GH_APP_SECRET
# if neither or both are specified script fails
#
set -e

GH_TOKEN=$GH_TOKEN
GH_APP_ID=$GH_APP_ID
GH_APP_SECRET=$GH_APP_SECRET

GH_ORGANIZATION=$GH_ORGANIZATION
GH_REPOSITORY=$GH_REPOSITORY

RUNNER_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
RUNNER_NAME="dockerNode-${RUNNER_SUFFIX}"
#####
# test for authentication inputs and test authentication
#####

# check for auth mechanism and build header function rest actions.
if   [[  ! -z "$GH_APP_SECRET" &&  ! -z "$GH_APP_ID" &&   -z "$GH_TOKEN" ]]; then
    echo "NOTICE:${RUNNER_NAME}:Authentication as GH APP"
    header() {
        SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd ) 
        jwt=$(source ${SCRIPT_DIR}/generate-jwt.sh "$GH_APP_SECRET" $GH_APP_ID)
        echo "Authorization: Bearer ${jwt}" 
    }
    authentication_type='app'
elif [[    -z "$GH_APP_SECRET" &&    -z "$GH_APP_ID" && ! -z "$GH_TOKEN" ]]; then
    echo "NOTICE:${RUNNER_NAME}:Authentication as GH USER"
    header() { echo "Authorization: token ${GH_TOKEN}" ;}
    authentication_type='user'
else
    echo "ERROR:${RUNNER_NAME}:Authentication input invalid. Authentication as a user passing PAT trough GH_TOKEN or as an app with environment variables GH_APP_ID and GH_APP_SECRET. Specify one."
    exit
fi

# check if authentication credentials are valid
auth_test_result=$(curl -I -s -o /dev/null -w "%{http_code}" -H "$(header)" "https://api.github.com/${authentication_type}")
if [ $auth_test_result != '200' ]; then
    echo "ERROR:${RUNNER_NAME}:Bad credentials. check if your github $authentication_type credentials are valid"
    echo ""
    exit
fi

####
# test for registration location input and test for access
####

if [ -n "$GH_ORGANIZATION" ] && [ -z "$GH_REPOSITORY" ]; then
    echo "NOTICE:${RUNNER_NAME}:registering runner with GH organisation ${GH_ORGANIZATION}"
    TOKEN_API_URL="https://api.github.com/orgs/${GH_ORGANIZATION}/actions/runners/registration-token"
    RUNNER_REGISTRATION_LOCATION="https://github.com/${GH_ORGANIZATION}"
elif [ -n "$GH_ORGANIZATION" ] && [ -n "$GH_REPOSITORY" ]; then
    echo "NOTICE:${RUNNER_NAME}:registering runner with GH repository ${GH_ORGANIZATION}/${GH_REPOSITORY}"
    TOKEN_API_URL="https://api.github.com/repos/${GH_ORGANIZATION}/${GH_REPOSITORY}/actions/runners/registration-token"
    RUNNER_REGISTRATION_LOCATION="https://github.com/${GH_ORGANIZATION}/${GH_REPOSITORY}"
else
    echo "ERROR:${RUNNER_NAME}:No valid registration location found. specify either GH_ORGANIZATION or GH_ORGANIZATION and GH_REPOSITORY to dictate the registration location."
    exit 22
fi


REG_TOKEN=$(curl -sX POST -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${INSTALLATION_PAT}" "${TOKEN_API_URL}" | jq .token --raw-output)

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