#!/usr/bin/env bash
set -euo pipefail

INPUT_NII="${1:-}"
if [[ -z "${INPUT_NII}" ]]; then
  echo "Usage: bash scripts/run.sh /path/to/input.nii.gz"
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/env/.venv"
LOG_DIR="${ROOT_DIR}/logs"
OUT_DIR="${ROOT_DIR}/outputs/totalseg_$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/run_$(date +%Y%m%d_%H%M%S).log"
TASK="${TOTALSEG_TASK:-spleen}"
FAST_FLAG="${TOTALSEG_FAST:-1}"

mkdir -p "${LOG_DIR}" "${OUT_DIR}" "${ROOT_DIR}/env"

if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
  echo "[totalsegmentator] missing venv at ${VENV_DIR}"
  echo "[totalsegmentator] run: bash ${ROOT_DIR}/scripts/setup_env.sh"
  exit 1
fi

source "${VENV_DIR}/bin/activate"

CMD=(TotalSegmentator -i "${INPUT_NII}" -o "${OUT_DIR}" --task "${TASK}")
if [[ "${FAST_FLAG}" == "1" ]]; then
  CMD+=(--fast)
fi

echo "[totalsegmentator] input: ${INPUT_NII}" | tee "${LOG_FILE}"
echo "[totalsegmentator] output: ${OUT_DIR}" | tee -a "${LOG_FILE}"
echo "[totalsegmentator] command: ${CMD[*]}" | tee -a "${LOG_FILE}"
"${CMD[@]}" 2>&1 | tee -a "${LOG_FILE}"

echo "[totalsegmentator] done" | tee -a "${LOG_FILE}"
