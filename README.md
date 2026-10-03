# SCR01_Enable_USB-C_Audio

삼성 SCR-01 / SM-H412J에서 USB-C DAC를 **일반 Android 앱의 오디오 출력 장치**로 사용하기 위한 커널 모듈, 오디오 정책, 설정 스크립트입니다.

2026-10-03, `SCR01KDU1AVK2` 기기와 Apple USB-C → 3.5mm DAC에서 **실제 소리 출력**을 확인했습니다. ALSA 재생은 **48kHz / 24비트 / 스테레오 / RUNNING** 상태였으며, 기본 USB HAL로 전환한 뒤 오디오 서비스도 안정적으로 유지됐습니다.

## 지원 범위

- 기기: Samsung SCR-01 / SM-H412J, Galaxy 5G Mobile Wi-Fi
- 펌웨어: **SCR01KDU1AVK2**
- Android: 11
- 커널: **4.14.186-24165939 / aarch64**
- 검증한 루팅 환경: SCRoot + KernelSU Next, SELinux `Permissive`
- 검증한 DAC: Apple USB-C to 3.5mm Headphone Jack Adapter

이 패키지는 루팅 도구가 아닙니다. 먼저 루팅을 완료해야 합니다. 다른 펌웨어·커널은 모듈 ABI가 달라질 수 있어 설정 스크립트가 중단합니다. 다른 DAC, SELinux `Enforcing`, 마이크의 실제 녹음은 검증하지 않았습니다. 스크립트는 SELinux 설정을 변경하지 않습니다.

## 어떤 기능인가요?

브라우저, 음악·영상 앱에서 재생하는 오디오를 USB-C DAC에 연결한 이어폰이나 스피커로 출력합니다. USB 오디오 입력 장치도 등록되지만 녹음 동작은 별도 검증이 필요합니다.

**DAC가 들어 있는 디지털 USB 오디오 어댑터**가 필요합니다. 단순 패시브 USB-C → 3.5mm 변환 젠더의 아날로그 오디오 모드는 이 방법의 대상이 아닙니다.

## 어떻게 동작하나요?

다음 세 단계를 연결합니다.

1. **커널 USB Audio 드라이버**: `snd-hwdep.ko` → `snd-usbmidi-lib.ko` → `snd-usb-audio.ko` 순서로 로드해 ALSA 재생·입력 장치를 생성합니다.
2. **Android 오디오 정책**: 삼성 정책 로더가 찾는 `/vendor/etc/audio_policy_configuration_sec.xml`을 읽기 전용 OverlayFS로 제공합니다. 기존 기본 설정의 primary 오디오 프로필에 USB 모듈과 볼륨 표를 추가한, include 의존성이 없는 XML입니다.
3. **USB HAL 전환**: 이 기기의 MediaTek `audio.usb.mt6853.so`는 실제 재생 시 `out_write()`에서 NULL 포인터 접근으로 반복 종료됐습니다. 기기에 이미 들어 있는 `audio.usb.default.so`를 MediaTek 경로에 bind mount해 기본 USB HAL을 사용합니다. 실제 오디오 HAL 서비스는 32비트이며, 32·64비트 경로를 모두 처리합니다.

```text
앱 → AudioTrack / AudioFlinger → USB 오디오 정책
   → 기본 USB HAL → ALSA / snd-usb-audio → USB-C DAC → 이어폰·스피커
```

원본 `/system`, `/vendor`, 커널 이미지에는 쓰지 않습니다. 라이브러리도 원본을 덮어쓰지 않습니다. 설정 적용 시 오디오 서비스만 한 번 재시작합니다. 재부팅하면 모듈과 mount가 해제되며, 추출한 파일은 `/data/local/tmp`에 남아 재사용할 수 있습니다.

## 포함된 파일

- `modules/snd-hwdep.ko`: ALSA hardware-dependent 인터페이스
- `modules/snd-usbmidi-lib.ko`: USB Audio 드라이버의 USB MIDI 의존성
- `modules/snd-usb-audio.ko`: USB Audio 재생·입력 드라이버
- `modules/SHA256SUMS`, `modules/manifest.json`: 파일 해시, vermagic, 소스·검증 정보
- `policy/audio_policy_configuration_sec.xml`: USB 오디오를 포함한 정책
- `scripts/enable.sh`: 호환성·해시 검사, 모듈 로드, HAL 전환, 정책 적용
- `scripts/status.sh`: 모듈·정책·HAL·미디어 경로·ALSA 재생 상태 확인
- `scripts/disable.sh`: 정책·HAL mount 해제 및 오디오 서비스 복구
- `scripts/common.sh`: 공통 검사와 오디오 재시작 함수
- `build/`: 재빌드 스크립트와 stock 커널 설정
- `docs/`: 동작 원리, 빌드 방법, 문제 해결

