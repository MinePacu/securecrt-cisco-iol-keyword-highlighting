<#
.SYNOPSIS
    SecureCRT Cisco IOL 키워드 하이라이트 설치/제거 스크립트 (Windows 전용).

.DESCRIPTION
    PNET-Cisco-Dark.ini를 SecureCRT 설정 폴더의 Keywords 하위 폴더에 설치하고,
    Config\Sessions\Default.ini에 기본 터미널/키워드 하이라이트 설정을 적용합니다.
    -Uninstall 스위치로 키워드 파일을 제거하고 최신 백업을 복원하며,
    Default.ini도 스크립트가 만든 최신 백업이 있으면 복원합니다.

    설정 파일을 수정하기 전에 SecureCRT를 종료하는 것이 좋습니다. -Force를
    사용하면 실행 중 경고와 기존 파일 덮어쓰기 확인을 건너뛰지만, 설정 파일이
    열려 있는 상태에서 변경하면 SecureCRT가 변경 내용을 덮어쓸 수 있습니다.

.PARAMETER ConfigPath
    SecureCRT 설정 폴더 경로를 수동으로 지정합니다. 지정하지 않으면
    일반적인 설치 위치를 자동으로 탐색합니다.

.PARAMETER Force
    SecureCRT 실행 중 경고 프롬프트와 기존 파일 덮어쓰기 확인 프롬프트를 건너뜁니다.

.PARAMETER Uninstall
    설치된 키워드 ini를 제거하고, 존재할 경우 키워드 ini와 Default.ini의
    가장 최근 백업을 원래 이름으로 복원합니다.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -ConfigPath 'C:\Path\To\Config'

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -Uninstall
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string]$ConfigPath,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

function Test-DirectoryExists {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    return Test-Path -LiteralPath $Path -PathType Container
}

function Get-TextFileInfo {
    param([Parameter(Mandatory = $true)][string]$Path)

    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $encoding = $null
    $bomLength = 0

    if ($bytes.Length -ge 4 -and
        $bytes[0] -eq 0x00 -and $bytes[1] -eq 0x00 -and
        $bytes[2] -eq 0xFE -and $bytes[3] -eq 0xFF) {
        $encoding = [System.Text.UTF32Encoding]::new($true, $true)
        $bomLength = 4
    }
    elseif ($bytes.Length -ge 4 -and
        $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE -and
        $bytes[2] -eq 0x00 -and $bytes[3] -eq 0x00) {
        $encoding = [System.Text.UTF32Encoding]::new($false, $true)
        $bomLength = 4
    }
    elseif ($bytes.Length -ge 3 -and
        $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $encoding = [System.Text.UTF8Encoding]::new($true)
        $bomLength = 3
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
        $encoding = [System.Text.UnicodeEncoding]::new($true, $true)
        $bomLength = 2
    }
    elseif ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
        $encoding = [System.Text.UnicodeEncoding]::new($false, $true)
        $bomLength = 2
    }
    else {
        # SecureCRT INI files are commonly ANSI or UTF-8 without a BOM. Prefer
        # UTF-8 when the byte sequence is valid, otherwise retain the Windows
        # default code page for non-Unicode files.
        $utf8Strict = [System.Text.UTF8Encoding]::new($false, $true)
        try {
            $null = $utf8Strict.GetString($bytes)
            $encoding = $utf8Strict
        }
        catch {
            $encoding = [System.Text.Encoding]::Default
        }
    }

    [PSCustomObject]@{
        Text     = $encoding.GetString($bytes, $bomLength, $bytes.Length - $bomLength)
        Encoding = $encoding
    }
}

function ConvertTo-EncodedBytes {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][System.Text.Encoding]$Encoding
    )

    $preamble = $Encoding.GetPreamble()
    $contentBytes = $Encoding.GetBytes($Text)
    $allBytes = [byte[]]::new($preamble.Length + $contentBytes.Length)

    [System.Array]::Copy($preamble, 0, $allBytes, 0, $preamble.Length)
    [System.Array]::Copy($contentBytes, 0, $allBytes, $preamble.Length, $contentBytes.Length)

    return ,$allBytes
}

