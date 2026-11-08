#!/bin/bash
set -euo pipefail
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$HERE/.."
python3 -m unittest discover -s tests -v
