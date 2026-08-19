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

$iniPath = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $PSScriptRoot '..') 'PNET-Cisco-Dark.ini'))
$iniText = [System.IO.File]::ReadAllText($iniPath)
$lines = $iniText -split '\r?\n'

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
Write-Host '[PASS] SecureCRT keyword list metadata includes every keyword rule'

$regexLineModeMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $iniText,
    '(?m)^\s*D:"Regex Line Mode"=([01]{8})\s*$',
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-Equal -Actual $regexLineModeMatches.Count -Expected 1 -Message 'keyword list must explicitly configure Regex Line Mode once'
Assert-Equal -Actual $regexLineModeMatches[0].Groups[1].Value -Expected '00000001' -Message 'Regex Line Mode must be enabled for line-anchored prompt rules'
Write-Host '[PASS] SecureCRT regex line mode is enabled for line-anchored prompt rules'
$sectionStart = -1
$sectionEnd = $lines.Count

for ($index = 0; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]OSPF_PROCESS_AREA_AND_IDS",',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $sectionStart = $index
        break
    }
}

Assert-True -Condition ($sectionStart -ge 0) -Message 'OSPF_PROCESS_AREA_AND_IDS section must exist'

for ($index = $sectionStart + 1; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $sectionEnd = $index
        break
    }
}

$sectionLines = $lines[$sectionStart..($sectionEnd - 1)]
$sectionText = [string]::Join([System.Environment]::NewLine, $sectionLines)
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
) -join [Environment]::NewLine
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

$costSectionStart = -1
$costSectionEnd = $lines.Count

for ($index = 0; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]OSPF_COST_METRIC_REFERENCE_BW",',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $costSectionStart = $index
        break
    }
}

Assert-True -Condition ($costSectionStart -ge 0) -Message 'OSPF_COST_METRIC_REFERENCE_BW section must exist'

for ($index = $costSectionStart + 1; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $costSectionEnd = $index
        break
    }
}

$costSectionLines = $lines[$costSectionStart..($costSectionEnd - 1)]
$costSectionText = [string]::Join([System.Environment]::NewLine, $costSectionLines)
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
) -join [Environment]::NewLine
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

$networkSectionStart = -1
$networkSectionEnd = $lines.Count

for ($index = 0; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]OSPF_NETWORK_TYPE_AND_DR_BDR",',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $networkSectionStart = $index
        break
    }
}

Assert-True -Condition ($networkSectionStart -ge 0) -Message 'OSPF_NETWORK_TYPE_AND_DR_BDR section must exist'

for ($index = $networkSectionStart + 1; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $networkSectionEnd = $index
        break
    }
}

$networkSectionLines = $lines[$networkSectionStart..($networkSectionEnd - 1)]
$networkSectionText = [string]::Join([System.Environment]::NewLine, $networkSectionLines)
$networkTranscript = @(
    '  Network Type BROADCAST',
    '  Network Type POINT_TO_POINT',
    '  Network Type NON_BROADCAST',
    '  Network Type POINT_TO_MULTIPOINT',
    '  Network Type LOOPBACK',
    '  Network Type NBMA',
    '  State POINT_TO_POINT'
) -join [Environment]::NewLine
$networkPhraseRules = @(
    @{ Pattern = '\bNetwork\x20+Type\x20+BROADCAST\b'; Color = '00FFFF00'; Matches = @('Network Type BROADCAST') },
    @{ Pattern = '\bNetwork\x20+Type\x20+POINT_TO_POINT\b'; Color = '00FFFF00'; Matches = @('Network Type POINT_TO_POINT') },
    @{ Pattern = '\bNetwork\x20+Type\x20+NON_BROADCAST\b'; Color = '0000A5FF'; Matches = @('Network Type NON_BROADCAST') },
    @{ Pattern = '\bNetwork\x20+Type\x20+POINT_TO_MULTIPOINT\b'; Color = '00FFFF00'; Matches = @('Network Type POINT_TO_MULTIPOINT') },
    @{ Pattern = '\bNetwork\x20+Type\x20+LOOPBACK\b'; Color = '00FACE87'; Matches = @('Network Type LOOPBACK') },
    @{ Pattern = '\bNetwork\x20+Type\x20+NBMA\b'; Color = '0000A5FF'; Matches = @('Network Type NBMA') },
    @{ Pattern = '\bState\x20+POINT_TO_POINT\b'; Color = '00FFFF00'; Matches = @('State POINT_TO_POINT') }
)
$networkCommandPattern = '\bip\x20+ospf\x20+network\x20+(?:broadcast|point-to-point|non-broadcast|point-to-multipoint)\b'
Assert-True -Condition (-not $networkSectionText.Contains('\s')) -Message 'OSPF network section must use SecureCRT literal-space syntax instead of \s'
Assert-True -Condition (-not $networkCommandPattern.Contains('\s')) -Message 'ip ospf network rule must use SecureCRT literal-space syntax'
$networkCommandRulePattern = '^\s*"' + [System.Text.RegularExpressions.Regex]::Escape($networkCommandPattern) + '",00FFFF00,00000001\s*$'
$networkCommandRuleMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $networkSectionText,
    $networkCommandRulePattern,
    [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
)
Assert-Equal -Actual $networkCommandRuleMatches.Count -Expected 1 -Message 'ip ospf network rule has exact yellow color'
Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
        'ip ospf network point-to-point',
        $networkCommandPattern,
        [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )) -Message 'ip ospf network rule matches command output with literal spaces'
