#!/usr/bin/env bash
# Imports the project, then compiles every script. Non-zero exit on any error.
set -uo pipefail
cd "$(dirname "$0")/.."
./tools/godot.sh --headless --path game --import >/dev/null 2>&1
out=$(./tools/godot.sh --headless --path game --script res://tools/parse_all.gd 2>&1)
status=$?
printf '%s\n' "$out" | grep -A1 -E "SCRIPT ERROR|FAILED|Parsed" | grep -v "^--" | sed 's/   at: GDScript::reload//'
exit $status
