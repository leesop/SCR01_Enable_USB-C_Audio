#!/system/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu
KIT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
. "$KIT/scripts/common.sh"
case "${1:-}" in ''|--check) ;; *) fail 'Usage: enable.sh [--check]';; esac
preflight
[ "${1:-}" != --check ] || exit 0

new_policy=0
new_hal32=0
new_hal64=0
cleanup_failure() {
    rc=$?
    [ "$rc" = 0 ] && return
    echo 'Apply failed; removing only the mounts created by this attempt.' >&2
    [ "$new_policy" = 0 ] || umount -l /vendor/etc || true
    [ "$new_hal64" = 0 ] || umount -l /vendor/lib64/hw/audio.usb.mt6853.so || true
    [ "$new_hal32" = 0 ] || umount -l /vendor/lib/hw/audio.usb.mt6853.so || true
    # Modules loaded successfully before a later failure remain loaded.
    exit "$rc"
}
trap cleanup_failure EXIT

for spec in snd_hwdep:snd-hwdep snd_usbmidi_lib:snd-usbmidi-lib snd_usb_audio:snd-usb-audio; do
    module_name=${spec%%:*}
    module_file=${spec#*:}
    if has_module "$module_name"; then
        echo "Already loaded: $module_name"
    else
        insmod "$KIT/modules/$module_file.ko"
        echo "Loaded: $module_name"
    fi
done

# Cover the crashing MediaTek HAL before activating USB audio policy.
if ! has_generic_hal /vendor/lib/hw; then
    mount --bind /vendor/lib/hw/audio.usb.default.so /vendor/lib/hw/audio.usb.mt6853.so
    new_hal32=1
fi
if ! has_generic_hal /vendor/lib64/hw; then
    mount --bind /vendor/lib64/hw/audio.usb.default.so /vendor/lib64/hw/audio.usb.mt6853.so
    new_hal64=1
fi

if has_policy; then
    cmp -s "$KIT/policy/audio_policy_configuration_sec.xml" /vendor/etc/audio_policy_configuration_sec.xml ||
        fail 'A different USB policy is mounted. Run disable.sh, then enable.sh.'
    echo 'Matching USB policy is already mounted.'
else
    mkdir -p "$STATE/upper" "$STATE/overlay-work"
    cp "$KIT/policy/audio_policy_configuration_sec.xml" "$STATE/upper/"
    chmod 755 "$STATE" "$STATE/upper" "$STATE/overlay-work"
    chmod 644 "$STATE/upper/audio_policy_configuration_sec.xml"
    chown 0:0 "$STATE/upper/audio_policy_configuration_sec.xml"
    chcon u:object_r:vendor_configs_file:s0 "$STATE/upper" "$STATE/upper/audio_policy_configuration_sec.xml"
    mount -t overlay "$POLICY_MARKER" \
        -o "ro,lowerdir=/vendor/etc,upperdir=$STATE/upper,workdir=$STATE/overlay-work" /vendor/etc
    new_policy=1
fi

if [ "$new_policy$new_hal32$new_hal64" != 000 ]; then
    restart_audio
else
    echo 'Already enabled; audio services were left running.'
fi
echo 'USB audio setup complete. Reconnect the DAC if it was attached before setup.'
echo 'Start playback, then run scripts/status.sh. Reboot removes the runtime setup.'
