# SecureCRT Cisco IOL 키워드 하이라이트

`PNET-Cisco-Dark.ini`는 Cisco IOL 장비의 CLI 출력에서 장애 상태, 인터페이스 상태, STP, EtherChannel, HSRP, OSPF 및 주요 식별자를 빠르게 찾을 수 있도록 만든 SecureCRT 키워드 하이라이트 설정입니다. 어두운 터미널 배경을 염두에 둔 색상 구성이지만, 실제 가독성은 SecureCRT의 터미널 테마와 사용자 설정에 따라 달라질 수 있습니다.

이 설정은 다음 특징을 가집니다.

- 대소문자를 구분합니다. 파일의 `D:"Match Case"=00000001` 설정에 해당합니다.
- SecureCRT의 `Keyword List V2`와 `Keyword List V3` 형식을 제공합니다. 두 목록은 같은 348개 규칙을 사용합니다.
- `show ip bgp`, `show ip bgp summary`, `show ip bgp neighbors`의 전용 규칙이 generic 상태 규칙보다 먼저 적용되며, neighbor `state = ...` 출력도 강조합니다.
- 정규식 패턴으로 상태 문자열, 숫자, IP 주소, 인터페이스 이름, 프롬프트 등을 하이라이트합니다.
- 키워드 목록 자체에 설치 스크립트, 자동화 명령, 외부 의존성은 포함하지 않습니다.

## 빠른 시작

### 준비 사항

- 이 설치 스크립트는 Windows에서만 실행됩니다.
- 저장소의 `Install-KeywordHighlight.ps1`, `PNET-Cisco-Dark.ini`, `PNET-Cisco-Dark-V3.ini`가 함께 있는지 확인하십시오.
- 설치 전 SecureCRT를 종료하고, 가능하면 SecureCRT의 설정 폴더와 세션/글로벌 설정을 별도로 백업하십시오. 스크립트도 덮어쓰기 직전에 timestamp 백업을 만들지만, 별도 보관본을 추가로 준비하는 것이 안전합니다.

### PowerShell 실행 위치와 일반 설치

PowerShell을 저장소 폴더에서 실행하십시오. 저장소 폴더가 현재 위치가 아니라면 먼저 그 폴더로 이동합니다.

```powershell
Set-Location 'C:\Path\To\securecrt-cisco-iol-keyword-highlighting'
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1
```

`-ConfigPath`를 생략하면 스크립트가 아래 순서로 SecureCRT 설정 폴더를 자동 탐색하고, **처음으로 존재하는 폴더**를 사용합니다.

1. `%APPDATA%\VanDyke\Config`
2. `%APPDATA%\VanDyke\SecureCRT\Config`
3. `%LOCALAPPDATA%\VanDyke\SecureCRT\Config`
4. `%USERPROFILE%\Documents\SecureCRT\Config`

