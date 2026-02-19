#!/usr/bin/env bash
set -euo pipefail

PIPE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${PIPE_DIR}/../.." && pwd)"
ENV_FILE="${PIPE_DIR}/configs/deepspleen.env"

if [[ -f "${ENV_FILE}" ]]; then
  # shellcheck disable=SC1090
  source "${ENV_FILE}"
fi

DEFAULT_SIF="${REPO_ROOT}/inputs/containers/spiders_DeepSpleen.sif"
if [[ ! -f "${DEFAULT_SIF}" ]]; then
  DEFAULT_SIF="${REPO_ROOT}/spiders_DeepSpleen.sif"
fi
SIF_PATH="${DEEPSPLEEN_SIF:-${DEFAULT_SIF}}"
RUNTIME_DIR="${PIPE_DIR}/runtime"

mkdir -p "${PIPE_DIR}/outputs" "${PIPE_DIR}/logs" "${PIPE_DIR}/data"

if [[ ! -f "${SIF_PATH}" ]]; then
  echo "[deepspleen] missing SIF: ${SIF_PATH}"
  exit 1
fi

echo "[deepspleen] setup using SIF: ${SIF_PATH}"
bash "${PIPE_DIR}/scripts/run_deepspleen_local.sh" setup \
  --sif "${SIF_PATH}" \
  --root "${RUNTIME_DIR}" \
  --no-copy-runtime

echo "[deepspleen] setup complete: ${RUNTIME_DIR}"
