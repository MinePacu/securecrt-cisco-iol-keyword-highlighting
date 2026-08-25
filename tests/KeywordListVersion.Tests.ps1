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

$rootPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$v2Path = Join-Path $rootPath 'PNET-Cisco-Dark.ini'
$v3Path = Join-Path $rootPath 'PNET-Cisco-Dark-V3.ini'
$installerPath = Join-Path $rootPath 'Install-KeywordHighlight.ps1'

$v2Text = [System.IO.File]::ReadAllText($v2Path)
$v3Text = [System.IO.File]::ReadAllText($v3Path)
$v2Lines = @($v2Text -split '\r?\n')
$v3Lines = @($v3Text -split '\r?\n')
$v2Rows = @($v2Lines | Where-Object { $_ -match '^\s+"' })
$v3Rows = @($v3Lines | Where-Object { $_ -match '^\s+"' })

$v2CountMatch = [System.Text.RegularExpressions.Regex]::Match(
    $v2Text,
    '(?m)^Z:"Keyword List V2"=([0-9A-Fa-f]{8})\s*$')
Assert-True -Condition $v2CountMatch.Success -Message 'V2 metadata must declare its rule count'
Assert-Equal -Actual ([Convert]::ToInt32($v2CountMatch.Groups[1].Value, 16)) -Expected $v2Rows.Count -Message 'V2 metadata count must match V2 rows'

Assert-Equal -Actual $v2Rows.Count -Expected 320 -Message 'V2 must retain all 320 existing rules'
Assert-Equal -Actual $v3Rows.Count -Expected $v2Rows.Count -Message 'V3 must contain every V2 rule'
Assert-Equal -Actual ([regex]::Matches($v3Text, '(?m)^D:"Match Case"=00000001\s*$').Count) -Expected 1 -Message 'V3 Match Case metadata must appear once'
Assert-Equal -Actual ([regex]::Matches($v3Text, '(?m)^D:"Regex Line Mode"=00000001\s*$').Count) -Expected 1 -Message 'V3 Regex Line Mode metadata must appear once'
$v3CountMatch = [System.Text.RegularExpressions.Regex]::Match(
    $v3Text,
    '(?m)^Z:"Keyword List V3"=([0-9A-Fa-f]{8})\s*$')
Assert-True -Condition $v3CountMatch.Success -Message 'V3 metadata must declare its rule count'
Assert-Equal -Actual ([Convert]::ToInt32($v3CountMatch.Groups[1].Value, 16)) -Expected 320 -Message 'V3 metadata count must declare 320 rules'
Assert-Equal -Actual ([Convert]::ToInt32($v3CountMatch.Groups[1].Value, 16)) -Expected $v3Rows.Count -Message 'V3 metadata count must match V3 rows'
Assert-Equal -Actual ([regex]::Matches($v3Text, '(?m)^S:"List Name"=PNET-Cisco-Dark-V3\s*$').Count) -Expected 1 -Message 'V3 list name metadata must identify the V3 basename'

for ($index = 0; $index -lt $v2Rows.Count; $index++) {
    Assert-True -Condition ([regex]::IsMatch(
            $v3Rows[$index],
            '^\s+"[^"]*",[^,]+,[^,]+,00000001\s*$')) -Message "V3 row $index must have four fields and a 00000001 fourth field"
    Assert-Equal -Actual $v3Rows[$index] -Expected ($v2Rows[$index] + ',00000001') -Message "V3 row $index must preserve the V2 row and append only the fourth field"
}

$installerText = [System.IO.File]::ReadAllText($installerPath)
Assert-True -Condition $installerText.Contains("[ValidateSet('V2', 'V3')]") -Message 'installer must expose a V2/V3 ValidateSet parameter'
Assert-True -Condition $installerText.Contains('[string]$KeywordListVersion') -Message 'installer must define -KeywordListVersion'
Assert-True -Condition $installerText.Contains("Read-Host '설치할 키워드 목록 버전을 선택하십시오 (V2/V3, Enter=V2)'") -Message 'interactive installation must visibly offer V2 and V3'
Assert-True -Condition $installerText.Contains("return 'V2'") -Message 'blank or non-interactive selection must default to V2'
Assert-True -Condition $installerText.Contains("Write-Warning '잘못된 키워드 목록 버전입니다.") -Message 'invalid interactive selections must be rejected clearly'
Assert-True -Condition $installerText.Contains('$null = $arguments.Add(''-KeywordListVersion'')') -Message 'self-update restart must propagate the selected version parameter'
Assert-True -Condition $installerText.Contains('$script:UpdateFileNames = @(') -and $installerText.Contains("'PNET-Cisco-Dark-V3.ini'") -Message 'self-update file list must include the V3 asset'
Assert-True -Condition $installerText.Contains("V2로 대체 설치하지 않습니다.") -Message 'missing historical V3 assets must not silently fall back to V2'
Assert-True -Condition $installerText.Contains('$defaultBackupFileName = if ($script:SelectedKeywordListVersion -eq ''V3'')') -Message 'uninstall/install Default.ini backups must be version-aware'

Write-Host '[PASS] V3 metadata, 320-rule mechanical mapping, row shape, selection, and propagation are statically verified'
