#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  run_deepspleen_local.sh all   --sif <file.sif> --input-nii <input.nii|input.nii.gz> [options]
  run_deepspleen_local.sh setup --sif <file.sif> [options]
  run_deepspleen_local.sh run   --input-nii <input.nii|input.nii.gz> [options]

Commands:
  all      Setup + run inference
  setup    Extract minimal assets from SIF and patch for local execution
  run      Run inference using extracted assets (default: legacy/original flow)

Options:
  --sif <path>           Path to SIF image (default: ./spiders_DeepSpleen.sif)
  --input-nii <path>     Input NIfTI file for inference
  --root <dir>           Working root (default: ./spleen_runtime)
  --offset <bytes>       Squashfs offset inside SIF (default: 40960)
  --case-id <id>         Subject id for generated output (default: case001)
  --view <name>          View name (default: view3)
  --batch-size <n>       Batch size for inference (default: 4)
  --lmk-num <n>          Number of output classes (default: 2)
  --infer-mode <mode>    Inference mode: legacy|minimal (default: legacy)
  --output-nii <path>    Output mask path (default: <root>/local_run/<case-id>_mask.nii.gz)
  --no-restore-shape     Keep output at 256x256xZ instead of restoring input XY shape
  --copy-runtime         Copy miniconda locally (slower, optional)
  --no-copy-runtime      Force mounted runtime at run-time (default)
  -h, --help             Show this help

Examples:
  ./run_deepspleen_local.sh all --sif ./spiders_DeepSpleen.sif --input-nii /data/raw.nii
  ./run_deepspleen_local.sh setup --sif ./spiders_DeepSpleen.sif --root ./spleen_runtime
  ./run_deepspleen_local.sh run --input-nii /data/raw.nii --root ./spleen_runtime
EOF
}

log() { printf '[%s] %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >&2; }
die() { echo "ERROR: $*" >&2; exit 1; }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing command: $1"
}

is_mounted() {
  mountpoint -q "$1" 2>/dev/null
}

SIF_PATH="./spiders_DeepSpleen.sif"
INPUT_NII=""
ROOT_DIR="./spleen_runtime"
OFFSET="40960"
CASE_ID="case001"
VIEW="view3"
BATCH_SIZE="4"
NETWORK="206"
LMK_NUM="2"
COPY_RUNTIME="0"
OUTPUT_NII=""
RESTORE_SHAPE="1"
INFER_MODE="legacy"

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

CMD="${1:-}"
[[ -n "$CMD" ]] || { usage; exit 1; }
shift || true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --sif) SIF_PATH="$2"; shift 2 ;;
    --input-nii) INPUT_NII="$2"; shift 2 ;;
    --root) ROOT_DIR="$2"; shift 2 ;;
    --offset) OFFSET="$2"; shift 2 ;;
    --case-id) CASE_ID="$2"; shift 2 ;;
    --view) VIEW="$2"; shift 2 ;;
    --batch-size) BATCH_SIZE="$2"; shift 2 ;;
    --lmk-num) LMK_NUM="$2"; shift 2 ;;
    --infer-mode) INFER_MODE="$2"; shift 2 ;;
    --output-nii) OUTPUT_NII="$2"; shift 2 ;;
    --no-restore-shape) RESTORE_SHAPE="0"; shift ;;
    --copy-runtime) COPY_RUNTIME="1"; shift ;;
    --no-copy-runtime) COPY_RUNTIME="0"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

EXTRACTED_DIR="$ROOT_DIR/extracted_spleen"
RUN_DIR="$ROOT_DIR/local_run"
MOUNT_DIR="/tmp/deepspleen_sif_mount_${USER:-user}"
OUTPUTS_DIR="$RUN_DIR/OUTPUTS"
RESULTS_DIR="$RUN_DIR/DeepSegResults"

