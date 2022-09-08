#!/usr/bin/env bash
set -Eeuo pipefail

# shellcheck source=runner/logger.bash
source logger.bash

log.debug "Running ARC Job Started Hooks"

for hook in $(find /etc/arc/hooks/job-started.d/ -name *.sh); do
  log.debug "Running hook: $hook"
  "$hook" "$@"
done