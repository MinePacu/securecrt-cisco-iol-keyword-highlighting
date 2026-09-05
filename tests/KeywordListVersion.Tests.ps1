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

function Get-InternalBlankLineNumbers {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Lines)

    return @(
        for ($index = 0; $index -lt $Lines.Count; $index++) {
            $isFinalSplitArtifact = $index -eq ($Lines.Count - 1) -and
                [string]::IsNullOrEmpty($Lines[$index])
            if (-not $isFinalSplitArtifact -and [string]::IsNullOrWhiteSpace($Lines[$index])) {
                $index + 1
            }
        }
    )
}

Assert-Equal -Actual (@(Get-InternalBlankLineNumbers -Lines $v2Lines).Count) -Expected 0 -Message 'V2 must not contain internal blank lines'
Assert-Equal -Actual (@(Get-InternalBlankLineNumbers -Lines $v3Lines).Count) -Expected 0 -Message 'V3 must not contain internal blank lines'
Assert-True -Condition ($v2Text.EndsWith("`n") -or $v2Text.EndsWith("`r")) -Message 'V2 fixture must retain its final newline'
Assert-True -Condition ($v3Text.EndsWith("`n") -or $v3Text.EndsWith("`r")) -Message 'V3 fixture must retain its final newline'

$installerText = [System.IO.File]::ReadAllText($installerPath)
$installerTokens = $null
$installerParseErrors = $null
$installerAst = [System.Management.Automation.Language.Parser]::ParseInput(
    $installerText,
    [ref]$installerTokens,
    [ref]$installerParseErrors
)
Assert-Equal -Actual $installerParseErrors.Count -Expected 0 -Message 'installer must parse before extracting the keyword validator fixture'
$resolverAsts = @($installerAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Resolve-KeywordListVersion'
    }, $true))
Assert-Equal -Actual $resolverAsts.Count -Expected 1 -Message 'keyword-list resolver function must exist for selection testing'
$resolverText = $resolverAsts[0].Extent.Text
Assert-True -Condition (-not $resolverText.Contains('Read-Host')) -Message 'omitted keyword-list selection must not prompt for V2/V3'
$resolverScript = [scriptblock]::Create($resolverText)
. $resolverScript
$keywordFileNameAsts = @($installerAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Get-KeywordListFileName'
    }, $true))
$keywordSetNameAsts = @($installerAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Get-KeywordListSetName'
    }, $true))
Assert-Equal -Actual $keywordFileNameAsts.Count -Expected 1 -Message 'keyword-list filename function must exist for selection testing'
Assert-Equal -Actual $keywordSetNameAsts.Count -Expected 1 -Message 'keyword-set name function must exist for selection testing'
. ([scriptblock]::Create($keywordFileNameAsts[0].Extent.Text))
. ([scriptblock]::Create($keywordSetNameAsts[0].Extent.Text))
$KeywordListVersion = $null
$automaticVersion = Resolve-KeywordListVersion -WasExplicitlyBound $false -NonInteractive $false
Assert-Equal -Actual $automaticVersion -Expected 'V3' -Message 'omitted normal execution must automatically select V3'
$forceVersion = Resolve-KeywordListVersion -WasExplicitlyBound $false -NonInteractive $true
Assert-Equal -Actual $forceVersion -Expected 'V3' -Message 'omitted -Force execution must automatically select V3'
$automaticKeywordSet = Get-KeywordListSetName -Version $automaticVersion
Assert-Equal -Actual $automaticKeywordSet -Expected 'PNET-Cisco-Dark-V3' -Message 'automatic V3 selection must target the V3 keyword set'
$KeywordListVersion = 'v2'
Assert-Equal -Actual (Resolve-KeywordListVersion -WasExplicitlyBound $true -NonInteractive $false) -Expected 'V2' -Message 'explicit V2 selection must remain supported'
$KeywordListVersion = 'V3'
Assert-Equal -Actual (Resolve-KeywordListVersion -WasExplicitlyBound $true -NonInteractive $true) -Expected 'V3' -Message 'explicit V3 selection must remain supported'
Assert-True -Condition $installerText.Contains("[PSCustomObject]@{ Prefix = 'S'; Name = 'Keyword Set'; Value = `$keywordSetName }") -Message 'Default.ini Keyword Set must use the resolved keyword-set basename'
Write-Host '[PASS] omitted selection is non-interactive, defaults to V3, and maps Default.ini to the V3 keyword set'
$validatorAsts = @($installerAst.Find({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq 'Test-KeywordIniContent'
    }, $true))
Assert-Equal -Actual $validatorAsts.Count -Expected 1 -Message 'keyword validator function must exist for fixture testing'
$validatorScript = [scriptblock]::Create($validatorAsts[0].Extent.Text)
. $validatorScript

