#!/usr/bin/env bash
set -euo pipefail

INPUT_NII="${1:-}"
if [[ -z "${INPUT_NII}" ]]; then
  echo "Usage: bash scripts/run.sh /path/to/input.nii.gz"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo "[totalsegmentator] TODO pipeline implementation"
echo "[totalsegmentator] input: ${INPUT_NII}"
echo "[totalsegmentator] output dir: ${ROOT_DIR}/outputs"
