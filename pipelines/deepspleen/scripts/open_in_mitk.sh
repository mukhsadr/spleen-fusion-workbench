#!/usr/bin/env bash
set -euo pipefail

PIPE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "${PIPE_DIR}/../.." && pwd)"

CT_PATH=""
MASK_PATH=""
MITK_EXE=""
CASE_ID=""
WL="50"
WW="400"
USE_WINDOWED_CT="1"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --case)
      CASE_ID="${2:-}"
      shift 2
      ;;
    --wl)
      WL="${2:-}"
      shift 2
      ;;
    --ww)
      WW="${2:-}"
      shift 2
      ;;
    --mitk)
      MITK_EXE="${2:-}"
      shift 2
      ;;
    --no-windowed)
      USE_WINDOWED_CT="0"
      shift
      ;;
    -*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      if [[ -z "${CT_PATH}" ]]; then
        CT_PATH="$1"
      elif [[ -z "${MASK_PATH}" ]]; then
        MASK_PATH="$1"
      elif [[ -z "${MITK_EXE}" ]]; then
        MITK_EXE="$1"
      else
        echo "Unexpected extra argument: $1"
        exit 1
      fi
      shift
      ;;
  esac
done

if [[ -n "${CASE_ID}" ]]; then
  CT_PATH="${REPO_ROOT}/inputs/${CASE_ID}.nii.gz"
  MASK_PATH="${REPO_ROOT}/outputs/deepspleenseg/masks/case_${CASE_ID}_mask.nii.gz"
fi

if [[ -z "${CT_PATH}" || -z "${MASK_PATH}" ]]; then
  echo "Usage:"
  echo "  bash scripts/open_in_mitk.sh --case <CT1|CT2|...> [--wl 50 --ww 400] [--mitk <exe>]"
  echo "  bash scripts/open_in_mitk.sh <ct.nii|ct.nii.gz> <mask.nii|mask.nii.gz> [mitk_exe_path]"
  echo "Example:"
  echo "  bash scripts/open_in_mitk.sh --case CT1 --wl 50 --ww 400"
  exit 1
fi

if [[ ! -f "${CT_PATH}" ]]; then
  echo "CT file not found: ${CT_PATH}"
  exit 1
fi

if [[ ! -f "${MASK_PATH}" ]]; then
  echo "Mask file not found: ${MASK_PATH}"
  exit 1
fi

if [[ -z "${MITK_EXE}" ]]; then
  # Common install locations on Windows.
  CANDIDATES=(
    "/mnt/c/Program Files/MITK v2024.12/bin/MitkWorkbench.exe"
    "/mnt/c/Program Files/MITK v2024.06/bin/MitkWorkbench.exe"
    "/mnt/c/Program Files/MITK Workbench/bin/MitkWorkbench.exe"
    "/mnt/c/Program Files/MITK/bin/MitkWorkbench.exe"
    "/mnt/c/Program Files/mitk/bin/MitkWorkbench.exe"
  )
  for c in "${CANDIDATES[@]}"; do
    if [[ -f "${c}" ]]; then
      MITK_EXE="${c}"
      break
    fi
  done
  if [[ -z "${MITK_EXE}" ]]; then
    for c in /mnt/c/Program\ Files/MITK*/bin/MitkWorkbench.exe; do
      if [[ -f "${c}" ]]; then
        MITK_EXE="${c}"
        break
      fi
    done
  fi
fi

if [[ -z "${MITK_EXE}" || ! -f "${MITK_EXE}" ]]; then
  echo "MITK executable not found automatically."
  echo "Pass it explicitly as 3rd argument."
  echo "Example:"
  echo "  bash scripts/open_in_mitk.sh <ct> <mask> \"/mnt/c/Program Files/MITK Workbench/bin/MitkWorkbench.exe\""
  exit 1
fi

# Create a windowed CT copy so MITK opens with soft-tissue-like appearance directly.
CT_TO_OPEN="${CT_PATH}"
if [[ "${USE_WINDOWED_CT}" == "1" ]]; then
  PY_HELPER=""
  for p in \
    "${REPO_ROOT}/pipelines/totalsegmentator/env/.venv/bin/python" \
    "${REPO_ROOT}/pipelines/deepspleen/runtime/extracted_spleen/miniconda/bin/python" \
    "/tmp/deepspleen_sif_mount_${USER:-user}/extra/miniconda/bin/python" \
    "python3"; do
    if command -v "${p}" >/dev/null 2>&1 || [[ -x "${p}" ]]; then
      PY_HELPER="${p}"
      break
    fi
  done

  if [[ -n "${PY_HELPER}" ]]; then
    VIEW_DIR="${REPO_ROOT}/outputs/deepspleenseg/view"
    mkdir -p "${VIEW_DIR}"
    CASE_TAG="${CASE_ID:-$(basename "${CT_PATH}" .nii.gz)}"
    WIN_CT_PATH="${VIEW_DIR}/${CASE_TAG}_wl${WL}_ww${WW}.nii.gz"

    if "${PY_HELPER}" - "${CT_PATH}" "${WIN_CT_PATH}" "${WL}" "${WW}" <<'PY'
import sys
import nibabel as nib
import numpy as np

ct_in, ct_out, wl, ww = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4])
img = nib.load(ct_in)
arr = np.asanyarray(img.dataobj).astype(np.float32)
low = wl - ww / 2.0
high = wl + ww / 2.0
arr = np.clip(arr, low, high)
out = nib.Nifti1Image(arr, img.affine, img.header)
nib.save(out, ct_out)
PY
    then
      CT_TO_OPEN="${WIN_CT_PATH}"
    fi
  fi
fi

MITK_WIN="$(wslpath -w "${MITK_EXE}")"
CT_WIN="$(wslpath -w "${CT_TO_OPEN}")"
MASK_WIN="$(wslpath -w "${MASK_PATH}")"

echo "Opening MITK with:"
echo "  CT   : ${CT_TO_OPEN}"
echo "  Mask : ${MASK_PATH}"
echo "  WL/WW: ${WL}/${WW}"

powershell.exe -NoProfile -Command "Start-Process -FilePath '${MITK_WIN}' -ArgumentList @('${CT_WIN}','${MASK_WIN}')"

cat <<'EOF'

MITK quick overlay steps:
0) Soft tissue preset (recommended):
   - Window Level (WL): set to your chosen value
   - Window Width (WW): set to your chosen value
1) In Data Manager, select the mask layer.
2) Set color to red (or preferred color).
3) Set opacity around 0.3-0.5.
4) Ensure mask is above CT in layer order.

EOF
