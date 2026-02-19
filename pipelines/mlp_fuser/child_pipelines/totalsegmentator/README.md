# totalsegmentator Child Pipeline

Place pipeline-specific code in:
- `scripts/`
- `configs/`
- `models/` (ignored by git)
- `data/` (ignored by git)
- `outputs/` (ignored by git)
- `logs/` (ignored by git)

Minimal spleen-only setup:
```bash
bash scripts/install_with_sudo.sh
```

Download spleen model once:
```bash
bash scripts/download_spleen_model.sh /path/to/input.nii.gz
```

Or install + warmup in one step:
```bash
bash scripts/install_with_sudo.sh /path/to/input.nii.gz
```

Run spleen segmentation:
```bash
bash scripts/run.sh /path/to/input.nii.gz
```
