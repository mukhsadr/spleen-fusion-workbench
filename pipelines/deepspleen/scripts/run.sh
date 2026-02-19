#!/usr/bin/env bash
set -euo pipefail

INPUT_NII="${1:-}"
if [[ -z "${INPUT_NII}" ]]; then
  echo "Usage: bash scripts/run.sh /path/to/input.nii.gz [case_id]"
  exit 1
fi

PIPE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${PIPE_DIR}/../.." && pwd)"
ENV_FILE="${PIPE_DIR}/configs/deepspleen.env"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

CASE_ID="${2:-${DEEPSPLEEN_CASE_ID:-case001}}"
BATCH_SIZE="${DEEPSPLEEN_BATCH:-4}"
DEFAULT_SIF="${REPO_ROOT}/inputs/containers/spiders_DeepSpleen.sif"
if [[ ! -f "${DEFAULT_SIF}" ]]; then
  DEFAULT_SIF="${REPO_ROOT}/spiders_DeepSpleen.sif"
fi
SIF_PATH="${DEEPSPLEEN_SIF:-${DEFAULT_SIF}}"
RUNTIME_DIR="${PIPE_DIR}/runtime"
OUT_FILE="${PIPE_DIR}/outputs/${CASE_ID}_mask.nii.gz"

mkdir -p "${PIPE_DIR}/outputs" "${PIPE_DIR}/logs" "${PIPE_DIR}/data"

if [[ ! -f "${INPUT_NII}" ]]; then
  echo "[deepspleen] missing input NIfTI: ${INPUT_NII}"
  exit 1
fi

if [[ ! -d "${RUNTIME_DIR}/extracted_spleen" ]]; then
  if [[ ! -f "${SIF_PATH}" ]]; then
    echo "[deepspleen] missing runtime and SIF not found: ${SIF_PATH}"
    echo "[deepspleen] provide SIF or place extracted runtime at ${RUNTIME_DIR}/extracted_spleen"
    exit 1
  fi
  echo "[deepspleen] runtime not initialized, running setup first"
  bash "${PIPE_DIR}/scripts/setup.sh"
fi

echo "[deepspleen] running inference"
echo "[deepspleen] input : ${INPUT_NII}"
echo "[deepspleen] output: ${OUT_FILE}"

bash "${PIPE_DIR}/scripts/run_deepspleen_local.sh" run \
  --input-nii "${INPUT_NII}" \
  --root "${RUNTIME_DIR}" \
  --output-nii "${OUT_FILE}" \
  --case-id "${CASE_ID}" \
  --batch-size "${BATCH_SIZE}" \
  --no-copy-runtime

echo "[deepspleen] done: ${OUT_FILE}"
