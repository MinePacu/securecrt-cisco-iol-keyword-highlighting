<#
.SYNOPSIS
    SecureCRT Cisco IOL 키워드 하이라이트 설치/제거 스크립트 (Windows 전용).

.DESCRIPTION
    PNET-Cisco-Dark.ini를 SecureCRT 설정 폴더의 Keywords 하위 폴더에 설치하고,
    Config\Sessions\Default.ini에 기본 터미널/키워드 하이라이트 설정을 적용합니다.
    -Uninstall 스위치로 키워드 파일을 제거하고 최신 백업을 복원하며,
    Default.ini도 스크립트가 만든 최신 백업이 있으면 복원합니다.

    실행할 때 공개 저장소의 main 브랜치에 더 최신 버전이 있으면 설치 자산을
    갱신한 뒤 같은 인자로 이 스크립트를 다시 실행합니다. 원격 확인이나
    업데이트에 실패해도 기존 로컬 설치는 계속합니다.

    -RollbackVersion을 지정하면 main 브랜치 self-update를 건너뛰고 해당 Git 태그의
    PNET-Cisco-Dark.ini만 설치 대상에 적용합니다. 요청한 태그 CHANGELOG의 버전과
    일치하지 않거나 원격 ini를 검증할 수 없으면 설치하지 않습니다.

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

.PARAMETER SkipUpdate
    원격 버전 확인과 self-update를 건너뜁니다.

.PARAMETER RollbackVersion
    지정한 Semantic Version의 Git 태그에서 PNET-Cisco-Dark.ini를 받아
    설치 대상 SecureCRT Keywords 파일에만 적용합니다. v0.1.0 또는 0.1.0
    형식을 사용할 수 있으며, -Version을 별칭으로 사용할 수 있습니다.

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -ConfigPath 'C:\Path\To\Config'

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -Uninstall

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -SkipUpdate

.EXAMPLE
    powershell -ExecutionPolicy Bypass -File .\Install-KeywordHighlight.ps1 -RollbackVersion v0.1.0
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter()]
    [string]$ConfigPath,

    [Parameter()]
    [switch]$Force,

    [Parameter()]
    [switch]$Uninstall,

    [Parameter()]
    [switch]$SkipUpdate,

    [Parameter()]
    [Alias('Version')]
    [string]$RollbackVersion
)

$ErrorActionPreference = 'Stop'

$script:UpdateRepository = 'MinePacu/securecrt-cisco-iol-keyword-highlighting'
$script:UpdateBranch = 'main'
$script:UpdateInProgressVariable = 'CRT_CISCO_IOL_KEYWORD_HIGHLIGHT_UPDATE_IN_PROGRESS'
$script:UpdateFileNames = @(
    'Install-KeywordHighlight.ps1',
    'PNET-Cisco-Dark.ini',
    'CHANGELOG.md'
)

function Test-DirectoryExists {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    return Test-Path -LiteralPath $Path -PathType Container
}

function ConvertTo-SemVer {
    param([Parameter(Mandatory = $true)][string]$Version)

    $normalizedVersion = $Version.Trim()
    if ($normalizedVersion.StartsWith('v', [System.StringComparison]::OrdinalIgnoreCase)) {
        $normalizedVersion = $normalizedVersion.Substring(1)
    }

    $pattern = '^(?<major>0|[1-9][0-9]*)\.(?<minor>0|[1-9][0-9]*)\.(?<patch>0|[1-9][0-9]*)(?:-(?<prerelease>[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$'
    $match = [System.Text.RegularExpressions.Regex]::Match($normalizedVersion, $pattern)
    if (-not $match.Success) {
        throw "유효하지 않은 Semantic Version입니다: $Version"
    }

    $preRelease = @()
    if ($match.Groups['prerelease'].Success) {
        foreach ($identifier in $match.Groups['prerelease'].Value.Split('.')) {
            if ($identifier -match '^[0-9]+$' -and $identifier.Length -gt 1 -and $identifier.StartsWith('0')) {
                throw "유효하지 않은 Semantic Version입니다: $Version"
            }

            $preRelease += $identifier
        }
    }

    return [PSCustomObject]@{
        Original   = $normalizedVersion
        Major      = $match.Groups['major'].Value
        Minor      = $match.Groups['minor'].Value
        Patch      = $match.Groups['patch'].Value
        PreRelease = $preRelease
    }
}

