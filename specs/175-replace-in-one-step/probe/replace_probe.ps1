<#
.SYNOPSIS
    Feature 175 probe: Files > Convert and Quick Rename onto an existing file replace the user's
    file in one step - what the file had stays (its streams), and a failure leaves it as it was.

.DESCRIPTION
    CONV-*  a.txt "a CRLF b CRLF" with an alternate data stream a.txt:note; all selected (841, '*'),
            Convert (814) with "end of line LF", OK. PASS = a.txt holds "a LF b LF" and still has
            its stream (a delete and a move made a new file without it), no cnv*.tmp left.
              CONV-PLAIN   as above
              CONV-RO      a read-only a.txt: converted, still read-only
              CONV-LOCKED  a.txt held open by another program without FILE_SHARE_DELETE: the
                           replace fails (an error box, Skip) - a.txt keeps its old content
    REN-*   Quick Rename (754) of b.txt to the existing a2.txt, the overwrite question Yes.
              REN-PLAIN    a2.txt now holds b's content, b.txt is gone
              REN-LOCKED   a2.txt held open without FILE_SHARE_DELETE: refused - both files as
                           they were
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows (0 with -Expect before).
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
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('Res175' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Res175
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    public static long SendR(IntPtr h, uint msg, long w, long l, uint timeout) { IntPtr r; SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 2, timeout, out r); return r.ToInt64(); }
}
'@
}
$Root = $TempRoot + '\tc175'
$StartDir = $Root + '\start'
function Btn-Of([IntPtr]$Dlg, [int]$CtlId) { $b = @(Buttons $Dlg | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }); if ($b.Count) { return $b[0] }; return [IntPtr]::Zero }
function Body([string]$p) { if (-not [IO.File]::Exists($LP + $p)) { return $null }; return [IO.File]::ReadAllText($LP + $p) }
function Stream([string]$p) {
    $c = & cmd.exe /c "more < `"$p`:note`" 2>nul"
    if ($LASTEXITCODE -ne 0) { return $null }
    return (($c | Out-String).Trim())
}
function Temps([string]$d) { return @([IO.Directory]::GetFiles($LP + $d) | ForEach-Object { [IO.Path]::GetFileName($_) } | Where-Object { $_ -like '*.tmp' }) }

function Run-Convert([string]$Case) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case.ToLower(); NewDir $d
    $f = $d + '\a.txt'
    [IO.File]::WriteAllText($LP + $f, "a`r`nb`r`n", (New-Object Text.ASCIIEncoding))
    & cmd.exe /c "echo kept-stream> `"$f`:note`""
    $attrs = $null
    if ($Case -eq 'CONV-RO') { $attrs = [IO.FileAttributes]::ReadOnly }
    if ($attrs) { [IO.File]::SetAttributes($LP + $f, $attrs) }
    $held = $null
    if ($Case -eq 'CONV-LOCKED') { $held = [IO.File]::Open($LP + $f, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite) }
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $d
        [void](Serve $id 10)
        $sel = Open-ByCmd $id 841 10
        if ($sel -eq [IntPtr]::Zero) { Row $Case 'FILE' 'NOT DRIVEN' 'no Select dialog'; return }
        [void][Drv098f]::SetText((Find-Ctl $sel 101), '*', 5000); Click-Ok $sel
        Start-Sleep -Milliseconds 600
        $dlg = Open-ByCmd $id 814 10
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'FILE' 'NOT DRIVEN' 'no Convert dialog'; return }
        $lf = Btn-Of $dlg 2495
        if ($lf -ne [IntPtr]::Zero) { [void][Res175]::SendR($lf, 0x00F5, 0, 0, 5000) }
        $checked = [Res175]::SendR($lf, 0x00F0, 0, 0, 5000)
        Click-Ok $dlg
        # an error box (the locked row): Skip (its id), else OK
        $r = Serve $id 30 @(1, 6)
        if ($held) { $held.Close(); $held = $null; Start-Sleep -Milliseconds 300 }
        End-Row $Case $id $null $before; $id = 0
        $b = Body $f; $st = Stream $f; $tmps = Temps $d
        $now = $(if ([IO.File]::Exists($LP + $f)) { [IO.File]::GetAttributes($LP + $f) } else { 'none' })
        if ($Case -eq 'CONV-LOCKED') { $ok = ($b -ceq "a`r`nb`r`n") -and $tmps.Count -eq 0 }
        else { $ok = ($b -ceq "a`nb`n") -and ($st -ceq 'kept-stream') -and $tmps.Count -eq 0 }
        if ($attrs) { $ok = $ok -and (($now -band $attrs) -eq $attrs) }
        Row $Case 'FILE' (V $ok) ("LF checked {0}; a.txt now '{1}', its stream: {2}; attributes {3}; temporary files: {4}; windows: {5}" -f $checked, (Esc $b), $(if ($null -eq $st) { 'GONE' } else { "'" + (Esc $st) + "'" }), $now, ($tmps -join ','), (Msgs $r))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($held) { $held.Close() }
        if ($id) { End-Row $Case $id $null $before }
        if ([IO.File]::Exists($LP + $f)) { [IO.File]::SetAttributes($LP + $f, [IO.FileAttributes]::Normal) }
    }
}