mount_sif() {
  require_cmd squashfuse
  mkdir -p "$MOUNT_DIR"
  if is_mounted "$MOUNT_DIR"; then
    log "SIF already mounted: $MOUNT_DIR"
    return
  fi
  log "Mounting SIF at $MOUNT_DIR (offset=$OFFSET)"
  squashfuse -o "offset=$OFFSET" "$SIF_PATH" "$MOUNT_DIR"
}

unmount_sif() {
  if is_mounted "$MOUNT_DIR"; then
    log "Unmounting $MOUNT_DIR"
    if command -v fusermount >/dev/null 2>&1; then
      fusermount -u "$MOUNT_DIR" || true
    fi
  fi
}

write_prepare_script() {
  cat >"$EXTRACTED_DIR/python/prepare_input_local.py" <<'PYEOF'
import argparse
import os
import nibabel as nib
import numpy as np
from PIL import Image


def mkdir(path):
    if not os.path.exists(path):
        os.makedirs(path)


def normalize_slice(x):
    x = np.asarray(x, dtype=np.float32)
    mn = x.min()
    mx = x.max()
    if mx > mn:
        x = (x - mn) / (mx - mn)
    else:
        x = np.zeros_like(x, dtype=np.float32)
    return (x * 255.0).astype(np.uint8)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--input_nii", required=True)
    parser.add_argument("--output_root", required=True)
    parser.add_argument("--subject_id", default="case001")
    parser.add_argument("--view", default="view3")
    args = parser.parse_args()

    nii = nib.load(args.input_nii)
    arr = nii.get_fdata()
    if arr.ndim > 3:
        arr = arr[..., 0]
    if arr.ndim != 3:
        raise RuntimeError("Expected 3D (or 4D) NIfTI, got shape: %s" % (arr.shape,))

    dicom2nifti_dir = os.path.join(args.output_root, "dicom2nifti")
    view_dir = os.path.join(args.output_root, "Data_2D", "img", args.subject_id, args.view)
    mkdir(dicom2nifti_dir)
    mkdir(view_dir)

    target_img = os.path.join(dicom2nifti_dir, "target_img.nii.gz")
    nib.save(nib.Nifti1Image(arr, nii.affine), target_img)

    zdim = arr.shape[2]
    for z in range(zdim):
        img = normalize_slice(arr[:, :, z])
        out_png = os.path.join(view_dir, "slice_%04d.png" % (z + 1))
        Image.fromarray(img, mode="L").save(out_png)

    print("Prepared slices:", zdim)
    print("Target image:", target_img)
    print("Slice dir:", view_dir)


if __name__ == "__main__":
    main()
PYEOF
}

