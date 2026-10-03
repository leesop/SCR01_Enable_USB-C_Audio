#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail
kit_dir=$(cd "$(dirname "$0")" && pwd)
source_dir=${1:?Usage: bash run-wsl.sh /path/to/SM-H412J_JPN_RR_Opensource [baseline|audio|all]}
source_dir=$(cd "$source_dir" && pwd)
stage=${2:-all}
test -f "$source_dir/Kernel.tar.gz"
if [[ "$(uname -s)" != Linux || "$(uname -m)" != x86_64 ]]; then
    echo "Run this script in x86_64 Linux (WSL2 Ubuntu-20.04)." >&2
    exit 2
fi
case "$kit_dir" in /mnt/*)
    echo "Extract the build kit inside the WSL Linux home directory, not /mnt/c or /mnt/d." >&2
    exit 2;;
esac
for tool in make gcc g++ curl python2 python3 modinfo modprobe; do
    command -v "$tool" >/dev/null || { echo "Missing $tool; run bash setup-wsl.sh first." >&2; exit 2; }
done
export SCR01_BUILD_ROOT=${SCR01_BUILD_ROOT:-"$kit_dir/work-wsl"}
case "$SCR01_BUILD_ROOT" in /mnt/*)
    echo "SCR01_BUILD_ROOT must be on the WSL Linux filesystem." >&2
    exit 2;;
esac
export SCR01_INPUT_DIR="$source_dir"
export SCR01_KIT_DIR="$kit_dir"
export SCR01_ARTIFACTS_DIR="$kit_dir/artifacts"
bash "$kit_dir/build.sh" "$stage"
