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

function Get-IniSectionText {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$SectionName
    )

    $sectionStart = -1
    $sectionEnd = $Lines.Count

    for ($index = 0; $index -lt $Lines.Count; $index++) {
        if ([System.Text.RegularExpressions.Regex]::IsMatch(
                $Lines[$index],
                ('^\s*"\[\*\]{0}",' -f [System.Text.RegularExpressions.Regex]::Escape($SectionName)),
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) {
            $sectionStart = $index
            break
        }
    }

    Assert-True -Condition ($sectionStart -ge 0) -Message "$SectionName section must exist"

    for ($index = $sectionStart + 1; $index -lt $Lines.Count; $index++) {
        if ([System.Text.RegularExpressions.Regex]::IsMatch(
                $Lines[$index],
                '^\s*"\[\*\]',
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) {
            $sectionEnd = $index
            break
        }
    }

    $sectionLines = $Lines[$sectionStart..($sectionEnd - 1)]
    return [string]::Join([System.Environment]::NewLine, $sectionLines)
}

function Get-IniRuleIndex {
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string[]]$Lines,
        [Parameter(Mandatory = $true)][string]$Pattern,
        [Parameter(Mandatory = $true)][string]$Color,
        [Parameter(Mandatory = $true)][ValidateSet('V2', 'V3')][string]$Version
    )

    $suffix = if ($Version -eq 'V3') { ',00000001' } else { '' }
    $expectedRow = '"' + $Pattern + '",' + $Color + ',00000001' + $suffix
    for ($index = 0; $index -lt $Lines.Count; $index++) {
        if ($Lines[$index].Trim() -ceq $expectedRow) {
            return $index
        }
    }

    return -1
}

$iniPath = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $PSScriptRoot '..') 'PNET-Cisco-Dark.ini'))
$iniText = [System.IO.File]::ReadAllText($iniPath)
$lines = $iniText -split '\r?\n'
$v3IniPath = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $PSScriptRoot '..') 'PNET-Cisco-Dark-V3.ini'))
$v3IniText = [System.IO.File]::ReadAllText($v3IniPath)
$v3Lines = $v3IniText -split '\r?\n'

$keywordCountMatch = [System.Text.RegularExpressions.Regex]::Match(
    $iniText,
    '(?m)^Z:"Keyword List V2"=([0-9A-Fa-f]{8})\s*$'
)
Assert-True -Condition $keywordCountMatch.Success -Message 'keyword list must declare its V2 entry count'
$declaredKeywordCount = [Convert]::ToInt32($keywordCountMatch.Groups[1].Value, 16)
$keywordEntryCount = @(
    $lines | Where-Object {
        [System.Text.RegularExpressions.Regex]::IsMatch(
            $_,
            '^\s+"',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )
    }
).Count
Assert-Equal -Actual $declaredKeywordCount -Expected $keywordEntryCount -Message 'Keyword List V2 entry count must include every keyword rule'
$v3KeywordCountMatch = [System.Text.RegularExpressions.Regex]::Match(
    $v3IniText,
    '(?m)^Z:"Keyword List V3"=([0-9A-Fa-f]{8})\s*$'
)
Assert-True -Condition $v3KeywordCountMatch.Success -Message 'keyword list must declare its V3 entry count'
$declaredV3KeywordCount = [Convert]::ToInt32($v3KeywordCountMatch.Groups[1].Value, 16)
$v3KeywordEntryCount = @(
    $v3Lines | Where-Object {
        [System.Text.RegularExpressions.Regex]::IsMatch(
            $_,
            '^\s+"',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )
    }
).Count
Assert-Equal -Actual $declaredV3KeywordCount -Expected $v3KeywordEntryCount -Message 'Keyword List V3 entry count must include every keyword rule'
Assert-Equal -Actual $v3KeywordEntryCount -Expected $keywordEntryCount -Message 'V2 and V3 must declare the same keyword-rule count'
$v2Rows = @($lines | Where-Object { $_ -match '^\s+"' })
$v3Rows = @($v3Lines | Where-Object { $_ -match '^\s+"' })
for ($rowIndex = 0; $rowIndex -lt $v2Rows.Count; $rowIndex++) {
    Assert-Equal -Actual $v3Rows[$rowIndex] -Expected ($v2Rows[$rowIndex] + ',00000001') -Message "V3 row $rowIndex must preserve the V2 row and append only its fourth field"
}
Write-Host '[PASS] SecureCRT V2/V3 keyword-list metadata and row parity include every keyword rule'

$regexLineModeMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $iniText,
    '(?m)^\s*D:"Regex Line Mode"=([01]{8})\s*$',
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-Equal -Actual $regexLineModeMatches.Count -Expected 1 -Message 'keyword list must explicitly configure Regex Line Mode once'
Assert-Equal -Actual $regexLineModeMatches[0].Groups[1].Value -Expected '00000001' -Message 'Regex Line Mode must be enabled for line-anchored prompt rules'
Write-Host '[PASS] SecureCRT regex line mode is enabled for line-anchored prompt rules'
$sectionText = Get-IniSectionText -Lines $lines -SectionName 'OSPF_PROCESS_AREA_AND_IDS'
$expectedPatterns = @(
    '\bIt is an autonomous system boundary router\b',
    '\bIt is an area border and autonomous system boundary router\b'
)

foreach ($expectedPattern in $expectedPatterns) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($expectedPattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",00FFFF00,00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $sectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "ASBR rule has exact pattern and yellow color: $expectedPattern"

    $sample = $expectedPattern -replace '\\b', ''
    Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $expectedPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "ASBR rule matches Cisco IOS phrase: $sample"
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            "prefix$sample",
            $expectedPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "ASBR rule respects the leading word boundary: $expectedPattern"
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            "${sample}suffix",
            $expectedPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "ASBR rule respects the trailing word boundary: $expectedPattern"
}

Write-Host '[PASS] OSPF ASBR phrase rules are present with exact yellow highlighting'

$routerIdRule = @{
    Pattern = '\b(?:Router ID\s+(?:[0-9]{1,3}\.){3}[0-9]{1,3}|local\x20+router\x20+ID\x20+is\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3})\b'
    Color = '00FFFF00'
}
$routerIdRulePattern = '^\s*"' + [System.Text.RegularExpressions.Regex]::Escape($routerIdRule.Pattern) + '",' + $routerIdRule.Color + ',00000001\s*$'
$routerIdRuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $sectionText,
    $routerIdRulePattern,
    [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-Equal -Actual $routerIdRuleMatches.Count -Expected 1 -Message 'Router ID rule has exact extended pattern and yellow color'
foreach ($sample in @(
        'Router ID 1.1.1.1',
        'BGP table version is 7, local router ID is 11.11.11.11'
    )) {
    Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $routerIdRule.Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Router ID rule matches valid transcript line: $sample"
}
foreach ($sample in @(
        'Router ID 1.1.1',
        'BGP table version is 7, local router ID is 11.11.11'
    )) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $routerIdRule.Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Router ID rule rejects malformed value: $sample"
}
Write-Host '[PASS] Router ID rule keeps yellow highlighting and covers local router ID lines'

$areaRules = @(
    @{
        Pattern = '\bArea(?:\x20ID)?\x20+(?:[0-9]+|(?:[0-9]{1,3}\.){3}[0-9]{1,3})\b'
        Color = '00FACE87'
        Matches = @(
            'Area 1',
            '    Area 1',
            'Area ID 1',
            'Area 0.0.0.0',
            '  Area ID 10.0.0.1'
        )
        Rejects = @('Area 1x', 'Area BACKBONE(0)')
    },
    @{
        Pattern = '\bArea(?:\x20ID)?\x20+BACKBONE\(0\)'
        Color = '00FACE87'
        Matches = @('Area BACKBONE(0)', '    Area BACKBONE(0)', 'Area ID BACKBONE(0)')
        Rejects = @('Area BACKBONE(1)', 'SubArea BACKBONE(0)')
    }
)