$validatorFixtures = @(
    [PSCustomObject]@{
        Version = 'V2'
        BlankAfterIndex = 2
        BlankLineNumber = 4
        ValidLines = @(
            'D:"Match Case"=00000001'
            'Z:"Keyword List V2"=00000002'
            ' "[*]FIRST",00FFFFFF,00000001'
            ' "SECOND",000000FF,00000001'
        )
    },
    [PSCustomObject]@{
        Version = 'V3'
        BlankAfterIndex = 3
        BlankLineNumber = 5
        ValidLines = @(
            'D:"Match Case"=00000001'
            'D:"Regex Line Mode"=00000001'
            'Z:"Keyword List V3"=00000002'
            ' "[*]FIRST",00FFFFFF,00000001,00000001'
            ' "SECOND",000000FF,00000001,00000001'
            'S:"List Name"=PNET-Cisco-Dark-V3'
        )
    }
)

foreach ($fixture in $validatorFixtures) {
    $validWithFinalNewline = ($fixture.ValidLines -join "`n") + "`n"
    Assert-True -Condition (Test-KeywordIniContent -Content $validWithFinalNewline -Version $fixture.Version) -Message "$($fixture.Version) validator fixture with final newline must pass"

    $invalidLines = @(
        $fixture.ValidLines[0..$fixture.BlankAfterIndex] +
            '' +
            $fixture.ValidLines[($fixture.BlankAfterIndex + 1)..($fixture.ValidLines.Count - 1)]
    )
    $invalidWithInternalBlank = ($invalidLines -join "`n") + "`n"
    $caught = $false
    $errorMessage = ''
    try {
        Test-KeywordIniContent -Content $invalidWithInternalBlank -Version $fixture.Version | Out-Null
    }
    catch {
        $caught = $true
        $errorMessage = $_.Exception.Message
    }

    Assert-True -Condition $caught -Message "$($fixture.Version) validator must reject a blank line between valid rows"
    Assert-True -Condition $errorMessage.Contains("$($fixture.Version) 키워드 목록") -Message "$($fixture.Version) blank-line error must identify the version"
    Assert-True -Condition $errorMessage.Contains("line $($fixture.BlankLineNumber)") -Message "$($fixture.Version) blank-line error must identify the line number"
}
Write-Host '[PASS] V2/V3 fixtures reject internal blank lines and accept the final newline artifact'

Assert-Equal -Actual $v2Rows.Count -Expected 368 -Message 'V2 must retain exactly 368 keyword rows'
Assert-Equal -Actual $v3Rows.Count -Expected 368 -Message 'V3 must retain exactly 368 keyword rows'

$v2CountMatch = [System.Text.RegularExpressions.Regex]::Match(
    $v2Text,
    '(?m)^Z:"Keyword List V2"=([0-9A-Fa-f]{8})\s*$')
Assert-True -Condition $v2CountMatch.Success -Message 'V2 metadata must declare its rule count'
${declaredV2Count} = [Convert]::ToInt32($v2CountMatch.Groups[1].Value, 16)
Assert-Equal -Actual $declaredV2Count -Expected $v2Rows.Count -Message 'V2 metadata count must match V2 rows'

Assert-Equal -Actual $v3Rows.Count -Expected $v2Rows.Count -Message 'V3 must contain every V2 rule'
Assert-Equal -Actual ([regex]::Matches($v3Text, '(?m)^D:"Match Case"=00000001\s*$').Count) -Expected 1 -Message 'V3 Match Case metadata must appear once'
Assert-Equal -Actual ([regex]::Matches($v3Text, '(?m)^D:"Regex Line Mode"=00000001\s*$').Count) -Expected 1 -Message 'V3 Regex Line Mode metadata must appear once'
$v3CountMatch = [System.Text.RegularExpressions.Regex]::Match(
    $v3Text,
    '(?m)^Z:"Keyword List V3"=([0-9A-Fa-f]{8})\s*$')
Assert-True -Condition $v3CountMatch.Success -Message 'V3 metadata must declare its rule count'
${declaredV3Count} = [Convert]::ToInt32($v3CountMatch.Groups[1].Value, 16)
Assert-Equal -Actual $declaredV3Count -Expected $v3Rows.Count -Message 'V3 metadata count must match V3 rows'
Assert-Equal -Actual ([regex]::Matches($v3Text, '(?m)^S:"List Name"=PNET-Cisco-Dark-V3\s*$').Count) -Expected 1 -Message 'V3 list name metadata must identify the V3 basename'

