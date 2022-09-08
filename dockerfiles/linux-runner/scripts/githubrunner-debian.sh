#!/bin/bash
#-------------------------------------------------------------------------------------------------------------
# Copyright (c) Thijs De Meester. All rights reserved.
# Licensed under the MIT License. 
#-------------------------------------------------------------------------------------------------------------
#
# Syntax: ./githubrunner-debian.sh [directory to install runner] [github runner version to install (use "latest" to install latest)] [non-root user]

export INSTALL_DIR=${1:-"/usr/local/share/actions-runner"}
export RUNNER_VERSION=${2:-"latest"}
USERNAME=${3:-"root"}

set -e

if [ "$(id -u)" -ne 0 ]; then
    echo -e 'Script must be run as root. Use sudo, su, or add "USER root" to your Dockerfile before running this script.'
    exit 1
fi

if [ "${USERNAME}" = "none" ] || ! id -u ${USERNAME} > /dev/null 2>&1; then
    USERNAME=root
fi

# adjust version
if [ "${RUNNER_VERSION}" = "latest" ]; then INSTALL_VERSION=$(curl -so- https://api.github.com/repos/actions/runner/releases/latest | jq --raw-output .name); 
elif [ "${RUNNER_VERSION:0:1}" = "v" ]; then INSTALL_VERSION="${RUNNER_VERSION:1}" ; else exit 22; fi

if [ ! -d "${INSTALL_DIR}" ]; then
    mkdir -p "${INSTALL_DIR}"
fi

# download runner
cd "${INSTALL_DIR}"
curl -O -L -o runner.tar.gz https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz
tar xzf ./runner.tar.gz
rm runner.tar.gz

echo "installing dependacies"
./bin/installdependencies.sh
chown -R "${USERNAME}" "${INSTALL_DIR}"

apt-get install -y libyaml-dev