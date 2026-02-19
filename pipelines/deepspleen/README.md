# DeepSpleen Pipeline (Wrapper)

This is a clean wrapper around the extracted DeepSpleen inference flow.

## Inference Code Path
- Main inference loader: `extracted_spleen/python/segment_test.py`
- Network definition: `extracted_spleen/python/torchsrc/models/gcn.py` (`FCNGCN`)
- Weights: `extracted_spleen/models/view3/model_spleen.pth`

The wrapper uses `pipelines/deepspleen/scripts/run_deepspleen_local.sh` and runs minimal inference mode.

## Folder Layout
- `scripts/`: setup and run wrappers
- `configs/`: environment defaults
- `data/`: optional local inputs (git-ignored)
- `outputs/`: segmentation outputs (git-ignored)
- `runtime/`: extracted runtime/assets cache (git-ignored)
- `logs/`: logs (git-ignored)

## Quick Run
```bash
cd pipelines/deepspleen
bash scripts/run.sh /path/to/input.nii.gz
```

Output is saved to:
- `outputs/deepspleenseg/masks/<case_id>_mask.nii.gz`
