#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
set -euo pipefail
stage=${1:-all}
build_root=${SCR01_BUILD_ROOT:-/build}
input_dir=${SCR01_INPUT_DIR:-/input}
kit_dir=${SCR01_KIT_DIR:-/kit}
artifacts_dir=${SCR01_ARTIFACTS_DIR:-/artifacts}
case "$stage" in baseline|audio|all) ;; *) echo "Unknown stage: $stage" >&2; exit 2;; esac
mkdir -p "${build_root}/toolchains" "$artifacts_dir"
exec > >(tee -a "$artifacts_dir/build.log") 2>&1

source_sha=$(sha256sum "${input_dir}/Kernel.tar.gz" | awk '{print $1}')
expected_source_sha=7f0ca9c6e04e7653e2f339b2f8822178d30915b7542ba5bf55c5636e034a173d
if [[ "$source_sha" != "$expected_source_sha" ]]; then
    echo "Unexpected Kernel.tar.gz. Use the exact SCR01KDU1AVK2 source archive." >&2
    exit 2
fi
if [[ ! -f ${build_root}/source.sha256 ]]; then
    mkdir -p "${build_root}/src"
    tar -xzf "${input_dir}/Kernel.tar.gz" -C "${build_root}/src"
    printf '%s\n' "$source_sha" > "${build_root}/source.sha256"
elif [[ "$(cat "$build_root/source.sha256")" != "$source_sha" ]]; then
    echo "Source archive changed. Use a new SCR01_BUILD_ROOT directory or build volume." >&2
    exit 2
fi
cp "${build_root}/source.sha256" "${artifacts_dir}/source.sha256"

fetch_toolchain() {
    local name=$1 url=$2
    if [[ ! -f "${build_root}/toolchains/$name/.complete" ]]; then
        mkdir -p "${build_root}/toolchains/$name"
        curl -fL --retry 3 --connect-timeout 30 "$url" \
            -o "${build_root}/toolchains/$name.tar.gz"
        tar -xzf "${build_root}/toolchains/$name.tar.gz" -C "${build_root}/toolchains/$name"
        sha256sum "${build_root}/toolchains/$name.tar.gz" >> "${artifacts_dir}/toolchains.sha256"
        touch "${build_root}/toolchains/$name/.complete"
    fi
}
fetch_toolchain clang \
    'https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/f71cc7fa68ac644595257d6fdebc2e543cb7041c/clang-r383902.tar.gz'
fetch_toolchain gcc \
    'https://android.googlesource.com/platform/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/+archive/refs/tags/android-11.0.0_r48.tar.gz'

export ARCH=arm64 ANDROID_MAJOR_VERSION=r
export PATH="${build_root}/toolchains/clang/bin:${build_root}/toolchains/gcc/bin:$PATH"
common=(ARCH=arm64 ANDROID_MAJOR_VERSION=r
    "CROSS_COMPILE=${build_root}/toolchains/gcc/bin/aarch64-linux-androidkernel-"
    CLANG_TRIPLE=aarch64-linux-gnu-
    "CC=${build_root}/toolchains/clang/bin/clang"
    "LD=${build_root}/toolchains/clang/bin/ld.lld"
    "NM=${build_root}/toolchains/clang/bin/llvm-nm"
    "OBJCOPY=${build_root}/toolchains/clang/bin/llvm-objcopy"
    HOSTCC=gcc HOSTCXX=g++ PYTHON=python2
    LOCALVERSION=-24165939 KCFLAGS=-w CONFIG_SECTION_MISMATCH_WARN_ONLY=y)
"${build_root}/toolchains/clang/bin/clang" --version | tee "${artifacts_dir}/clang-version.txt"
grep -q '6443078' "${artifacts_dir}/clang-version.txt"
test -x "${build_root}/toolchains/gcc/bin/aarch64-linux-androidkernel-elfedit"
cd "${build_root}/src"
test "$(sed -n 's/^SUBLEVEL = //p' Makefile)" = 186

if [[ "$stage" = baseline || "$stage" = all ]]; then
    mkdir -p "${build_root}/out-stock"
    cp "${kit_dir}/device.config" "${build_root}/out-stock/.config"
    make "${common[@]}" "O=${build_root}/out-stock" olddefconfig
    make "${common[@]}" "O=${build_root}/out-stock" -j"${JOBS:-4}" Image modules
    test -s "${build_root}/out-stock/Module.symvers"
    cp "${build_root}/out-stock/Module.symvers" "${artifacts_dir}/stock-Module.symvers"
    cp "${build_root}/out-stock/.config" "${artifacts_dir}/stock.config"
    cp "${build_root}/out-stock/include/generated/utsrelease.h" "${artifacts_dir}/stock-utsrelease.h"
    grep -q '"4.14.186-24165939"' "${artifacts_dir}/stock-utsrelease.h"
    touch "${build_root}/stock.complete"
fi

if [[ "$stage" = audio || "$stage" = all ]]; then
    test -f "$build_root/stock.complete" || { echo "Run baseline first." >&2; exit 2; }
    mkdir -p "${build_root}/out-audio"
    cp "${kit_dir}/device.config" "${build_root}/out-audio/.config"
    scripts/config --file "${build_root}/out-audio/.config" \
        --module SND_USB_AUDIO --module SND_HWDEP
    make "${common[@]}" "O=${build_root}/out-audio" olddefconfig
    grep -qx 'CONFIG_SND_USB_AUDIO=m' "${build_root}/out-audio/.config"
    grep -qx 'CONFIG_SND_HWDEP=m' "${build_root}/out-audio/.config"
    # A separate full build ensures all module-to-module CRCs are generated.
    # Its kernel Image is a build artifact, not an image to flash.
    make "${common[@]}" "O=${build_root}/out-audio" -j"${JOBS:-4}" Image modules
    cp "${build_root}/out-audio/sound/core/snd-hwdep.ko" "${artifacts_dir}/"
    cp "${build_root}/out-audio/sound/usb/snd-usbmidi-lib.ko" "${artifacts_dir}/"
    cp "${build_root}/out-audio/sound/usb/snd-usb-audio.ko" "${artifacts_dir}/"
    cp "${build_root}/out-audio/Module.symvers" "${artifacts_dir}/audio-Module.symvers"
    cp "${build_root}/out-audio/.config" "${artifacts_dir}/audio.config"
    python3 "${kit_dir}/verify.py" "$artifacts_dir"
    echo 'Build and static checks passed. Compatibility with the running kernel still needs validation.'
fi
