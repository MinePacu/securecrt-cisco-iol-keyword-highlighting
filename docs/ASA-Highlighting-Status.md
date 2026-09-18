# ASA 통합 강조 상태

이 문서는 2026-09-18 루트 운영 INI 통합 상태를 기록합니다. 원본 ASA 설계·전용 목록·회귀 자료는 `dist/upstream-main/asa`와 `dist/upstream-main/tests/AsaKeywordLists.Tests.ps1`에 보존되어 있습니다.

## 통합 내용

ASA Extended 목록의 64개 항목 중 별도 목록 전용 default-color fallback을 제외한 63개 정규식을 V2/V3의 `ASA_FIREWALL_OPERATIONAL_STATES` 블록에 패턴·색상·순서 그대로 병합했습니다. 후속 IOS crypto 명령과 인터페이스 요약 보호 보강 후 두 운영 소스 목록은 515개 행이며 선언값은 `00000203`입니다. ASA 블록 자체는 변경하지 않았습니다.

블록 순서는 다음과 같습니다.

1. ACL 행 우선 보호
2. NAT 문맥 보호와 NAT 열 강조
3. BGP 상세
4. IOS/ASA 공통 brief 인터페이스 행의 토큰 색상 보호
5. ASA 운영 상태
6. GRE/DMVPN/NHRP/IKE/IPsec
7. 범용 오류·정상 상태 및 나머지 블록

ASA 블록을 터널 및 범용 상태보다 먼저 두어 ASA의 구체적인 행 규칙을 보존합니다. 다만 사용자 화면에서 ASA 요약 인터페이스 전체 행 규칙이 IOS `show ip interface brief`까지 잡아 정상 행 전체를 초록, administratively-down 행 전체를 회색으로 바꾸는 충돌을 확인했습니다. ASA와 IOS의 brief 행은 줄 자체가 동일해 플랫폼을 구분할 수 없으므로, 앞선 `IOS_SHOW_IP_INTERFACE_BRIEF`에서 인터페이스·주소·중립 필드·up/down 토큰을 기존 색상으로 보호하고 두 플랫폼에 같은 토큰식 스타일을 적용합니다. IPsec `#pkts encaps/decaps`, nonzero `#send/#recv errors`의 ASA 우선순위는 유지합니다.

## 포함 범위

- ASA syslog severity 0–5와 7
- 상세·요약 인터페이스 상태와 nonzero 오류/drop
- failover Primary/Secondary, Active/Standby Ready, Group, 인터페이스 Failed/Waiting, Sync Done/Skipped
- ASAv Unlicensed/Noncompliant/entitlement 및 Compliant
- SLA Track, AAA server, 예약 reload, 환경 실패
- IKEv1/IKEv2, IPsec packet/error, VPN session/bytes
- ASA ACL permit/deny와 hitcnt, 정적 기본 경로
- ASA NAT/xlate/connection, CPU·메모리, 버전·PID, 설정 구획
- service-policy/ASP/resource drop, OSPF neighbor, 인증서 등록 보류

`TCP conn`과 `UDP conn` failover 통계는 연결 종류 규칙에서 제외하며, 실제 `TCP PAT` 강조는 유지합니다. 0 errors, SA 없음, historical failure reason, Normal (Monitored), zero drop/resource counters 등은 자동 장애로 표시하지 않습니다.

## 검증 상태

다음 검사는 통과합니다.

```powershell
pwsh -NoProfile -File tests/AsaFirewallHighlights.Tests.ps1
pwsh -NoProfile -File tests/InterfaceBriefHighlights.Tests.ps1
pwsh -NoProfile -File tests/KeywordListVersion.Tests.ps1
pwsh -NoProfile -File tests/NatTranslations.Tests.ps1
pwsh -NoProfile -File tests/TunnelingHighlights.Tests.ps1
```

ASA 검사는 보존된 Core 46개·Extended 64개 구조, Core 부분집합, 62개 출력 양성/음성 사례, fallback을 제외한 63개 통합 규칙의 V2/V3 일치, PCRE 문법 및 우선순위를 확인합니다.

과거 ASA 통합본에서는 사용자 화면으로 failover Primary/Secondary·Active/Standby Ready·Sync Done, historical `Ifc Failure`/`inside: Failed`의 기본색 유지, ASAv entitlement/Unlicensed 경고, NAT 정책·hit 카운터, `show xlate`의 `NAT from`, ASA ACL permit 및 0/양수 hitcnt를 확인했습니다. 실제 deny ACL 행과 `TCP PAT` 행은 그 화면에 없었습니다. 494행·`000001EE` 설치본에서 IOS `show ip interface brief` 전체 행 색상 충돌을 화면으로 확인했고, 이를 보정한 515행·`00000203` V3를 `-SkipUpdate`로 재설치했습니다. 소스와 설치본 SHA256은 일치하지만 변경 후 화면 검증은 남아 있습니다. 최신 파일 전체의 네이티브 검증 완료로 확대하지 않습니다.

## 후속 화면 확인

재설치는 완료했습니다. `Default.ini`는 이미 최신이라 변경하지 않았고, 직전 487행 V3 설치본은 `PNET-Cisco-Dark-V3.ini.bak-20260917-112538540`으로 백업했습니다. SecureCRT를 다시 열어 실제 ASA 출력에서 다음을 점검합니다.

- Primary/Secondary, Active/Standby Ready와 historical `Ifc Failure` 분리
- Sync Done/Skipped와 ASAv license/entitlement
- `TCP conn`/`UDP conn` 오탐 방지 및 실제 `TCP PAT`
- ASA ACL permit/deny 및 hitcnt 0/positive
- IKE/IPsec packet/error와 터널 공통 규칙의 우선 색상
- 기존 NAT·라우팅·GRE/DMVPN 강조 회귀 여부
