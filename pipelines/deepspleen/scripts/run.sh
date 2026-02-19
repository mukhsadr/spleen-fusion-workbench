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
INFER_MODE="${DEEPSPLEEN_INFER_MODE:-legacy}"
DEFAULT_SIF="${REPO_ROOT}/inputs/containers/spiders_DeepSpleen.sif"
if [[ ! -f "${DEFAULT_SIF}" ]]; then
  DEFAULT_SIF="${REPO_ROOT}/spiders_DeepSpleen.sif"
fi
SIF_PATH="${DEEPSPLEEN_SIF:-${DEFAULT_SIF}}"
RUNTIME_DIR="${PIPE_DIR}/runtime"
OUT_DIR="${REPO_ROOT}/outputs/deepspleenseg/masks"
OUT_FILE="${OUT_DIR}/${CASE_ID}_mask.nii.gz"
TMP_DIR="${RUNTIME_DIR}/tmp/${CASE_ID}"
LAS_INPUT="${TMP_DIR}/input_las.nii.gz"
LAS_OUT="${TMP_DIR}/mask_las.nii.gz"
HELPER_PY="${RUNTIME_DIR}/extracted_spleen/miniconda/bin/python"
MOUNT_HELPER_PY="/tmp/deepspleen_sif_mount_${USER:-user}/extra/miniconda/bin/python"

mkdir -p "${OUT_DIR}" "${PIPE_DIR}/logs" "${PIPE_DIR}/data" "${TMP_DIR}"

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

if [[ ! -x "${HELPER_PY}" ]]; then
  if [[ -x "${MOUNT_HELPER_PY}" ]]; then
    HELPER_PY="${MOUNT_HELPER_PY}"
  else
    HELPER_PY="python3"
  fi
fi

echo "[deepspleen] reorient input to LAS"
"${HELPER_PY}" "${PIPE_DIR}/scripts/reorient_to_las.py" \
  --input "${INPUT_NII}" \
  --output "${LAS_INPUT}"

bash "${PIPE_DIR}/scripts/run_deepspleen_local.sh" run \
  --input-nii "${LAS_INPUT}" \
  --root "${RUNTIME_DIR}" \
  --output-nii "${LAS_OUT}" \
  --infer-mode "${INFER_MODE}" \
  --case-id "${CASE_ID}" \
  --batch-size "${BATCH_SIZE}" \
  --no-copy-runtime

echo "[deepspleen] restore output orientation to original"
"${HELPER_PY}" "${PIPE_DIR}/scripts/reorient_from_las.py" \
  --las_seg "${LAS_OUT}" \
  --orig_img "${INPUT_NII}" \
  --output "${OUT_FILE}"

echo "[deepspleen] done: ${OUT_FILE}"
