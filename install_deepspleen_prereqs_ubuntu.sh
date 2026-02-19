#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Installing prerequisites for local DeepSpleen runner"
echo "[INFO] Requires sudo privileges"

sudo apt-get update
sudo apt-get install -y squashfuse fuse mount

echo "[INFO] Installed. Validate with:"
echo "       which squashfuse"
echo "       which fusermount"
