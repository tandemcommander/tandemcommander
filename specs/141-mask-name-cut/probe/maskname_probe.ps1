<#
.SYNOPSIS
    Feature 141 probe: Copy, Move and Quick Rename in a disk panel with names that are long in
    UTF-8 (up to the 255 UTF-16 units Windows allows) - is the name kept whole?

.DESCRIPTION
    Rows (names for -Only); every row starts its own instance in English and ends it:

      CP250   Copy  a file named 'a' + 249 CJK letters + '.txt' (752 bytes of UTF-8)
      MV250   Move  the same
      CPD250  Copy  a directory named 'a' + 249 CJK letters with one file in it
      CP200   Copy  a file named 'a' + 199 CJK letters + '.txt' (602 bytes)
      QR250   Quick Rename of one.txt to 'a' + 249 CJK letters + '.txt'
      QR200   Quick Rename of one.txt to 'a' + 199 CJK letters + '.txt'
      QR256   Quick Rename of one.txt to 256 CJK letters (no file system takes it): must be
              refused, the file keeps its name

    Verdict of a row: the names found in the target folder afterwards, compared character by
    character with the expected one. With -Expect before every row is PASS (it only records).

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.
.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Root = $TempRoot + '\tc141'
$StartDir = $Root + '\start'
$Cjk = [string][char]0x4E2D

function Start-P([string]$Left, [string]$Right) {
    $a = @('-t', 'T141', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
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
function Dialogs([int]$Id) { return @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowEnabled($_) -and [Drv098f]::IsWindowVisible($_) }) }
function Short([string]$t) { $e = [regex]::Replace((Esc $t), '(?:\\u4E2D){8,}', '<CJK letters>'); if ($e.Length -le 420) { return $e }; return ($e.Substring(0, 420) + ' ...') }

# answers every dialog until none shows for $Quiet seconds: OK / Yes by id, else Skip / Close /
# Cancel. $FirstEdit: text for the first dialog with an edit; a dialog with an edit that comes
# back after the text was typed is cancelled.
function Answer([int]$Id, [double]$Seconds = 60, [double]$Quiet = 4, [string]$FirstEdit = $null) {
    $texts = @(); $sw = [Diagnostics.Stopwatch]::StartNew(); $last = [Diagnostics.Stopwatch]::StartNew(); $typed = $false; $seenOp = $false
    while ($sw.Elapsed.TotalSeconds -lt $Seconds -and $last.Elapsed.TotalSeconds -lt $Quiet -and (Test-Alive $Id)) {
        $acted = $false
        foreach ($h in (Dialogs $Id)) {
            $bs = Buttons $h
            $ids = @($bs | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if ($ids.Count -eq 0 -or ($ids.Count -eq 1 -and $ids[0] -eq 2)) { continue }
            Start-Sleep -Milliseconds 500
            $desc = WinDesc $h
            if ($desc -match $FatalRx) { $texts += ('FATAL ' + (Tail $desc 300)); return $texts }
            $edits = @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' -and [Drv098f]::IsWindowVisible($_) })
            $isMsg = (@([Drv098f]::Kids($h) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2477 }).Count -gt 0)
            if ($FirstEdit -and -not $typed -and $edits.Count) {
                [void][Drv098f]::SetText($edits[0], $FirstEdit, 5000); $typed = $true
                $texts += ('typed into [' + (Tail ([Drv098f]::Txt($h)) 40) + ']'); Click-Ok $h; $acted = $true; break
            }
            if (-not $isMsg -and $edits.Count -and ($typed -or $seenOp)) { $texts += ('[' + (Tail ([Drv098f]::Txt($h)) 40) + '] came back - cancelled'); Close-Win $h; $acted = $true; break }
            if (-not $isMsg -and $edits.Count) { $seenOp = $true }
            $b = $null
            foreach ($w in @(1, 6)) { if (-not $b) { $b = $bs | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1 } }
            if (-not $b) { $b = $bs | Where-Object { [Drv098f]::Txt($_) -match '^&?(Skip|Close)$' } | Select-Object -First 1 }
            $texts += (Short $desc)
            if ($b) { Click $b } else { Close-Win $h }
            $acted = $true
            break
        }
        if ($acted) { $last.Restart(); Start-Sleep -Milliseconds 900 } else { Start-Sleep -Milliseconds 250 }
    }
    return $texts
}
function Names([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return @() }
    return @([IO.Directory]::GetFileSystemEntries($LP + $Dir) | ForEach-Object { $_.Substring(($LP + $Dir).Length + 1) })
}
function Describe([string[]]$Names, [string]$Want) {
    if (-not $Names.Count) { return 'nothing' }
    return (($Names | ForEach-Object { if ($_ -ceq $Want) { 'the expected name (' + $_.Length + ' letters)' } else { "'" + (Short $_) + "' (" + $_.Length + ' letters, ' + (U8Len $_) + ' bytes)' } }) -join ', ')
}