자동 탐색 대신 경로를 직접 지정하려면 `-ConfigPath`에 **SecureCRT 설정 폴더 자체**를 입력하십시오. `Keywords` 폴더나 `Default.ini` 파일 경로를 입력하면 안 됩니다. 지정한 폴더 안에는 `Sessions\Default.ini`가 있어야 하며, 경로가 존재하지 않거나 이 구조가 아니면 오류로 종료합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -ConfigPath 'C:\Path\To\Config'
```

자동 탐색 후보를 모두 찾지 못한 경우 `-Force`가 없으면 다음 프롬프트가 표시됩니다.

```text
SecureCRT 설정 폴더를 자동으로 찾지 못했습니다. 설정 폴더 경로를 직접 입력하십시오:
```

이때 `Sessions\Default.ini`가 들어 있는 **전체 설정 폴더 경로**를 입력하고 Enter를 누르십시오. 잘못된 경로를 입력하면 종료합니다. `-Force`를 함께 사용하면 이 프롬프트가 나오지 않고 자동 탐색 실패가 오류가 되므로, 이 경우에는 반드시 유효한 `-ConfigPath`를 명시해야 합니다.

### 설치 전후 순서

1. SecureCRT를 종료하고 별도 설정 백업을 준비합니다.
2. PowerShell에서 저장소 폴더로 이동합니다.
3. 일반 설치 명령을 실행하거나, 필요한 경우 `-ConfigPath`로 설정 폴더를 직접 지정합니다.
4. 실행 중인 SecureCRT, 기존 키워드 파일, 기존 `Default.ini`에 대한 확인이 나오면 아래 [입력과 선택지](#입력과-선택지)의 규칙대로 응답합니다. 승인 입력은 `Y` 또는 `y`뿐입니다.
5. 설치가 끝나면 SecureCRT를 다시 시작합니다.
6. 저장된 CLI 출력 또는 테스트 장비에서 하이라이트와 실제 색상을 확인합니다. 예를 들어 `show interfaces`, `show spanning-tree`, `show etherchannel summary`, `show standby`, `show ip ospf neighbor` 등의 출력으로 점검할 수 있습니다.

## Windows 자동 설치 스크립트

`Install-KeywordHighlight.ps1`은 SecureCRT 설정 폴더를 확인한 뒤 선택한 키워드 목록을 `Keywords`에 설치하고, `Sessions\Default.ini`에 기본 세션 하이라이트 옵션을 적용하는 Windows용 PowerShell 스크립트입니다. `-KeywordListVersion`을 생략하면 V3를 자동 선택하며 V2/V3 선택 프롬프트를 표시하지 않습니다. V2는 `PNET-Cisco-Dark.ini`/`PNET-Cisco-Dark`, V3는 `PNET-Cisco-Dark-V3.ini`/`PNET-Cisco-Dark-V3`를 사용하므로 두 파일을 함께 보관할 수 있습니다.

### 입력과 선택지

| 상황 | 스크립트가 묻는 내용 | 입력 방법과 결과 |
|---|---|---|
| 키워드 목록 버전 자동 선택 | 별도 프롬프트 없음 | `-KeywordListVersion`을 생략하면 V3를 즉시 선택합니다. V2를 사용하려면 `-KeywordListVersion V2`를 명시하십시오. |
| 자동 탐색 실패(`-Force` 없음) | `SecureCRT 설정 폴더를 자동으로 찾지 못했습니다. 설정 폴더 경로를 직접 입력하십시오` | `Sessions\Default.ini`가 있는 전체 설정 폴더 경로를 입력하고 Enter를 누릅니다. 잘못된 경로면 종료합니다. |
| SecureCRT 실행 중(`-Force` 없음) | `계속하시겠습니까? (Y/N)` | `Y` 또는 `y`만 계속입니다. 그 밖의 모든 입력은 취소이며 변경하지 않습니다. 종료 후 실행하는 것을 권장합니다. |
| 선택한 키워드 파일 존재(`-Force`/`-WhatIf` 없음) | `기존 <선택한 파일>가 존재합니다. 백업 후 덮어쓰시겠습니까? (Y/N)` | `Y` 또는 `y`만 백업 후 덮어쓰기를 승인합니다. 그 밖의 입력은 취소이며 변경하지 않습니다. |
| 기존 `Default.ini` 적용(`-Force`/`-WhatIf` 없음) | `기존 Default.ini가 존재합니다. 백업 후 기본 세션 설정을 적용하시겠습니까? (Y/N)` | `Y` 또는 `y`만 백업 후 기본 옵션 적용을 승인합니다. 그 밖의 입력은 취소이며 변경하지 않습니다. |

따라서 `yes`, `Yes`, `예` 등은 승인 입력으로 취급되지 않습니다. 각 질문에는 반드시 `Y` 또는 `y`를 입력하십시오. `-WhatIf`를 사용하면 두 파일의 설치 확인 프롬프트는 건너뛰지만, 실제 변경 없이도 Windows 실행 환경, 설정 경로, `Sessions\Default.ini` 존재 여부 및 필요한 접근 권한을 검증해야 합니다. SecureCRT 실행 여부 확인은 `-WhatIf`가 자동으로 건너뛰는 항목이 아니며, 실행 중이고 `-Force`도 없으면 해당 프롬프트가 표시될 수 있습니다.

### 주요 옵션

| 옵션 | 입력과 동작 |
|---|---|
| `-ConfigPath <경로>` | `Sessions\Default.ini`가 들어 있는 SecureCRT 설정 폴더 자체를 입력합니다. `Keywords` 폴더나 `Default.ini` 파일을 지정하지 마십시오. 존재하지 않는 경로면 오류로 종료합니다. 생략 시 위의 후보 경로를 순서대로 자동 탐색합니다. |
| `-Force` | SecureCRT 실행 확인과 기존 키워드 파일/`Default.ini`의 백업 후 적용 확인을 건너뜁니다. 자동 탐색 실패를 해결하는 옵션은 아니므로, 자동 탐색이 실패할 때는 `-ConfigPath`를 명시해야 합니다. 실행 중인 SecureCRT가 설정 파일을 다시 저장해 변경 내용을 덮어쓸 수 있으므로 종료 후 실행하는 것이 좋습니다. |
| `-KeywordListVersion V2|V3` | 설치·제거 대상을 명시적으로 선택합니다. 생략 시 V3를 자동 선택하며 V2/V3 선택 프롬프트를 표시하지 않습니다. 명시적으로 V2를 지정하면 V2를 선택합니다. |
| `-WhatIf` | 실제 파일 변경 없이 예정된 작업만 출력합니다. 설치 확인 프롬프트는 건너뛰지만 경로·파일·접근 권한 검증은 필요합니다. |
| `-Uninstall` | `-KeywordListVersion`으로 선택한 키워드 파일과 해당 버전의 백업만 복원·제거합니다. 다른 버전의 키워드 파일은 삭제하지 않습니다. `Default.ini` 백업도 버전별로 구분하며, 백업이 없을 때 현재 `Default.ini`를 임의로 삭제하거나 변경하지 않습니다. `-RollbackVersion`/`-Version`과 함께 사용할 수 없습니다. |
| `-SkipUpdate` | GitHub 원격 버전 확인과 self-update를 건너뜁니다. 인터넷에 연결되지 않은 환경에서는 이 옵션을 사용하십시오. |
| `-IncludePrerelease` | prerelease 선택을 명시적으로 허용합니다. 생략하면 GitHub가 prerelease로 표시하지 않고 태그 SemVer에도 prerelease 식별자가 없는 published non-draft stable 릴리스 중 가장 높은 유효한 버전을 사용합니다. |
| `-RollbackVersion <버전>` | `v0.1.0` 또는 `0.1.0`처럼 유효한 Semantic Version을 입력합니다. 별칭은 `-Version`입니다. 선택한 버전의 Git 태그 자산과 `CHANGELOG.md`를 검증한 뒤 설치합니다. 요청한 V3 파일이 태그에 없으면 V2로 대체하지 않고 오류로 중단합니다. |

일반 설치/제거는 공개 저장소 `MinePacu/securecrt-cisco-iol-keyword-highlighting`의 GitHub Releases에서 가장 높은 유효한 published non-draft stable 릴리스의 태그를 확인합니다. 기본 self-update는 GitHub가 prerelease로 표시하지 않고 태그 SemVer에도 prerelease 식별자가 없는 릴리스만 선택합니다. `-IncludePrerelease`를 지정한 경우에만 비-draft prerelease 릴리스도 선택 대상에 포함합니다. 원격 버전이 더 높으면 선택한 태그에서 설치 스크립트, V2/V3 키워드 파일, `CHANGELOG.md`를 가져와 검증하고 self-update한 뒤 선택한 `-KeywordListVersion`을 보존하여 다시 실행합니다. V3 자산이 없거나 원격 검증에 실패하면 경고를 표시하고 기존 로컬 설치를 계속합니다. 오프라인이거나 원격 확인을 원하지 않으면 `-SkipUpdate`를 지정하십시오. `-RollbackVersion`을 지정한 경우에는 일반 최신 버전 확인 대신 지정한 Git 태그의 선택된 버전을 검증합니다.

### 설치, 변경 계획, 제거 명령

키워드 파일과 기본 세션 옵션을 설치합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -ConfigPath 'C:\Path\To\Config'
```