foreach ($areaRule in $areaRules) {
    Assert-True -Condition (-not $areaRule.Pattern.Contains('\s')) -Message "Area rule must use SecureCRT literal-space syntax: $($areaRule.Pattern)"
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($areaRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $areaRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $sectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "Area rule has exact pattern and color: $($areaRule.Pattern)"

    foreach ($sample in $areaRule.Matches) {
        Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $areaRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Area rule matches Cisco IOS output: $sample"
    }

    foreach ($sample in $areaRule.Rejects) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $areaRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Area rule rejects non-matching output: $sample"
    }
}

$areaTranscript = @(
    '      Area BACKBONE(0)',
    '      Area 1'
) -join ([char]10)
$areaTranscriptOptions = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$backboneTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $areaTranscript,
    $areaRules[1].Pattern,
    $areaTranscriptOptions
)
$numericTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $areaTranscript,
    $areaRules[0].Pattern,
    $areaTranscriptOptions
)
Assert-Equal -Actual $backboneTranscriptMatches.Count -Expected 1 -Message 'indented Area BACKBONE(0) transcript line must match'
Assert-Equal -Actual $numericTranscriptMatches.Count -Expected 1 -Message 'indented Area 1 transcript line must match'

Write-Host '[PASS] Cisco Area rules match indented BACKBONE(0), numeric, and IP output'

$neighborSectionText = Get-IniSectionText -Lines $lines -SectionName 'OSPF_NEIGHBOR_STATES'
$fullPattern = '\bFULL\b'
$fullRulePattern = '^\s*"' + [System.Text.RegularExpressions.Regex]::Escape($fullPattern) + '",0032CD32,00000001\s*$'
$fullRuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $neighborSectionText,
    $fullRulePattern,
    [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-Equal -Actual $fullRuleMatches.Count -Expected 1 -Message 'standalone OSPF FULL rule has exact green color'
Assert-True -Condition (-not $fullPattern.Contains('\s')) -Message 'standalone OSPF FULL rule must use SecureCRT-compatible syntax'

$neighborLogTranscript = @(
    'Aug 25 11:51:06: %OSPF-5-ADJCHG: Process 12, Nbr 10.0.0.2 on GigabitEthernet0/0/2 from LOADING to FULL, Loading Done',
    '*Mar  8 17:47:03.345: OSPFv3-1-IPv6 ADJ Gi0/0: Synchronized with 10.1.1.1, state FULL'
) -join ([char]10)
$neighborTranscriptOptions = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$neighborLogMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $neighborLogTranscript,
    $fullPattern,
    $neighborTranscriptOptions
)
Assert-Equal -Actual $neighborLogMatches.Count -Expected 2 -Message 'standalone FULL rule matches Cisco OSPF adjacency log variants'
Assert-True -Condition (($neighborLogMatches | ForEach-Object { $_.Value }) -contains 'FULL') -Message 'standalone FULL rule must match the Cisco neighbor state token'

foreach ($falseFullSample in @('FULLY', 'FULLNESS', 'preFULL', 'FULL_suffix')) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $falseFullSample,
            $fullPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "standalone FULL rule rejects false-positive token: $falseFullSample"
}

Write-Host '[PASS] OSPF neighbor FULL state logs receive standalone green highlighting without false positives'

$costSectionText = Get-IniSectionText -Lines $lines -SectionName 'OSPF_COST_METRIC_REFERENCE_BW'
$costFullPattern = '\b[Cc]ost\x20*:\x20*[0-9]+\b'
$costPattern = '\b[Cc]ost\b'
$costFullRulePattern = '^\s*"' + [System.Text.RegularExpressions.Regex]::Escape($costFullPattern) + '",0000D7FF,00000001\s*$'
$costFullRuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $costSectionText,
    $costFullRulePattern,
    [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-Equal -Actual $costFullRuleMatches.Count -Expected 1 -Message 'Cost full phrase rule has exact gold color'
Assert-True -Condition (-not $costFullPattern.Contains('\s')) -Message 'Cost full phrase rule must use SecureCRT literal-space syntax'
$costRulePattern = '^\s*"' + [System.Text.RegularExpressions.Regex]::Escape($costPattern) + '",0000D7FF,00000001\s*$'
$costRuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $costSectionText,
    $costRulePattern,
    [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-Equal -Actual $costRuleMatches.Count -Expected 1 -Message 'Cost token rule has exact gold color'

$costTranscript = @(
    '      Cost: 10',
    '      Cost : 10',
    '      cost: 20',
    '      cost 20'
) -join ([char]10)
$transcriptOptions = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$costTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $costTranscript,
    $costPattern,
    $transcriptOptions
)
Assert-Equal -Actual $costTranscriptMatches.Count -Expected 4 -Message 'Cost token rule matches Cost: and Cost-space numeric transcript lines'
Assert-True -Condition (($costTranscriptMatches | ForEach-Object { $_.Value }) -notcontains '10') -Message 'Cost token rule must not color the numeric value as a standalone match'
$costFullTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $costTranscript,
    $costFullPattern,
    $transcriptOptions
)
Assert-Equal -Actual $costFullTranscriptMatches.Count -Expected 3 -Message 'Cost full phrase rule matches Cost: 10 and Cost : 10 transcript lines'
Assert-True -Condition (($costFullTranscriptMatches | ForEach-Object { $_.Value }) -contains 'Cost: 10') -Message 'Cost full phrase rule must include Cost: 10 and its numeric value'
Assert-True -Condition (($costFullTranscriptMatches | ForEach-Object { $_.Value }) -contains 'Cost : 10') -Message 'Cost full phrase rule must include Cost : 10 and its numeric value'

foreach ($sample in @('Costs: 1', 'preCost: 1', 'Costume: 10')) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $costPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Cost token rule rejects non-matching output: $sample"
}

Write-Host '[PASS] OSPF Cost token rule matches screenshot transcript without coloring numbers'

$routeSectionStart = -1
$routeSectionEnd = $lines.Count

for ($index = 0; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]ROUTING_TABLE_CODES_AND_METRICS",',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $routeSectionStart = $index
        break
    }
}

Assert-True -Condition ($routeSectionStart -ge 0) -Message 'ROUTING_TABLE_CODES_AND_METRICS section must exist'

for ($index = $routeSectionStart + 1; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $routeSectionEnd = $index
        break
    }
}

$routeSectionLines = $lines[$routeSectionStart..($routeSectionEnd - 1)]
$routeSectionText = [string]::Join([System.Environment]::NewLine, $routeSectionLines)
$routeMetricRule = @{ Pattern = '\[[0-9]+/[0-9]+\]'; Color = '0000D7FF' }
$routeLegendRuleSpecs = @(
    @{ Pattern = '\bL\x20+-'; Color = '0032CD32' },
    @{ Pattern = '\bC\x20+-'; Color = '00FFFF00' },
    @{ Pattern = '\bS\*?\x20+-'…16433 tokens truncated…alid', 'internal', 'external')
for ($statusRuleOffset = 0; $statusRuleOffset -lt $statusPathTokens.Count; $statusRuleOffset++) {
    $statusPathValues = [System.Text.RegularExpressions.Regex]::Matches(
        $bgpPathAttributeTranscript,
        $bgpPathRuleSpecs[6 + $statusRuleOffset].Pattern,
        $bgpTranscriptOptions
    ) | ForEach-Object { $_.Value }
    Assert-True -Condition ($statusPathValues -contains $statusPathTokens[$statusRuleOffset]) -Message "$($bgpPathRuleSpecs[6 + $statusRuleOffset].Name) matches its status token"
    $statusValuesWithRouteFields = @($statusPathValues | Where-Object { $_ -match 'localpref|[0-9]' })
    Assert-Equal -Actual $statusValuesWithRouteFields.Count -Expected 0 -Message "$($bgpPathRuleSpecs[6 + $statusRuleOffset].Name) matches only the status token, without localpref or its numeric value"
}
$bestPathValues = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpPathAttributeTranscript,
    $bgpPathRuleSpecs[9].Pattern,
    $bgpTranscriptOptions
) | ForEach-Object { $_.Value }
$expectedBestPathValues = @('internal, best', 'external, best', 'valid external best', 'internal, best')
Assert-Equal -Actual $bestPathValues.Count -Expected $expectedBestPathValues.Count -Message 'best path status rule matches only Cisco path-attribute variants'
for ($bestValueIndex = 0; $bestValueIndex -lt $expectedBestPathValues.Count; $bestValueIndex++) {
    Assert-Equal -Actual $bestPathValues[$bestValueIndex] -Expected $expectedBestPathValues[$bestValueIndex] -Message 'best path status rule preserves its scoped status context without localpref or numeric values'
}
Assert-True -Condition (@($bestPathValues | Where-Object { $_ -match 'localpref|[0-9]' }).Count -eq 0) -Message 'best path status rule must not consume localpref or any numeric value'
foreach ($falsePathSample in @(
        'metric 0',
        'metric is 0, localpref is 100',
        'valid route status best',
        'unrelated prose, best',
        'internal best route',
        'external path best',
        'Origin IGP, metric 0, localpref 100, valid route, internal, best'
    )) {
    foreach ($pathRule in $bgpPathRuleSpecs) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $falsePathSample,
                $pathRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "$($pathRule.Name) rejects malformed or non-BGP prose: $falsePathSample"
    }
}

