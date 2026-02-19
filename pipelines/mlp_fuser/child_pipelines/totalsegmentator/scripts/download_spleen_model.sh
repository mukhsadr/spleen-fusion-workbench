#!/usr/bin/env bash
set -euo pipefail

INPUT_NII="${1:-}"
if [[ -z "${INPUT_NII}" ]]; then
  echo "Usage: bash scripts/download_spleen_model.sh /path/to/input.nii.gz"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/env/.venv"
TMP_OUT="${ROOT_DIR}/outputs/_download_check"
LOG_DIR="${ROOT_DIR}/logs"
mkdir -p "${TMP_OUT}" "${LOG_DIR}"

if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  echo "[totalsegmentator] missing venv at ${VENV_DIR}"
  echo "[totalsegmentator] run: bash ${ROOT_DIR}/scripts/setup_env.sh"
  exit 1
fi

source "${VENV_DIR}/bin/activate"

echo "[totalsegmentator] triggering spleen model download"
TotalSegmentator -i "${INPUT_NII}" -o "${TMP_OUT}" --task spleen --fast
echo "[totalsegmentator] download complete"
