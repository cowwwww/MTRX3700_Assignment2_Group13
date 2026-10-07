#!/bin/sh
set -eu
cd "$(dirname "$0")"
python3 tools/check_project.py
python3 tools/lint_top.py
python3 tools/run_tests.py --sim verilator "$@"
