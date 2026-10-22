<#
.SYNOPSIS
    Feature 313 probe: quick search (the new mode of feature 244) ignores diacritics.

.DESCRIPTION
    Each case starts a fresh instance (left panel = a fixture folder, right panel = an empty
    target folder), types into the left panel with synchronous WM_CHAR to its list box and
    observes through the disk, as the feature 244 probe does:
      FOCUS    F5 with nothing selected copies the focused item into the target -> its name
      VISIBLE  Select all (842) + F5 copies the visible items -> their names
    Every case judges what it saw against the expectation of -Expect:
      before  the rule of feature 244 (marks are part of the key)
      after   feature 313 (marks of the Latin / Greek / Cyrillic blocks dropped, a few letters folded)
      off     the option switched off (-FilterOption 0): the 0.1.10 prefix rule, the same before and after
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][ValidateSet('before', 'after', 'off')][string]$Expect,
    [int]$FilterOption = -1,          # -1 = leave the registry value as it is; 0/1 = write 'Quick Search Filter'
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
$Root = $TempRoot + '\tc313'
$RegBackup = $TempRoot + '\tc313_backup.reg'

function S([int[]]$cps) { return -join ($cps | ForEach-Object { [char]::ConvertFromUtf32($_) }) }
# the names of the fixture (NFC unless said otherwise)
$N_Zlutoucky = S @(0x17E, 0x6C, 0x75, 0x165, 0x6F, 0x75, 0x10D, 0x6B, 0xFD)          # zluto-u-c-ky with z-caron, t-caron, c-caron, y-acute (a folder)
$N_Zluty = 'zlut' + (S @(0xFD)) + '.txt'                                               # zlut + y-acute
$N_Cesky = (S @(0x10C)) + 'esk' + (S @(0xFD)) + '.txt'                                  # C-caron + esk + y-acute
$N_Uber = (S @(0xDC)) + 'bersicht.doc'                                                 # U-diaeresis
$N_Lodz = (S @(0x141, 0xF3)) + 'd' + (S @(0x17A)) + '.txt'                              # L-stroke o-acute d z-acute
$N_Strasse = 'Stra' + (S @(0xDF)) + 'e.txt'                                             # sharp s
$N_RekaNfd = ('r' + (S @(0x30C)) + 'eka.txt')                                          # r + combining caron (NFD)
$N_Kana = (S @(0x304C)) + 'kko.txt'                                                    # Hiragana GA (NFD: KA + U+3099) - kept apart from KA
$N_Ka = (S @(0x304B)) + 'kko.txt'                                                      # Hiragana KA
# extra names of single rows (review 313): a distractor sharing a prefix, the oe ligature
$N_Strand = 'Strand.txt'
$N_Coeur = 'c' + (S @(0x153)) + 'ur.txt'
$N_Cat = 'cat.txt'

