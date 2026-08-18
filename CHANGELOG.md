# Changelog

이 파일은 [Keep a Changelog](https://keepachangelog.com/ko/1.1.0/) 형식을 따르며, 버전 번호에는 [Semantic Versioning](https://semver.org/lang/ko/) 원칙을 적용합니다.

## [Unreleased]

## [0.1.2] - 2026-08-18

### Added

- `Install-KeywordHighlight.ps1`이 공개 저장소의 더 최신 버전을 확인하고, 설치 자산을 갱신한 뒤 원래 인자로 다시 실행하도록 했습니다.
- 원격 업데이트를 건너뛰는 `-SkipUpdate` 옵션을 추가했습니다.
- `-RollbackVersion`과 `-Version` 별칭으로 Git 태그의 `PNET-Cisco-Dark.ini`를 설치 대상에 적용하는 기능을 추가했습니다.

### Changed

- 자동 업데이트의 SemVer 비교, `-WhatIf` 동작, 네트워크 실패 시 안전한 계속 진행을 문서화했습니다.
- 회귀 시 태그의 `CHANGELOG.md` 버전과 요청 버전을 검증하고, 현재 저장소의 ini는 변경하지 않도록 했습니다. `-RollbackVersion`과 `-Uninstall`의 충돌도 명확한 오류로 처리합니다.

### Fixed

- Windows PowerShell 5.1에서 `Split-Path -LiteralPath`와 `-Parent`를 함께 사용할 때 발생하는 매개 변수 집합 충돌을 수정했습니다.
- Windows PowerShell 5.1에서 `Get-ChildItem -LiteralPath`와 `-File` 필터링을 함께 사용할 때 발생하는 호환성 문제를 수정했습니다.

## [0.1.1] - 2026-08-16

### Added

- `Install-KeywordHighlight.ps1` Windows 설치/제거 스크립트와 `PNET-Cisco-Dark.ini`를 함께 배포해야 하는 설치 자산으로 명시했습니다.

### Changed

- `README.md`에 자동 설치/제거 절차와 백업/복원 동작을 문서화했습니다.

## [0.1.0] - 2026-08-15

### Added

- `PNET-Cisco-Dark.ini`를 최초 기준선으로 추가했습니다.
- `README.md`를 최초 기준선으로 추가했습니다.