V2 목록을 설치하려면 명시적으로 선택합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -ConfigPath 'C:\Path\To\Config' -KeywordListVersion V2
```

경로 자동 탐색을 사용하려면 `-ConfigPath`를 생략합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1
```

자동 업데이트 확인에 GitHub prerelease도 포함하려면 명시적으로 선택합니다. 생략하면 가장 높은 유효한 published non-draft stable GitHub Release만 확인합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -ConfigPath 'C:\Path\To\Config' -IncludePrerelease
```

변경 계획만 확인합니다. `-WhatIf`에서는 실제 파일을 쓰거나 백업을 만들지 않습니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -ConfigPath 'C:\Path\To\Config' -WhatIf
```

설치된 키워드 파일과 스크립트가 만든 최신 백업을 복원합니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -ConfigPath 'C:\Path\To\Config' -Uninstall
```

특정 태그의 설정으로 회귀하려면 유효한 Semantic Version을 입력합니다. `-Version`은 `-RollbackVersion`의 별칭입니다.

```powershell
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -ConfigPath 'C:\Path\To\Config' -RollbackVersion v0.1.0 -KeywordListVersion V3
powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -ConfigPath 'C:\Path\To\Config' -Version 0.1.0 -WhatIf
```

회귀는 `MinePacu/securecrt-cisco-iol-keyword-highlighting`의 해당 `v<버전>` Git 태그에서 선택한 V2/V3 파일과 `CHANGELOG.md`를 가져와 CHANGELOG 버전이 요청한 버전과 정확히 일치하는지 확인합니다. 태그의 검증이 실패하거나 요청한 V3 파일이 없으면 V2로 바꾸지 않고 설치를 중단하며, 현재 로컬 파일은 덮어쓰지 않습니다. 회귀가 유효하면 선택한 키워드 파일과 해당 버전의 `Default.ini` timestamp 백업을 만들고, 현재 설치 로직의 기본 세션 옵션을 `Default.ini`에 적용합니다. `Default.ini` 자체를 태그별 내용으로 회귀시키는 것은 아닙니다. `-RollbackVersion`과 `-Uninstall`은 함께 사용할 수 없습니다.

### 설치 시 적용되는 파일과 옵션

- `Sessions\Default.ini`가 없으면 새로 만들지 않고 명확한 오류로 종료합니다.
- 선택한 버전의 키워드 설정을 설치합니다: V2는 `Keywords\PNET-Cisco-Dark.ini`, V3는 `Keywords\PNET-Cisco-Dark-V3.ini`입니다.
- `S:"Color Scheme"=Birds of Paradise`
- `D:"Use Cursor Color"=00000001`, `D:"Cursor Color"=00FFFFFF`
- `S:"Keyword Set"=PNET-Cisco-Dark` 또는 `S:"Keyword Set"=PNET-Cisco-Dark-V3`를 선택한 basename으로 적용합니다.
- `D:"Highlight Reverse Video"=00000000`, `D:"Highlight Bold"=00000001`, `D:"Highlight Color"=00000001`
- 기존 선택 키워드 파일과 `Default.ini`는 덮어쓰기 전에 각각 timestamp 백업을 만듭니다. V3의 `Default.ini` 백업은 V3 이름으로 구분하며, `-Uninstall`은 선택한 버전에 해당하는 최신 백업만 복원합니다.

## 제공 파일

- `PNET-Cisco-Dark.ini`: SecureCRT용 키워드 하이라이트 목록
- `PNET-Cisco-Dark-V3.ini`: 같은 348개 규칙을 SecureCRT `Keyword List V3` 형식으로 저장한 키워드 하이라이트 목록
- `README.md`: 설정 범위, 설치/제거 절차, 적용 시 주의사항 및 그룹/색상 설명
- `Install-KeywordHighlight.ps1`: Windows용 자동 설치/제거 PowerShell 스크립트

현재 저장소에는 설치 스크립트(`Install-KeywordHighlight.ps1`)가 포함되어 있지만, 별도의 라이선스 문서는 없습니다.

## SecureCRT 적용 결과와 제한사항

설치 스크립트는 선택한 `Keywords\PNET-Cisco-Dark.ini` 또는 `Keywords\PNET-Cisco-Dark-V3.ini` 설치와 `Sessions\Default.ini`의 기본 세션 설정 적용을 함께 수행하므로, 설치 후 별도로 ini를 복사하거나 세션 옵션을 수동으로 입력할 필요가 없습니다. SecureCRT 설정 폴더와 `Keywords` 하위 폴더의 실제 위치는 버전·프로필 구성에 따라 달라질 수 있습니다. `-ConfigPath`에는 반드시 `Sessions\Default.ini`가 들어 있는 설정 폴더를 지정하십시오.

스크립트는 Cisco 장비에 명령을 실행하거나 장비 설정을 변경하지 않으며, 자동 업데이트에 필요한 원격 확인 외의 네트워크나 레지스트리 작업을 수행하지 않습니다. 하이라이트는 표시 기능일 뿐이므로, 장비에 명령을 붙여 넣거나 적용하는 작업과는 별개입니다.

SecureCRT가 실행 중이어도 `-Force`로 진행할 수 있지만, SecureCRT가 파일을 다시 저장하면서 변경 내용을 덮어쓸 수 있습니다. 따라서 설치·제거 전에는 SecureCRT를 종료하고, 설치 후에는 SecureCRT를 다시 시작해 저장된 출력 또는 테스트 장비에서 결과를 확인하십시오.

## 색상 코드

INI의 색상값은 일반적인 SecureCRT/Windows `COLORREF` 저장 방식인 `0x00BBGGRR`로 해석해 RGB 색상으로 병기했습니다. `설정값`은 파일에 실제로 들어 있는 8자리 값이며, `RGB`는 화면 색을 이해하기 위한 `#RRGGBB` 표기입니다. 터미널 테마, 글꼴, 선택 영역 및 SecureCRT의 렌더링 설정에 따라 체감 색상은 달라질 수 있습니다.