foreach ($networkPhraseRule in $networkPhraseRules) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($networkPhraseRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $networkPhraseRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $networkSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "Network phrase has exact color: $($networkPhraseRule.Pattern)"
    Assert-True -Condition (-not $networkPhraseRule.Pattern.Contains('\s')) -Message "Network phrase must use SecureCRT literal-space syntax: $($networkPhraseRule.Pattern)"
    foreach ($sample in $networkPhraseRule.Matches) {
        Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $networkPhraseRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Network phrase matches screenshot output: $sample"
    }
    $phraseTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $networkTranscript,
        $networkPhraseRule.Pattern,
        $transcriptOptions
    )
    Assert-Equal -Actual $phraseTranscriptMatches.Count -Expected 1 -Message "Network phrase matches full screenshot transcript: $($networkPhraseRule.Pattern)"
}
$networkRules = @(
    @{ Pattern = '\bBROADCAST\b'; Color = '00FFFF00'; Matches = @('Network Type BROADCAST'); ExpectedCount = 1 },
    @{ Pattern = '\bPOINT_TO_POINT\b'; Color = '00FFFF00'; Matches = @('Network Type POINT_TO_POINT', 'State POINT_TO_POINT'); ExpectedCount = 2 },
    @{ Pattern = '\bNON_BROADCAST\b'; Color = '0000A5FF'; Matches = @('Network Type NON_BROADCAST'); ExpectedCount = 1 },
    @{ Pattern = '\bPOINT_TO_MULTIPOINT\b'; Color = '00FFFF00'; Matches = @('Network Type POINT_TO_MULTIPOINT'); ExpectedCount = 1 },
    @{ Pattern = '\bLOOPBACK\b'; Color = '00FACE87'; Matches = @('Network Type LOOPBACK'); ExpectedCount = 1 },
    @{ Pattern = '\bNBMA\b'; Color = '0000A5FF'; Matches = @('Network Type NBMA'); ExpectedCount = 1 }
)

foreach ($networkRule in $networkRules) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($networkRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $networkRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $networkSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "Network type token has exact color: $($networkRule.Pattern)"

    foreach ($sample in $networkRule.Matches) {
        Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $networkRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Network type token matches screenshot output: $sample"
    }

    $networkTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $networkTranscript,
        $networkRule.Pattern,
        $transcriptOptions
    )
    Assert-Equal -Actual $networkTranscriptMatches.Count -Expected $networkRule.ExpectedCount -Message "Network type token matches expected screenshot transcript count: $($networkRule.Pattern)"
    foreach ($sample in @("prefix$($networkRule.Pattern -replace '\\b', '')", "$($networkRule.Pattern -replace '\\b', '')suffix")) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $networkRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Network type token respects word boundaries: $($networkRule.Pattern)"
    }
}

Write-Host '[PASS] OSPF network type tokens match screenshot transcript without multi-word whitespace rules'

$promptSectionStart = -1
$promptSectionEnd = $lines.Count

for ($index = 0; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]PROMPTS",',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $promptSectionStart = $index
        break
    }
}

Assert-True -Condition ($promptSectionStart -ge 0) -Message 'PROMPTS section must exist'

