$ErrorActionPreference = 'Stop'

$scriptPath = [System.IO.Path]::GetFullPath((Join-Path (Join-Path $PSScriptRoot '..') 'Install-KeywordHighlight.ps1'))
$tokens = $null
$parseErrors = $null
$scriptAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $scriptPath,
    [ref]$tokens,
    [ref]$parseErrors
)
if ($parseErrors.Count -gt 0) {
    throw "설치 스크립트를 파싱할 수 없습니다: $($parseErrors[0].Message)"
}

# Dot-source only the production functions under test. This avoids executing
# the installer (which performs environment checks and file operations).
foreach ($functionName in @(
        'Set-IniOptions',
        'Get-TextFileInfo',
        'ConvertTo-EncodedBytes',
        'New-TemporaryPath',
        'Copy-FileAtomic',
        'Restore-BackupAtomic'
    )) {
    $functionAst = $scriptAst.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $functionName
        }, $true)
    if ($null -eq $functionAst) {
        throw "테스트할 함수를 찾을 수 없습니다: $functionName"
    }
    . ([scriptblock]::Create($functionAst.Extent.Text))
}

function Assert-True {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-False {
    param(
        [Parameter(Mandatory = $true)][bool]$Condition,
        [Parameter(Mandatory = $true)][string]$Message
    )
    Assert-True -Condition (-not $Condition) -Message $Message
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

function Assert-Contains {
    param(
        [Parameter(Mandatory = $true)][string]$Text,
        [Parameter(Mandatory = $true)][string]$Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )
    Assert-True -Condition $Text.Contains($Expected) -Message "$Message (missing: $Expected)"
}

function Assert-BytesEqual {
    param(
        [Parameter(Mandatory = $true)][byte[]]$Actual,
        [Parameter(Mandatory = $true)][byte[]]$Expected,
        [Parameter(Mandatory = $true)][string]$Message
    )
    Assert-Equal -Actual $Actual.Length -Expected $Expected.Length -Message "$Message length"
    for ($index = 0; $index -lt $Expected.Length; $index++) {
        Assert-Equal -Actual $Actual[$index] -Expected $Expected[$index] -Message "$Message byte $index"
    }
}

function Invoke-Test {
    param(
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][scriptblock]$Body
    )
    try {
        $null = & $Body
        Write-Host "[PASS] $Name"
        return $true
    }
    catch {
        Write-Error "[FAIL] ${Name}: $($_.Exception.Message)"
        return $false
    }
}

$options = @(
    [PSCustomObject]@{ Prefix = 'S'; Name = 'Color Scheme'; Value = 'Birds of Paradise' },
    [PSCustomObject]@{ Prefix = 'D'; Name = 'Use Cursor Color'; Value = '00000001' },
    [PSCustomObject]@{ Prefix = 'D'; Name = 'Cursor Color'; Value = '00FFFFFF' },
    [PSCustomObject]@{ Prefix = 'S'; Name = 'Keyword Set'; Value = 'PNET-Cisco-Dark' },
    [PSCustomObject]@{ Prefix = 'D'; Name = 'Highlight Reverse Video'; Value = '00000000' },
    [PSCustomObject]@{ Prefix = 'D'; Name = 'Highlight Bold'; Value = '00000001' },
    [PSCustomObject]@{ Prefix = 'D'; Name = 'Highlight Color'; Value = '00000001' }
)

$crlfContent = @(
    '# comment: S:"Color Scheme"=comment',
    'S:"Color Scheme"=Old Scheme',
    'D:"Use Cursor Color"=00000000',
    'D:"Cursor Color"=00000000',
    'S:"Keyword Set"=Old Set',
    'D:"Highlight Reverse Video"=00000001',
    'D:"Highlight Bold"=old-one',
    'D:"Highlight Bold"=old-two',
    'B:"Keyword Set"=preserve B value',
    'S:"Not A Target"=preserve this line'
) -join "`r`n"
$crlfContent += "`r`n"

$allPassed = $true
$allPassed = (Invoke-Test -Name 'patches target options and preserves non-target content' -Body {
        $patched = Set-IniOptions -Content $crlfContent -Options $options
        Assert-Contains -Text $patched -Expected 'S:"Color Scheme"=Birds of Paradise' -Message 'Color Scheme should be replaced'
        Assert-Contains -Text $patched -Expected 'D:"Use Cursor Color"=00000001' -Message 'Use Cursor Color should be replaced'
        Assert-Contains -Text $patched -Expected 'D:"Cursor Color"=00FFFFFF' -Message 'Cursor Color should be replaced'
        Assert-Contains -Text $patched -Expected 'S:"Keyword Set"=PNET-Cisco-Dark' -Message 'Keyword Set should be replaced'
        Assert-Contains -Text $patched -Expected 'D:"Highlight Reverse Video"=00000000' -Message 'Highlight Reverse Video should be replaced'
        Assert-Contains -Text $patched -Expected 'B:"Keyword Set"=preserve B value' -Message 'B: value should be preserved'
        Assert-Contains -Text $patched -Expected '# comment: S:"Color Scheme"=comment' -Message 'comment should be preserved'
        Assert-Contains -Text $patched -Expected 'S:"Not A Target"=preserve this line' -Message 'non-target line should be preserved'
        Assert-Contains -Text $patched -Expected 'D:"Highlight Color"=00000001' -Message 'missing option should be appended'
        Assert-True -Condition ($patched.EndsWith("`r`n")) -Message 'CRLF ending should be preserved for appended keys'
        $highlightColorCount = [System.Text.RegularExpressions.Regex]::Matches(
            $patched,
            '(?m)^D:"Highlight Color"=00000001\r?$'
        ).Count
        Assert-Equal -Actual $highlightColorCount -Expected 1 -Message 'missing option should be appended exactly once'
        $boldCount = [System.Text.RegularExpressions.Regex]::Matches(
            $patched,
            '(?m)^D:"Highlight Bold"=00000001\r?$'
        ).Count
        Assert-Equal -Actual $boldCount -Expected 2 -Message 'duplicate target keys should all be replaced'
        return $patched
    }) -and $allPassed

$patchedContent = Set-IniOptions -Content $crlfContent -Options $options
$allPassed = (Invoke-Test -Name 'uses Ordinal change detection and is idempotent' -Body {
        $changed = -not [string]::Equals(
            $crlfContent,
            $patchedContent,
            [System.StringComparison]::Ordinal
        )
        $secondPatch = Set-IniOptions -Content $patchedContent -Options $options
        $unchanged = [string]::Equals(
            $patchedContent,
            $secondPatch,
            [System.StringComparison]::Ordinal
        )
        Assert-True -Condition $changed -Message 'initial patch should be detected as a change'
        Assert-True -Condition $unchanged -Message 'second patch should be byte-for-text idempotent'
        $caseChanged = -not [string]::Equals(
            $patchedContent,
            $patchedContent.ToUpperInvariant(),
            [System.StringComparison]::Ordinal
        )
        Assert-True -Condition $caseChanged -Message 'change detection must use Ordinal comparison'
    }) -and $allPassed

$lfContent = @(
    'S:"Color Scheme"=Birds of Paradise',
    'D:"Use Cursor Color"=00000001',
    'D:"Cursor Color"=00FFFFFF',
    'S:"Keyword Set"=PNET-Cisco-Dark',
    'D:"Highlight Reverse Video"=00000000',
    'D:"Highlight Bold"=00000001',
    'D:"Highlight Color"=00000001'
) -join "`n"
$allPassed = (Invoke-Test -Name 'preserves LF line endings' -Body {
        $patched = Set-IniOptions -Content $lfContent -Options $options
        Assert-Equal -Actual $patched -Expected $lfContent -Message 'already-current LF content should stay unchanged'
        Assert-False -Condition $patched.Contains("`r") -Message 'LF content must not gain CR characters'
    }) -and $allPassed

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ('crt-default-ini-tests-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
try {
    $allPassed = (Invoke-Test -Name 'preserves UTF-8 BOM and UTF-16 encodings' -Body {
            $encodingCases = @(
                [PSCustomObject]@{ Name = 'utf8-bom'; Encoding = [System.Text.UTF8Encoding]::new($true) },
                [PSCustomObject]@{ Name = 'utf16-le'; Encoding = [System.Text.UnicodeEncoding]::new($false, $true) },
                [PSCustomObject]@{ Name = 'utf16-be'; Encoding = [System.Text.UnicodeEncoding]::new($true, $true) }
            )
            foreach ($encodingCase in $encodingCases) {
                $path = Join-Path $tempRoot ($encodingCase.Name + '.ini')
                $bytes = ConvertTo-EncodedBytes -Text $crlfContent -Encoding $encodingCase.Encoding
                [System.IO.File]::WriteAllBytes($path, $bytes)
                $fileInfo = Get-TextFileInfo -Path $path
                Assert-Equal -Actual $fileInfo.Text -Expected $crlfContent -Message "$($encodingCase.Name) text round-trip"
                $roundTripBytes = ConvertTo-EncodedBytes -Text $fileInfo.Text -Encoding $fileInfo.Encoding
                Assert-BytesEqual -Actual $roundTripBytes -Expected $bytes -Message "$($encodingCase.Name) bytes round-trip"
            }
        }) -and $allPassed

    $allPassed = (Invoke-Test -Name 'backs up and restores the original bytes atomically' -Body {
            $destinationPath = Join-Path $tempRoot 'atomic-destination.ini'
            $backupPath = Join-Path $tempRoot 'atomic-destination.ini.bak-test'
            $originalBytes = [byte[]](0x00, 0x01, 0x7F, 0x80, 0xFE, 0xFF)
            $changedBytes = [byte[]](0x43, 0x48, 0x41, 0x4E, 0x47, 0x45, 0x44)

            [System.IO.File]::WriteAllBytes($destinationPath, $originalBytes)
            Copy-FileAtomic -Source $destinationPath -Destination $backupPath
            Assert-True -Condition (Test-Path -LiteralPath $backupPath -PathType Leaf) -Message 'backup should be created'
            Assert-BytesEqual -Actual ([System.IO.File]::ReadAllBytes($backupPath)) -Expected $originalBytes -Message 'backup should preserve original bytes'

            [System.IO.File]::WriteAllBytes($destinationPath, $changedBytes)
            Assert-BytesEqual -Actual ([System.IO.File]::ReadAllBytes($destinationPath)) -Expected $changedBytes -Message 'destination should contain changed bytes before restore'

            Restore-BackupAtomic -BackupPath $backupPath -DestinationPath $destinationPath
            Assert-BytesEqual -Actual ([System.IO.File]::ReadAllBytes($destinationPath)) -Expected $originalBytes -Message 'restore should recover original bytes'
            Assert-False -Condition (Test-Path -LiteralPath $backupPath -PathType Leaf) -Message 'restore should consume the backup'

            $temporaryFiles = @(Get-ChildItem -LiteralPath $tempRoot -Filter '.atomic-destination.ini.tmp-*' -ErrorAction SilentlyContinue)
            Assert-Equal -Actual $temporaryFiles.Count -Expected 0 -Message 'atomic operations should clean temporary files'
        }) -and $allPassed

    $isWindows = $false
    if ($PSVersionTable.PSEdition -eq 'Desktop') {
        $isWindows = $true
    }
    elseif (Get-Variable -Name IsWindows -ErrorAction SilentlyContinue) {
        $isWindows = [bool]$IsWindows
    }

    $allPassed = (Invoke-Test -Name 'integration skips Default.ini backup and write when unchanged' -Body {
            if (-not $isWindows) {
                Write-Host '[SKIP] integration requires Windows PowerShell or pwsh on Windows'
                return
            }

            $configPath = Join-Path $tempRoot 'integration-config'
            $sessionsPath = Join-Path $configPath 'Sessions'
            New-Item -ItemType Directory -Path $sessionsPath -Force | Out-Null
            $defaultPath = Join-Path $sessionsPath 'Default.ini'
            $defaultBytes = ConvertTo-EncodedBytes -Text $lfContent -Encoding ([System.Text.UTF8Encoding]::new($true))
            [System.IO.File]::WriteAllBytes($defaultPath, $defaultBytes)

            $powershellCommand = Get-Command powershell.exe -ErrorAction Stop
            & $powershellCommand.Source -NoProfile -ExecutionPolicy Bypass -File $scriptPath `
                -ConfigPath $configPath -Force -SkipUpdate
            Assert-Equal -Actual $LASTEXITCODE -Expected 0 -Message 'installer should succeed'
            $backupFiles = @(Get-ChildItem -LiteralPath $sessionsPath -Filter 'Default.ini.bak-*' -ErrorAction SilentlyContinue)
            Assert-Equal -Actual $backupFiles.Count -Expected 0 -Message 'unchanged Default.ini must not be backed up'
            Assert-BytesEqual -Actual ([System.IO.File]::ReadAllBytes($defaultPath)) -Expected $defaultBytes -Message 'unchanged Default.ini must not be written'
            Assert-True -Condition (Test-Path -LiteralPath (Join-Path $configPath 'Keywords\PNET-Cisco-Dark.ini') -PathType Leaf) -Message 'keyword installation should still run'
        }) -and $allPassed
}
finally {
    if (Test-Path -LiteralPath $tempRoot -PathType Container) {
        Remove-Item -LiteralPath $tempRoot -Recurse -Force
    }
}

if (-not $allPassed) {
    exit 1
}
