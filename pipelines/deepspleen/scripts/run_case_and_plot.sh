#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: bash scripts/run_case_and_plot.sh <CASE_ID> [--wl 50] [--ww 400] [--mitk <exe>]"
  echo "Example: bash scripts/run_case_and_plot.sh CT1 --wl 50 --ww 350"
  exit 1
fi

CASE_ID="$1"
shift

PIPE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${PIPE_DIR}/../.." && pwd)"
INPUT_NII="${REPO_ROOT}/inputs/${CASE_ID}.nii.gz"

if [[ ! -f "${INPUT_NII}" ]]; then
  echo "Input not found: ${INPUT_NII}"
  exit 1
fi

bash "${PIPE_DIR}/scripts/run.sh" "${INPUT_NII}" "case_${CASE_ID}"
bash "${PIPE_DIR}/scripts/open_in_mitk.sh" --case "${CASE_ID}" "$@"