$bgpDetailTranscript = @(
    '      Originator: 77.77.77.77, Cluster list: 22.22.22.22',
    '      Originator: 10.10.10.10,  Cluster list: 20.20.20.20, 30.30.30.30',
    'Originator: 1.1.1.1, Cluster list: 2.2.2.2,3.3.3.3'
) -join ([char]10)
$expectedDetailMatchTexts = @{
    'Originator label' = @('Originator:', 'Originator:', 'Originator:')
    'Originator IPv4 value' = @('77.77.77.77', '10.10.10.10', '1.1.1.1')
    'Cluster list label' = @('Cluster list:', 'Cluster list:', 'Cluster list:')
    'Cluster list IPv4 values' = @('22.22.22.22', '20.20.20.20', '30.30.30.30', '2.2.2.2', '3.3.3.3')
}
foreach ($detailRule in $bgpDetailRuleSpecs) {
    $detailMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $bgpDetailTranscript,
        $detailRule.Pattern,
        $bgpTranscriptOptions
    )
    $expectedDetailValues = $expectedDetailMatchTexts[$detailRule.Name]
    Assert-Equal -Actual $detailMatches.Count -Expected $expectedDetailValues.Count -Message "$($detailRule.Name) matches valid Cisco path-detail tokens"
    for ($detailMatchIndex = 0; $detailMatchIndex -lt $detailMatches.Count; $detailMatchIndex++) {
        Assert-Equal -Actual $detailMatches[$detailMatchIndex].Value -Expected $expectedDetailValues[$detailMatchIndex] -Message "$($detailRule.Name) match is token-only"
    }
}
$clusterListValues = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpDetailTranscript,
    $bgpDetailRuleSpecs[3].Pattern,
    $bgpTranscriptOptions
) | ForEach-Object { $_.Value }
Assert-True -Condition (($clusterListValues -contains '20.20.20.20') -and ($clusterListValues -contains '30.30.30.30')) -Message 'Cluster list value rule preserves multiple comma-separated IPv4 values as separate tokens'
foreach ($falseDetailSample in @(
        'Originator: 77.77.77, Cluster list: 22.22.22',
        'Originator: not-an-ip, Cluster list: none',
        'Cluster list: 22.22.22'
    )) {
    foreach ($detailRule in $bgpDetailRuleSpecs) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $falseDetailSample,
                $detailRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "$($detailRule.Name) rejects malformed or non-BGP detail output: $falseDetailSample"
    }
}
$unrelatedDetailSample = 'Unrelated: 77.77.77.77, Cluster list: 22.22.22.22'
$unrelatedOriginatorLabelMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $unrelatedDetailSample,
    $bgpDetailRuleSpecs[0].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $unrelatedOriginatorLabelMatches.Count -Expected 0 -Message 'Originator label rejects unrelated-line context'
$unrelatedOriginatorValues = [System.Text.RegularExpressions.Regex]::Matches(
    $unrelatedDetailSample,
    $bgpDetailRuleSpecs[1].Pattern,
    $bgpTranscriptOptions
) | ForEach-Object { $_.Value }
Assert-Equal -Actual $unrelatedOriginatorValues.Count -Expected 1 -Message 'Originator value remains token-only when the left context cannot be asserted without lookbehind'
Assert-Equal -Actual $unrelatedOriginatorValues[0] -Expected '77.77.77.77' -Message 'Originator value rule does not consume unrelated prefix text'
$unrelatedClusterLabelMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $unrelatedDetailSample,
    $bgpDetailRuleSpecs[2].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $unrelatedClusterLabelMatches.Count -Expected 1 -Message 'Cluster list label remains independently matchable'
Assert-Equal -Actual $unrelatedClusterLabelMatches[0].Value -Expected 'Cluster list:' -Message 'Cluster list label match is label-only on an unrelated prefix'
$unrelatedClusterValues = [System.Text.RegularExpressions.Regex]::Matches(
    $unrelatedDetailSample,
    $bgpDetailRuleSpecs[3].Pattern,
    $bgpTranscriptOptions
) | ForEach-Object { $_.Value }
Assert-Equal -Actual $unrelatedClusterValues.Count -Expected 1 -Message 'Cluster list value rule does not consume unrelated prefix text'
Assert-Equal -Actual $unrelatedClusterValues[0] -Expected '22.22.22.22' -Message 'Cluster list value rule matches only the IPv4 token on an unrelated prefix'
Write-Host '[PASS] BGP path attributes and Originator/Cluster-list details match Cisco forms with scoped false-positive coverage'

$bgpSummarySectionText = Get-IniSectionText -Lines $lines -SectionName 'BGP_SHOW_IP_SUMMARY'
$bgpSummaryRuleSpecs = @(
    @{ Pattern = '(?:^|\x20)local\x20+AS\x20+number\x20+(?:[0-9]{1,5}\.[0-9]{1,5}|[0-9]{1,10})\x20*$'; Color = '0000D7FF' },
    @{ Pattern = '^\x20*BGP\x20+router\x20+identifier\x20+(?:[0-9]{1,3}\.){3}[0-9]{1,3},\x20+local\x20+AS\x20+number\b'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Neighbor\x20+V\x20+AS\x20+MsgRcvd\x20+MsgSent\x20+TblVer\x20+InQ\x20+OutQ\x20+Up/Down\x20+State(?:/PfxRcd)?\x20*$'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Neighbor\x20+V(?=\x20+AS\x20+MsgRcvd\b)'; Color = '00FACE87' },
    @{ Pattern = '\bAS(?=\x20+MsgRcvd\b)'; Color = '00FACE87' },
    @{ Pattern = 'MsgRcvd\x20+MsgSent\x20+TblVer\x20+InQ\x20+OutQ\x20+Up/Down\x20+State(?=\x2fPfxRcd\b|\x20*$)'; Color = '00FACE87' },
    @{ Pattern = '^\x20*/PfxRcd\x20*$'; Color = '00FACE87' },
    @{ Pattern = 'Idle(?=\x20+\(Admin\)\x20*$|\x20*$)|\(Admin\)(?=\x20*$)|^\x20*\*?(?:[0-9]{1,3}\.){3}[0-9]{1,3}\x20+[0-9]+\x20+(?:[0-9]{1,5}\.[0-9]{1,5}|[0-9]{1,10})\x20+[0-9]+\x20+[0-9]+\x20+[0-9]+\x20+[0-9]+(?:\x20+[0-9]+)?\x20+(?:[0-9]{2}:[0-9]{2}:[0-9]{2}|never)\x20+(?:[0-9]+|Idle(?:\x20+\(Admin\))?|Active|Connect|OpenSent|OpenConfirm|Established|PfxRcd)\x20*$'; Color = '0000D7FF' }
)
Assert-True -Condition (-not $bgpSummarySectionText.Contains('\s')) -Message 'BGP summary rules must use SecureCRT literal-space syntax instead of \s'
Assert-True -Condition (-not $bgpSummarySectionText.Contains('(?<=')) -Message 'BGP summary rules must not depend on lookbehind'
foreach ($summaryRule in $bgpSummaryRuleSpecs) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($summaryRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $summaryRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $bgpSummarySectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "BGP summary rule has exact pattern and color: $($summaryRule.Pattern)"
}

