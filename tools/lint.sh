#!/usr/bin/env bash
# GDScript formatting and lint checks (gdtoolkit, pinned in tools/requirements-dev.txt).
# Usage: tools/lint.sh          # check only (CI)
#        tools/lint.sh --fix    # reformat in place
set -euo pipefail
cd "$(dirname "$0")/../game"
dirs=(scripts tests tools)
if [[ "${1:-}" == "--fix" ]]; then
  gdformat --line-length 120 "${dirs[@]}"
else
  gdformat --check --line-length 120 "${dirs[@]}"
fi
cp ../.gdlintrc gdlintrc
trap 'rm -f gdlintrc' EXIT
gdlint "${dirs[@]}"
