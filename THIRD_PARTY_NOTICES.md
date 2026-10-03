# Third-party notices and source mapping

## Linux / ALSA USB Audio modules

Distributed binaries:

- `modules/snd-hwdep.ko`: `sound/core/hwdep.c` and related headers in Samsung's kernel source; module license GPL.
- `modules/snd-usbmidi-lib.ko`: `sound/usb/midi.c` and related headers; module license Dual BSD/GPL, distributed here under the GPL option.
- `modules/snd-usb-audio.ko`: `sound/usb/` USB Audio sources and related headers; module license GPL.

Copyright belongs to the original Linux, ALSA, and Samsung contributors. The kernel's GPL version 2 terms and clarification are in [LICENSE](LICENSE). Per-file notices remain in the source archive.

The corresponding kernel source archive is distributed alongside the binaries in [Releases](https://github.com/leesop/SCR01_Enable_USB-C_Audio/releases/latest) as `SM-H412J_SCR01KDU1AVK2_Kernel.tar.gz`:

```text
SHA256 7f0ca9c6e04e7653e2f339b2f8822178d30915b7542ba5bf55c5636e034a173d
```

It is the unchanged `Kernel.tar.gz` from Samsung's `SM-H412J_JPN_RR_Opensource.zip` for SCR01KDU1AVK2. The stock configuration, toolchain references, build scripts, module configuration changes and verification tool are in `build/` and [docs/BUILD.md](docs/BUILD.md). No kernel C-source patch is applied by that recipe.

The binaries were built by the device owner from that source and supplied for this package. They were checked for architecture, vermagic, hashes, successful module loading, and actual audio playback. A fresh bit-for-bit rebuild and extraction of every running-kernel symbol CRC were not performed.

## AOSP audio policy XML

`policy/audio_policy_configuration_sec.xml` combines a minimal primary policy with USB policy and volume tables derived from these files on the target firmware:

- `/system/etc/usb_audio_policy_configuration.xml`
- `/system/etc/audio_policy_volumes.xml`
- `/system/etc/default_volume_tables.xml`

Copyright (C) The Android Open Source Project. These portions retain Apache License 2.0 terms, reproduced in [licenses/Apache-2.0.txt](licenses/Apache-2.0.txt). The XML header retains attribution and the license URL.

## Repository scripts

Setup, status, rollback and build helper code is distributed under GPL-2.0-only. Existing third-party components retain their own terms.

## Components used on the device, not redistributed

- Stock `audio.usb.default.so` and `audio.usb.mt6853.so`: this repository contains paths and mount instructions only, not copies of Samsung/vendor HAL libraries.
- [SCRoot](https://github.com/hackintoanetwork/SCRoot), KernelSU Next and its OverlayFS metamodule: installed separately; their binaries and sources are not incorporated into this repository.
- Android Clang/GCC toolchains: downloaded from official Android repositories by the build script, not included in the release bundle.