$bgpSummaryTranscript = @(
    'BGP router identifier 192.168.3.1, local AS number 45000',
    'BGP table version is 1, main routing table version 1',
    'Neighbor        V    AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd',
    '*192.168.3.2    4 50000       2       2        0    0    0 00:00:37        0',
    'BGP router identifier 172.17.1.99, local AS number 1.2',
    'Neighbor        V           AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State',
    '192.168.1.2     4         1.0       9       9        1    0    0 00:04:13      0',
    '/PfxRcd',
    '10.1.1.1 4 2 5 6 0 0 00:52:39 2'
) -join ([char]10)
$summaryLocalValueMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpSummaryTranscript,
    $bgpSummaryRuleSpecs[0].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $summaryLocalValueMatches.Count -Expected 2 -Message 'Summary local AS value rule matches asplain and asdot 2/4-byte ASNs'
Assert-True -Condition (($summaryLocalValueMatches | ForEach-Object { $_.Value }) -contains ' local AS number 45000') -Message 'Summary local AS value rule matches the local-AS suffix inside the full router-ID line'
Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
        'local AS number 2',
        $bgpSummaryRuleSpecs[0].Pattern,
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )) -Message 'Summary local AS value rule matches the exact local AS number 2 phrase'
$summaryLocalTitleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpSummaryTranscript,
    $bgpSummaryRuleSpecs[1].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $summaryLocalTitleMatches.Count -Expected 2 -Message 'Summary local AS title rule matches both Cisco local-AS sentence forms'
Assert-True -Condition (($summaryLocalTitleMatches | ForEach-Object { $_.Value }) -notcontains 'BGP router identifier 192.168.3.1, local AS number 45000') -Message 'Summary local AS title rule stops before the ASN value'
$summaryFullHeaderMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpSummaryTranscript,
    $bgpSummaryRuleSpecs[2].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $summaryFullHeaderMatches.Count -Expected 2 -Message 'Summary full header rule matches State and State/PfxRcd variants'
foreach ($headerRule in $bgpSummaryRuleSpecs[3..5]) {
    $headerMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $bgpSummaryTranscript,
        $headerRule.Pattern,
        $bgpTranscriptOptions
    )
    Assert-Equal -Actual $headerMatches.Count -Expected 2 -Message "Summary $($headerRule.Pattern) title rule matches both header variants"
}
Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
        'AS MsgRcvd',
        $bgpSummaryRuleSpecs[4].Pattern,
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )) -Message 'Summary AS title rule matches the exact AS header token'
$summaryWrapMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpSummaryTranscript,
    $bgpSummaryRuleSpecs[6].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $summaryWrapMatches.Count -Expected 1 -Message 'Summary wrapped /PfxRcd title rule matches Cisco line variant'
$summaryValueMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpSummaryTranscript,
    $bgpSummaryRuleSpecs[7].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $summaryValueMatches.Count -Expected 3 -Message 'Summary value rule matches standard, asdot, and IOL compact rows'
Assert-True -Condition (($summaryValueMatches | ForEach-Object { $_.Value }) -contains '*192.168.3.2    4 50000       2       2        0    0    0 00:00:37        0') -Message 'Summary value rule includes dynamic-neighbor rows'
Assert-True -Condition (($summaryValueMatches | ForEach-Object { $_.Value }) -contains '10.1.1.1 4 2 5 6 0 0 00:52:39 2') -Message 'Summary value rule includes the screenshot-style compact row'
$bgpSummaryScreenshotTranscript = @(
    'BGP router identifier 11.11.11.11, local AS number 2',
    'BGP table version is 7, main routing table version 7',
    'Neighbor        V          AS MsgRcvd MsgSent   TblVer  InQ OutQ Up/Down  State/PfxRcd',
    '2.2.2.2         4          2  28      30       7       0    0    00:24:19 1',
    '2.2.2.2         4          2  0 0 1 0 0 00:01:39 Idle (Admin)',
    '2.2.2.2         4          2  0 0 1 0 0 00:01:39 Idle',
    '5.5.5.5         4          2  28      30       7       0    0    00:22:57 1',
    '3.3.3.3         4          2  0 0 1 0 0 00:01:35 Idle (Admin)',
    '10.1.14.4       4          1  32      32       7       0    0    00:25:10 1',
    '10.1.23.3       4          2  21      19       7       0    0    00:08:21 2'
) -join ([char]10)
Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
        $bgpSummaryScreenshotTranscript,
        $bgpSummaryRuleSpecs[0].Pattern,
        $bgpTranscriptOptions
    )) -Message 'Summary local AS value rule matches the screenshot local AS number 2 line'
Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
        $bgpSummaryScreenshotTranscript,
        $bgpSummaryRuleSpecs[4].Pattern,
        $bgpTranscriptOptions
    )) -Message 'Summary AS title rule matches the screenshot header AS token'
