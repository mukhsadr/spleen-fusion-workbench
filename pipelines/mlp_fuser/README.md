# MLP Fuser Workspace

This folder is the orchestration root for multi-model segmentation fusion.

## Structure
- `scripts/`: top-level orchestration scripts
- `models/`: local model artifacts (git-ignored)
- `configs/`: shared YAML/JSON configs
- `data/`: local input data (git-ignored)
- `outputs/`: generated predictions (git-ignored)
- `logs/`: runtime logs (git-ignored)
- `child_pipelines/`: per-model pipelines run independently

## Child Pipelines
- `totalsegmentator`
- `gennunt`
- `nv_segmentation`

## Quick Start
```bash
cd pipelines/mlp_fuser
bash scripts/run_all.sh /path/to/input.nii.gz
```
