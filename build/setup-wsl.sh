#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail
if [[ "$(uname -m)" != x86_64 ]]; then
    echo "This kit uses x86_64 Linux toolchains. Use an Intel/AMD PC." >&2
    exit 2
fi
if ! grep -qx 'VERSION_ID="20.04"' /etc/os-release; then
    echo "Use Ubuntu-20.04 for this legacy toolchain recipe." >&2
    exit 2
fi
sudo apt-get update
sudo apt-get install -y \
    bash bc bison build-essential ca-certificates curl flex git kmod \
    libelf-dev libssl-dev libncurses5 libtinfo5 python2 python3 xz-utils unzip