foreach ($neighborRow in @(
        '2.2.2.2         4          2  28      30       7       0    0    00:24:19 1',
        '2.2.2.2         4          2  0 0 1 0 0 00:01:39 Idle (Admin)',
        '2.2.2.2         4          2  0 0 1 0 0 00:01:39 Idle',
        '5.5.5.5         4          2  28      30       7       0    0    00:22:57 1',
        '3.3.3.3         4          2  0 0 1 0 0 00:01:35 Idle (Admin)',
        '10.1.14.4       4          1  32      32       7       0    0    00:25:10 1',
        '10.1.23.3       4          2  21      19       7       0    0    00:08:21 2'
    )) {
    Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
            $neighborRow,
            $bgpSummaryRuleSpecs[7].Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Summary value rule matches screenshot neighbor row: $neighborRow"
}
$idleAdminTokenMatches = [System.Text.RegularExpressions.Regex]::Matches(
    'Idle (Admin)',
    $bgpSummaryRuleSpecs[7].Pattern,
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-True -Condition (($idleAdminTokenMatches | ForEach-Object { $_.Value }) -contains 'Idle') -Message 'Summary value rule explicitly matches the Idle token in Idle (Admin)'
Assert-True -Condition (($idleAdminTokenMatches | ForEach-Object { $_.Value }) -contains '(Admin)') -Message 'Summary value rule explicitly matches the (Admin) token in Idle (Admin)'
$idleTokenMatches = [System.Text.RegularExpressions.Regex]::Matches(
    'Idle',
    $bgpSummaryRuleSpecs[7].Pattern,
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-True -Condition (($idleTokenMatches | ForEach-Object { $_.Value }) -contains 'Idle') -Message 'Summary value rule explicitly matches a standalone Idle token'
foreach ($falseSummarySample in @(
        'V AS MsgRcvd MsgSent',
        'not-a-neighbor V 50000 2 2 0 0 0 00:00:37 0',
        'BGP router identifier 192.168.3.1, local AS number not-an-asn',
        'not-a-neighbor 4 50000 2 2 0 0 0 00:00:37 0',
        '192.168.3.2 4 50000 2 2 0 0 0 00:00:37 Unknown',
        'This session is Idle now',
        'Admin'
    )) {
    foreach ($summaryRule in $bgpSummaryRuleSpecs[0,3,4,5,6,7]) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $falseSummarySample,
                $summaryRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Summary rule rejects malformed or non-summary text: $falseSummarySample"
    }
}
Write-Host '[PASS] BGP summary local-AS, V/AS/State headers, and neighbor values match Cisco output without malformed-row false positives'

$bgpNeighborSectionText = Get-IniSectionText -Lines $lines -SectionName 'BGP_SHOW_IP_NEIGHBORS'
$bgpNeighborV3SectionText = Get-IniSectionText -Lines $v3Lines -SectionName 'BGP_SHOW_IP_NEIGHBORS'
$bgpNeighborRuleSpecs = @(
    @{ Pattern = '^\x20*BGP\x20+neighbor\x20+is\x20+\*?(?:[0-9]{1,3}\.){3}[0-9]{1,3},\x20+remote\x20+AS\x20+(?:[0-9]{1,5}\.[0-9]{1,5}|[0-9]{1,10})\b'; Color = '0000D7FF' },
    @{ Pattern = '^\x20*BGP\x20+neighbor\x20+is\x20+\*?(?:[0-9]{1,3}\.){3}[0-9]{1,3},\x20+remote\x20+AS\b'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Last\x20+read\x20+[0-9]{2}:[0-9]{2}:[0-9]{2}\b'; Color = '0000D7FF' },
    @{ Pattern = '^\x20*Last\x20+read\b'; Color = '00FACE87' },
    @{ Pattern = '(?:^\x20*|\x20+)last\x20+write\x20+[0-9]{2}:[0-9]{2}:[0-9]{2}\b'; Color = '0000D7FF' },
    @{ Pattern = '(?:^\x20*|\x20+)last\x20+write\b'; Color = '00FACE87' },
    @{ Pattern = '^\x20*Last\x20+written\x20+[0-9]{2}:[0-9]{2}:[0-9]{2}\b'; Color = '0000D7FF' },
    @{ Pattern = '^\x20*Last\x20+written\b'; Color = '00FACE87' },
    @{ Pattern = '(?:^\x20*|\x20+)hold\x20+time\x20+(?:is|=)\x20+[0-9]+\b'; Color = '0000D7FF' },
    @{ Pattern = '(?:^\x20*|\x20+)hold\x20+time\x20+(?:is\b|=)'; Color = '00FACE87' },
    @{ Pattern = '(?:^\x20*|\x20+)keepalive\x20+interval\x20+(?:is|=)\x20+[0-9]+\x20+seconds\b'; Color = '0000D7FF' },
    @{ Pattern = '(?:^\x20*|\x20+)keepalive\x20+interval\x20+(?:is\b|=)'; Color = '00FACE87' },
    @{ Pattern = '^\x20*NEXT_HOP\x20+is\x20+always\x20+this\x20+router\x20+for\x20+eBGP\x20+paths\x20*$'; Color = '00FFFF00' }
)
$bgpNeighborStatusRuleSpecs = @(
    @{ Pattern = 'remote\x20+AS\x20+(?:[0-9]{1,5}\.[0-9]{1,5}|[0-9]{1,10})\b'; Color = '0000D7FF'; Name = 'remote-AS value phrase' },
    @{ Pattern = ',\x20+internal\x20+link\x20*$'; Color = '0000D7FF'; Name = 'internal link' },
    @{ Pattern = ',\x20+external\x20+link\x20*$'; Color = '0000D7FF'; Name = 'external link' },
    @{ Pattern = '^\x20*Route-Reflector\x20+Client\x20*$'; Color = '0000D7FF'; Name = 'Route-Reflector Client' }
)
$stateRuleSpecs = @(
    @{ Pattern = '(?:^\x20*|\x20+)(?:state|State|STATE)\x20*=\x20*(?:REACHABLE|Reachable|reachable|STALE|Stale|stale|DELAY|Delay|delay|PROBE|Probe|probe|INCOMPLETE|Incomplete|incomplete)\b'; Color = '0000D7FF'; States = @('REACHABLE', 'Reachable', 'reachable', 'STALE', 'Stale', 'stale', 'DELAY', 'Delay', 'delay', 'PROBE', 'Probe', 'probe', 'INCOMPLETE', 'Incomplete', 'incomplete') }
    @{ Pattern = '(?:^\x20*|\x20+)(?:state|State|STATE)\x20*=\x20*(?:FAILED|Failed|failed|NOARP|Noarp|noarp|PERMANENT|Permanent|permanent|REACH|Reach|reach|VALID|Valid|valid|INVALID|Invalid|invalid)\b'; Color = '0000D7FF'; States = @('FAILED', 'Failed', 'failed', 'NOARP', 'Noarp', 'noarp', 'PERMANENT', 'Permanent', 'permanent', 'REACH', 'Reach', 'reach', 'VALID', 'Valid', 'valid', 'INVALID', 'Invalid', 'invalid') }
    @{ Pattern = '(?:^\x20*|\x20+)(?:state|State|STATE)\x20*=\x20*(?:DUPLICATE|Duplicate|duplicate|TENTATIVE|Tentative|tentative|UP|Up|up|DOWN|Down|down|FULL|Full|full|INIT|Init|init)\b'; Color = '0000D7FF'; States = @('DUPLICATE', 'Duplicate', 'duplicate', 'TENTATIVE', 'Tentative', 'tentative', 'UP', 'Up', 'up', 'DOWN', 'Down', 'down', 'FULL', 'Full', 'full', 'INIT', 'Init', 'init') }
    @{ Pattern = '(?:^\x20*|\x20+)(?:state|State|STATE)\x20*=\x20*(?:ACTIVE|Active|active|IDLE|Idle|idle|CONNECT|Connect|connect|OPENSENT|OpenSent|opensent|OPENCONFIRM|OpenConfirm|openconfirm|ESTABLISHED|Established|established)\b'; Color = '0000D7FF'; States = @('ACTIVE', 'Active', 'active', 'IDLE', 'Idle', 'idle', 'CONNECT', 'Connect', 'connect', 'OPENSENT', 'OpenSent', 'opensent', 'OPENCONFIRM', 'OpenConfirm', 'openconfirm', 'ESTABLISHED', 'Established', 'established') }
)
Assert-True -Condition (-not $bgpNeighborSectionText.Contains('\s')) -Message 'BGP neighbor rules must use SecureCRT literal-space syntax instead of \s'
Assert-True -Condition (-not $bgpNeighborSectionText.Contains('(?<=')) -Message 'BGP neighbor rules must not depend on lookbehind'
Assert-True -Condition (-not $bgpNeighborV3SectionText.Contains('\s')) -Message 'V3 BGP neighbor rules must use SecureCRT literal-space syntax instead of \s'
Assert-True -Condition (-not $bgpNeighborV3SectionText.Contains('(?<=')) -Message 'V3 BGP neighbor rules must not depend on lookbehind'
foreach ($neighborRule in $bgpNeighborRuleSpecs) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($neighborRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $neighborRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $bgpNeighborSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "BGP neighbor rule has exact pattern and color: $($neighborRule.Pattern)"
}
foreach ($stateRule in $stateRuleSpecs) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($stateRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $stateRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $bgpNeighborSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "BGP state rule has exact pattern and color: $($stateRule.Pattern)"
}
foreach ($statusRule in $bgpNeighborStatusRuleSpecs) {
    Assert-True -Condition (-not $statusRule.Pattern.Contains('\s')) -Message "$($statusRule.Name) rule must use SecureCRT literal-space syntax"
    Assert-True -Condition (-not $statusRule.Pattern.Contains('(?<=')) -Message "$($statusRule.Name) rule must not use lookbehind"
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($statusRule.Pattern)
    $v2RulePattern = '^\s*"' + $escapedPattern + '",' + $statusRule.Color + ',00000001\s*$'
    $v3RulePattern = '^\s*"' + $escapedPattern + '",' + $statusRule.Color + ',00000001,00000001\s*$'
    $v2RuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $bgpNeighborSectionText,
        $v2RulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    $v3RuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $bgpNeighborV3SectionText,
        $v3RulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $v2RuleMatches.Count -Expected 1 -Message "V2 BGP $($statusRule.Name) rule has exact pattern and value color"
    Assert-Equal -Actual $v3RuleMatches.Count -Expected 1 -Message "V3 BGP $($statusRule.Name) rule has exact pattern and value color"
}
$specificRuleIndices = @(
    $bgpNeighborStatusRuleSpecs | ForEach-Object {
        Get-IniRuleIndex -Lines $lines -Pattern $_.Pattern -Color $_.Color -Version 'V2'
    }
)
$specificV3RuleIndices = @(
    $bgpNeighborStatusRuleSpecs | ForEach-Object {
        Get-IniRuleIndex -Lines $v3Lines -Pattern $_.Pattern -Color $_.Color -Version 'V3'
    }
)
$legacyRemoteRuleIndices = @(
    $bgpNeighborRuleSpecs[0, 1] | ForEach-Object {
        Get-IniRuleIndex -Lines $lines -Pattern $_.Pattern -Color $_.Color -Version 'V2'
    }
)
$legacyRemoteV3RuleIndices = @(
    $bgpNeighborRuleSpecs[0, 1] | ForEach-Object {
        Get-IniRuleIndex -Lines $v3Lines -Pattern $_.Pattern -Color $_.Color -Version 'V3'
    }
)
Assert-True -Condition (-not ($specificRuleIndices -contains -1)) -Message 'V2 BGP-specific rules must be present exactly once'
Assert-True -Condition (-not ($specificV3RuleIndices -contains -1)) -Message 'V3 BGP-specific rules must be present exactly once'
Assert-True -Condition (-not ($legacyRemoteRuleIndices -contains -1)) -Message 'V2 legacy remote-AS rules must be present exactly once'
Assert-True -Condition (-not ($legacyRemoteV3RuleIndices -contains -1)) -Message 'V3 legacy remote-AS rules must be present exactly once'
Assert-True -Condition (($specificRuleIndices | Measure-Object -Maximum).Maximum -lt ($legacyRemoteRuleIndices | Measure-Object -Minimum).Minimum) -Message 'V2 BGP-specific rules must precede both legacy remote-AS rules'
Assert-True -Condition (($specificV3RuleIndices | Measure-Object -Maximum).Maximum -lt ($legacyRemoteV3RuleIndices | Measure-Object -Minimum).Minimum) -Message 'V3 BGP-specific rules must precede both legacy remote-AS rules'
Assert-True -Condition (($stateRuleSpecs | ForEach-Object { $_.Pattern.Length } | Measure-Object -Maximum).Maximum -lt 246) -Message 'Every BGP state rule pattern must be shorter than 246 characters'

$bgpNeighborTranscript = @(
    'BGP neighbor is 1.1.1.1,  remote AS 2, internal link',
    'BGP neighbor is *172.16.10.2,  remote AS 45000, external link',
    'BGP neighbor is 192.0.2.1,  remote AS 4200000000, external link',
    'BGP neighbor is 203.0.113.1,  remote AS 65000.123, external link',
    '    Route-Reflector Client   ',
    '  Last read 00:00:39, last write 00:00:00, hold time is 180, keepalive interval is 60 seconds',
    '  Last read 00:00:28, hold time = 90, keepalive interval = 30 seconds',
    '  Last written 00:00:28, keepalive timer expiry due 00:00:31',
    ' NEXT_HOP is always this router for eBGP paths',
    '    NEXT_HOP   is  always   this router  for   eBGP   paths   '
) -join ([char]10)
$neighborRemoteValueMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpNeighborTranscript,
    $bgpNeighborRuleSpecs[0].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $neighborRemoteValueMatches.Count -Expected 4 -Message 'Neighbor remote-AS value rule matches 2-byte, dotted-AS, and 4-byte ASN forms'
Assert-True -Condition (($neighborRemoteValueMatches | ForEach-Object { $_.Value }) -contains 'BGP neighbor is 192.0.2.1,  remote AS 4200000000') -Message 'Neighbor remote-AS value rule matches a four-byte ASN'
$neighborRemoteTitleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $bgpNeighborTranscript,
    $bgpNeighborRuleSpecs[1].Pattern,
    $bgpTranscriptOptions
)
Assert-Equal -Actual $neighborRemoteTitleMatches.Count -Expected 3 -Message 'Neighbor remote-AS title rule matches single and double-space Cisco variants'
Assert-True -Condition (($neighborRemoteTitleMatches | ForEach-Object { $_.Value }) -notcontains 'BGP neighbor is 1.1.1.1,  remote AS 2') -Message 'Neighbor remote-AS title rule stops before the ASN value'
$remotePhraseMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborStatusRuleSpecs[0].Pattern, $bgpTranscriptOptions)
$internalLinkMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborStatusRuleSpecs[1].Pattern, $bgpTranscriptOptions)
$externalLinkMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborStatusRuleSpecs[2].Pattern, $bgpTranscriptOptions)
$routeReflectorClientMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborStatusRuleSpecs[3].Pattern, $bgpTranscriptOptions)
Assert-Equal -Actual $remotePhraseMatches.Count -Expected 4 -Message 'Remote-AS value phrase matches all numeric ASN forms'
Assert-True -Condition (($remotePhraseMatches | ForEach-Object { $_.Value }) -contains 'remote AS 4200000000') -Message 'Remote-AS value phrase matches a four-byte ASN without consuming the neighbor prefix'
Assert-True -Condition (($remotePhraseMatches | ForEach-Object { $_.Value }) -contains 'remote AS 65000.123') -Message 'Remote-AS value phrase matches dotted-AS notation'
Assert-Equal -Actual $internalLinkMatches.Count -Expected 1 -Message 'internal link rule matches the Cisco iBGP neighbor line'
Assert-Equal -Actual $externalLinkMatches.Count -Expected 3 -Message 'external link rule matches Cisco eBGP neighbor lines with 2-byte, dotted-AS, and 4-byte ASNs'
Assert-Equal -Actual $routeReflectorClientMatches.Count -Expected 1 -Message 'Route-Reflector Client rule matches the indented IPv4-unicast detail line'
Assert-True -Condition (($internalLinkMatches | ForEach-Object { $_.Value }) -contains ',  internal link') -Message 'internal link rule matches the Cisco iBGP screenshot form with its neighbor-line delimiter'
Assert-True -Condition (($externalLinkMatches | ForEach-Object { $_.Value }) -contains ',  external link') -Message 'external link rule matches the Cisco eBGP screenshot form with its neighbor-line delimiter'
Assert-True -Condition (($routeReflectorClientMatches | ForEach-Object { $_.Value }) -contains '    Route-Reflector Client   ') -Message 'Route-Reflector Client rule preserves indentation and trailing spaces'
$lastReadMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[2].Pattern, $bgpTranscriptOptions)
$lastWriteMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[4].Pattern, $bgpTranscriptOptions)
$lastWriteTitleMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[5].Pattern, $bgpTranscriptOptions)
$lastWrittenValueMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[6].Pattern, $bgpTranscriptOptions)
$lastWrittenTitleMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[7].Pattern, $bgpTranscriptOptions)
Assert-Equal -Actual $lastReadMatches.Count -Expected 2 -Message 'Last read value rule matches IOS timer lines'
Assert-Equal -Actual $lastWriteMatches.Count -Expected 1 -Message 'last write value rule matches the lowercase Cisco variant'
Assert-Equal -Actual $lastWriteTitleMatches.Count -Expected 1 -Message 'last write title rule matches the lowercase Cisco variant'
Assert-Equal -Actual $lastWrittenValueMatches.Count -Expected 1 -Message 'Last written value rule matches the alternate Cisco wording'
Assert-Equal -Actual $lastWrittenTitleMatches.Count -Expected 1 -Message 'Last written title rule matches the alternate Cisco wording'
$holdValueMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[8].Pattern, $bgpTranscriptOptions)
$holdTitleMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[9].Pattern, $bgpTranscriptOptions)
$keepaliveValueMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[10].Pattern, $bgpTranscriptOptions)
$keepaliveTitleMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[11].Pattern, $bgpTranscriptOptions)
$nextHopMatches = [System.Text.RegularExpressions.Regex]::Matches($bgpNeighborTranscript, $bgpNeighborRuleSpecs[12].Pattern, $bgpTranscriptOptions)
Assert-Equal -Actual $holdValueMatches.Count -Expected 2 -Message 'hold-time value rule matches is and equals IOS variants'
Assert-Equal -Actual $holdTitleMatches.Count -Expected 2 -Message 'hold-time title rule matches is and equals IOS variants'
Assert-Equal -Actual $keepaliveValueMatches.Count -Expected 2 -Message 'keepalive value rule matches interval is/equals and seconds'
Assert-Equal -Actual $keepaliveTitleMatches.Count -Expected 2 -Message 'keepalive title rule matches interval is/equals variants'
Assert-True -Condition (($keepaliveValueMatches | ForEach-Object { $_.Value }) -contains 'keepalive interval is 60 seconds') -Message 'keepalive value rule includes the seconds phrase and numeric value'
Assert-Equal -Actual $nextHopMatches.Count -Expected 2 -Message 'NEXT_HOP rule matches leading and multiple-space Cisco variants'
Assert-True -Condition (($nextHopMatches | ForEach-Object { $_.Value }) -contains ' NEXT_HOP is always this router for eBGP paths') -Message 'NEXT_HOP rule matches the official Cisco phrase'
Assert-True -Condition (($nextHopMatches | ForEach-Object { $_.Value }) -contains '    NEXT_HOP   is  always   this router  for   eBGP   paths   ') -Message 'NEXT_HOP rule consumes the complete phrase with trailing spaces'
$stateTranscriptLines = foreach ($stateLabel in @('state', 'State', 'STATE')) {
    foreach ($stateRule in $stateRuleSpecs) {
        foreach ($state in $stateRule.States) {
            "  $stateLabel = $state"
        }
    }
}
$stateTranscript = $stateTranscriptLines -join ([char]10)
$stateMatches = @()
foreach ($stateRule in $stateRuleSpecs) {
    $matchesForRule = [System.Text.RegularExpressions.Regex]::Matches($stateTranscript, $stateRule.Pattern, $bgpTranscriptOptions)
    Assert-Equal -Actual $matchesForRule.Count -Expected ($stateRule.States.Count * 3) -Message 'state=value rule matches every uppercase, Title, and lowercase state form'
    $stateMatches += @($matchesForRule)
}
Assert-Equal -Actual $stateMatches.Count -Expected ($stateRuleSpecs | ForEach-Object { $_.States.Count * 3 } | Measure-Object -Sum).Sum -Message 'all four state rules match every expected state form'
foreach ($stateRule in $stateRuleSpecs) {
    foreach ($state in $stateRule.States) {
        foreach ($stateLabel in @('state', 'State', 'STATE')) {
            $sample = "  $stateLabel = $state"
            $matchingRuleCount = @($stateRuleSpecs | Where-Object {
                [System.Text.RegularExpressions.Regex]::IsMatch($sample, $_.Pattern, [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
            }).Count
            Assert-Equal -Actual $matchingRuleCount -Expected 1 -Message "state=value rules must match exactly one group for $sample"
        }
    }
}
foreach ($falseNeighborSample in @(
        'Neighbor 1.1.1.1, remote AS 2',
        'BGP neighbor is 1.1.1.1, remote AS unknown, internal link',
        'Last read never',
        'last write 00:00',
        'hold time is many',
        'keepalive interval is 60 sec'
    )) {
    foreach ($neighborRule in $bgpNeighborRuleSpecs[0,2,4,6,8,10]) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $falseNeighborSample,
                $neighborRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Neighbor value rule rejects malformed or incomplete output: $falseNeighborSample"
    }
}
foreach ($falseLinkSample in @(
        'internal link',
        'external link',
        'internal links',
        'external links',
        'BGP neighbor is 1.1.1.1, remote AS 2, internal link state',
        'BGP neighbor is 1.1.1.1, remote AS 2, external link state'
    )) {
    foreach ($statusRule in $bgpNeighborStatusRuleSpecs[1, 2]) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $falseLinkSample,
                $statusRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "$($statusRule.Name) rule rejects malformed link output: $falseLinkSample"
    }
}
foreach ($falseRouteReflectorSample in @(
        'Route-Reflector Clients',
        'Neighbor Route-Reflector Client',
        'Route-Reflector Client enabled'
    )) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $falseRouteReflectorSample,
            $bgpNeighborStatusRuleSpecs[3].Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Route-Reflector Client rule rejects malformed or non-detail output: $falseRouteReflectorSample"
}
foreach ($falseRemoteSample in @(
        'BGP neighbor is 1.1.1.1, remote AS unknown, internal link',
        'BGP neighbor is 1.1.1.1, remote AS 2.3.4, internal link',
        'BGP neighbor is 1.1.1.1, remote AS 12345678901, internal link'
    )) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $falseRemoteSample,
            $bgpNeighborStatusRuleSpecs[0].Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "Remote-AS value phrase rejects malformed ASN output: $falseRemoteSample"
}
Assert-True -Condition (-not ($stateRuleSpecs | Where-Object {
        [System.Text.RegularExpressions.Regex]::IsMatch('state = UNKNOWN', $_.Pattern, [System.Text.RegularExpressions.RegexOptions]::CultureInvariant)
    })) -Message 'state=value rules reject unknown states'
