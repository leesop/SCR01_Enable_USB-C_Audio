#!/system/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu
KIT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$KIT/scripts/common.sh"
echo "Firmware: $(getprop ro.build.PDA)"
echo "Kernel: $(uname -r)"
echo "SELinux: $(getenforce)"
echo '--- Loaded audio modules ---'
awk '$1 ~ /^snd_(hwdep|usbmidi_lib|usb_audio)$/ {print}' /proc/modules
echo '--- ALSA cards ---'
cat /proc/asound/cards
echo '--- USB policy ---'
if has_policy; then echo 'Mounted'; else echo 'Not mounted'; fi
for libdir in /vendor/lib/hw /vendor/lib64/hw; do
    if has_generic_hal "$libdir"; then echo "$libdir: generic USB HAL active";
    else echo "$libdir: generic USB HAL bind is absent"; fi
done
echo '--- Android audio policy source and media device ---'
dumpsys media.audio_policy | awk '
    /Config source:/ {print}
    /STRATEGY_MEDIA/ {print; getline; print}
'
echo '--- ALSA playback status and hardware parameters ---'
for card in /proc/asound/card[0-9]*; do
    [ -d "$card" ] || continue
    [ ! -f "$card/stream0" ] || cat "$card/stream0"
    for pcm in "$card"/pcm*p/sub*/status; do
        [ -f "$pcm" ] || continue
        echo "$pcm"
        cat "$pcm"
        cat "${pcm%/status}/hw_params"
    done
done
