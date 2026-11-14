#!/bin/bash
set -euo pipefail

if [ "${1:-}" = "" ]; then
  echo "Usage: $0 <version-or-ref>"
  exit 1
fi

VERSION="$1"

echo "Editing files with given version/ref: ${VERSION}"