foreach ($falseNextHopSample in @(
        ' NEXT_HOP is always this router for eBGP',
        ' NEXT_hop is always this router for eBGP paths'
    )) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $falseNextHopSample,
            $bgpNeighborRuleSpecs[12].Pattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "NEXT_HOP rule rejects incomplete or case-mismatched output: $falseNextHopSample"
}
Write-Host '[PASS] BGP neighbor remote-AS, read/write, hold-time, keepalive, state=value, and NEXT_HOP rules match IOS variants without malformed values'

$interfaceAclSectionText = Get-IniSectionText -Lines $lines -SectionName 'IP_INTERFACE_ACL_BINDINGS'
$interfaceAclV3SectionText = Get-IniSectionText -Lines $v3Lines -SectionName 'IP_INTERFACE_ACL_BINDINGS'
$interfaceAclRuleSpecs = @(
    @{ Name = 'IP interface ACL bindings header'; Pattern = '[*]IP_INTERFACE_ACL_BINDINGS'; Color = '00FFFFFF' },
    @{ Name = 'ACL binding not-set state'; Pattern = '^\x20*(?:Inbound|Outgoing)\x20+access\x20+list\x20+is\x20+not\x20+set\x20*$'; Color = '00C0C0C0' },
    @{ Name = 'ACL binding applied value'; Pattern = '^\x20*(?:Inbound|Outgoing)\x20+access\x20+list\x20+is\x20+(?:permit\x20+Any|[0-9]+|[A-Za-z0-9_.:/-]+)\x20*$'; Color = '00EE82EE' }
)
$interfaceAclV2Rows = @($interfaceAclSectionText -split [Environment]::NewLine | Where-Object { $_ -match '^\s+"' })
$interfaceAclV3Rows = @($interfaceAclV3SectionText -split [Environment]::NewLine | Where-Object { $_ -match '^\s+"' })
Assert-Equal -Actual $interfaceAclV2Rows.Count -Expected 3 -Message 'IP interface ACL bindings V2 section must contain exactly its header and two behavior rules'
Assert-Equal -Actual $interfaceAclV3Rows.Count -Expected 3 -Message 'IP interface ACL bindings V3 section must contain exactly its header and two behavior rules'
Assert-True -Condition (-not $interfaceAclSectionText.Contains('\s')) -Message 'IP interface ACL binding rules must use SecureCRT literal-space syntax instead of \s'
Assert-True -Condition (-not $interfaceAclV3SectionText.Contains('\s')) -Message 'V3 IP interface ACL binding rules must use SecureCRT literal-space syntax instead of \s'
foreach ($interfaceAclRule in $interfaceAclRuleSpecs) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($interfaceAclRule.Pattern)
    $v2RulePattern = '^\s*"' + $escapedPattern + '\",' + $interfaceAclRule.Color + ',00000001\s*$'
    $v3RulePattern = '^\s*"' + $escapedPattern + '\",' + $interfaceAclRule.Color + ',00000001,00000001\s*$'
    $v2RuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $interfaceAclSectionText,
        $v2RulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    $v3RuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $interfaceAclV3SectionText,
        $v3RulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $v2RuleMatches.Count -Expected 1 -Message "V2 $($interfaceAclRule.Name) has exact pattern and color"
    Assert-Equal -Actual $v3RuleMatches.Count -Expected 1 -Message "V3 $($interfaceAclRule.Name) has exact pattern and color"
}
for ($interfaceAclRowIndex = 0; $interfaceAclRowIndex -lt $interfaceAclV2Rows.Count; $interfaceAclRowIndex++) {
    Assert-Equal -Actual $interfaceAclV3Rows[$interfaceAclRowIndex] -Expected ($interfaceAclV2Rows[$interfaceAclRowIndex] + ',00000001') -Message "V3 IP interface ACL binding row $interfaceAclRowIndex must preserve the V2 row and append only its fourth field"
}

