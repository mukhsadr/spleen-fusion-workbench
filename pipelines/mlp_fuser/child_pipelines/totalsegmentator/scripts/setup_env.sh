#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV_DIR="${ROOT_DIR}/env/.venv"
LOG_DIR="${ROOT_DIR}/logs"
mkdir -p "${ROOT_DIR}/env" "${LOG_DIR}"

if ! command -v python3 >/dev/null 2>&1; then
  echo "[totalsegmentator] python3 is required"
  exit 1
fi

if ! python3 -m pip --version >/dev/null 2>&1; then
  echo "[totalsegmentator] missing pip for python3"
  echo "[totalsegmentator] install: sudo apt-get install -y python3-pip python3.12-venv"
  exit 1
fi

if python3 -m venv "${VENV_DIR}" >/dev/null 2>&1; then
  :
else
  if command -v virtualenv >/dev/null 2>&1; then
    virtualenv -p python3 "${VENV_DIR}"
  else
    echo "[totalsegmentator] could not create venv (python3-venv not installed)"
    echo "[totalsegmentator] install: sudo apt-get install -y python3.12-venv"
    exit 1
  fi
fi

source "${VENV_DIR}/bin/activate"

python -m pip install --upgrade pip wheel setuptools
python -m pip install --no-cache-dir TotalSegmentator

python - <<'PY'
import importlib
mod = importlib.import_module("totalsegmentator")
print("totalsegmentator import OK:", mod.__name__)
PY

echo "[totalsegmentator] environment ready: ${VENV_DIR}"