function Run-Rename([string]$Case) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case.ToLower(); NewDir $d
    WriteFile ($d + '\b.txt') 'content of b'
    WriteFile ($d + '\a2.txt') 'content of a2'
    $held = $null
    if ($Case -eq 'REN-LOCKED') { $held = [IO.File]::Open($LP + $d + '\a2.txt', [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite) }
    $id = 0; $before = Reports
    try {
        $id = Start-Tc $d
        [void](Do-ChangeDir $id ($d + '\b.txt'))   # focuses b.txt
        [void](Serve $id 5 @(2))
        $dlg = Open-ByCmd $id 754 10
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'FILE' 'NOT DRIVEN' 'no Quick Rename dialog'; return }
        $ed = @([Drv098f]::Kids($dlg) | Where-Object { @('Edit', 'ComboBox') -contains [Drv098f]::Cls($_) -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
        [void][Drv098f]::SetText($ed, 'a2.txt', 5000)
        Click-Ok $dlg
        # the overwrite question: Yes; an error box: OK; the Quick Rename dialog opened again after
        # an error: Cancel (answering it would retry the rename)
        $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList }
        $sw = [Diagnostics.Stopwatch]::StartNew(); $idle = 0
        while ($sw.Elapsed.TotalSeconds -lt 25 -and $idle -lt 15) {
            $w = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::IsWindowVisible($_) -and [Drv098f]::IsWindowEnabled($_) }) | Select-Object -First 1
            if (-not $w) { $idle++; Start-Sleep -Milliseconds 200; continue }
            $idle = 0
            Start-Sleep -Milliseconds 600
            [void]$r.Messages.Add((WinDesc $w))
            if ([Drv098f]::Txt($w) -eq 'Quick Rename') { Post-Cmd $w 2 }
            else {
                $b = @(Buttons $w | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 6 }) + @(Buttons $w | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 1 }) | Select-Object -First 1
                if ($b) { Click $b } else { Close-Win $w }
            }
            Start-Sleep -Milliseconds 600
        }
        if ($held) { $held.Close(); $held = $null; Start-Sleep -Milliseconds 300 }
        End-Row $Case $id $null $before; $id = 0
        $a2 = Body ($d + '\a2.txt'); $b = Body ($d + '\b.txt')
        if ($Case -eq 'REN-LOCKED') { $ok = ($a2 -ceq 'content of a2') -and ($b -ceq 'content of b') }
        else { $ok = ($a2 -ceq 'content of b') -and ($null -eq $b) }
        Row $Case 'FILE' (V $ok) ("a2.txt '{0}', b.txt '{1}'; windows: {2}" -f (Esc $a2), (Esc $b), (Msgs $r))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($held) { $held.Close() }; if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc175_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("replace_probe (feature 175), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; export SHA-256 {2}; ACP {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, $regHash, [Drv098f]::GetACP())
    Out ''
    Run-Convert 'CONV-PLAIN'
    Run-Convert 'CONV-LOCKED'
    Run-Convert 'CONV-RO'
    Run-Rename 'REN-PLAIN'
    Run-Rename 'REN-LOCKED'
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
if ($Expect -eq 'before') { exit 0 }
exit $nf