for ($index = $promptSectionStart + 1; $index -lt $lines.Count; $index++) {
    if ([System.Text.RegularExpressions.Regex]::IsMatch(
            $lines[$index],
            '^\s*"\[\*\]',
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
        )) {
        $promptSectionEnd = $index
        break
    }
}

$promptSectionLines = $lines[$promptSectionStart..($promptSectionEnd - 1)]
$promptSectionText = [string]::Join([System.Environment]::NewLine, $promptSectionLines)
$promptRules = @(
    @{
        Pattern = '^[A-Za-z0-9_.:/-]+\(config(?:-[^)]+)?\)#'
        Color = '0000FFFF'
        Matches = @(
            'Router(config)#',
            'Router(config-if)#',
            'RP/0/RP0/CPU0:router(config)#',
            'RP/0/RP0/CPU0:router(config-if)#'
        )
        Rejects = @('  Router(config)#', 'show ip route #')
    },
    @{
        Pattern = '^[A-Za-z0-9_.:/-]+#'
        Color = '00FFFF00'
        Matches = @('Router#', 'RP/0/RP0/CPU0:router#')
        Rejects = @('  Router#', 'show ip route #')
    },
    @{
        Pattern = '^[A-Za-z0-9_.:/-]+>'
        Color = '00C0C0C0'
        Matches = @('Router>', 'RP/0/RP0/CPU0:router>')
        Rejects = @('  Router>', 'show ip route >')
    }
)

foreach ($promptRule in $promptRules) {
    $escapedPattern = [System.Text.RegularExpressions.Regex]::Escape($promptRule.Pattern)
    $rulePattern = '^\s*"' + $escapedPattern + '",' + $promptRule.Color + ',00000001\s*$'
    $ruleMatches = [System.Text.RegularExpressions.Regex]::Matches(
        $promptSectionText,
        $rulePattern,
        [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
            [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    )
    Assert-Equal -Actual $ruleMatches.Count -Expected 1 -Message "Prompt rule has exact pattern and color: $($promptRule.Pattern)"

    foreach ($sample in $promptRule.Matches) {
        Assert-True -Condition ([System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $promptRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Prompt rule matches Cisco CLI prompt: $sample"
    }

    foreach ($sample in $promptRule.Rejects) {
        Assert-True -Condition (-not [System.Text.RegularExpressions.Regex]::IsMatch(
                $sample,
                $promptRule.Pattern,
                [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
            )) -Message "Prompt rule rejects non-prompt output: $sample"
    }
}

$promptTranscript = @(
    'R2#conf t',
    'Enter configuration commands, one per line.',
    'R2(config)#end',
    'R2#conf t',
    'Enter configuration commands, one per line.',
    'R2(config)#router ospf 1',
    'R2(config-router)#',
    'R9#',
    'R9(config)#',
    'R9(config-router)#end',
    'RP/0/RP0/CPU0:router#show version',
    'RP/0/RP0/CPU0:router(config-if)#'
) -join [Environment]::NewLine
$lineModeOptions = [System.Text.RegularExpressions.RegexOptions]::Multiline -bor
    [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
$configTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $promptTranscript,
    $promptRules[0].Pattern,
    $lineModeOptions
)
$privilegedTranscriptMatches = [System.Text.RegularExpressions.Regex]::Matches(
    $promptTranscript,
    $promptRules[1].Pattern,
    $lineModeOptions
)
Assert-Equal -Actual $configTranscriptMatches.Count -Expected 6 -Message 'config prompt rule must match each prompt prefix in a multi-line terminal transcript'
Assert-Equal -Actual $privilegedTranscriptMatches.Count -Expected 4 -Message 'privileged prompt rule must match each prompt prefix in a multi-line terminal transcript'
Assert-Equal -Actual $configTranscriptMatches[2].Value -Expected 'R2(config-router)#' -Message 'config prompt rule must match nested configuration mode'
Assert-Equal -Actual $configTranscriptMatches[4].Value -Expected 'R9(config-router)#' -Message 'config prompt rule must match nested configuration prompt with trailing command'
Assert-Equal -Actual $privilegedTranscriptMatches[2].Value -Expected 'R9#' -Message 'privileged prompt rule must match standalone R9 prompt'

Write-Host '[PASS] Cisco prompt rules match prompt prefixes across a multi-line transcript'

Write-Host '[PASS] Cisco prompt rules match IOS/XR prompts and reject ordinary output'
