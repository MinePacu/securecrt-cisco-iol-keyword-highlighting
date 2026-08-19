$ErrorActionPreference = 'Stop'

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )

    if ($Actual -is [string] -and $Expected -is [string]) {
        $equal = [string]::Equals($Actual, $Expected, [System.StringComparison]::Ordinal)
    }
    else {
        $equal = $Actual -eq $Expected
    }

    Assert-True -Condition ([bool]$equal) -Message "$Message (actual: $Actual; expected: $Expected)"
}

$scriptPath = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $PSScriptRoot '..') 'Install-KeywordHighlight.ps1'))
$source = [System.IO.File]::ReadAllText($scriptPath)
$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath,
    [ref]$tokens,
    [ref]$parseErrors
) | Out-Null
Assert-Equal -Actual $parseErrors.Count -Expected 0 -Message 'installer script must parse without errors'

$functionStart = $source.IndexOf('function Invoke-SelfUpdate {', [System.StringComparison]::Ordinal)
Assert-True -Condition ($functionStart -ge 0) -Message 'Invoke-SelfUpdate function must exist'
$functionText = $source.Substring($functionStart)

$requiredMessages = @(
    '[업데이트] 최신 버전을 확인하는 중입니다.',
    '[업데이트] 다운로드 중:',
    '[업데이트] 원격 파일 검증이 완료되었습니다.',
    '[업데이트] 로컬 파일 교체를 시작합니다.',
    '[업데이트] 로컬 파일 설치가 완료되었습니다.',
    '[업데이트] 업데이트된 설치기로 재시작합니다.',
    '[업데이트] 업데이트된 설치기로 재시작되었습니다.',
    '[WhatIf] 설치 스크립트와 관련 파일을 갱신하고 다시 실행하는 작업을 건너뜁니다.'
)

foreach ($message in $requiredMessages) {
    Assert-True -Condition ($functionText.Contains($message)) -Message "self-update progress message must be present: $message"
}

Assert-True -Condition ($functionText.Contains('Write-Host "[업데이트] 다운로드 중: $fileName ($downloadIndex/$downloadCount)"')) -Message 'download progress must include filename and ordinal count'
Assert-True -Condition ($functionText.Contains('$downloadCount = $script:UpdateFileNames.Count')) -Message 'download progress must derive total from update file list'
Assert-True -Condition ($functionText.Contains('$downloadIndex++')) -Message 'download progress must advance once per file'

$requiredOrder = @(
    '[업데이트] 최신 버전을 확인하는 중입니다.',
    '[업데이트] 다운로드 중:',
    '[업데이트] 원격 파일 검증이 완료되었습니다.',
    '[업데이트] 로컬 파일 교체를 시작합니다.',
    '[업데이트] 로컬 파일 설치가 완료되었습니다.',
    '[업데이트] 업데이트된 설치기로 재시작합니다.'
)
$previousIndex = -1
foreach ($message in $requiredOrder) {
    $messageIndex = $functionText.IndexOf($message, [System.StringComparison]::Ordinal)
    Assert-True -Condition ($messageIndex -gt $previousIndex) -Message "self-update messages must appear in order: $message"
    $previousIndex = $messageIndex
}

$skipGuardIndex = $functionText.IndexOf('if ($SkipUpdate -or $RollbackVersion)', [System.StringComparison]::Ordinal)
$restartGuardIndex = $functionText.IndexOf('$updateRestarted = [string]::Equals(', [System.StringComparison]::Ordinal)
$restartMessageIndex = $functionText.IndexOf('[업데이트] 업데이트된 설치기로 재시작되었습니다.', [System.StringComparison]::Ordinal)
$releaseLookupIndex = $functionText.IndexOf('Get-HighestGitHubRelease', [System.StringComparison]::Ordinal)
Assert-True -Condition ($skipGuardIndex -ge 0) -Message 'SkipUpdate and RollbackVersion must bypass self-update'
Assert-True -Condition ($restartGuardIndex -gt $skipGuardIndex) -Message 'child restart flag check must follow skip/rollback guard'
Assert-True -Condition ($restartMessageIndex -gt $restartGuardIndex -and $restartMessageIndex -lt $releaseLookupIndex) -Message 'child restart confirmation must be printed before any network lookup'
Assert-True -Condition ($functionText.Contains("Write-Host '[업데이트] 업데이트된 설치기로 재시작되었습니다.'`n        return")) -Message 'child restart confirmation must return to normal installation without another update check'

Assert-True -Condition ($functionText.Contains("[Environment]::SetEnvironmentVariable($script:UpdateInProgressVariable, '1', 'Process')")) -Message 'restart must set the in-progress flag'
Assert-True -Condition ($functionText.Contains("[Environment]::SetEnvironmentVariable($script:UpdateInProgressVariable, $previousUpdateFlag, 'Process')")) -Message 'restart must restore the in-progress flag in finally'
Assert-True -Condition ($functionText.Contains('finally {')) -Message 'self-update must retain cleanup/finally handling'
Assert-True -Condition ($functionText.Contains("Write-Warning $updateErrorMessage")) -Message 'self-update must retain the existing error fallback'

Write-Host '[PASS] self-update progress, restart confirmation, ordering, and fallback are statically verified'
