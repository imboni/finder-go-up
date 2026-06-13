#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
make all
echo "Built:"
echo "  build/finder-go-up-daemon"
echo "  build/finder-go-up-client"
echo "  build/finder-go-up.app"
