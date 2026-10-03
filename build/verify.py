# SPDX-License-Identifier: GPL-2.0-only
"""Check built module metadata and symbol CRCs against the baseline build."""
from pathlib import Path
import json
import re
import subprocess
import sys

root = Path(sys.argv[1] if len(sys.argv) > 1 else '/artifacts')
def symvers(path):
    result = {}
    for line in path.read_text().splitlines():
        fields = line.split()
        if len(fields) >= 3:
            result[fields[1]] = (int(fields[0], 16), fields[2])
    return result

stock = symvers(root / 'stock-Module.symvers')
audio = symvers(root / 'audio-Module.symvers')
module_names = ['snd-hwdep', 'snd-usbmidi-lib', 'snd-usb-audio']
allowed_suffixes = ('sound/core/snd-hwdep', 'sound/usb/snd-usbmidi-lib',
                    'sound/usb/snd-usb-audio')
report = {}
for name in module_names:
    path = root / (name + '.ko')
    magic = subprocess.check_output(['modinfo', '-F', 'vermagic', str(path)], text=True).strip()
    if not magic.startswith('4.14.186-24165939 '):
        raise SystemExit(f'{name}: unexpected vermagic {magic!r}')
    imports = subprocess.check_output(['modprobe', '--dump-modversions', str(path)], text=True)
    checked = 0
    for line in imports.splitlines():
        crc_text, symbol = line.split()[:2]
        crc = int(crc_text, 16)
        if symbol in stock:
            expected = stock[symbol][0]
        elif symbol in audio and audio[symbol][1].endswith(allowed_suffixes):
            expected = audio[symbol][0]
        else:
            raise SystemExit(f'{name}: no baseline or bundled provider for {symbol}')
        if crc != expected:
            raise SystemExit(f'{name}: CRC mismatch for {symbol}: {crc:#x} != {expected:#x}')
        checked += 1
    if not checked:
        raise SystemExit(f'{name}: no symbol-version records found')
    report[name] = {'vermagic': magic, 'checked_imports': checked}
def config(path):
    return {m.group(1): m.group(2) for line in path.read_text().splitlines()
            if (m := re.fullmatch(r'(CONFIG_\w+)=(.*)', line))}
baseline, changed = config(root/'stock.config'), config(root/'audio.config')
report['config_changes'] = {key: [baseline.get(key, 'n'), changed.get(key, 'n')]
                            for key in sorted(baseline.keys() | changed.keys())
                            if baseline.get(key, 'n') != changed.get(key, 'n')}
report['limitation'] = 'CRCs are compared to the rebuilt baseline, not extracted from the running kernel.'
(root / 'verification.json').write_text(json.dumps(report, indent=2) + '\n')
print(json.dumps(report, indent=2))