for ($index = 0; $index -lt $v2Rows.Count; $index++) {
    Assert-True -Condition ([regex]::IsMatch(
            $v3Rows[$index],
            '^\s+"[^"]*",[^,]+,[^,]+,00000001\s*$')) -Message "V3 row $index must have four fields and a 00000001 fourth field"
    Assert-Equal -Actual $v3Rows[$index] -Expected ($v2Rows[$index] + ',00000001') -Message "V3 row $index must preserve the V2 row and append only the fourth field"
}

function Get-SectionOrder {
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Lines)

    return @(
        foreach ($line in $Lines) {
            $match = [regex]::Match($line, '^\s+"\[\*\](?<name>[^"]+)",')
            if ($match.Success) {
                $match.Groups['name'].Value
            }
        }
    )
}

$expectedSectionOrder = @(
    'SHOW_ACCESS_LISTS',
    'NAT_CONTEXT_GUARDS',
    'SHOW_IP_NAT_TRANSLATIONS',
    'BGP_SHOW_IP',
    'CRITICAL_ERRORS_AND_DOWN_STATES',
    'GOOD_AND_INTERFACE_STATES',
    'STP_RAPID_PVST_MST',
    'ETHERCHANNEL',
    'HSRP',
    'OSPF_PROCESS_AREA_AND_IDS',
    'OSPF_COST_METRIC_REFERENCE_BW',
    'OSPF_ROUTE_TYPES',
    'ROUTING_TABLE_CODES_AND_METRICS',
    'ROUTING_TABLE_SUMMARY_DISCARD',
    'OSPF_NETWORK_TYPE_AND_DR_BDR',
    'OSPF_NEIGHBOR_STATES',
    'OSPF_TIMERS',
    'OSPF_LSDB_AND_LSA',
    'OSPF_SPF_AND_CONFIG',
    'OSPF_VIRTUAL_LINKS',
    'VLAN_TRUNK_AND_LAYER2',
    'INTERFACES_ADDRESSES_AND_IDENTIFIERS',
    'IP_INTERFACE_ACL_BINDINGS',
    'ROUTING_REDISTRIBUTION',
    'ROUTING_PROTOCOL_DISTANCE',
    'ROUTING_PROTOCOLS_AND_MISC',
    'BGP_SHOW_IP_SUMMARY',
    'BGP_SHOW_IP_NEIGHBORS',
    'PROMPTS'
)
Assert-Equal -Actual ((Get-SectionOrder -Lines $v2Lines) -join '|') -Expected ($expectedSectionOrder -join '|') -Message 'V2 sections must retain alpha-4 ordering with BGP summary and neighbor blocks late'
Assert-Equal -Actual ((Get-SectionOrder -Lines $v3Lines) -join '|') -Expected ($expectedSectionOrder -join '|') -Message 'V3 sections must retain alpha-4 ordering with BGP summary and neighbor blocks late'
Write-Host '[PASS] V2/V3 BGP summary and neighbor sections retain alpha-4 late-file ordering'

Assert-True -Condition $installerText.Contains("[ValidateSet('V2', 'V3')]") -Message 'installer must expose a V2/V3 ValidateSet parameter'
Assert-True -Condition $installerText.Contains('[string]$KeywordListVersion') -Message 'installer must define -KeywordListVersion'
Assert-True -Condition $installerText.Contains("Write-Host '[정보] -KeywordListVersion이 생략되어 V3를 자동 선택했습니다.'") -Message 'omitted selection must report automatic V3 selection'
$legacyDefaultSelectionText = 'Enter' + '=V3'
Assert-True -Condition (-not $installerText.Contains($legacyDefaultSelectionText)) -Message 'installer must not advertise the legacy keyword-list default token'
$legacyKeywordVersionPromptText = '설치할 키워드 목록 버전' + '을 선택하십시오'
Assert-True -Condition (-not $installerText.Contains($legacyKeywordVersionPromptText)) -Message 'installer must not advertise a V2/V3 keyword-list prompt'
Assert-True -Condition $installerText.Contains('return $KeywordListVersion.ToUpperInvariant()') -Message 'explicit V2 or V3 selection must be preserved'
Assert-True -Condition $installerText.Contains('$null = $arguments.Add(''-KeywordListVersion'')') -Message 'self-update restart must propagate the selected version parameter'
Assert-True -Condition ($installerText.Contains('$script:UpdateFileNames = @(') -and $installerText.Contains("'PNET-Cisco-Dark-V3.ini'")) -Message 'self-update file list must include the V3 asset'
Assert-True -Condition $installerText.Contains("V2로 대체 설치하지 않습니다.") -Message 'missing historical V3 assets must not silently fall back to V2'
Assert-True -Condition $installerText.Contains('$defaultBackupFileName = if ($script:SelectedKeywordListVersion -eq ''V3'')') -Message 'uninstall/install Default.ini backups must be version-aware'

Write-Host '[PASS] V2/V3 declared counts, mechanical row mapping, row shape, selection, and propagation are statically verified'