$interfaceAclNotSetPattern = $interfaceAclRuleSpecs[1].Pattern
$interfaceAclAppliedPattern = $interfaceAclRuleSpecs[2].Pattern
foreach ($sample in @(
        'Inbound access list is not set',
        'Outgoing  access list is not set',
        '  Inbound    access list   is   not   set  '
    )) {
    Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $interfaceAclNotSetPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "ACL not-set rule matches exact Cisco output with permitted spacing: $sample"
}
foreach ($sample in @(
        'Inbound access list is 102',
        'Outgoing access list is simple-ip_acl.name/zone:1',
        'Outgoing  access list is permit   Any'
    )) {
    Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $interfaceAclAppliedPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "ACL applied-value rule matches numeric, named, and legacy permit-Any output: $sample"
}
foreach ($sample in @(
        'Inbound access-list is 102',
        'This is unrelated text',
        'Inbound access list is not set',
        'Outgoing access list is simple ip'
    )) {
    Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $interfaceAclAppliedPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "ACL applied-value rule rejects malformed or non-applied output: $sample"
}
Write-Host '[PASS] IP interface ACL bindings match inbound/outgoing not-set, numeric/named ACLs, and permit Any without false positives'

$showAccessListsSectionText = Get-IniSectionText -Lines $lines -SectionName 'SHOW_ACCESS_LISTS'
$showAccessListsV3SectionText = Get-IniSectionText -Lines $v3Lines -SectionName 'SHOW_ACCESS_LISTS'
$showAccessListsRuleSpecs = @(
    @{ Name = 'show access-lists header'; Pattern = '^\x20*(?:(?:Standard|Extended)\x20+IP|IPv[46]|IP)\x20+access\x20+list\x20+[A-Za-z0-9_.:/-]+\x20*$'; Color = '00FFFFFF' },
    @{ Name = 'show access-lists permit entry'; Pattern = '^\x20*(?:[0-9]+\x20+)?permit\b.*$'; Color = '0032CD32' },
    @{ Name = 'show access-lists deny entry'; Pattern = '^\x20*(?:[0-9]+\x20+)?deny\b.*$'; Color = '000000FF' },
    @{ Name = 'show access-lists remark entry'; Pattern = '^\x20*(?:[0-9]+\x20+)?remark\b.*$'; Color = '00C0C0C0' }
)
$showAccessListsV2Rows = @($showAccessListsSectionText -split [Environment]::NewLine | Where-Object { $_ -match '^\s+"' })
$showAccessListsV3Rows = @($showAccessListsV3SectionText -split [Environment]::NewLine | Where-Object { $_ -match '^\s+"' })
Assert-Equal -Actual $showAccessListsV2Rows.Count -Expected 5 -Message 'show access-lists V2 section must contain its header and four rules'
Assert-Equal -Actual $showAccessListsV3Rows.Count -Expected 5 -Message 'show access-lists V3 section must contain its header and four rules'
Assert-True -Condition (-not $showAccessListsSectionText.Contains('\s')) -Message 'show access-lists rules must use SecureCRT literal-space syntax instead of \s'
Assert-True -Condition (-not $showAccessListsV3SectionText.Contains('\s')) -Message 'V3 show access-lists rules must use SecureCRT literal-space syntax instead of \s'
foreach ($showAccessListsRule in $showAccessListsRuleSpecs) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($showAccessListsRule.Pattern)
    $v2RulePattern = '^\s*"' + $escapedPattern + '\",' + $showAccessListsRule.Color + ',00000001\s*$'
    $v3RulePattern = '^\s*"' + $escapedPattern + '\",' + $showAccessListsRule.Color + ',00000001,00000001\s*$'
    $v2RuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $showAccessListsSectionText,
        $v2RulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    $v3RuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $showAccessListsV3SectionText,
        $v3RulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $v2RuleMatches.Count -Expected 1 -Message "V2 $($showAccessListsRule.Name) has exact pattern and color"
    Assert-Equal -Actual $v3RuleMatches.Count -Expected 1 -Message "V3 $($showAccessListsRule.Name) has exact pattern and color"
}
for ($showAccessListsRowIndex = 0; $showAccessListsRowIndex -lt $showAccessListsV2Rows.Count; $showAccessListsRowIndex++) {
    Assert-Equal -Actual $showAccessListsV3Rows[$showAccessListsRowIndex] -Expected ($showAccessListsV2Rows[$showAccessListsRowIndex] + ',00000001') -Message "V3 show access-lists row $showAccessListsRowIndex must preserve the V2 row and append only its fourth field"
}