| 설정값 | RGB | 대표 색상 | 이 설정에서의 주요 용도 |
|---|---|---|---|
| `00FFFFFF` | `#FFFFFF` | 흰색 | 그룹 제목, 라우팅 테이블 특수 경로 modifier |
| `000000FF` | `#FF0000` | 빨강 | 오류, 실패, 비활성/다운 상태 |
| `00FF00FF` | `#FF00FF` | 자홍 | 불일치, Guard 관련 상태, 일부 중요 경고 |
| `0032CD32` | `#32CD32` | 라임 그린 | 정상, up, connected, forwarding, active |
| `00FFFF00` | `#00FFFF` | 시안 | Root 관련 항목, 일부 상태·주소 강조 |
| `00FACE87` | `#87CEFA` | 라이트 스카이 블루 | 보조 상태, 인터페이스 모드, 파라미터 |
| `0000A5FF` | `#FFA500` | 주황 | 대체/비정상 경로, 일부 EtherChannel·OSPF 상태 |
| `0000FFFF` | `#FFFF00` | 노랑 | 대기/차단/중간 단계 등 주의가 필요한 상태 |
| `00C0C0C0` | `#C0C0C0` | 은색 | 중립적이거나 초기화된 상태 |
| `00B469FF` | `#FF69B4` | 핫 핑크 | 프로토콜·기능 이름, LSDB/OSPF 식별자 |
| `00EE82EE` | `#EE82EE` | 바이올렛 | 인스턴스·그룹·LSA 유형 등 분류 정보 |
| `0000D7FF` | `#FFD700` | 골드 | OSPF cost/metric/reference bandwidth |
| `00FF0000` | `#0000FF` | 파랑 | BGP 경로 코드 |
| `00FFBF00` | `#00BFFF` | 딥 스카이 블루 | OSPF N2/E2 경로 코드 |
| `00C1B6FF` | `#FFB6C1` | 라이트 핑크 | IS-IS 계층·요약 경로 코드 |