function Assert-In([string]$p) { if (-not ($p + '\').StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "path outside the fixture: $p" } }
function Clear-Dir([string]$d) {
    Assert-In $d
    if (Test-Path -LiteralPath $d) { Get-ChildItem -LiteralPath $d -Force | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force } }
    else { [void][IO.Directory]::CreateDirectory($d) }
}
function Make-Fixture([string]$Case, [string[]]$Extra = @()) {
    $d = $Root + '\' + $Case
    Assert-In $d
    if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
    $l = $d + '\left'; $r = $d + '\right'
    NewDir ($l + '\' + $N_Zlutoucky); WriteFile ($l + '\' + $N_Zlutoucky + '\inner.txt') 'i'
    NewDir ($l + '\alpha')
    WriteFile ($l + '\beta.md') 'b'
    foreach ($n in @($N_Zluty, $N_Cesky, $N_Uber, $N_Lodz, $N_Strasse, $N_RekaNfd, $N_Kana, $N_Ka) + $Extra) { WriteFile ($l + '\' + $n) 'x' }
    NewDir $r
    return [pscustomobject]@{ Dir = $d; Left = $l; Right = $r }
}
function Names([string]$d) { return @(Get-ChildItem -LiteralPath $d -Force | ForEach-Object { $_.Name } | Sort-Object { $_.Normalize([Text.NormalizationForm]::FormC) }) }
function Show([string[]]$a) { if (-not $a -or $a.Count -eq 0) { return '{}' }; return '{' + ((@($a) | ForEach-Object { Esc $_ }) -join ', ') + '}' }

function Start-Tc313($F) {
    $a = @('-t', 'T313', '-l', ('"{0}"' -f $F.Left), '-r', ('"{0}"' -f $F.Right), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
# types text into the left panel: one synchronous WM_CHAR per UTF-16 unit
function Type-Text([int]$Id, [string]$Text) {
    $l = Get-LeftList $Id
    foreach ($c in $Text.ToCharArray()) { [void][Drv098f]::Send($l, 0x0102, [int]$c, 1, 30000) }
    Start-Sleep -Milliseconds 150
}
function Cmd([int]$Id, [int]$C, [int[]]$Answer = @(1, 6)) {
    Post-Cmd (Get-Main $Id) $C
    Start-Sleep -Milliseconds 300
    $r = Serve $Id 30 $Answer
    if ($r.Fatal) { throw ('FATAL: ' + $r.Fatal) }
    return $r
}
function Copy-Out([int]$Id, $F) {
    Clear-Dir $F.Right
    [void](Cmd $Id 727)
    Start-Sleep -Milliseconds 500
    $n = Names $F.Right
    Clear-Dir $F.Right
    [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 10000)
    return , $n
}
function Visible-Out([int]$Id, $F) { [void](Cmd $Id 842); $n = Copy-Out $Id $F; [void](Cmd $Id 844); return , $n }

# $Exp: hashtable before/after/off (PowerShell names ignore case: no $exp beside it) -> expected names ($null = INFO)
function Judge([string]$Case, [string]$Step, [string[]]$Got, [hashtable]$Exp, [string]$Note = '') {
    $want = $Exp[$Expect]
    $g = Show $Got
    if ($null -eq $want) { Row $Case $Step 'INFO' ("got {0} {1}" -f $g, $Note); return }
    $e = Show ([string[]]$want | Sort-Object { $_.Normalize([Text.NormalizationForm]::FormC) })
    Row $Case $Step (V ($g -ceq $e)) ("got {0} expected {1} {2}" -f $g, $e, $Note)
}

# a case with extra fixture names and keys (virtual-key codes) after the text
function Run-Keys([string]$Case, [string[]]$Extra, [string]$Text, [int[]]$Keys, [string]$Step, [hashtable]$Exp, [string]$Note) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        $F = Make-Fixture $Case $Extra
        $id = Start-Tc313 $F
        Type-Text $id $Text
        foreach ($k in $Keys) { Key $id $k; Start-Sleep -Milliseconds 150 }
        if ($Step -eq 'FOCUS') { $got = Copy-Out $id $F } else { $got = Visible-Out $id $F }
        Judge $Case $Step $got $Exp $Note
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}

function Run-Case([string]$Case, [string]$Text, [string]$Step, [hashtable]$Exp, [string]$Note) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        $F = Make-Fixture $Case
        $id = Start-Tc313 $F
        Type-Text $id $Text
        if ($Step -eq 'FOCUS') { $got = Copy-Out $id $F } else { $got = Visible-Out $id $F }
        Judge $Case $Step $got $Exp $Note
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}

# ---- run ------------------------------------------------------------------------------------
$existed = Backup-Reg $RegBackup
Out ("Feature 313 probe {0}; exe {1}; expect {2}; registry backup {3} (existed {4})" -f $Label, $Exe, $Expect, $RegBackup, $existed)
if ($existed) { Out ('export SHA-256 ' + (Get-FileHash -LiteralPath $RegBackup).Hash) }
try {
    Set-Config
    & reg.exe add "$RegKey\0.1\Configuration" /v 'Quick Search Enter Alt' /t REG_DWORD /d 0 /f | Out-Null
    if ($FilterOption -ge 0) { & reg.exe add "$RegKey\0.1\Configuration" /v 'Quick Search Filter' /t REG_DWORD /d $FilterOption /f | Out-Null }

    $both = @($N_Zlutoucky, $N_Zluty)
    # D01 typed without accents: 'zlut' -> the folder and the file (before: only zlut + y-acute; off: focus on it)
    Run-Case 'D01' 'zlut' 'VISIBLE' @{ before = @($N_Zluty); after = $both; off = $null } "typed 'zlut'"
    # D02 typed with the accent: z-caron + 'lut' -> both too (before: the folder only, 't' refused)
    Run-Case 'D02' ((S @(0x17E)) + 'lut') 'VISIBLE' @{ before = @($N_Zlutoucky); after = $both; off = $null } "typed z-caron 'lut'"
    # D03 'cesky' -> C-caron + esky (before: 'c' finds Ubersicht only)
    Run-Case 'D03' 'cesky' 'VISIBLE' @{ before = @($N_Uber); after = @($N_Cesky); off = $null } "typed 'cesky'"
    # D04 'ubersicht' -> U-diaeresis + bersicht (before: 'u' finds names with a plain u)
    Run-Case 'D04' 'ubersicht' 'VISIBLE' @{ before = $null; after = @($N_Uber); off = $null } "typed 'ubersicht'"
    # D05 'lodz' -> L-stroke (the table) + o-acute + z-acute
    Run-Case 'D05' 'lodz' 'VISIBLE' @{ before = $null; after = @($N_Lodz); off = $null } "typed 'lodz'"
    # D06 'strasse' -> sharp s = ss (the table). Recorded only: without a name sharing the prefix
    # it cannot tell the builds apart (the text sticks at 'stra' before) - D12 can
    Run-Case 'D06' 'strasse' 'VISIBLE' @{ before = @($N_Strasse); after = @($N_Strasse); off = $null } "typed 'strasse'"
    # D07 'reka' -> a name stored decomposed (r + combining caron)
    Run-Case 'D07' 'reka' 'VISIBLE' @{ before = $null; after = @($N_RekaNfd); off = $null } "typed 'reka', NFD name"
    # D08 Hiragana KA + 'kko' -> the KA name only: the voiced mark U+3099 is not dropped
    Run-Case 'D08' ((S @(0x304B)) + 'kko') 'VISIBLE' @{ before = @($N_Ka); after = @($N_Ka); off = $null } "typed KA 'kko'"
    # D09 option off: 'zlut' focuses zlut + y-acute (prefix rule of 0.1.10), the same before and after
    Run-Case 'D09' 'zlut' 'FOCUS' @{ before = $null; after = $null; off = @($N_Zluty) } "typed 'zlut' (option off)"
    # D10 option off: 'cesky' - no name starts with c (C-caron is another letter there); recorded,
    # compared between the builds
    Run-Case 'D10' 'cesky' 'FOCUS' @{ before = $null; after = $null; off = $null } "typed 'cesky' (option off)"
    # D11 Right on a decomposed name: 'r' focuses r + caron + eka.txt (a prefix match); Right appends the
    # character after the whole letter (its mark included), 'e', so only that name stays. Appending the
    # mark instead would leave the text 'r' (the mark is ignored) and three names visible.
    if (Want 'D11') {
        $before = Reports; $id = 0
        try {
            $F = Make-Fixture 'D11'
            $id = Start-Tc313 $F
            Type-Text $id 'r'
            Key $id 0x27; Start-Sleep -Milliseconds 150
            Judge 'D11' 'VISIBLE' (Visible-Out $id $F) @{ before = $null; after = @($N_RekaNfd); off = $null } "typed 'r', Right"
        }
        catch { Row 'D11' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { if ($id) { $fatal = Fatal-Win $id; End-Row 'D11' $id $fatal $before } }
    }
    # review 313: rows with extra names or keys after the text
    # D12 'strasse' typed letter by letter with Strand.txt beside Strasse: 'stras' must match the sharp s
    # (before: the text sticks at 'stra' and both stay)
    Run-Keys 'D12' @($N_Strand) 'strasse' @() 'VISIBLE' @{ before = @($N_Strasse, $N_Strand); after = @($N_Strasse); off = $null } "typed 'strasse', Strand.txt beside"
    # D13 'coeur' typed letter by letter: 'co' must match the oe ligature (before: the text sticks at 'c')
    Run-Keys 'D13' @($N_Coeur, $N_Cat) 'coeur' @() 'VISIBLE' @{ before = $null; after = @($N_Coeur); off = $null } "typed 'coeur', cat.txt beside"
    # D14 Left on a decomposed name: 'r' matches r + caron; one Left removes the whole letter and ends the
    # search (the bug of the first 313 build: Left removed only the ignored mark and stuck)
    $allNames = @('alpha', 'beta.md', $N_Zlutoucky, $N_Zluty, $N_Cesky, $N_Uber, $N_Lodz, $N_Strasse, $N_RekaNfd, $N_Kana, $N_Ka)
    Run-Keys 'D14' @() 'r' @(0x25) 'VISIBLE' @{ before = $allNames; after = $allNames; off = $null } "typed 'r', Left"
    # D15 Left copies a decomposed fragment into the text ('rek' -> 'r'+caron+'e'); two Backspaces remove
    # 'e' and then the whole letter, which ends the search
    Run-Keys 'D15' @() 'rek' @(0x25, 0x08, 0x08) 'VISIBLE' @{ before = $null; after = $allNames; off = $null } "typed 'rek', Left, Backspace, Backspace"
}
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Kill-Mine $p } }
    $ok = Restore-Reg $RegBackup $existed
    if (-not $ok) { Out 'REGISTRY RESTORE FAILED' }
    $fails = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    Out ("ROWS {0}; FAIL {1}" -f $script:Rows.Count, $fails)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, $Utf8) }
}
exit $fails
