#!/usr/bin/env bash
set -eo pipefail

cd "$(dirname "$0")"

echo "Running tests..."

# Use systemd scope when available (ensures all descendant processes are killed)
# Fall back to direct execution in CI where systemd user session isn't available
run_cmd=(roc dev --linker=legacy test-runner.roc)
if systemctl --user show-environment &>/dev/null; then
    systemd-run --scope --user "${run_cmd[@]}"
else
    "${run_cmd[@]}"
fi