색상은 위험도를 엄밀하게 표현하는 표준이 아니라 출력 탐색을 위한 시각적 분류입니다. 예를 들어 같은 색상이 여러 그룹에서 서로 다른 종류의 정보에 사용될 수 있으므로, 색상만으로 장비 상태를 판정하지 말고 원문 출력과 장비의 실제 상태를 함께 확인해야 합니다.

## 주요 하이라이트 그룹

그룹 제목은 INI에서 `[*]`로 시작하는 항목으로 구분됩니다.

| 그룹 | 강조 대상 |
|---|---|
| `CRITICAL_ERRORS_AND_DOWN_STATES` | `administratively down`, `err-disabled`, 불일치, 실패/오류, shutdown, down 등 장애·다운 상태 |
| `GOOD_AND_INTERFACE_STATES` | up, connected, enabled, permit, success, passed 및 `down->up` 등 정상·회복 상태 |
| `STP_RAPID_PVST_MST` | Root/Bridge ID, Root Port, 역할(Desg/Altn/Back), FWD/BLK, PVST/RSTP/MST, PortFast·Guard·inconsistent |
| `ETHERCHANNEL` | `(P)`, `(I)`, `(s)`, `(D)`, `(H)`, `(w)`, `(u)`, SU/RU/SD/RD, stand-alone, bundled, LACP/PAgP |
| `HSRP` | Active/Standby/Speak/Listen/Init/Learn, 가상 IP, 우선순위, 그룹, preemption |
| `OSPF_PROCESS_AREA_AND_IDS` | OSPF 프로세스·Process ID, Router ID, Area, ABR/ASBR, stub/NSSA |
| `OSPF_COST_METRIC_REFERENCE_BW` | cost, metric, reference bandwidth, OSPF 경로 비용, BW, MTU |
| `OSPF_ROUTE_TYPES` | O, O IA, O E1/E2, O N1/N2 및 metric type |
| `OSPF_NETWORK_TYPE_AND_DR_BDR` | 네트워크 유형, DR/BDR/DROTHER, OSPF priority |
| `OSPF_NEIGHBOR_STATES` | FULL, 2WAY, EXSTART, EXCHANGE, LOADING, ATTEMPT, 인접성/Neighbor Count |
| `OSPF_TIMERS` | Hello, Dead, Wait, Retransmit, Dead Time, Transmit Delay |
| `OSPF_LSDB_AND_LSA` | LSDB/LSA, Router·Network·Summary·External/NSSA LSA, Link State ID, sequence/checksum |
| `OSPF_SPF_AND_CONFIG` | SPF 실행·타이머, `ip ospf ... area`, network area, passive-interface, default-information, area 설정 |
| `OSPF_VIRTUAL_LINKS` | `show ip ospf virtual-links`의 `OSPF_VL<n>` 식별자, `Transit area` 문구와 정수·IPv4 형식 transit area ID |
| `VLAN_TRUNK_AND_LAYER2` | trunk/access, VLAN/Vl 번호, native VLAN, dot1q/802.1Q |
| `INTERFACES_ADDRESSES_AND_IDENTIFIERS` | 장문·축약 인터페이스 이름, IPv4 주소/프리픽스, Cisco dotted MAC 및 콜론 형식 MAC |
| `ROUTING_TABLE_CODES_AND_METRICS` | `show ip route` 범례와 경로 행의 L/C/S·S*/R/I/M/B/D/EX/O, OSPF 세부 코드, IS-IS 계층 코드 및 `[AD/Metric]` 값 |
| `ROUTING_TABLE_SUMMARY_DISCARD` | OSPF·EIGRP 요약 경로의 `is a summary` 문구와 `Null0` 등 숫자형 Null discard next-hop |
| `ROUTING_REDISTRIBUTION` | `show ip protocols`의 `Redistributing:` 필드, OSPF `External Routes from`, EIGRP/RIP 및 BGP·IS-IS·IGRP·connected·static 재분배 소스 |
| `ROUTING_PROTOCOL_DISTANCE` | `show ip protocols`의 EIGRP `Distance: internal ... external ...` 및 RIP·OSPF·ODR `Distance: (default is ...)` 값 |
| `ROUTING_PROTOCOLS_AND_MISC` | EIGRP/BGP/RIP/HSRP/OSPF/MST/PVST/STP, route-map/prefix-list/ACL, SSH/Telnet/TFTP/NTP/SNMP, 표 헤더 |
| `PROMPTS` | 설정 모드 프롬프트(`#`), privileged EXEC 프롬프트(`#`), 사용자 EXEC 프롬프트(`>`) |

