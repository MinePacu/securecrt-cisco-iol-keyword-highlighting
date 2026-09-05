$ErrorActionPreference = 'Stop'
$samples = @(Get-Content (Join-Path $PSScriptRoot 'fixtures/NatProbe2.txt'))
$colors = @('00B469FF','0000D7FF','00FFFF00','00FACE87','00EE82EE')
foreach ($mode in @('Position','Suffix')) {
    $lines = @(Get-Content (Join-Path $PSScriptRoot "NAT-Probe3-$mode.ini"))
    $rules = @($lines | ForEach-Object {
        if ($_ -match '^ "([^"]+)",([A-F0-9]{8}),') {
            [pscustomobject]@{Pattern=$Matches[1]; Color=$Matches[2]; Regex=[regex]::new($Matches[1])}
        }
    })
    $declared = ($lines | Where-Object { $_ -like 'Z:*' }) -split '='
    if ([Convert]::ToInt32($declared[1],16) -ne $rules.Count) { throw 'Incorrect count' }
    foreach ($rule in $rules[7..($rules.Count-1)]) {
        if ($rule.Pattern -match 'DEFINE|\\K|\(\?&' -or $rule.Pattern.Length -gt 256) { throw 'Unexpected complexity' }
        if ($mode -eq 'Position' -and $rule.Pattern.Contains('(?=')) { throw 'Position must not use positive lookahead' }
        if ($mode -eq 'Suffix' -and $rule.Pattern.Contains('(?<')) { throw 'Suffix must not use lookbehind' }
    }
    $checked=0
    foreach ($n in 0..4) {
        $text=$samples[$n]
        $tokens=if($n -eq 0){[regex]::Matches($text,'Pro|Inside global|Inside local|Outside local|Outside global')}else{[regex]::Matches($text,'\S+')}
        $expected=@{}
        for($c=0;$c -lt 5;$c++) {
            $color=if($tokens[$c].Value -eq '---'){'00C0C0C0'}elseif($n -eq 0 -and $c -eq 0){'000000FF'}else{$colors[$c]}
            $expected[$tokens[$c].Index]=@($tokens[$c].Value,$color)
        }
        for($p=0;$p -lt $text.Length;) {
            $hit=$null
            foreach($r in $rules) {
                $m=$r.Regex.Match($text,$p)
                if($m.Success -and $m.Index -eq $p){$hit=$m; $color=$r.Color; break}
            }
            if($null -eq $hit){if($expected.ContainsKey($p)){throw "Missing $mode token at $n/$p"};$p++;continue}
            $want=$expected[$p]
            if($null -eq $want -or $hit.Value -cne $want[0] -or $color -cne $want[1]){throw "Wrong $mode span at $n/$p"}
            $p+=$hit.Length;$checked++
        }
    }
    Write-Host "[PASS] $mode : $checked spans/colors in retained-context .NET scan; rule isolation and INI counts"
}
Write-Host '[PENDING] Native SecureCRT screenshots for both lists. These are diagnostic-only, not production-safe rules.'
