#!/usr/bin/env bash
set -euo pipefail

bash "$(cd "$(dirname "$0")/.." && pwd)/scripts/purge.sh"

echo "Uninstalled."