function Compare-SemVerNumericIdentifier {
    param(
        [Parameter(Mandatory = $true)][string]$Left,
        [Parameter(Mandatory = $true)][string]$Right
    )

    $leftNormalized = $Left.TrimStart('0')
    $rightNormalized = $Right.TrimStart('0')
    if ([string]::IsNullOrEmpty($leftNormalized)) { $leftNormalized = '0' }
    if ([string]::IsNullOrEmpty($rightNormalized)) { $rightNormalized = '0' }

    if ($leftNormalized.Length -lt $rightNormalized.Length) { return -1 }
    if ($leftNormalized.Length -gt $rightNormalized.Length) { return 1 }

    return [string]::Compare($leftNormalized, $rightNormalized, [System.StringComparison]::Ordinal)
}

function Compare-SemVer {
    param(
        [Parameter(Mandatory = $true)][object]$Left,
        [Parameter(Mandatory = $true)][object]$Right
    )

    foreach ($property in @('Major', 'Minor', 'Patch')) {
        $comparison = Compare-SemVerNumericIdentifier -Left ([string]$Left.$property) -Right ([string]$Right.$property)
        if ($comparison -lt 0) { return -1 }
        if ($comparison -gt 0) { return 1 }
    }

    $leftPreRelease = @()
    $rightPreRelease = @()
    if ($null -ne $Left.PreRelease) { $leftPreRelease = @($Left.PreRelease) }
    if ($null -ne $Right.PreRelease) { $rightPreRelease = @($Right.PreRelease) }

    if ($leftPreRelease.Count -eq 0 -and $rightPreRelease.Count -eq 0) { return 0 }
    if ($leftPreRelease.Count -eq 0) { return 1 }
    if ($rightPreRelease.Count -eq 0) { return -1 }

    $identifierCount = [Math]::Max($leftPreRelease.Count, $rightPreRelease.Count)
    for ($index = 0; $index -lt $identifierCount; $index++) {
        if ($index -ge $leftPreRelease.Count) { return -1 }
        if ($index -ge $rightPreRelease.Count) { return 1 }

        $leftIdentifier = [string]$leftPreRelease[$index]
        $rightIdentifier = [string]$rightPreRelease[$index]
        $leftIsNumeric = $leftIdentifier -match '^[0-9]+$'
        $rightIsNumeric = $rightIdentifier -match '^[0-9]+$'

        if ($leftIsNumeric -and $rightIsNumeric) {
            $comparison = Compare-SemVerNumericIdentifier -Left $leftIdentifier -Right $rightIdentifier
            if ($comparison -lt 0) { return -1 }
            if ($comparison -gt 0) { return 1 }
        }
        elseif ($leftIsNumeric -and -not $rightIsNumeric) {
            return -1
        }
        elseif (-not $leftIsNumeric -and $rightIsNumeric) {
            return 1
        }
        else {
            $comparison = [string]::Compare($leftIdentifier, $rightIdentifier, [System.StringComparison]::Ordinal)
            if ($comparison -lt 0) { return -1 }
            if ($comparison -gt 0) { return 1 }
        }
    }

    return 0
}

function Get-ChangelogVersion {
    param([Parameter(Mandatory = $true)][string]$Content)

    $pattern = '(?m)^\s*##\s*\[\s*(?<version>v?[0-9]+\.[0-9]+\.[0-9]+(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?)\s*\]'
    $match = [System.Text.RegularExpressions.Regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        throw 'CHANGELOG.md에서 릴리스 버전을 찾을 수 없습니다.'
    }

    return ConvertTo-SemVer -Version $match.Groups['version'].Value
}

function Get-GitHubFile {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter()][string]$Ref = $script:UpdateBranch
    )

    $encodedPath = (($Path -split '/') | ForEach-Object { [System.Uri]::EscapeDataString($_) }) -join '/'
    $encodedRef = [System.Uri]::EscapeDataString($Ref)
    $uri = "https://api.github.com/repos/$($script:UpdateRepository)/contents/$encodedPath?ref=$encodedRef"
    $headers = @{
        Accept     = 'application/vnd.github+json'
        'User-Agent' = 'CRT-Cisco-IOL-Highlight-Installer'
    }

    $response = Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -TimeoutSec 15
    if ($response.type -ne 'file' -or [string]::IsNullOrWhiteSpace([string]$response.content)) {
        throw "GitHub에서 파일 내용을 받지 못했습니다: $Path"
    }

    try {
        $bytes = [Convert]::FromBase64String(([string]$response.content -replace '\s', ''))
    }
    catch {
        throw "GitHub 파일의 Base64 내용을 해석하지 못했습니다: $Path"
    }

    [PSCustomObject]@{
        Path  = $Path
        Bytes = $bytes
        Text  = [System.Text.UTF8Encoding]::new($false, $true).GetString($bytes)
    }
}

