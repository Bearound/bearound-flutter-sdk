#!/usr/bin/env bash
set -euo pipefail
launcher_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec python3 "$launcher_dir/physical_check.py" "$@"
