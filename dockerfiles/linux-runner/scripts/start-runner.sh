#!/bin/bash

# ---
# local variables
# ---

RUNNER_SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 5 | head -n 1)
RUNNER_NAME="dockerNode-${RUNNER_SUFFIX}"

# ---
# helper functions
# ---

helper.app.generatejwt() { 
    if [[ $# -ne 2 ]] || [[ -z "$1" ]];
    then
        >&2 echo "Usage: $0 PRIVATE_KEY APP_ID"

        return 1
    fi

    private_key_file="$1"
    app_id=$2

    current_time=$(date +%s)
    # issued at time, 60 seconds in the past to allow for clock drift
    iat_time=$(($current_time - 60))
    # the maxiumum expiration time is 10 minutes, but we set it to 9 minutes
    # to avoid clock skew differences between us and GitHub (which would cause GitHub to reject the token,
    # because the expiration time is set too far in the future).
    exp_time=$(($current_time + 9 * 60))

    header='{
        "alg":"RS256"
    }'
    payload='{
        "iat":'$iat_time',
        "exp":'$exp_time',
        "iss":'$app_id'
    }'

    compact_json() {
        jq -c '.' | tr -d '\n'
    }

    base64url_encode() {
        openssl enc -base64 -A | tr '+/' '-_' | tr -d '='
    }

    rs_sign() { 
        openssl dgst -binary -sha256 -sign <(printf '%s\n' "$1") 
    }

    encoded_header=$(echo $header | compact_json | base64url_encode)
    encoded_payload=$(echo $payload | compact_json | base64url_encode)
    encoded_body="$encoded_header.$encoded_payload"
    signature=$(echo -n $encoded_body | rs_sign "$1" | base64url_encode)

    echo "$encoded_body.$signature"
}