삼성 HAL `.so`, SCRoot APK, KernelSU 바이너리는 재배포하지 않습니다. HAL은 단말에 있는 파일을 사용하고, 루팅 도구는 [SCRoot 원본 프로젝트](https://github.com/hackintoanetwork/SCRoot)에서 받으세요.

## 다운로드

[Releases](https://github.com/leesop/SCR01_Enable_USB-C_Audio/releases/latest)의 `SCR01_Enable_USB-C_Audio-v1.0.0.zip`을 받거나 저장소를 clone합니다. ZIP에는 `.ko` 3개와 실행에 필요한 파일이 들어 있습니다. 이미 빌드된 모듈을 사용한다면 소스·툴체인을 별도로 내려받을 필요가 없습니다.

```sh
git clone https://github.com/leesop/SCR01_Enable_USB-C_Audio.git
cd SCR01_Enable_USB-C_Audio
```

## 루팅 이후 설정 방법

### 1. 루팅과 ADB 확인

SCRoot로 루팅과 KernelSU 설정을 완료한 뒤, ADB에서 루트 셸을 사용할 수 있는지 확인합니다. 루팅 방법과 자동 루팅 옵션은 [SCRoot 사용법](https://github.com/hackintoanetwork/SCRoot#usage)을 따릅니다.

아래의 `DEVICE`는 문자 그대로 입력하는 값이 아닙니다. `adb devices -l`에 표시되는 실제 기기 식별자로 바꾸세요. USB 연결은 기기 serial, 무선 연결은 `기기IP:포트`입니다.

```sh
adb devices -l
adb -s DEVICE shell "su -M -c 'id'"
adb -s DEVICE shell getprop ro.build.PDA
adb -s DEVICE shell uname -r
```

`uid=0`, `SCR01KDU1AVK2`, `4.14.186-24165939`를 확인합니다. `su -M`은 init과 같은 전역 mount namespace에서 실행하기 위한 옵션입니다.

DAC를 꽂으면 USB 포트로 연결한 PC의 ADB가 끊기므로, 재생 상태 확인에는 무선 ADB가 편리합니다. SCRoot의 해당 기능 또는 기존에 사용하는 무선 ADB 설정으로 연결한 뒤 `adb connect 기기IP:포트`를 실행하세요. 이 패키지는 ADB 네트워크 설정을 바꾸지 않습니다.

### 2. 파일 전송

PC에서 이 저장소 폴더 또는 릴리스 ZIP을 풀어 나온 폴더로 이동합니다. Windows PowerShell, macOS, Linux에서 같은 명령을 사용할 수 있습니다.

```sh
adb -s DEVICE push . /data/local/tmp/scr01-usb-audio/
```

### 3. 검사 후 적용

우선 변경 없이 호환성과 파일 해시만 검사할 수 있습니다.

```sh
adb -s DEVICE shell "su -M -c 'sh /data/local/tmp/scr01-usb-audio/scripts/enable.sh --check'"
```

적용은 다음 한 줄입니다.

```sh
adb -s DEVICE shell "su -M -c 'sh /data/local/tmp/scr01-usb-audio/scripts/enable.sh'"
```

스크립트는 `.ko`를 필요한 순서로 로드하고, **HAL을 먼저 전환한 뒤** 정책을 적용합니다. 따라서 고장 난 MediaTek HAL로 USB 재생을 시작하는 것을 피합니다. 적용이 이미 끝난 상태에서 다시 실행하면 mount를 중복하지 않고, 오디오 서비스도 재시작하지 않습니다.

가능하면 **설정을 적용한 다음 DAC를 연결**하세요. 이미 연결했다면 한 번 뽑았다 다시 꽂으세요. 오디오 서버 재시작 후 앱의 스트림이 복구되지 않으면 영상·음악을 다시 재생하거나 페이지를 새로고침합니다.

### 4. 재생과 확인

이어폰·스피커를 DAC에 연결하고 일반 앱에서 소리를 재생한 상태로 실행합니다.

```sh
adb -s DEVICE shell "su -M -c 'sh /data/local/tmp/scr01-usb-audio/scripts/status.sh'"
```

성공 여부는 다음 순서로 확인합니다.

1. 모듈 3개가 `/proc/modules`에 있고 ALSA cards에 DAC가 표시됩니다.
2. `Config source`가 `/vendor/etc/audio_policy_configuration_sec.xml`입니다.
3. 미디어의 `Selected Device`가 `AUDIO_DEVICE_OUT_USB_HEADSET` 또는 USB 장치입니다.
4. 실제 재생 중 PCM `state: RUNNING`과 `hw_ptr` 증가가 확인됩니다.
5. 실제 소리가 들리는지 확인합니다.

`Stop` / `closed`는 정지 상태에서는 정상입니다. 재생 중인데 계속 이 상태이거나 오디오 서비스가 사라진다면 [문제 해결](docs/TROUBLESHOOTING.md)을 확인하세요. Android 출력 장치 등록만으로 실제 소리 출력이 검증된 것은 아닙니다.

## 재부팅했을 때

SCRoot의 기본 루팅은 재부팅하면 사라집니다. **루팅 복구 → USB 오디오 적용 → DAC 연결 → 재생** 순서로 진행합니다.

1. DAC를 분리한 상태로 기기를 재부팅합니다.
2. SCRoot를 다시 실행해 루팅을 완료합니다. SCRoot의 자동 루팅을 쓰면 완료될 때까지 기다립니다.
3. ADB에 다시 연결합니다. 무선 ADB 주소·포트가 바뀌면 `DEVICE` 값도 바꿉니다.
4. 파일이 남아 있으면 아래 한 줄만 다시 실행합니다.
5. DAC를 연결하고 재생을 확인합니다.

```sh
adb -s DEVICE shell "su -M -c 'sh /data/local/tmp/scr01-usb-audio/scripts/enable.sh'"
```

`/data/local/tmp/scr01-usb-audio`가 지워졌다면 파일 전송부터 다시 합니다. 이 저장소는 부팅 자동 실행이나 KernelSU 모듈을 설치하지 않습니다. SCRoot의 자동 루팅과 이 USB 오디오 스크립트의 자동 실행은 별개입니다.

PC 없이 재적용하려면 **루팅 완료 후**, KernelSU에서 루트 권한을 허용한 Android 터미널 앱에서 실행할 수 있습니다.

```sh
su -M -c 'sh /data/local/tmp/scr01-usb-audio/scripts/enable.sh'
```

Android 터미널 앱에서의 실행은 이번 검증에 포함하지 않았습니다.

## 되돌리기

재생을 멈춘 뒤 실행합니다.

```sh
adb -s DEVICE shell "su -M -c 'sh /data/local/tmp/scr01-usb-audio/scripts/disable.sh'"
```

이 스크립트가 관리하는 HAL bind mount와 정책 OverlayFS를 해제하고 오디오 서비스를 재시작합니다. 커널 모듈은 그대로 둡니다. 재부팅하면 커널 모듈까지 해제됩니다.

## 소스와 빌드

[빌드 설명](docs/BUILD.md)을 참고하세요. 릴리스에 `.ko`와 함께 삼성 원본 `Kernel.tar.gz`를 **`SM-H412J_SCR01KDU1AVK2_Kernel.tar.gz`**라는 이름으로 제공합니다. 원본 소스, 설정, 빌드 스크립트와 검증 도구를 같은 저장소·릴리스에서 받을 수 있습니다.

소스 SHA-256:

```text
7f0ca9c6e04e7653e2f339b2f8822178d30915b7542ba5bf55c5636e034a173d
```

이번에 포함한 바이너리는 삼성 공개 소스를 사용해 사용자가 빌드한 파일을 그대로 가져온 것입니다. 해당 기기에서 모듈 로드와 실제 재생을 검증했습니다. 게시한 빌드 절차로 전체 빌드를 새로 반복해 바이너리 일치까지 확인한 것은 아닙니다. 자세한 메타데이터는 [manifest.json](modules/manifest.json)에 있습니다.

## 라이선스

커널 소스와 드라이버는 원래의 Linux/ALSA 라이선스를 따릅니다. 설정 스크립트와 빌드 보조 도구는 GPL-2.0-only, AOSP에서 가져온 USB 정책·볼륨 XML 부분은 Apache-2.0입니다. [LICENSE](LICENSE), [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)를 참고하세요.
