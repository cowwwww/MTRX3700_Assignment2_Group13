#!/bin/sh
set -eu
cd "$(dirname "$0")"
# Check saved recordings before building the demo image.
python3 tools/check_project.py --require-trained
quartus_sh --flow compile shine_sing
quartus_sta -t tools/report_timing.tcl
