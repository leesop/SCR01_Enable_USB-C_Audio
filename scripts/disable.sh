#!/system/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu
KIT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$KIT/scripts/common.sh"
require_root
changed=0
for libdir in /vendor/lib/hw /vendor/lib64/hw; do
    if has_generic_hal "$libdir"; then
        umount -l "$libdir/audio.usb.mt6853.so"
        changed=1
    fi
done
if has_policy; then
    umount -l /vendor/etc
    changed=1
fi
[ "$changed" = 0 ] || restart_audio
echo 'Original audio policy and USB HAL are visible again.'
echo 'Kernel modules remain loaded. Reboot removes them as well.'