helper.app.header() {
    if [[ $# -ne 2 ]] || [[ -z "$1" ]];
    then
        >&2 echo "Usage: $0 PRIVATE_KEY APP_ID"

        return 1
    fi

    private_key_file="$1"
    app_id=$2

    jwt=$(helper.app.generatejwt "$private_key_file" $app_id) 
    echo "Authorization: Bearer $jwt" 
}

# --- 
# check input params
# ---

# registration organization
if [ -n "$RUNNER_ORGANIZATION" ] ; then
    echo "registering runner with GH organization ${RUNNER_ORGANIZATION}"
    TOKEN_API_URL="https://api.github.com/orgs/${RUNNER_ORGANIZATION}/actions/runners/registration-token"
    RUNNER_REGISTRATION_LOCATION="https://github.com/${RUNNER_ORGANIZATION}"
else
    echo "No valid registration location found. specify RUNNER_ORGANIZATION to dictate the registration location."
    exit 22
fi

# authentication mechanism
if [ -n "${RUNNER_APP_SECRET}" ] && [ -n "${RUNNER_APP_ID}" ] && [ -n "${RUNNER_PAT}" ] ; then
    echo 'either app credentials (RUNNER_APP_SECRET and RUNNER_APP_ID) or user credentials (RUNNER_PAT) need to be set. not both.'
    exit 1
elif [ -n "${RUNNER_PAT}" ] ; then
    echo 'authenticating as user'
    RUNNER_TOKEN="${RUNNER_PAT}"
elif [ -n "${RUNNER_APP_SECRET}" ] && [ -n "${RUNNER_APP_ID}" ]; then
    echo "authenticating as github app"
    app_auth_header=$(helper.app.header "${RUNNER_APP_SECRET}" "${RUNNER_APP_ID}")

    # testing authentication
    retries_left=10
    while [[ ${retries_left} -gt 0 ]]; do
        echo "validate authentication"
        auth_test_result=$(curl -I -s -o /dev/null -w "%{http_code}" -H "${app_auth_header}" "https://api.github.com/app")
       
        if [ "$auth_test_result" == '200' ]; then
            echo 'App successfully authenticated.'
            break
        fi
   
        echo 'App authentication failed. Retrying'
        retries_left=$((retries_left - 1))
        sleep 1
    done

    if [ "$auth_test_result" != '200' ]; then
        echo 'App authentication failed.'
        exit 2
    fi  

    # test authorization for organization
    retries_left=10
    while [[ ${retries_left} -gt 0 ]]; do
        echo "Get app installation token for organization ${RUNNER_ORGANIZATION}"
        response=$(curl -sX GET -H "Accept: application/vnd.github+json" -H "${app_auth_header}" "https://api.github.com/app/installations")
        installation_id=$(echo "$response"| jq -c ".[] | select( .account.login == \"${RUNNER_ORGANIZATION}\" ) | select( .target_type == \"Organization\" ) | .id" --raw-output)
        echo "installation id: ${installation_id}"
        installation_test_result=$(curl -I -s -o /dev/null -w "%{http_code}" -H "${app_auth_header}" "https://api.github.com/app/installations/${installation_id}")
        if [ "${installation_test_result}" != '200' ]; then
            echo 'Could not find installation. Retrying'
            retries_left=$((retries_left - 1))
            continue
        fi

        token_response=$(curl -sX POST -H "Accept: application/vnd.github+json" -H "${app_auth_header}" -d '{"permissions":{"organization_self_hosted_runners":"write"}}' "https://api.github.com/app/installations/${installation_id}/access_tokens")
        installation_token=$(echo "$token_response" | jq .token --raw-output)

        if [ "$installation_token" != '' ]; then
            echo 'Installation token successfully retrieved.'
            break
        fi

        echo "Could not get token for installation ${installation_id}. Retrying"
        retries_left=$((retries_left - 1))
        sleep 1
    done

    if [ "$installation_token" == '' ]; then
        echo "Could not get app installation token for organization ${RUNNER_ORGANIZATION}"
        exit 2
    fi

    RUNNER_TOKEN="${installation_token}"
else
  echo 'either app credentials (RUNNER_APP_SECRET and RUNNER_APP_ID) or user credentials (RUNNER_PAT) need to be set and valid.'
  exit 1
fi
TOKEN_RESPONSE=$(curl -sX POST -H "Accept: application/vnd.github.v3+json" -H "Authorization: token ${RUNNER_TOKEN}" "$TOKEN_API_URL")
RUNNER_REGISTRATION_TOKEN=$(echo "${TOKEN_RESPONSE}" | jq .token --raw-output)

cd /home/runner/actions-runner

cleanup() {
    echo "Removing runner..."
    ./config.sh remove --unattended --token ${RUNNER_REGISTRATION_TOKEN}
}
trap 'cleanup; exit' EXIT
trap 'cleanup; exit 130' INT
trap 'cleanup; exit 143' TERM

retries_left=2
while [[ ${retries_left} -gt 0 ]]; do
  echo 'Configuring the runner.'
  ./config.sh --unattended --url ${RUNNER_REGISTRATION_LOCATION} --token ${RUNNER_REGISTRATION_TOKEN} --name ${RUNNER_NAME} --ephemeral --disableupdate
    

  if [ -f .runner ]; then
    echo 'Runner successfully configured.'
    break
  fi

  echo 'Configuration failed. Retrying'
  retries_left=$((retries_left - 1))
  sleep 1
done

if [ ! -f .runner ]; then
  # we couldn't configure and register the runner; no point continuing
  echo 'Configuration failed!'
  exit 2
fi

# Unset entrypoint environment variables so they don't leak into the runner environment
unset RUNNER_NAME RUNNER_REPO RUNNER_TOKEN RUNNER_PAT RUNNER_REGISTRATION_TOKEN RUNNER_APP_ID RUNNER_APP_SECRET STARTUP_DELAY_IN_SECONDS DISABLE_WAIT_FOR_DOCKER

exec env -- "${env[@]}" ./run.sh 