## 정규식 및 매칭 케이스 주의사항

- `Match Case=1`이므로 `up`, `UP`, `Up`은 서로 다르게 취급될 수 있습니다. 파일은 자주 나타나는 대문자/소문자 변형을 일부 `(?:...)` 대안으로 직접 열거하지만, 모든 혼합형을 포함한다는 보장은 없습니다.
- `\b`는 단어 경계입니다. 단어 일부가 다른 문자열에 포함되는 오탐을 줄이는 데 사용되지만, 장비 출력의 구두점이나 축약 표기에 따라 기대와 다르게 매칭될 수 있습니다.
- `(?:a|b)`는 여러 문자열 중 하나를, `[0-9]+`는 하나 이상의 숫자를 의미합니다. IPv4 패턴은 형식과 자리 수를 확인할 뿐 각 옥텟이 0~255인지까지 검증하지 않습니다.
- `^`로 시작하는 패턴은 줄의 시작을 요구합니다. OSPF 경로 유형과 프롬프트는 출력이 줄의 시작에 놓이는 형식을 전제로 하므로, 줄 앞 공백이나 장비별 출력 형식이 다르면 매칭되지 않을 수 있습니다.
- 프롬프트 패턴은 영문자·숫자·`_ . : -`로 구성된 호스트 이름을 전제로 합니다. 다른 문자나 커스텀 프롬프트를 사용하는 경우 별도 패턴이 필요합니다.
- 같은 텍스트가 여러 그룹의 패턴에 걸릴 수 있습니다. 어떤 색상이 최종적으로 보이는지는 SecureCRT 버전과 키워드 목록 처리 순서에 영향을 받을 수 있으므로, 겹치는 패턴을 추가·수정한 뒤 실제 출력에서 확인하십시오.

