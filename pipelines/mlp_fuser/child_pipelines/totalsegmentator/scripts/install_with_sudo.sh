#!/usr/bin/env bash
set -euo pipefail

# Optional: pass one NIfTI path to warm up/download spleen model weights.
WARMUP_INPUT="${1:-}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/env/.venv"
LOG_DIR="${ROOT_DIR}/logs"
mkdir -p "${ROOT_DIR}/env" "${LOG_DIR}"

echo "[totalsegmentator] installing system deps (sudo)"
sudo apt-get update
sudo apt-get install -y python3-pip python3.12-venv

echo "[totalsegmentator] creating venv at ${VENV_DIR}"
python3 -m venv "${VENV_DIR}"
source "${VENV_DIR}/bin/activate"

echo "[totalsegmentator] upgrading pip tooling"
python -m pip install --upgrade pip wheel setuptools

echo "[totalsegmentator] installing CPU torch"
python -m pip install --no-cache-dir \
  --index-url https://download.pytorch.org/whl/cpu \
  torch torchvision

echo "[totalsegmentator] installing TotalSegmentator"
python -m pip install --no-cache-dir TotalSegmentator

echo "[totalsegmentator] validating install"
python - <<'PY'
import importlib
import torch
ts = importlib.import_module("totalsegmentator")
print("totalsegmentator:", ts.__name__)
print("torch:", torch.__version__)
print("cuda_available:", torch.cuda.is_available())
PY

if [[ -n "${WARMUP_INPUT}" ]]; then
  mkdir -p "${ROOT_DIR}/outputs/_warmup"
  echo "[totalsegmentator] warmup/download using: ${WARMUP_INPUT}"
  TotalSegmentator -i "${WARMUP_INPUT}" -o "${ROOT_DIR}/outputs/_warmup" --task spleen --fast
fi

echo "[totalsegmentator] install complete"
echo "[totalsegmentator] run example:"
echo "  bash ${ROOT_DIR}/scripts/run.sh /path/to/input.nii.gz"