write_minimal_infer_script() {
  cat >"$EXTRACTED_DIR/python/minimal_infer.py" <<'PYEOF'
import argparse
import os

import nibabel as nib
import numpy as np
from PIL import Image
import torch
from torch.autograd import Variable
import torchsrc


def normalize_slice(x):
    x = np.asarray(x, dtype=np.float32)
    mn = x.min()
    mx = x.max()
    if mx > mn:
        x = (x - mn) / (mx - mn)
    else:
        x = np.zeros_like(x, dtype=np.float32)
    return x


def preprocess_to_256(x):
    x = normalize_slice(x)
    img = Image.fromarray((x * 255.0).astype(np.uint8), mode='L')
    img = img.resize((256, 256), Image.BICUBIC)
    arr = np.asarray(img, dtype=np.float32) / 255.0
    arr = (arr - 0.5) / 0.5
    return arr


def resize_mask(mask256, out_h, out_w):
    img = Image.fromarray(mask256.astype(np.uint8), mode='L')
    img = img.resize((out_w, out_h), Image.NEAREST)
    return np.asarray(img, dtype=np.uint8)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--input-nii', required=True)
    parser.add_argument('--output-nii', required=True)
    parser.add_argument('--model-pth', required=True)
    parser.add_argument('--batch-size', type=int, default=4)
    parser.add_argument('--lmk-num', type=int, default=2)
    parser.add_argument('--restore-shape', action='store_true')
    parser.add_argument('--cpu', action='store_true')
    args = parser.parse_args()

    nii = nib.load(args.input_nii)
    vol = np.asanyarray(nii.dataobj)
    if vol.ndim > 3:
        vol = vol[..., 0]
    if vol.ndim != 3:
        raise RuntimeError('Expected 3D or 4D NIfTI, got shape: %r' % (vol.shape,))

    sx, sy, sz = vol.shape
    out_x, out_y = (sx, sy) if args.restore_shape else (256, 256)
    seg = np.zeros((out_x, out_y, sz), dtype=np.uint8)

    model = torchsrc.models.FCNGCN(num_classes=args.lmk_num)
    use_cuda = torch.cuda.is_available() and (not args.cpu)
    if use_cuda:
        model = model.cuda()
        state = torch.load(args.model_pth)
    else:
        state = torch.load(args.model_pth, map_location=lambda storage, loc: storage)
    model.load_state_dict(state)
    model.eval()

    bs = max(1, int(args.batch_size))
    for start in range(0, sz, bs):
        end = min(start + bs, sz)
        b = end - start
        batch = np.zeros((b, 1, 256, 256), dtype=np.float32)
        for i, z in enumerate(range(start, end)):
            batch[i, 0, :, :] = preprocess_to_256(vol[:, :, z])

        tensor = torch.from_numpy(batch).float()
        if use_cuda:
            tensor = tensor.cuda()
        pred = model(Variable(tensor, volatile=True))
        lbl = pred.data.max(1)[1].cpu().numpy().astype(np.uint8)

        for i, z in enumerate(range(start, end)):
            if args.restore_shape:
                seg[:, :, z] = resize_mask(lbl[i], sx, sy)
            else:
                seg[:, :, z] = lbl[i]

    out_dir = os.path.dirname(args.output_nii)
    if out_dir and (not os.path.exists(out_dir)):
        os.makedirs(out_dir)
    nib.save(nib.Nifti1Image(seg, nii.affine), args.output_nii)
    print('Saved:', args.output_nii)
    print('Shape:', seg.shape)


if __name__ == '__main__':
    main()
PYEOF
}

patch_local_python() {
  local seg="$EXTRACTED_DIR/python/segment_test.py"
  local gcn="$EXTRACTED_DIR/python/torchsrc/models/gcn.py"

  [[ -f "$seg" ]] || die "Missing file: $seg"
  [[ -f "$gcn" ]] || die "Missing file: $gcn"

  python3 - "$seg" "$gcn" <<'PYEOF'
import re
import sys
from pathlib import Path

seg_path = Path(sys.argv[1])
gcn_path = Path(sys.argv[2])
seg = seg_path.read_text()
gcn = gcn_path.read_text()

if "import os, sys" in seg:
    seg = seg.replace("import os, sys", "import os, sys", 1)
elif "import os" not in seg:
    seg = "import os\n" + seg

seg = seg.replace(
    "model_root_path = '/extra/deepNetworks/EssNet/500/cross_entropy/models'",
    "model_root_path = os.environ.get('MODEL_ROOT_PATH', '/extra/deepNetworks/EssNet/500/cross_entropy/models')",
)
seg = seg.replace(
    "test_img_root_dir = '/OUTPUTS/Data_2D/'",
    "test_img_root_dir = os.environ.get('TEST_IMG_ROOT_DIR', '/OUTPUTS/Data_2D/')",
)
seg = seg.replace(
    "working_root_dir = '/OUTPUTS/DeepSegResults/'",
    "working_root_dir = os.environ.get('WORKING_ROOT_DIR', '/OUTPUTS/DeepSegResults/')",
)
seg = seg.replace(
    "img_load_name = '/OUTPUTS/dicom2nifti/'",
    "img_load_name = os.environ.get('IMG_LOAD_NAME', '/OUTPUTS/dicom2nifti/')",
)
seg = seg.replace(
    "img_name = '/OUTPUTS/dicom2nifti/target_img.nii.gz'",
    "img_name = os.environ.get('IMG_NAME', '/OUTPUTS/dicom2nifti/target_img.nii.gz')",
)
seg = re.sub(r"num_workers\s*=\s*\d+", "num_workers = opt.workers", seg)
gcn = gcn.replace(
    "resnet = models.resnet50(pretrained=True)",
    "resnet = models.resnet50(pretrained=False)",
)

seg_path.write_text(seg)
gcn_path.write_text(gcn)
PYEOF
  write_prepare_script
  write_minimal_infer_script
}

