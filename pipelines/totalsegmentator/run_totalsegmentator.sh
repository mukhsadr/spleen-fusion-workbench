#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run_totalseg_cpu.sh install [--with-sudo-deps]
  run_totalsegmentator.sh run --input <input.nii|input.nii.gz> --output <output_dir> [--task total|spleen] [--fast]
  run_totalsegmentator.sh all --input <input.nii|input.nii.gz> --output <output_dir> [--task total|spleen] [--fast] [--with-sudo-deps]

Commands:
  install   Create venv and install CPU torch + TotalSegmentator
  run       Run TotalSegmentator on given input/output
  all       Install (if needed) + run

Options:
  --input <path>            Input NIfTI
  --output <dir>            Output folder
  --task <name>             TotalSegmentator task (default: spleen shortcut)
  --fast                    Add --fast flag
  --with-sudo-deps          Install system deps via apt (python3-pip python3.12-venv)
  -h, --help                Show this help
EOF
}

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${ROOT_DIR}/env/.venv"
LOG_DIR="${ROOT_DIR}/logs"
TS_HOME_DIR="${ROOT_DIR}/env/.totalsegmentator"
mkdir -p "${ROOT_DIR}/env" "${LOG_DIR}"

CMD="${1:-}"
[[ -n "${CMD}" ]] || { usage; exit 1; }
shift || true

INPUT=""
OUTPUT=""
TASK="spleen"
FAST="0"
WITH_SUDO_DEPS="0"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) INPUT="$2"; shift 2 ;;
    --output) OUTPUT="$2"; shift 2 ;;
    --task) TASK="$2"; shift 2 ;;
    --fast) FAST="1"; shift ;;
    --with-sudo-deps) WITH_SUDO_DEPS="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1"; usage; exit 1 ;;
  esac
done

install_env() {
  if [[ "${WITH_SUDO_DEPS}" == "1" ]]; then
    sudo apt-get update
    sudo apt-get install -y python3-pip python3.12-venv
  fi

  command -v python3 >/dev/null 2>&1 || { echo "python3 missing"; exit 1; }
  python3 -m venv "${VENV_DIR}" || {
    echo "Failed to create venv. Try:"
    echo "  sudo apt-get install -y python3-pip python3.12-venv"
    exit 1
  }

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"
  python -m pip install --upgrade pip wheel setuptools
  python -m pip install --no-cache-dir \
    --index-url https://download.pytorch.org/whl/cpu \
    torch torchvision
  python -m pip install --no-cache-dir TotalSegmentator

  python - <<'PY'
import importlib, torch
importlib.import_module("totalsegmentator")
print("totalsegmentator OK")
print("torch", torch.__version__, "cuda_available", torch.cuda.is_available())
PY
}

run_inference() {
  [[ -n "${INPUT}" ]] || { echo "--input is required"; exit 1; }
  [[ -n "${OUTPUT}" ]] || { echo "--output is required"; exit 1; }
  [[ -f "${INPUT}" ]] || { echo "Input not found: ${INPUT}"; exit 1; }
  [[ -x "${VENV_DIR}/bin/python" ]] || { echo "Missing env. Run install first."; exit 1; }

  mkdir -p "${OUTPUT}"
  mkdir -p "${TS_HOME_DIR}"
  export TOTALSEG_HOME_DIR="${TS_HOME_DIR}"
  # shellcheck disable=SC1091
  source "${VENV_DIR}/bin/activate"

  if [[ "${TASK}" == "spleen" ]]; then
    CMD_ARR=(TotalSegmentator -i "${INPUT}" -o "${OUTPUT}" --task total --roi_subset spleen)
  else
    CMD_ARR=(TotalSegmentator -i "${INPUT}" -o "${OUTPUT}" --task "${TASK}")
  fi
  if [[ "${FAST}" == "1" ]]; then
    CMD_ARR+=(--fast)
  fi

  echo "[totalseg_cpu] running: ${CMD_ARR[*]}"
  "${CMD_ARR[@]}"
  echo "[totalseg_cpu] done: ${OUTPUT}"
}

case "${CMD}" in
  install)
    install_env
    ;;
  run)
    run_inference
    ;;
  all)
    if [[ ! -x "${VENV_DIR}/bin/python" ]]; then
      install_env
    fi
    run_inference
    ;;
  *)
    usage
    exit 1
    ;;
esac
