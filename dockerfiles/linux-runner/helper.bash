#!/usr/bin/env bash
# We are not using `set -Eeuo pipefail` here because this file is sourced by
# other scripts that might not be ready for a strict Bash setup. The functions
# in this file do not require it, because they are not handling signals, have
# no external calls that can fail (printf as well as date failures are ignored),
# are not using any variables that need to be set, and are not using any pipes.

source logger.bash

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

helper.app.credentials.valid() {
    if [[ $# -ne 2 ]] || [[ -z "$1" ]];
    then
        >&2 echo "Usage: $0 PRIVATE_KEY APP_ID"

        return 1
    fi

    private_key_file="$1"
    app_id=$2

    auth_header=$(helper.app.header "$private_key_file" $app_id)

    auth_test_result=$(curl -I -s -o /dev/null -w "%{http_code}" -H "${auth_header}" "https://api.github.com/app")
    if [ $auth_test_result != '200' ]; then
        return 1
    fi
    return 0
}

helper.app.installed() {
    if [[ $# -ne 3 ]] || [[ -z "$1" ]];
    then
        >&2 echo "Usage: $0 PRIVATE_KEY APP_ID RUNNER_ORG_NAME"

        return 1
    fi
    
    private_key_file="$1"
    app_id=$2
    runner_org_name=$3

    auth_header=$(helper.app.header "$private_key_file" $app_id) 

    response=$(curl -sX GET -H "Accept: application/vnd.github+json" -H "${auth_header}" "https://api.github.com/app/installations")
    installation_id=$(echo "$response"| jq -c ".[] | select( .account.login == \"${runner_org_name}\" ) | select( .target_type == \"Organization\" ) | .id" --raw-output)
    installation_test_result=$(curl -I -s -o /dev/null -w "%{http_code}" -H "${auth_header}" "https://api.github.com/app/installations/${installation_id}")
    if [ $installation_test_result != '200' ]; then
        return 1
    fi
    return 0
}

helper.app.installation.token() {
    if [[ $# -ne 3 ]] || [[ -z "$1" ]];
    then
        >&2 echo "Usage: $0 PRIVATE_KEY APP_ID RUNNER_ORG_NAME"

        exit 1
    fi
    
    private_key_file="$1"
    app_id=$2
    runner_org_name=$3

    auth_header=$(helper.app.header "$private_key_file" $app_id) 
    
    installation_response=$(curl -sX GET -H "Accept: application/vnd.github+json" -H "${auth_header}" "https://api.github.com/app/installations")
    installation_id=$(echo "$installation_response"| jq -c ".[] | select( .account.login == \"${runner_org_name}\" ) | select( .target_type == \"Organization\" ) | .id" --raw-output)

    token_response=$(curl -sX POST -H "Accept: application/vnd.github+json" -H "${auth_header}" -d '{"permissions":{"organization_self_hosted_runners":"write"}}' "https://api.github.com/app/installations/${installation_id}/access_tokens")
    installation_token=$(echo "$token_response" | jq .token --raw-output)
    echo "$installation_token"
}

helper.org.runner.registrationtoken() {
    if [[ $# -ne 2 ]] || [[ -z "$1" ]];
    then
        >&2 echo "Usage: $0 RUNNER_ORG_NAME API_TOKEN"

        exit 1
    fi
    
    runner_org_name="$1"
    api_token="$2"

    registration_token_uri="https://api.github.com/orgs/${runner_org_name}/actions/runners/registration-token"
    token_response=$(curl -sX POST -H "Accept: application/vnd.github.v3+json" -H "Authorization: Bearer ${api_token}" "${registration_token_uri}")
    registration_token=$(echo "$token_response" | jq .token --raw-output)
    echo "$registration_token"
}