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

$releaseFunctionStart = $source.IndexOf('function Get-HighestGitHubRelease {', [System.StringComparison]::Ordinal)
$rollbackFunctionStart = $source.IndexOf('function Get-RollbackAsset {', $releaseFunctionStart, [System.StringComparison]::Ordinal)
Assert-True -Condition ($releaseFunctionStart -ge 0) -Message 'Get-HighestGitHubRelease function must exist'
Assert-True -Condition ($rollbackFunctionStart -gt $releaseFunctionStart) -Message 'Get-HighestGitHubRelease function boundary must be discoverable'
$releaseFunctionText = $source.Substring($releaseFunctionStart, $rollbackFunctionStart - $releaseFunctionStart)

Assert-True -Condition ($releaseFunctionText.Contains('$pageSize = 100')) -Message 'release lookup must request 100 releases per page'
Assert-True -Condition ($releaseFunctionText.Contains('$pageNumber = 1')) -Message 'release lookup must start at page 1'
Assert-True -Condition ($releaseFunctionText.Contains('$pageUri = ''{0}&page={1}'' -f $releasesUri, $pageNumber')) -Message 'release lookup must request each paginated page'
Assert-True -Condition ($releaseFunctionText.Contains('-Headers $headers -TimeoutSec 15')) -Message 'paginated release lookup must retain request headers and timeout'
Assert-True -Condition ($releaseFunctionText.Contains('$pageReleases.Count -eq 0')) -Message 'release lookup must stop on an empty page'
Assert-True -Condition ($releaseFunctionText.Contains('$pageReleases.Count -lt $pageSize')) -Message 'release lookup must stop on a short page'
Assert-True -Condition ($releaseFunctionText.Contains('$pageNumber++')) -Message 'release lookup must advance to the next page'
Assert-True -Condition ($releaseFunctionText.Contains('$releases += $pageReleases')) -Message 'release lookup must accumulate releases across pages'
Assert-True -Condition ($releaseFunctionText.Contains('ConvertTo-SemVer -Version $tagName')) -Message 'release lookup must retain tag Semantic Version validation'
Assert-True -Condition ($releaseFunctionText.Contains('$release.prerelease -or @($releaseVersion.PreRelease).Count -gt 0')) -Message 'stable release lookup must exclude GitHub and SemVer prereleases by default'
Assert-True -Condition ($releaseFunctionText.Contains('if ($null -eq $release -or $release.draft)')) -Message 'release lookup must exclude draft releases'

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
