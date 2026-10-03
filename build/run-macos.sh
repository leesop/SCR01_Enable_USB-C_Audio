#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail
kit_dir=$(cd "$(dirname "$0")" && pwd)
source_dir=${1:?Usage: bash run-macos.sh /absolute/path/to/SM-H412J_JPN_RR_Opensource [baseline|audio|all]}
source_dir=$(cd "$source_dir" && pwd)
stage=${2:-all}
test -f "$source_dir/Kernel.tar.gz"
command -v docker >/dev/null || { echo "Install and start Docker Desktop first." >&2; exit 1; }
docker info >/dev/null
mkdir -p "$kit_dir/artifacts"
docker build --platform linux/amd64 -t scr01-usb-audio-builder "$kit_dir"
docker volume create scr01-usb-audio-build >/dev/null
docker run --rm --platform linux/amd64 \
    -e JOBS="${JOBS:-4}" \
    --mount "type=volume,source=scr01-usb-audio-build,target=/build" \
    --mount "type=bind,source=$source_dir,target=/input,readonly" \
    --mount "type=bind,source=$kit_dir,target=/kit,readonly" \
    --mount "type=bind,source=$kit_dir/artifacts,target=/artifacts" \
    scr01-usb-audio-builder "$stage"
