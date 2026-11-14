#!/usr/bin/env bash
# Updates Chart.yaml and values.ci.yaml with the given docker tag.
# This is a stub — the smoke test chart has no image reference to update.
set -euo pipefail

TAG="${1:?Usage: $0 <docker-tag>}"

echo "Setting docker tag: ${TAG}"

yq -i ".version = \"0.1.0\"" chart/Chart.yaml