function New-TemporaryPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    $directory = Split-Path -LiteralPath $Path -Parent
    $fileName = [System.IO.Path]::GetFileName($Path)
    return Join-Path $directory ('.' + $fileName + '.tmp-' + [guid]::NewGuid().ToString('N'))
}

function Copy-FileAtomic {
    param(
        [Parameter(Mandatory = $true)][string]$Source,
        [Parameter(Mandatory = $true)][string]$Destination
    )

    $temporaryPath = New-TemporaryPath -Path $Destination
    try {
        Copy-Item -LiteralPath $Source -Destination $temporaryPath -Force | Out-Null
        Move-Item -LiteralPath $temporaryPath -Destination $Destination -Force | Out-Null
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Write-TextFileAtomic {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][System.Text.Encoding]$Encoding
    )

    $temporaryPath = New-TemporaryPath -Path $Path
    try {
        $bytes = ConvertTo-EncodedBytes -Text $Text -Encoding $Encoding
        [System.IO.File]::WriteAllBytes($temporaryPath, $bytes)
        Move-Item -LiteralPath $temporaryPath -Destination $Path -Force | Out-Null
    }
    finally {
        if (Test-Path -LiteralPath $temporaryPath -PathType Leaf) {
            Remove-Item -LiteralPath $temporaryPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Get-TimestampBackupPath {
    param(
        [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][string]$FileName
    )

    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmssfff'
    $backupPath = Join-Path $Directory ($FileName + '.bak-' + $timestamp)
    $suffix = 1

    while (Test-Path -LiteralPath $backupPath) {
        $backupPath = Join-Path $Directory ($FileName + '.bak-' + $timestamp + '-' + $suffix)
        $suffix++
    }

    return $backupPath
}

function Get-LatestBackup {
    param(
        [Parameter(Mandatory = $true)][string]$Directory,
        [Parameter(Mandatory = $true)][string]$Pattern
    )

    if (-not (Test-DirectoryExists -Path $Directory)) {
        return $null
    }

    return Get-ChildItem -LiteralPath $Directory -Filter $Pattern -File -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1
}

function Set-IniOptions {
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][object[]]$Options
    )

    $updatedContent = $Content
    $missingLines = New-Object System.Collections.Generic.List[string]

    foreach ($option in $Options) {
        # Match only a complete S:/D: option line. This deliberately excludes
        # B: multiline values and similarly named options.
        $pattern = '^(?<indent>[ \t]*)' +
            [System.Text.RegularExpressions.Regex]::Escape($option.Prefix) +
            ':"' + [System.Text.RegularExpressions.Regex]::Escape($option.Name) +
            '"=[^\r\n]*(?=\r?$)'

        if ([System.Text.RegularExpressions.Regex]::IsMatch(
                $updatedContent,
                $pattern,
                [System.Text.RegularExpressions.RegexOptions]::Multiline)) {
            $replacement = '${indent}' + $option.Prefix + ':"' + $option.Name + '"=' + $option.Value
            $updatedContent = [System.Text.RegularExpressions.Regex]::Replace(
                $updatedContent,
                $pattern,
                $replacement,
                [System.Text.RegularExpressions.RegexOptions]::Multiline)
        }
        else {
            $null = $missingLines.Add($option.Prefix + ':"' + $option.Name + '"=' + $option.Value)
        }
    }

    if ($missingLines.Count -gt 0) {
        if ($Content.Contains("`r`n")) {
            $newline = "`r`n"
        }
        elseif ($Content.Contains("`n")) {
            $newline = "`n"
        }
        else {
            $newline = [System.Environment]::NewLine
        }

        if ($updatedContent.Length -gt 0 -and -not $updatedContent.EndsWith($newline)) {
            $updatedContent += $newline
        }

        $updatedContent += ($missingLines -join $newline) + $newline
    }

    return $updatedContent
}

function Restore-BackupAtomic {
    param(
        [Parameter(Mandatory = $true)][string]$BackupPath,
        [Parameter(Mandatory = $true)][string]$DestinationPath
    )

    # Copy through a temporary file so a failed restore does not first remove
    # the current target. Consume the backup only after the replacement works.
    Copy-FileAtomic -Source $BackupPath -Destination $DestinationPath
    Remove-Item -LiteralPath $BackupPath -Force
}

# --- 1. Windows 여부 확인 -------------------------------------------------
$isWindowsOs = $false
if ($PSVersionTable.PSEdition -eq 'Desktop') {
    $isWindowsOs = $true
}
elseif (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
    if ($IsWindows) {
        $isWindowsOs = $true
    }
}
elseif ([System.Environment]::OSVersion.Platform -eq 'Win32NT') {
    $isWindowsOs = $true
}

if (-not $isWindowsOs) {
    Write-Error "이 스크립트는 Windows 환경에서만 실행할 수 있습니다. SecureCRT 설정 폴더 구조가 Windows를 기준으로 하기 때문입니다."
    exit 1
}

# --- 2. 소스 ini 파일 확인 (초기에 먼저 확인) -----------------------------
$sourceIniPath = Join-Path $PSScriptRoot 'PNET-Cisco-Dark.ini'
if (-not (Test-Path -LiteralPath $sourceIniPath -PathType Leaf)) {
    Write-Error "원본 파일을 찾을 수 없습니다: $sourceIniPath. 스크립트와 같은 폴더에 PNET-Cisco-Dark.ini가 있는지 확인하십시오."
    exit 1
}

$keywordSetName = [System.IO.Path]::GetFileNameWithoutExtension($sourceIniPath)
if ([string]::IsNullOrWhiteSpace($keywordSetName)) {
    Write-Error "키워드 ini 파일의 basename을 확인할 수 없습니다: $sourceIniPath"
    exit 1
}

# --- 3. SecureCRT 설정 폴더 결정 ------------------------------------------
$resolvedConfigPath = $null

if ($ConfigPath) {
    if (Test-DirectoryExists -Path $ConfigPath) {
        $resolvedConfigPath = $ConfigPath
    }
    else {
        Write-Error "지정한 -ConfigPath 경로를 찾을 수 없습니다: $ConfigPath"
        exit 1
    }
}
else {
    $candidatePaths = @(
        (Join-Path $env:APPDATA 'VanDyke\Config'),
        (Join-Path $env:APPDATA 'VanDyke\SecureCRT\Config'),
        (Join-Path $env:LOCALAPPDATA 'VanDyke\SecureCRT\Config'),
        (Join-Path $env:USERPROFILE 'Documents\SecureCRT\Config')
    )

    foreach ($candidate in $candidatePaths) {
        if (Test-DirectoryExists -Path $candidate) {
            $resolvedConfigPath = $candidate
            break
        }
    }

    if (-not $resolvedConfigPath) {
        if ($Force) {
            Write-Error "SecureCRT 설정 폴더를 자동으로 찾을 수 없습니다. -Force 사용 시 자동 탐색 실패는 오류로 처리됩니다. -ConfigPath로 경로를 직접 지정하십시오."
            exit 1
        }

        $manualPath = Read-Host "SecureCRT 설정 폴더를 자동으로 찾지 못했습니다. 설정 폴더 경로를 직접 입력하십시오"
        if (Test-DirectoryExists -Path $manualPath) {
            $resolvedConfigPath = $manualPath
        }
        else {
            Write-Error "입력한 경로를 찾을 수 없습니다: $manualPath"
            exit 1
        }
    }
}

# Default.ini는 자동 생성하지 않는다. 설치와 제거 모두 실제 세션
# 설정 파일을 대상으로 해야 하므로 Sessions 폴더와 파일을 먼저 검증한다.
$sessionsPath = Join-Path $resolvedConfigPath 'Sessions'
if (-not (Test-DirectoryExists -Path $sessionsPath)) {
    Write-Error "SecureCRT Sessions 폴더를 찾을 수 없습니다: $sessionsPath. 올바른 -ConfigPath를 지정하십시오."
    exit 1
}

$defaultIniPath = Join-Path $sessionsPath 'Default.ini'
if (-not (Test-Path -LiteralPath $defaultIniPath -PathType Leaf)) {
    Write-Error "SecureCRT 기본 세션 파일을 찾을 수 없습니다: $defaultIniPath. Default.ini를 자동으로 만들지 않으므로 올바른 설정 폴더인지 확인하십시오."
    exit 1
}

# --- 4. SecureCRT 실행 여부 확인 ------------------------------------------
$secureCrtProcess = Get-Process -Name 'SecureCRT' -ErrorAction SilentlyContinue

if ($secureCrtProcess) {
    if ($Force) {
        Write-Host "[정보] SecureCRT가 현재 실행 중이지만 -Force가 지정되어 계속 진행합니다. 설정 파일 수정은 SecureCRT 종료 후 수행하는 것이 좋습니다."
    }
    else {
        Write-Warning "SecureCRT가 현재 실행 중입니다. 설정 파일이 열려 있는 상태에서 변경하면 예기치 않은 동작이 발생할 수 있습니다. SecureCRT를 종료한 뒤 실행하는 것이 좋습니다."
        $answer = Read-Host "계속하시겠습니까? (Y/N)"
        if ($answer -notmatch '^[Yy]$') {
            Write-Host "사용자가 취소했습니다. 변경 사항이 없습니다."
            exit 0
        }
    }
}

# --- 5. Keywords/Default.ini 경로 및 옵션 ---------------------------------
$keywordsPath = Join-Path $resolvedConfigPath 'Keywords'
$destinationFileName = $keywordSetName + '.ini'
$destinationIniPath = Join-Path $keywordsPath $destinationFileName

$iniOptions = @(
    [PSCustomObject]@{ Prefix = 'S'; Name = 'Color Scheme'; Value = 'Birds of Paradise' },
    [PSCustomObject]@{ Prefix = 'D'; Name = 'Use Cursor Color'; Value = '00000001' },
    [PSCustomObject]@{ Prefix = 'D'; Name = 'Cursor Color'; Value = '00FFFFFF' },
    [PSCustomObject]@{ Prefix = 'S'; Name = 'Keyword Set'; Value = $keywordSetName },
    [PSCustomObject]@{ Prefix = 'D'; Name = 'Highlight Reverse Video'; Value = '00000000' },
    [PSCustomObject]@{ Prefix = 'D'; Name = 'Highlight Bold'; Value = '00000001' },
    [PSCustomObject]@{ Prefix = 'D'; Name = 'Highlight Color'; Value = '00000001' }
)

try {
    if ($Uninstall) {
        # --- Uninstall 경로 ---------------------------------------------
        $latestKeywordBackup = Get-LatestBackup -Directory $keywordsPath -Pattern ($destinationFileName + '.bak-*')

        if ($latestKeywordBackup) {
            if ($PSCmdlet.ShouldProcess($destinationIniPath, "$($latestKeywordBackup.Name)에서 $destinationFileName 복원")) {
                Restore-BackupAtomic -BackupPath $latestKeywordBackup.FullName -DestinationPath $destinationIniPath
                Write-Host "키워드 파일 제거를 완료했습니다. 가장 최근 백업($($latestKeywordBackup.Name))을 $destinationFileName로 복원했습니다."
            }
        }
        elseif (Test-Path -LiteralPath $destinationIniPath -PathType Leaf) {
            if ($PSCmdlet.ShouldProcess($destinationIniPath, "$destinationFileName 삭제")) {
                Remove-Item -LiteralPath $destinationIniPath -Force
            }
        }
        elseif (-not $WhatIfPreference) {
            Write-Host "[정보] $destinationFileName의 복원할 백업 파일이 없습니다. 현재 파일이 있으면 제거만 수행했습니다."
        }

        $latestDefaultBackup = Get-LatestBackup -Directory $sessionsPath -Pattern 'Default.ini.bak-*'
        if ($latestDefaultBackup) {
            if ($PSCmdlet.ShouldProcess($defaultIniPath, "$($latestDefaultBackup.Name)에서 Default.ini 복원")) {
                Restore-BackupAtomic -BackupPath $latestDefaultBackup.FullName -DestinationPath $defaultIniPath
                Write-Host "Default.ini를 가장 최근 백업($($latestDefaultBackup.Name))에서 복원했습니다."
            }
        }
        elseif (-not $WhatIfPreference) {
            Write-Host "[정보] 복원할 Default.ini 백업이 없습니다. 현재 Default.ini 설정은 변경하지 않았습니다."
        }

        exit 0
    }

    # --- 설치 경로 ---------------------------------------------------------
    $defaultFileInfo = Get-TextFileInfo -Path $defaultIniPath
    $updatedDefaultContent = Set-IniOptions -Content $defaultFileInfo.Text -Options $iniOptions
    $keywordFileExists = Test-Path -LiteralPath $destinationIniPath -PathType Leaf

    # 기존 동작의 확인 프롬프트를 유지하되, 새로 덮어쓰는 Default.ini도
    # 같은 정책으로 확인한다. -WhatIf에서는 확인 없이 계획만 출력한다.
    if (-not $Force -and -not $WhatIfPreference) {
        if ($keywordFileExists) {
            $confirmKeyword = Read-Host "기존 $destinationFileName가 존재합니다. 백업 후 덮어쓰시겠습니까? (Y/N)"
            if ($confirmKeyword -notmatch '^[Yy]$') {
                Write-Host "사용자가 취소했습니다. 변경 사항이 없습니다."
                exit 0
            }
        }

        $confirmDefault = Read-Host '기존 Default.ini가 존재합니다. 백업 후 기본 세션 설정을 적용하시겠습니까? (Y/N)'
        if ($confirmDefault -notmatch '^[Yy]$') {
            Write-Host "사용자가 취소했습니다. 변경 사항이 없습니다."
            exit 0
        }
    }

    if (-not (Test-DirectoryExists -Path $keywordsPath)) {
        if ($PSCmdlet.ShouldProcess($keywordsPath, 'Keywords 폴더 생성')) {
            New-Item -ItemType Directory -Path $keywordsPath -Force | Out-Null
        }
    }

    # 두 대상 파일의 백업을 먼저 끝낸 다음 어느 파일도 덮어쓴다.
    if ($keywordFileExists) {
        $keywordBackupPath = Get-TimestampBackupPath -Directory $keywordsPath -FileName $destinationFileName
        if ($PSCmdlet.ShouldProcess($destinationIniPath, "백업 생성 ($keywordBackupPath)")) {
            Copy-FileAtomic -Source $destinationIniPath -Destination $keywordBackupPath
        }
    }

    $defaultBackupPath = Get-TimestampBackupPath -Directory $sessionsPath -FileName 'Default.ini'
    if ($PSCmdlet.ShouldProcess($defaultIniPath, "백업 생성 ($defaultBackupPath)")) {
        Copy-FileAtomic -Source $defaultIniPath -Destination $defaultBackupPath
    }

    if ($PSCmdlet.ShouldProcess($destinationIniPath, "$destinationFileName 설치")) {
        Copy-FileAtomic -Source $sourceIniPath -Destination $destinationIniPath
    }

    if ($PSCmdlet.ShouldProcess($defaultIniPath, '기본 세션 옵션 적용')) {
        Write-TextFileAtomic -Path $defaultIniPath -Text $updatedDefaultContent -Encoding $defaultFileInfo.Encoding
    }

    if (-not $WhatIfPreference) {
        Write-Host "설치를 완료했습니다: $destinationIniPath"
        Write-Host "기본 세션 설정을 적용했습니다: $defaultIniPath"
        Write-Host '[중요] 설정 파일 수정은 SecureCRT를 종료한 상태에서 수행하는 것이 좋습니다. -Force로 실행 중 변경을 허용할 수 있지만, SecureCRT가 변경 내용을 덮어쓸 수 있습니다.'
    }

    exit 0
}
catch {
    Write-Error "파일 작업 중 오류가 발생했습니다: $($_.Exception.Message)"
    exit 1
}