# one row: $Setup { param($src) } fills the source folder; the focus goes to its first item;
# command $Cmd (727 Copy, 728 Move, 754 Quick Rename), $Type typed into the first edit;
# $Judge { param($texts, $srcNames, $dstNames) } returns @{ Ok; Facts }
function Row-Do([string]$Case, [int]$Cmd, [string]$Type, [scriptblock]$Setup, [scriptblock]$Judge) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0
    $src = $StartDir + '\' + $Case + '\s'; $dst = $StartDir + '\' + $Case + '\d'
    try {
        NewDir $src; NewDir $dst
        & $Setup $src | Out-Null
        $id = Start-P $src $dst
        Key $id 0x24; Key $id 0x28
        Post-Cmd (Get-Main $id) $Cmd; Start-Sleep -Milliseconds 700
        $texts = @(Answer $id 60 4 $Type)
        [void][Drv098f]::Send((Get-Main $id), 0, 0, 0, 20000)
        $sn = [string[]]@(Names $src); $dn = [string[]]@(Names $dst)      # a one-name list must stay a list
        $r = & $Judge $texts $sn $dn
        $verdict = $(if ($Expect -eq 'before') { 'PASS' } else { V ([bool]$r.Ok) })
        Row $Case 'ROW' $verdict ("{0}; dialogs: {1}" -f $r.Facts, $(if ($texts.Count) { $texts -join ' || ' } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { $fatal = Fatal-Win $id; End-Row $Case $id $fatal $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc141_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    NewDir $StartDir
    Set-Config
    Out ("maskname_probe (feature 141), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), $existed, $regHash)
    Out ''
    $n250 = 'a' + ($Cjk * 249) + '.txt'      # 254 units, 752 bytes
    $n200 = 'a' + ($Cjk * 199) + '.txt'      # 204 units, 602 bytes
    $d250 = 'a' + ($Cjk * 249)
    $n256 = $Cjk * 256
    $TL = 'too long|Too long'
    $f250 = { param($s) [IO.File]::WriteAllText($LP + $s + [string][char]92 + $n250, 'content-141') }
    $f200 = { param($s) [IO.File]::WriteAllText($LP + $s + [string][char]92 + $n200, 'content-141') }
    $one = { param($s) [IO.File]::WriteAllText($LP + $s + '\one.txt', 'content-141') }
    Row-Do 'CP250' 727 $null $f250 { param($t, $sn, $dn) $ok = ($dn.Count -eq 1 -and $dn[0] -ceq $n250); @{ Ok = $ok; Facts = ("copy a file with a 254-letter name (752 bytes): the target folder holds {0}; the source {1}" -f (Describe $dn $n250), (Describe $sn $n250)) } }
    Row-Do 'MV250' 728 $null $f250 { param($t, $sn, $dn) $ok = ($dn.Count -eq 1 -and $dn[0] -ceq $n250 -and $sn.Count -eq 0); @{ Ok = $ok; Facts = ("move it: the target folder holds {0}; the source {1}" -f (Describe $dn $n250), (Describe $sn $n250)) } }
    Row-Do 'CPD250' 727 $null { param($s) NewDir ($s + '\' + $d250); [IO.File]::WriteAllText($LP + $s + '\' + $d250 + '\in.txt', 'content-141') } { param($t, $sn, $dn) $in = [IO.File]::Exists($LP + $StartDir + '\CPD250\d\' + $d250 + '\in.txt'); $ok = ($dn.Count -eq 1 -and $dn[0] -ceq $d250 -and $in); @{ Ok = $ok; Facts = ("copy a directory with a 250-letter name (748 bytes): the target folder holds {0}; the file inside arrived {1}" -f (Describe $dn $d250), $in) } }
    Row-Do 'CP200' 727 $null $f200 { param($t, $sn, $dn) $ok = ($dn.Count -eq 1 -and $dn[0] -ceq $n200); @{ Ok = $ok; Facts = ("copy a file with a 204-letter name (602 bytes): the target folder holds {0}" -f (Describe $dn $n200)) } }
    Row-Do 'QR250' 754 $n250 $one { param($t, $sn, $dn) $ok = ($sn.Count -eq 1 -and $sn[0] -ceq $n250); @{ Ok = $ok; Facts = ("Quick Rename of one.txt to a 254-letter name (752 bytes): the folder holds {0}" -f (Describe $sn $n250)) } }
    Row-Do 'QR200' 754 $n200 $one { param($t, $sn, $dn) $ok = ($sn.Count -eq 1 -and $sn[0] -ceq $n200); @{ Ok = $ok; Facts = ("Quick Rename of one.txt to a 204-letter name (602 bytes): the folder holds {0}" -f (Describe $sn $n200)) } }
    Row-Do 'QR256' 754 $n256 $one { param($t, $sn, $dn) $said = [bool](@($t | Where-Object { $_ -match $TL -or $_ -match 'Error|error|Cannot|cannot' }).Count); $ok = ($sn.Count -eq 1 -and $sn[0] -ceq 'one.txt' -and $said); @{ Ok = $ok; Facts = ("Quick Rename of one.txt to 256 letters (more than a name may have): the folder holds {0}; a refusal was shown {1}" -f (Describe $sn 'one.txt'), $said) } }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } }
    catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