extract_assets() {
  [[ -f "$SIF_PATH" ]] || die "SIF not found: $SIF_PATH"
  mount_sif

  mkdir -p "$EXTRACTED_DIR/models/view3"

  log "Copying pipeline files"
  rm -rf "$EXTRACTED_DIR/python"
  cp -a "$MOUNT_DIR/extra/python" "$EXTRACTED_DIR/"
  cp -f "$MOUNT_DIR/extra/deepNetworks/EssNet/500/cross_entropy/models/view3/model_spleen.pth" "$EXTRACTED_DIR/models/view3/model_spleen.pth"
  cp -f "$MOUNT_DIR/extra/deepNetworks/EssNet/500/cross_entropy/models/view3/model_spleen.pth" "$EXTRACTED_DIR/models/model_spleen.pth"

  if [[ "$COPY_RUNTIME" == "1" ]] && [[ ! -x "$EXTRACTED_DIR/miniconda/bin/python" ]]; then
    log "Copying embedded miniconda runtime (one-time, may take a few minutes)"
    rm -rf "$EXTRACTED_DIR/miniconda"
    if ! cp -a "$MOUNT_DIR/extra/miniconda" "$EXTRACTED_DIR/"; then
      log "Runtime copy failed on this filesystem. Falling back to mounted runtime."
      COPY_RUNTIME="0"
      rm -rf "$EXTRACTED_DIR/miniconda"
    fi
  fi

  patch_local_python
  log "Setup complete at $EXTRACTED_DIR"

  if [[ "$COPY_RUNTIME" == "1" ]]; then
    unmount_sif
  fi
}

pick_python() {
  if [[ -x "$EXTRACTED_DIR/miniconda/bin/python" ]]; then
    echo "$EXTRACTED_DIR/miniconda/bin/python"
    return
  fi
  mount_sif
  [[ -x "$MOUNT_DIR/extra/miniconda/bin/python" ]] || die "No Python runtime found in mounted SIF"
  echo "$MOUNT_DIR/extra/miniconda/bin/python"
}

