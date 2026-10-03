#!/system/bin/sh
# SPDX-License-Identifier: GPL-2.0-only
set -eu
EXPECTED_FIRMWARE=SCR01KDU1AVK2
EXPECTED_KERNEL=4.14.186-24165939
POLICY_MARKER=scr01-usb-policy
STATE=/data/local/tmp/scr01-usb-policy-state

fail() { echo "ERROR: $*" >&2; exit 1; }
require_root() {
    [ "$(id -u)" = 0 ] || fail 'Run with su -M -c (root in the global mount namespace).'
    [ "$(readlink /proc/self/ns/mnt)" = "$(readlink /proc/1/ns/mnt)" ] ||
        fail 'Mount namespace differs from init. Use su -M -c.'
}
has_mount() {
    awk -v target="$1" '$5 == target { found=1 } END { exit !found }' /proc/self/mountinfo
}
has_policy() {
    awk -v marker="$POLICY_MARKER" '$1 == marker && $2 == "/vendor/etc" { found=1 } END { exit !found }' /proc/mounts
}
has_generic_hal() {
    # /vendor is its own partition on the supported stock firmware.
    source_root="${1#/vendor}/audio.usb.default.so"
    target="$1/audio.usb.mt6853.so"
    awk -v source="$source_root" -v target="$target" '$4 == source && $5 == target { found=1 } END { exit !found }' /proc/self/mountinfo
}
has_module() { awk -v name="$1" '$1 == name { found=1 } END { exit !found }' /proc/modules; }
restart_audio() {
    if setprop ctl.restart audioserver 2>/dev/null; then
        echo 'Requested audioserver restart.'
        return
    fi
    # SCRoot's root context can still be rejected by Android's property service.
    audio_pid=$(pidof audioserver || true)
    if [ -n "$audio_pid" ]; then
        kill -TERM $audio_pid
    else
        hal_pid=$(pidof android.hardware.audio.service || true)
        [ -z "$hal_pid" ] || kill -TERM $hal_pid
    fi
    echo 'Audio restart requested via SIGTERM; init restarts the services.'
}
preflight() {
    require_root
    [ "$(getprop ro.product.device)" = SCR01 ] || fail 'This package is for SCR01 only.'
    [ "$(getprop ro.build.PDA)" = "$EXPECTED_FIRMWARE" ] || fail "Expected firmware $EXPECTED_FIRMWARE."
    [ "$(uname -r)" = "$EXPECTED_KERNEL" ] || fail "Expected kernel $EXPECTED_KERNEL."
    [ "$(uname -m)" = aarch64 ] || fail 'Expected aarch64 kernel.'
    grep -q overlay /proc/filesystems || fail 'OverlayFS is unavailable.'
    for libdir in /vendor/lib/hw /vendor/lib64/hw; do
        [ -f "$libdir/audio.usb.default.so" ] || fail "Missing $libdir/audio.usb.default.so"
        [ -f "$libdir/audio.usb.mt6853.so" ] || fail "Missing $libdir/audio.usb.mt6853.so"
        if has_mount "$libdir/audio.usb.mt6853.so" && ! has_generic_hal "$libdir"; then
            fail "Another mount covers $libdir/audio.usb.mt6853.so; inspect it first."
        fi
    done
    if has_mount /vendor/etc && ! has_policy; then
        fail 'Another mount covers /vendor/etc; inspect it first.'
    fi
    [ -s "$KIT/policy/audio_policy_configuration_sec.xml" ] || fail 'Policy XML is missing.'
    (cd "$KIT/modules" && sha256sum -c SHA256SUMS) || fail 'Module checksums do not match.'
    echo "Preflight passed: $EXPECTED_FIRMWARE / $EXPECTED_KERNEL; SELinux=$(getenforce)"
}
