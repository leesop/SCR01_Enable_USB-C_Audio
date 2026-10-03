# 커널 모듈 재빌드

동봉 `.ko`를 사용하는 경우 빌드하지 않아도 됩니다.

## 입력 소스

[릴리스](https://github.com/leesop/SCR01_Enable_USB-C_Audio/releases/latest)의 `SM-H412J_SCR01KDU1AVK2_Kernel.tar.gz`를 내려받아 빌드 입력 폴더에 **`Kernel.tar.gz`**라는 이름으로 둡니다. 삼성 원본의 이름만 바꿔 릴리스에 게시한 파일이며 내용은 변경하지 않았습니다.

공식 다운로드 위치: https://opensource.samsung.com/uploadSearch?searchValue=SCR01

- 모델: SM-H412J
- 펌웨어: SCR01KDU1AVK2
- 원본 패키지: SM-H412J_JPN_RR_Opensource.zip
- 커널 아카이브 SHA-256: `7f0ca9c6e04e7653e2f339b2f8822178d30915b7542ba5bf55c5636e034a173d`

원본 삼성 안내는 [Samsung-README_Kernel.txt](../build/Samsung-README_Kernel.txt), 실제 빌드 명령은 [build.sh](../build/build.sh)에 있습니다. 이 빌드에 Platform.tar.gz는 사용하지 않습니다.

## Windows / WSL2

x86_64 Windows PC의 WSL2 Ubuntu 20.04를 기준으로 준비했습니다. 오래된 Clang에 필요한 Python 2, libtinfo5, libncurses5 때문에 Ubuntu 24.04용 설치 스크립트와는 다릅니다. Ubuntu 24.04에서 직접 빌드하는 절차는 제공하지 않습니다.

관리자 PowerShell에서 필요한 배포판을 설치합니다. 설치 후 Ubuntu의 사용자 설정을 마칩니다.

```powershell
wsl --install -d Ubuntu-20.04
```

예를 들어 소스를 `C:\scr01\source\Kernel.tar.gz`에 두고, WSL Ubuntu에서 저장소를 clone합니다. **소스 압축 파일은 Windows 폴더에서 읽어도 되지만, 빌드 작업 폴더는 WSL의 Linux 파일시스템에 둡니다.**

```bash
git clone https://github.com/leesop/SCR01_Enable_USB-C_Audio.git
cd SCR01_Enable_USB-C_Audio/build
bash setup-wsl.sh
bash run-wsl.sh /mnt/c/scr01/source all
```

Linux 사용자의 홈 아래에서 실행하세요. `/mnt/c`, `/mnt/d` 안에 빌드 작업 폴더를 만들면 스크립트가 중단합니다.

## macOS / Docker 또는 Linux / Docker

Docker를 설치한 뒤 빌드 폴더에서 실행합니다. 파일 이름은 기존 키트와의 호환성을 위해 `run-macos.sh`이지만 Docker가 있는 Linux에서도 사용할 수 있습니다.

```bash
cd SCR01_Enable_USB-C_Audio/build
bash run-macos.sh /absolute/path/to/source all
```

`source` 폴더에는 `Kernel.tar.gz`가 있어야 합니다. Docker는 Ubuntu 20.04 AMD64 환경과 Linux 볼륨에서 빌드합니다. Apple Silicon에서는 x86_64 에뮬레이션으로 시간이 오래 걸릴 수 있습니다. 메모리 8GB와 여유 디스크 20GB 이상을 시작점으로 잡고 필요하면 늘리세요.

## 빌드 방식

1. stock 설정으로 커널과 모듈 전체를 빌드해 baseline `Module.symvers`를 생성합니다.
2. 별도 출력 폴더에서 다음 두 설정을 모듈로 바꿔 다시 빌드합니다.

```text
CONFIG_SND_USB_AUDIO=m
CONFIG_SND_HWDEP=m
```

3. `sound/core/snd-hwdep.ko`, `sound/usb/snd-usbmidi-lib.ko`, `sound/usb/snd-usb-audio.ko`를 수집합니다.
4. vermagic와 imported symbol CRC를 재빌드한 baseline 또는 함께 만든 모듈의 CRC와 비교합니다.

`build/device.config`는 검증 기기의 stock 설정이며 삼성 `shootingkdi_defconfig`와 설정 항목이 일치했습니다. USB MIDI 모듈은 USB Audio 설정에서 함께 생성됩니다. 기존 PCM, RAWMIDI, BITREVERSE 내장 설정은 유지합니다.

도구는 다음 버전에 고정되어 있습니다.

- Clang r383902 / 11.0.1 / build 6443078
- Android 11 ARM64 GCC 4.9 계열 binutils
- `ARCH=arm64`, `ANDROID_MAJOR_VERSION=r`
- `LOCALVERSION=-24165939`

다운로드 주소와 커밋·태그는 `build.sh`에 있습니다. baseline 없이 `modules_prepare`만 실행해서는 MODVERSIONS용 CRC가 생성되지 않습니다. [Linux 모듈 빌드 문서](https://docs.kernel.org/kbuild/modules.html)를 참고하세요.

## 산출물과 검증 범위

`build/artifacts/`에 `.ko` 3개, stock/audio Module.symvers, 설정, 빌드 로그, `verification.json`이 생성됩니다. `baseline`, `audio`를 순서대로 실행하거나 `all`로 한 번에 실행할 수 있습니다.

정적 CRC 비교는 **재빌드한 baseline**을 기준으로 하며 실행 중인 삼성 커널의 모든 CRC를 추출한 검사가 아닙니다. 오류가 나오면 모듈을 로드하지 말고 입력 소스와 빌드 조건을 확인합니다.

동봉 바이너리는 사용자가 빌드한 후 실기에서 로드·재생을 검증했습니다. 이 저장소를 게시하는 과정에서 전체 빌드는 다시 수행하지 않았습니다. 새로 빌드한 파일도 실기 확인이 필요합니다. 빌드 중 생성된 **Image는 단말에 플래시하지 않습니다.** 이 절차의 목적은 추가 모듈 3개입니다.