run_inference() {
  [[ -n "$INPUT_NII" ]] || die "--input-nii is required for run/all"
  [[ -f "$INPUT_NII" ]] || die "Input NIfTI not found: $INPUT_NII"
  [[ -f "$EXTRACTED_DIR/python/segment_test.py" ]] || die "Missing extracted files. Run setup first."
  [[ "$INFER_MODE" == "legacy" || "$INFER_MODE" == "minimal" ]] || die "--infer-mode must be: legacy|minimal"
  patch_local_python

  local pybin
  pybin="$(pick_python)"

  mkdir -p "$RUN_DIR" "$RESULTS_DIR"
  local out_file
  out_file="${OUTPUT_NII:-$RUN_DIR/${CASE_ID}_mask.nii.gz}"
  mkdir -p "$(dirname "$out_file")"

  if [[ "$INFER_MODE" == "minimal" ]]; then
    local restore_flag=""
    if [[ "$RESTORE_SHAPE" == "1" ]]; then
      restore_flag="--restore-shape"
    fi
    log "Running minimal model inference"
    "$pybin" "$EXTRACTED_DIR/python/minimal_infer.py" \
      --input-nii "$INPUT_NII" \
      --output-nii "$out_file" \
      --model-pth "$EXTRACTED_DIR/models/view3/model_spleen.pth" \
      --batch-size "$BATCH_SIZE" \
      --lmk-num "$LMK_NUM" \
      $restore_flag
  else
    log "Running legacy DeepSpleen inference (segment_test.py)"
    rm -rf "$OUTPUTS_DIR" "$RESULTS_DIR"
    mkdir -p "$OUTPUTS_DIR" "$RESULTS_DIR"

    "$pybin" "$EXTRACTED_DIR/python/prepare_input_local.py" \
      --input_nii "$INPUT_NII" \
      --output_root "$OUTPUTS_DIR" \
      --subject_id "$CASE_ID" \
      --view "$VIEW"

    (
      cd "$EXTRACTED_DIR/python"
      MODEL_ROOT_PATH="$EXTRACTED_DIR/models" \
      TEST_IMG_ROOT_DIR="$OUTPUTS_DIR/Data_2D" \
      WORKING_ROOT_DIR="$RESULTS_DIR" \
      IMG_LOAD_NAME="$OUTPUTS_DIR/dicom2nifti" \
      IMG_NAME="$OUTPUTS_DIR/dicom2nifti/target_img.nii.gz" \
      PYTHONPATH="$EXTRACTED_DIR/python${PYTHONPATH:+:$PYTHONPATH}" \
      "$pybin" "$EXTRACTED_DIR/python/segment_test.py" \
        --model_name model_spleen \
        --network "$NETWORK" \
        --workers 0 \
        --batchSize_lmk "$BATCH_SIZE" \
        --viewName "$VIEW" \
        --loss_fun cross_entropy \
        --lmk_num "$LMK_NUM"
    )

    local legacy_out
    legacy_out="$RESULTS_DIR/results_single/$NETWORK/cross_entropy/seg_output/$CASE_ID/${CASE_ID}_${VIEW}.nii.gz"
    if [[ ! -f "$legacy_out" ]]; then
      legacy_out="$(find "$RESULTS_DIR" -type f -name "${CASE_ID}_${VIEW}.nii.gz" | head -n 1 || true)"
    fi
    [[ -n "$legacy_out" && -f "$legacy_out" ]] || die "Legacy output not found under: $RESULTS_DIR"
    if [[ "$RESTORE_SHAPE" == "1" ]]; then
      "$pybin" - "$INPUT_NII" "$legacy_out" "$out_file" <<'PYEOF'
import sys
import nibabel as nib
import numpy as np
from PIL import Image

in_nii = sys.argv[1]
legacy_nii = sys.argv[2]
out_nii = sys.argv[3]

src_img = nib.load(in_nii)
msk_img = nib.load(legacy_nii)
src = np.asanyarray(src_img.dataobj)
msk = np.asanyarray(msk_img.dataobj)

if src.ndim > 3:
    src = src[..., 0]
if msk.ndim > 3:
    msk = msk[..., 0]
if src.ndim != 3 or msk.ndim != 3:
    raise RuntimeError("Expected 3D arrays")

sx, sy, sz = src.shape
mx, my, mz = msk.shape
if sz != mz:
    raise RuntimeError("Slice mismatch: src z=%d mask z=%d" % (sz, mz))

if sx == mx and sy == my:
    out = msk.astype(np.uint8)
else:
    out = np.zeros((sx, sy, sz), dtype=np.uint8)
    for z in range(sz):
        sl = msk[:, :, z].astype(np.uint8)
        pil = Image.fromarray(sl, mode='L')
        pil = pil.resize((sy, sx), Image.NEAREST)
        out[:, :, z] = np.asarray(pil, dtype=np.uint8)

nib.save(nib.Nifti1Image(out, src_img.affine, src_img.header), out_nii)
print("Saved:", out_nii)
PYEOF
    else
      cp -f "$legacy_out" "$out_file"
    fi
  fi

  [[ -f "$out_file" ]] || die "Expected output not found: $out_file"

  log "Done"
  echo "Output mask: $out_file"
}

case "$CMD" in
  setup)
    extract_assets
    ;;
  run)
    run_inference
    ;;
  all)
    extract_assets
    run_inference
    ;;
  *)
    usage
    die "Unknown command: $CMD"
    ;;
esac
