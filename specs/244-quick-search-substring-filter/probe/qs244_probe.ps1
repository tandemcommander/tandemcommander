<#
.SYNOPSIS
    Feature 244 probe: quick search that finds text anywhere in a name and filters the panel.

.DESCRIPTION
    Each case starts a fresh instance (left panel = a fixture folder, right panel = an empty
    target folder), types into the left panel with synchronous WM_CHAR / WM_KEYDOWN to its list
    box, posts commands to the main window, and observes through the disk:
      FOCUS    F5 with nothing selected copies the focused item into the target -> its name
      VISIBLE  Select all (842) + F5 copies the visible items -> their names
    Every case records what it saw and judges it against the expectation of -Expect:
      old  0.1.10 behaviour (also: the option switched off, V8)
      new  feature 244 behaviour
    A case with no expectation for the mode is recorded as INFO.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [Parameter(Mandatory = $true)][ValidateSet('old', 'new')][string]$Expect,
    [int]$FilterOption = -1,          # -1 = leave the registry value as it is; 0/1 = write 'Quick Search Filter'
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [switch]$Perf
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Root = $TempRoot + '\tc244'
$RegBackup = $TempRoot + '\tc244_backup.reg'

$U_NFC = [string][char]0x00DA + [char]0x010D + 'etnictv' + [char]0x00ED + ' 2024.xlsx'
$U_NFD = $U_NFC.Normalize([Text.NormalizationForm]::FormD).Replace('.xlsx', ' d.xlsx')
$Emoji = 'notes ' + [char]::ConvertFromUtf32(0x1F600) + '.txt'