$showAccessListsHeaderPattern = $showAccessListsRuleSpecs[0].Pattern
$showAccessListsPermitPattern = $showAccessListsRuleSpecs[1].Pattern
$showAccessListsDenyPattern = $showAccessListsRuleSpecs[2].Pattern
$showAccessListsRemarkPattern = $showAccessListsRuleSpecs[3].Pattern
foreach ($sample in @(
        'Standard IP access list 2',
        'Extended IP access list WEB-FILTER',
        'IPv4 access list ACL_V4',
        'IPv6 access list V6-ACL',
        'IP access list CAMPUS-IN'
    )) {
    Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $showAccessListsHeaderPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "show access-lists header rule matches IOS header output: $sample"
}
foreach ($sample in @(
        '    10 permit 172.16.1.0, wildcard bits 0.0.0.255',
        '10 permit ip any any',
        'permit tcp any any eq bgp (8 matches) sequence 10'
    )) {
    Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $showAccessListsPermitPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "show access-lists permit rule matches IOS ACE output: $sample"
}
foreach ($sample in @(
        '    20 deny ip any any',
        '20 deny tcp any any eq telnet (15 matches)'
    )) {
    Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
            $sample,
            $showAccessListsDenyPattern,
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) -Message "show access-lists deny rule matches IOS ACE output: $sample"
}
Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
        '    30 remark management access',
        $showAccessListsRemarkPattern,
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )) -Message 'show access-lists remark rule matches IOS remark output'
foreach ($sample in @(
        'Standard IP access-list 2',
        'access-list 101 permit ip any any',
        '    10 permitted ip any any',
        '    20 denyed ip any any',
        'Extended IP access list'
    )) {
    foreach ($pattern in @(
            $showAccessListsHeaderPattern,
            $showAccessListsPermitPattern,
            $showAccessListsDenyPattern,
            $showAccessListsRemarkPattern
        )) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "show access-lists rules reject malformed or unrelated output: $sample"
    }
}
Write-Host '[PASS] show access-lists headers and permit/deny/remark entries match IOS output without false positives'
