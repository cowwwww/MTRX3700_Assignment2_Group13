#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
python3 tools/prepare_h95.py
python3 tools/run_tests.py extract_h95_features
python3 tools/train_h95.py
python3 tools/check_project.py --require-trained
python3 tools/run_tests.py tb_h95_classifier