function Assert-In([string]$p) { if (-not ($p + '\').StartsWith($Root + '\', [StringComparison]::OrdinalIgnoreCase)) { throw "path outside the fixture: $p" } }
function Clear-Dir([string]$d) {
    Assert-In $d
    if (Test-Path -LiteralPath $d) { Get-ChildItem -LiteralPath $d -Force | ForEach-Object { Remove-Item -LiteralPath $_.FullName -Recurse -Force } }
    else { [void][IO.Directory]::CreateDirectory($d) }
}
# the standard fixture; $Variant: 'std' (with chat.txt) or 'nochat' (without chat.txt, with xchatter.log)
function Make-Fixture([string]$Case, [string]$Variant) {
    $d = $Root + '\' + $Case
    Assert-In $d
    if (Test-Path -LiteralPath $d) { Remove-Item -LiteralPath $d -Recurse -Force }
    $l = $d + '\left'; $r = $d + '\right'
    NewDir ($l + '\2024_chatbot'); WriteFile ($l + '\2024_chatbot\inner.txt') 'i'; WriteFile ($l + '\2024_chatbot\x.md') 'x'
    NewDir ($l + '\alpha')
    WriteFile ($l + '\beta.md') 'b'
    if ($Variant -eq 'std') { WriteFile ($l + '\chat.txt') 'c' } else { WriteFile ($l + '\xchatter.log') 'x' }
    WriteFile ($l + '\old.log') 'o'
    WriteFile ($l + '\Report.PDF') 'p'
    WriteFile ($l + '\' + $U_NFC) 'u'
    WriteFile ($l + '\' + $U_NFD) 'u'
    WriteFile ($l + '\' + $Emoji) 'e'
    WriteFile ($l + '\secret_chat.txt') 's'
    [IO.File]::SetAttributes($LP + $l + '\secret_chat.txt', [IO.FileAttributes]::Hidden)
    NewDir $r
    return [pscustomobject]@{ Dir = $d; Left = $l; Right = $r }
}
function Names([string]$d) { return @(Get-ChildItem -LiteralPath $d -Force | ForEach-Object { $_.Name } | Sort-Object { $_.Normalize([Text.NormalizationForm]::FormC) }) }
function Show([string[]]$a) { if (-not $a -or $a.Count -eq 0) { return '{}' }; return '{' + ((@($a) | ForEach-Object { Esc $_ }) -join ', ') + '}' }

function Start-Tc244($F) {
    $a = @('-t', 'T244', '-l', ('"{0}"' -f $F.Left), '-r', ('"{0}"' -f $F.Right), '-p', '1')
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
function K([int]$Id, [int]$Vk) { Key $Id $Vk; Start-Sleep -Milliseconds 150 }
# posts a command and serves the windows it opens (answers OK / Yes); returns the Serve record
function Cmd([int]$Id, [int]$C, [int[]]$Answer = @(1, 6)) {
    Post-Cmd (Get-Main $Id) $C
    Start-Sleep -Milliseconds 300
    $r = Serve $Id 30 $Answer
    if ($r.Fatal) { throw ('FATAL: ' + $r.Fatal) }
    return $r
}
# what F5 copies now into the target; the target is emptied before and after
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

$script:Expectations = @{}
function Judge([string]$Case, [string]$Step, [string[]]$Got, $Old, $New, [string]$Note = '') {
    $exp = $Old; if ($Expect -eq 'new') { $exp = $New }
    $g = Show $Got
    if ($null -eq $exp) { Row $Case $Step 'INFO' ("got {0} {1}" -f $g, $Note); return }
    $e = Show ([string[]]$exp | Sort-Object { $_.Normalize([Text.NormalizationForm]::FormC) })
    Row $Case $Step (V ($g -ceq $e)) ("got {0} expected {1} {2}" -f $g, $e, $Note)
}

$All = { param($F) Names $F.Left | Where-Object { $_ -ne 'secret_chat.txt' -or $script:ShowHidden } }

function Run-Case([string]$Case, [string]$Variant, [scriptblock]$Body) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    try {
        $F = Make-Fixture $Case $Variant
        $id = Start-Tc244 $F
        & $Body $id $F
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}

# ---- run ------------------------------------------------------------------------------------
$existed = Backup-Reg $RegBackup
Out ("Feature 244 probe {0}; exe {1}; expect {2}; registry backup {3} (existed {4})" -f $Label, $Exe, $Expect, $RegBackup, $existed)
if ($existed) { Out ('export SHA-256 ' + (Get-FileHash -LiteralPath $RegBackup).Hash) }
try {
    Set-Config
    & reg.exe add "$RegKey\0.1\Configuration" /v 'Quick Search Enter Alt' /t REG_DWORD /d 0 /f | Out-Null
    if ($FilterOption -ge 0) { & reg.exe add "$RegKey\0.1\Configuration" /v 'Quick Search Filter' /t REG_DWORD /d $FilterOption /f | Out-Null }
    $hid = (& reg.exe query "$RegKey\0.1\Configuration" /v 'Hide Hidden and System Files and Directories' 2>$null) -join ' '
    $script:ShowHidden = -not ($hid -match '0x1\b')
    Out ("hidden files shown: {0} (registry: {1})" -f $script:ShowHidden, ($hid -replace '\s+', ' ').Trim())
    $hs = @(); if ($script:ShowHidden) { $hs = @('secret_chat.txt') }

    # C01/C02 prefix: 'c', 'chat' -> chat.txt in both modes
    Run-Case 'C01' 'std' { param($id, $F) Type-Text $id 'c'; Judge 'C01' 'FOCUS' (Copy-Out $id $F) @('chat.txt') @('chat.txt') "typed 'c'" }
    Run-Case 'C02' 'std' { param($id, $F) Type-Text $id 'chat'; Judge 'C02' 'FOCUS' (Copy-Out $id $F) @('chat.txt') @('chat.txt') "typed 'chat'" }
    # C03 substring: nothing starts with 'c' -> old: c,h refused, 'a' -> alpha, t refused; new: 2024_chatbot
    Run-Case 'C03' 'nochat' { param($id, $F) Type-Text $id 'chat'; Judge 'C03' 'FOCUS' (Copy-Out $id $F) @('alpha') @('2024_chatbot') "typed 'chat', no name starts with c" }
    # C04 the wildcard: '/chat' -> 2024_chatbot in both modes
    Run-Case 'C04' 'nochat' { param($id, $F) Type-Text $id '/chat'; Judge 'C04' 'FOCUS' (Copy-Out $id $F) @('2024_chatbot') @('2024_chatbot') "typed '/chat'" }
    # C05 'pdf' -> old: refused (focus stays on '..', nothing copied); new: Report.PDF
    Run-Case 'C05' 'std' { param($id, $F) Type-Text $id 'pdf'; Judge 'C05' 'FOCUS' (Copy-Out $id $F) @() @('Report.PDF') "typed 'pdf'" }
    # C06 'q' matches nothing -> refused in both modes
    Run-Case 'C06' 'std' { param($id, $F) Type-Text $id 'q'; Judge 'C06' 'FOCUS' (Copy-Out $id $F) @() @() "typed 'q'" }
    # C07 Czech prefix typed in NFC: the first of the two equivalent names (sort order)
    Run-Case 'C07' 'std' { param($id, $F) Type-Text $id ([string][char]0x00FA + [char]0x010D); Judge 'C07' 'FOCUS' (Copy-Out $id $F) $null $null "typed U+00FA U+010D" }
    # C08 visible set after 'chat': old = everything (select all ends the search); new = the matches
    Run-Case 'C08' 'std' { param($id, $F)
        Type-Text $id 'chat'
        $allNames = @(& $All $F)
        Judge 'C08' 'VISIBLE' (Visible-Out $id $F) $allNames (@('2024_chatbot', 'chat.txt') + $hs) "typed 'chat', select all, F5"
    }
    # C09 a selected item hidden by the search is not copied; it stays selected after Esc
    Run-Case 'C09' 'std' { param($id, $F)
        Type-Text $id 'old'; K $id 0x2D   # Insert selects old.log
        K $id 0x1B                        # Esc
        Type-Text $id 'rep'
        Judge 'C09' 'COPY1' (Copy-Out $id $F) @('old.log') @('Report.PDF') "old.log selected, typed 'rep', F5"
        K $id 0x1B
        Judge 'C09' 'COPY2' (Copy-Out $id $F) $null @('old.log') "after Esc, F5 again (new: old.log still selected)"
    }
    # C10 F6 with a hidden selection: only the visible selected item moves
    Run-Case 'C10' 'std' { param($id, $F)
        Type-Text $id 'old'; K $id 0x2D; K $id 0x1B
        Type-Text $id 'rep'; K $id 0x2D   # Insert selects Report.PDF
        Clear-Dir $F.Right
        [void](Cmd $id 728)
        Start-Sleep -Milliseconds 500
        $moved = Names $F.Right
        Judge 'C10' 'MOVED' $moved @('old.log', 'Report.PDF') @('Report.PDF') 'F6 with old.log hidden-selected'
        $left = @(Names $F.Left | Where-Object { $_ -eq 'old.log' })
        Judge 'C10' 'KEPT' $left @() @('old.log') 'old.log still in the source folder'
    }
    # C11 Esc ends: all items visible again
    Run-Case 'C11' 'std' { param($id, $F) Type-Text $id 'chat'; K $id 0x1B; Judge 'C11' 'VISIBLE' (Visible-Out $id $F) @(& $All $F) @(& $All $F) "typed 'chat', Esc" }
    # C12 Backspace widens: 'ch' + Backspace = 'c'
    Run-Case 'C12' 'std' { param($id, $F)
        Type-Text $id 'ch'; K $id 0x08
        $c = @('2024_chatbot', 'chat.txt', $U_NFC, $U_NFD) + $hs
        Judge 'C12' 'VISIBLE' (Visible-Out $id $F) @(& $All $F) $c "typed 'ch', Backspace"
    }
    # C13 Backspace of the last character ends the search
    Run-Case 'C13' 'std' { param($id, $F) Type-Text $id 'c'; K $id 0x08; Judge 'C13' 'VISIBLE' (Visible-Out $id $F) @(& $All $F) @(& $All $F) "typed 'c', Backspace" }
    # C14 a dialog opened and cancelled keeps the search (new)
    Run-Case 'C14' 'std' { param($id, $F)
        Type-Text $id 'chat'
        [void](Cmd $id 727 @(2))          # F5 dialog, Cancel
        Judge 'C14' 'VISIBLE' (Visible-Out $id $F) @(& $All $F) (@('2024_chatbot', 'chat.txt') + $hs) "typed 'chat', F5 cancelled"
    }
    # C15 refresh: a new matching file appears in the filtered view
    Run-Case 'C15' 'std' { param($id, $F)
        Type-Text $id 'chat'
        WriteFile ($F.Left + '\chat2.txt') 'n'
        [void](Cmd $id 740)               # refresh
        Start-Sleep -Milliseconds 500
        Judge 'C15' 'VISIBLE' (Visible-Out $id $F) (@(& $All $F)) (@('2024_chatbot', 'chat.txt', 'chat2.txt') + $hs) "typed 'chat', chat2.txt created, refresh"
    }
    # C16 Enter into a matching directory: the new directory is complete
    Run-Case 'C16' 'nochat' { param($id, $F)
        Type-Text $id '2024'; K $id 0x0D
        Start-Sleep -Milliseconds 800
        Judge 'C16' 'VISIBLE' (Visible-Out $id $F) @('inner.txt', 'x.md') @('inner.txt', 'x.md') "typed '2024', Enter"
    }
    # C17 Tab to the other panel and back ends the search
    Run-Case 'C17' 'std' { param($id, $F)
        Type-Text $id 'chat'; K $id 0x09; Start-Sleep -Milliseconds 300
        $rl = @([Drv098f]::Kids((Get-Main $id)) | Where-Object { [Drv098f]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv098f]::IsWindowVisible($_) })
        if ($rl.Count -ge 2) { [void][Drv098f]::Send($rl[1], 0x0100, 0x09, 1, 30000); [void][Drv098f]::Send($rl[1], 0x0101, 0x09, 0xC0000001, 30000) }
        Start-Sleep -Milliseconds 300
        Judge 'C17' 'VISIBLE' (Visible-Out $id $F) @(& $All $F) @(& $All $F) "typed 'chat', Tab, Tab"
    }
    # C18 Right extends the text by the focused name: 'chat' on 2024_chatbot + Right = 'chatb'
    Run-Case 'C18' 'nochat' { param($id, $F)
        Type-Text $id 'chat'; K $id 0x27
        Judge 'C18' 'VISIBLE' (Visible-Out $id $F) @(& $All $F) @('2024_chatbot') "typed 'chat', Right"
    }
    # C19 F7 creates a folder that does not match: the search ends, the folder is focused
    Run-Case 'C19' 'std' { param($id, $F)
        Type-Text $id 'chat'
        $dlg = Open-ByCmd $id 730
        if ($dlg -eq [IntPtr]::Zero) { Row 'C19' 'MKDIR' 'FAIL' 'no Create Directory dialog'; return }
        $ctl = Find-Ctl $dlg 210
        if ($ctl -eq [IntPtr]::Zero) { Close-Win $dlg; Row 'C19' 'MKDIR' 'FAIL' 'no name field'; return }
        [void][Drv098f]::SetText($ctl, 'zzz', 5000); Click-Ok $dlg
        [void](Serve $id 10)
        Start-Sleep -Milliseconds 500
        Judge 'C19' 'FOCUS' (Copy-Out $id $F) @('zzz') @('zzz') "typed 'chat', F7 zzz"
        Judge 'C19' 'VISIBLE' (Visible-Out $id $F) $null (@(& $All $F)) 'the search ended: everything visible'
    }
    # C20 sort change keeps the search (new)
    Run-Case 'C20' 'std' { param($id, $F)
        Type-Text $id 'chat'
        [void](Cmd $id 701)               # sort by extension
        Judge 'C20' 'VISIBLE' (Visible-Out $id $F) @(& $All $F) (@('2024_chatbot', 'chat.txt') + $hs) "typed 'chat', sort by extension"
        [void](Cmd $id 700)
    }
    # C21 inside a ZIP archive
    Run-Case 'C21' 'std' { param($id, $F)
        $zip = $F.Dir + '\arc.zip'; Assert-In $zip
        [IO.Compression.ZipFile]::CreateFromDirectory($F.Left, $zip)
        if (-not (Do-ChangeDir $id $zip)) { Row 'C21' 'ZIP' 'FAIL' 'could not type the archive path'; return }
        Start-Sleep -Milliseconds 1500
        Type-Text $id 'chat'
        Judge 'C21' 'VISIBLE' (Visible-Out $id $F) $null @('2024_chatbot', 'chat.txt', 'secret_chat.txt') "inside arc.zip, typed 'chat', select all, F5"
    }

    if ($Perf) {
        # Czech names (review 244: non-ASCII names went through the slow comparison per position)
        $cz = [string][char]0x00FA + [char]0x010D + 'etn' + [char]0x00ED + '_doklad_{0:D6}_' + [char]0x0159 + [char]0x00E1 + 'dek_' + [char]0x017E + 'lu' + [char]0x0165 + 'ou' + [char]0x010D + 'k' + [char]0x00FD + '_{1}.txt'
        foreach ($variant in @(@{ N = 10000; Cz = $false }, @{ N = 100000; Cz = $false }, @{ N = 10000; Cz = $true }, @{ N = 100000; Cz = $true })) {
            $n = $variant.N
            $case = 'P' + $n + $(if ($variant.Cz) { 'cz' } else { '' })
            if (-not (Want $case)) { continue }
            $d = $Root + '\' + $case; Assert-In $d
            if (-not (Test-Path -LiteralPath ($d + '\left'))) {
                NewDir ($d + '\left'); NewDir ($d + '\right')
                for ($i = 0; $i -lt $n; $i++) {
                    $tag = if ($i % 100 -eq 7) { 'needle' } else { 'hay' }
                    $name = if ($variant.Cz) { $cz -f $i, $tag } else { 'file_{0:D6}_{1}.txt' -f $i, $tag }
                    [IO.File]::WriteAllBytes($LP + $d + '\left\' + $name, [byte[]]@())
                }
            }
            $F = [pscustomobject]@{ Dir = $d; Left = $d + '\left'; Right = $d + '\right' }
            $before = Reports; $id = 0
            try {
                $id = Start-Tc244 $F
                Start-Sleep -Milliseconds 2000
                $l = Get-LeftList $id
                $times = @()
                foreach ($c in 'needle'.ToCharArray()) {
                    $sw = [Diagnostics.Stopwatch]::StartNew()
                    [void][Drv098f]::Send($l, 0x0102, [int]$c, 1, 60000)
                    [void][Drv098f]::Send($l, 0x000F, 0, 0, 60000)   # WM_PAINT handled synchronously as a proxy for the repaint
                    $times += [math]::Round($sw.Elapsed.TotalMilliseconds)
                }
                $bs = @()
                for ($i = 0; $i -lt 5; $i++) {
                    $sw = [Diagnostics.Stopwatch]::StartNew()
                    Key $id 0x08
                    [void][Drv098f]::Send($l, 0x000F, 0, 0, 60000)
                    $bs += [math]::Round($sw.Elapsed.TotalMilliseconds)
                }
                Key $id 0x1B
                # the worst case: every item matches every character ("file" / the Czech word in every name)
                $allText = if ($variant.Cz) { [string][char]0x0159 + [char]0x00E1 + 'dek' } else { 'file' }
                $all = @()
                foreach ($c in $allText.ToCharArray()) {
                    $sw = [Diagnostics.Stopwatch]::StartNew()
                    [void][Drv098f]::Send($l, 0x0102, [int]$c, 1, 60000)
                    [void][Drv098f]::Send($l, 0x000F, 0, 0, 60000)
                    $all += [math]::Round($sw.Elapsed.TotalMilliseconds)
                }
                $limit = if ($n -eq 10000) { 100 } else { 300 }
                $max = ($times + $bs + $all | Measure-Object -Maximum).Maximum
                Row $case 'TIME' $(if ($Expect -eq 'new') { V ($max -lt $limit) } else { 'INFO' }) ("ms per character {0}; Backspace {1}; all items match {2}; limit {3}" -f ($times -join ','), ($bs -join ','), ($all -join ','), $limit)
            }
            catch { Row $case 'ERROR' 'FAIL' ($_.Exception.Message) }
            finally { if ($id) { $fatal = Fatal-Win $id; End-Row $case $id $fatal $before } }
        }
    }
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
