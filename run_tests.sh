#!/usr/bin/env bash
# Runs the GUT unit tests headless. Exit code is non-zero if any test fails.
set -euo pipefail
cd "$(dirname "$0")"
# Build the class cache on first run (or after adding class_name scripts).
godot --headless --import >/dev/null 2>&1 || true
godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@"
