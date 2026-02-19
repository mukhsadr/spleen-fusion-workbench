#!/usr/bin/env bash
set -euo pipefail

INPUT_NII="${1:-}"
if [[ -z "${INPUT_NII}" ]]; then
  echo "Usage: bash scripts/run_all.sh /path/to/input.nii.gz"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[mlp_fuser] input: ${INPUT_NII}"
bash "${ROOT_DIR}/child_pipelines/totalsegmentator/scripts/run.sh" "${INPUT_NII}"
bash "${ROOT_DIR}/child_pipelines/gennunt/scripts/run.sh" "${INPUT_NII}"
bash "${ROOT_DIR}/child_pipelines/nv_segmentation/scripts/run.sh" "${INPUT_NII}"

echo "[mlp_fuser] child pipelines finished"
echo "[mlp_fuser] next: add fusion step in ${ROOT_DIR}/scripts"
