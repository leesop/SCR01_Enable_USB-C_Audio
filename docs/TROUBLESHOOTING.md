# 문제 해결

## insmod 실패

`Invalid module format`, `disagrees about version of symbol`, `Unknown symbol`이 나오면 펌웨어·커널과 모듈이 맞는지 먼저 확인합니다. 이 저장소의 바이너리는 `4.14.186-24165939 SMP preempt mod_unload modversions aarch64`용입니다. 로드 순서는 `snd-hwdep` → `snd-usbmidi-lib` → `snd-usb-audio`입니다.

```sh
adb -s DEVICE shell "su -M -c 'uname -r; cat /proc/modules; dmesg | tail -n 100'"
```

`enable.sh`는 맞지 않는 기기와 해시가 다른 파일을 거부합니다. 오류를 무시하거나 force-load하지 말고 해당 커널에 맞게 다시 빌드하세요.

## DAC는 ALSA에 있지만 Android USB 출력이 없음

```sh
adb -s DEVICE shell dumpsys media.audio_policy
```

`Config source: AudioPolicyConfig::setDefault`이면 USB 정책이 활성화되지 않은 상태입니다. 이 단말에서는 삼성 로더가 찾는 `_sec.xml`, `_base.xml`이 없었고 기본 설정에는 primary 모듈만 있었습니다. 이 패키지는 `_sec.xml`을 제공합니다.

`createDevice: could not find HW module for device 4000000`은 USB 헤드셋을 처리할 오디오 모듈이 정책에 없는 경우에 관찰됐습니다. `enable.sh`를 전역 mount namespace에서 실행했는지, 정책을 읽은 뒤 DAC를 재연결했는지 확인합니다.

## 등록됐지만 재생하면 소리가 없거나 오디오 서비스가 계속 재시작함

```sh
adb -s DEVICE shell "ps -A | grep audio"
adb -s DEVICE shell "logcat -d -b crash -v time | tail -n 100"
```

이번 단말에서는 다음 충돌이 반복됐습니다.

```text
SIGSEGV / NULL pointer dereference
/vendor/lib/hw/audio.usb.mt6853.so
android::out_write(...)
```

이 문제 때문에 기본 USB HAL 전환이 필요합니다. `status.sh`에서 **32비트 `/vendor/lib/hw`와 64비트 `/vendor/lib64/hw` 모두** generic USB HAL active로 나와야 합니다. 64비트 커널이라도 실제 HAL 서비스는 32비트입니다.

`/vendor/lib*/hw/audio.usb.mt6853.so`를 삭제하거나 vendor 파티션을 쓰기 가능하게 바꾸지 마세요. `enable.sh`가 단말에 있는 같은 아키텍처의 `audio.usb.default.so`를 일시적으로 bind mount합니다.

## 앱은 재생 표시인데 PCM은 closed / Stop

재생 표시와 실제 AudioTrack은 다를 수 있습니다. DAC가 인식됐고 USB 출력 경로가 선택됐는지 확인한 뒤 앱에서 정지·재생 또는 페이지 새로고침을 합니다. 서비스 충돌 여부도 확인합니다.

```sh
adb -s DEVICE shell dumpsys media.audio_flinger
adb -s DEVICE shell dumpsys audio
```

검증 시 실제 성공 상태는 USB 출력 스레드 `Standby: no`, PCM `state: RUNNING`, `hw_ptr` 증가였습니다. 재생 데이터가 전달돼도 실제 소리는 이어폰·스피커와 볼륨을 확인해야 합니다.

## 재연결 후 ALSA card가 사라짐

검증 도중 USB 컨트롤러의 분리 처리에서 `usb_disconnect` → `usb_disable_device` → `xhci_configure_endpoint` 대기가 일시적으로 관찰됐습니다. 이후 재연결로 복구됐지만 정확한 원인은 확정하지 않았습니다. 이 패키지는 xHCI 드라이버를 수정하지 않습니다.

먼저 DAC를 분리했다 다시 연결하고 cards를 확인합니다. 계속 복구되지 않으면 DAC를 분리한 상태로 재부팅하고 루팅·오디오 설정을 다시 적용한 다음 연결합니다.

## 다른 mount와 충돌함

`Another mount covers ...` 오류는 해당 경로에 다른 설정이 이미 적용돼 있다는 뜻입니다. 스크립트는 이를 덮어쓰지 않습니다. 기존 오디오 변경을 해제한 뒤 다시 시도하세요. 이전 임시 키트의 `scr01-usb-policy` 정책과 동일한 기본 HAL bind mount는 재사용할 수 있습니다.

## SELinux Enforcing에서 실패함

이번 실기 검증은 SCRoot 루팅 이후 Permissive 환경에서 진행했습니다. Enforcing 환경의 mount·오디오 장치 접근은 별도 검증과 SELinux 정책 작업이 필요할 수 있습니다. 스크립트는 `setenforce`, SELinux 정책 패치를 실행하지 않습니다.