## 커스터마이징 및 안전한 사용

- 원본을 복사해 별도 목록으로 보관한 뒤 색상이나 패턴을 수정하십시오. 기존 목록을 직접 덮어쓰면 되돌리기 어렵습니다.
- 먼저 색상만 바꾸고, 그 다음 필요한 키워드나 정규식을 작은 단위로 추가하는 방식이 안전합니다. 패턴을 너무 일반적으로 만들면 CLI 출력 대부분이 강조되어 오히려 가독성이 떨어질 수 있습니다.
- 장비별 호스트 이름, 인터페이스 명칭, VRF·IPv6·벤더별 상태 문자열을 추가할 때는 테스트 출력에서 오탐과 누락을 함께 확인하십시오.
- 하이라이트 색상은 관찰을 돕는 표시일 뿐입니다. 빨강/초록 여부만으로 장애 유무, 수렴 완료, 보안 상태 또는 변경 성공을 확정하지 마십시오.
- 운영 장비에 적용하기 전 비운영 세션이나 저장된 출력으로 확인하고, 세션 설정과 SecureCRT 전체 설정의 백업/복원 가능성을 확인하십시오.
- 이 설정은 명령을 자동 실행하지 않으므로, 장비에 명령을 붙여 넣거나 적용하는 작업과는 별개입니다. 변경 전후의 CLI 출력과 장비 로그를 정상적인 운영 절차에 따라 검토하십시오.

## 검증 방법

`Install-KeywordHighlight.ps1`을 통해 키워드 파일과 기본 세션 옵션을 설치할 수 있지만, 실제 표시 여부는 다음과 같이 수동으로 검증해야 합니다.

1. SecureCRT를 다시 시작하고 기본 세션 또는 테스트 세션을 엽니다.
2. 정상/장애 상태, STP, EtherChannel, HSRP, OSPF, VLAN/트렁크 및 프롬프트가 포함된 저장 출력 또는 테스트 장비 출력으로 확인합니다.
3. 대소문자, 줄 시작 위치, 축약 표기, IPv4/MAC/인터페이스 형식이 실제 패턴과 일치하는지 확인합니다.
4. 색상이 보이지 않거나 겹쳐 보이면 `Default.ini`의 일곱 옵션, 선택된 키워드 세트, 터미널 테마 및 해당 SecureCRT 버전의 정규식 지원 범위를 점검합니다.

## 버전 관리

변경 기록의 기준 파일은 [`CHANGELOG.md`](CHANGELOG.md)입니다. 버전은 Semantic Versioning의 `MAJOR.MINOR.PATCH` 규칙을 따르며, 호환성이 깨지는 변경은 MAJOR, 하위 호환 기능 추가는 MINOR, 하위 호환 버그 수정이나 문서 수정은 PATCH를 올립니다.

변경 중인 항목은 `CHANGELOG.md`의 `Unreleased`에 기록하고, 릴리스할 때 해당 내용을 새 버전 번호와 날짜로 확정합니다. 릴리스마다 전용 커밋을 만들고 `vX.Y.Z` 형식의 Git 태그를 함께 생성하는 것을 권장합니다.

기본 자동 업데이트는 공개 저장소의 GitHub Releases에서 GitHub가 prerelease로 표시하지 않고 태그 SemVer에도 prerelease 식별자가 없는 published non-draft stable 릴리스 중 가장 높은 유효한 버전을 선택합니다. `-IncludePrerelease`는 prerelease 선택을 위한 명시적 opt-in이며, 지정한 경우에만 비-draft prerelease도 선택 대상에 포함합니다. 따라서 기본 동작을 사용할 때는 릴리스 커밋과 GitHub Release를 먼저 갱신해야 사용자 스크립트가 새 버전을 감지합니다.