function Get-RollbackAsset {
    param([Parameter(Mandatory = $true)][object]$Version)

    # Version has already passed ConvertTo-SemVer before this function is called.
    # Only this validated value is used to construct the Git ref.
    $tagRef = 'v' + $Version.Original
    $iniFile = Get-GitHubFile -Path 'PNET-Cisco-Dark.ini' -Ref $tagRef
    $changelogFile = Get-GitHubFile -Path 'CHANGELOG.md' -Ref $tagRef

    if ($null -eq $iniFile.Bytes -or $iniFile.Bytes.Length -eq 0 -or
        [string]::IsNullOrWhiteSpace([string]$iniFile.Text) -or
        $iniFile.Text -notmatch '(?m)^\s*S:"Keyword List"=') {
        throw "GitHub 태그 $tagRef의 PNET-Cisco-Dark.ini가 비어 있거나 유효한 INI가 아닙니다."
    }

    $changelogVersion = Get-ChangelogVersion -Content $changelogFile.Text
    if (-not [string]::Equals(
            $Version.Original,
            $changelogVersion.Original,
            [System.StringComparison]::Ordinal)) {
        throw "GitHub 태그 $tagRef의 CHANGELOG 버전($($changelogVersion.Original))이 요청한 버전($($Version.Original))과 일치하지 않습니다."
    }

    [PSCustomObject]@{
        Tag   = $tagRef
        Bytes = $iniFile.Bytes
    }
}

function Test-InstallScriptContent {
    param([Parameter(Mandatory = $true)][string]$Content)

    if ($Content -notmatch '(?m)^\s*\[CmdletBinding\(' -or $Content -notmatch '(?m)^\s*param\s*\(') {
        throw '원격 설치 스크립트의 기본 PowerShell 구조를 확인할 수 없습니다.'
    }

    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors.Count -gt 0) {
        throw "원격 설치 스크립트의 PowerShell 문법을 확인할 수 없습니다: $($parseErrors[0].Message)"
    }
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

function Write-BytesAtomic {
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][byte[]]$Bytes
    )

    $temporaryPath = New-TemporaryPath -Path $Path
    try {
        [System.IO.File]::WriteAllBytes($temporaryPath, $Bytes)
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

function Get-RestartArguments {
    $arguments = New-Object System.Collections.Generic.List[object]

    if ($ConfigPath) {
        $null = $arguments.Add('-ConfigPath')
        $null = $arguments.Add($ConfigPath)
    }
    if ($Force) {
        $null = $arguments.Add('-Force')
    }
    if ($Uninstall) {
        $null = $arguments.Add('-Uninstall')
    }
    if ($WhatIfPreference) {
        $null = $arguments.Add('-WhatIf')
    }
    if ($RollbackVersion) {
        $null = $arguments.Add('-RollbackVersion')
        $null = $arguments.Add($RollbackVersion)
    }

    return ,$arguments.ToArray()
}

function Invoke-SelfUpdate {
    if ($SkipUpdate -or $RollbackVersion -or
        [string]::Equals(
            [Environment]::GetEnvironmentVariable($script:UpdateInProgressVariable, 'Process'),
            '1',
            [System.StringComparison]::Ordinal)) {
        return
    }

    try {
        $localChangelogPath = Join-Path $PSScriptRoot 'CHANGELOG.md'
        if (-not (Test-Path -LiteralPath $localChangelogPath -PathType Leaf)) {
            throw "로컬 CHANGELOG.md를 찾을 수 없습니다: $localChangelogPath"
        }

        $localChangelogContent = [System.IO.File]::ReadAllText(
            $localChangelogPath,
            [System.Text.UTF8Encoding]::new($false, $true))
        $localVersion = Get-ChangelogVersion -Content $localChangelogContent

        $remoteFiles = @{}
        foreach ($fileName in $script:UpdateFileNames) {
            $remoteFiles[$fileName] = Get-GitHubFile -Path $fileName
        }

        $remoteVersion = Get-ChangelogVersion -Content $remoteFiles['CHANGELOG.md'].Text
        $versionComparison = Compare-SemVer -Left $localVersion -Right $remoteVersion
        if ($versionComparison -ge 0) {
            return
        }

        Write-Host "[업데이트] 원격 버전 $($remoteVersion.Original)이 로컬 버전 $($localVersion.Original)보다 최신입니다."
        Test-InstallScriptContent -Content $remoteFiles['Install-KeywordHighlight.ps1'].Text
        if ($remoteFiles['PNET-Cisco-Dark.ini'].Bytes.Length -eq 0) {
            throw '원격 PNET-Cisco-Dark.ini가 비어 있습니다.'
        }

        if ($WhatIfPreference) {
            Write-Host '[WhatIf] 설치 스크립트와 관련 파일을 갱신하고 다시 실행하는 작업을 건너뜁니다.'
            return
        }

        $stagingDirectory = Join-Path ([System.IO.Path]::GetTempPath()) ('.crt-cisco-iol-update-' + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $stagingDirectory -Force | Out-Null
        try {
            foreach ($fileName in $script:UpdateFileNames) {
                $stagedPath = Join-Path $stagingDirectory $fileName
                [System.IO.File]::WriteAllBytes($stagedPath, $remoteFiles[$fileName].Bytes)
            }

            foreach ($fileName in $script:UpdateFileNames) {
                $destinationPath = Join-Path $PSScriptRoot $fileName
                Write-BytesAtomic -Path $destinationPath -Bytes $remoteFiles[$fileName].Bytes
            }

            $shellCommand = if ($PSVersionTable.PSEdition -eq 'Desktop') { 'powershell.exe' } else { 'pwsh' }
            $shellPath = (Get-Command $shellCommand -ErrorAction Stop).Path
            $restartArguments = Get-RestartArguments
            $previousUpdateFlag = [Environment]::GetEnvironmentVariable($script:UpdateInProgressVariable, 'Process')
            [Environment]::SetEnvironmentVariable($script:UpdateInProgressVariable, '1', 'Process')
            try {
                & $shellPath -NoProfile -ExecutionPolicy Bypass -File $PSCommandPath @restartArguments
                $restartExitCode = $LASTEXITCODE
            }
            finally {
                [Environment]::SetEnvironmentVariable($script:UpdateInProgressVariable, $previousUpdateFlag, 'Process')
            }

            if ($null -eq $restartExitCode) {
                $restartExitCode = 0
            }

            if ($restartExitCode -ne 0) {
                throw "업데이트된 스크립트의 재실행이 종료 코드 $restartExitCode로 실패했습니다."
            }

            exit 0
        }
        finally {
            if (Test-Path -LiteralPath $stagingDirectory -PathType Container) {
                Remove-Item -LiteralPath $stagingDirectory -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
    catch {
        Write-Warning "[업데이트] 원격 업데이트를 적용하지 못했습니다: $($_.Exception.Message) 기존 로컬 설치를 계속합니다."
    }
}

$rollbackRequested = $PSBoundParameters.ContainsKey('RollbackVersion')
$rollbackSemVer = $null
if ($rollbackRequested -and $Uninstall) {
    throw '-RollbackVersion과 -Uninstall은 함께 사용할 수 없습니다. 하나만 지정하십시오.'
}

if ($rollbackRequested) {
    try {
        $rollbackSemVer = ConvertTo-SemVer -Version $RollbackVersion
    }
    catch {
        throw "-RollbackVersion 값이 유효한 Semantic Version이 아닙니다: $RollbackVersion"
    }
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

$rollbackAsset = $null
if ($rollbackRequested) {
    try {
        $rollbackAsset = Get-RollbackAsset -Version $rollbackSemVer
        Write-Host "[회귀] GitHub 태그 $($rollbackAsset.Tag)의 PNET-Cisco-Dark.ini를 확인했습니다."
    }
    catch {
        $rollbackErrorMessage = '[회귀] 지정한 버전의 설치 자산을 확인하지 못했습니다. 설치를 진행하지 않습니다: ' + $_.Exception.Message
        throw $rollbackErrorMessage
    }
}
else {
    Invoke-SelfUpdate
}

# --- 2. 소스 ini 파일 확인 (초기에 먼저 확인) -----------------------------
$sourceIniPath = Join-Path $PSScriptRoot 'PNET-Cisco-Dark.ini'
if (-not $rollbackRequested -and -not (Test-Path -LiteralPath $sourceIniPath -PathType Leaf)) {
    Write-Error "원본 파일을 찾을 수 없습니다: $sourceIniPath. 스크립트와 같은 폴더에 PNET-Cisco-Dark.ini가 있는지 확인하십시오."
    exit 1
}

$keywordSetName = if ($rollbackRequested) {
    'PNET-Cisco-Dark'
}
else {
    [System.IO.Path]::GetFileNameWithoutExtension($sourceIniPath)
}
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
        if ($rollbackRequested) {
            Write-BytesAtomic -Path $destinationIniPath -Bytes $rollbackAsset.Bytes
        }
        else {
            Copy-FileAtomic -Source $sourceIniPath -Destination $destinationIniPath
        }
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
