<#
.SYNOPSIS
    Feature 317 probe: the Pack dialog (Alt+F5, CM_PACK 850) packs into the archive its entry shows -
    a relative archive name that starts with a space (offered for an item ' report', or typed) keeps
    the space; SalGetFullName strips leading spaces of a relative name, so ' report.zip' became
    'report.zip'.

.DESCRIPTION
    Fixture per row: <row>\src (the left panel, active) holding the items of the row, and <row>\tgt\L
    (the right panel). "Use the other panel for packing" is off (Packers & Unpackers\Custom Packers,
    'Use Another Panel' = 0, the default) and the "add to an existing archive" question is on
    (Confirmation\Add To Archive = 1, the default); both written before the start. Home, Down focuses
    the first item; Alt+F5 (850) opens the Pack dialog; the archive-name combo box (210) items are
    read; the row picks item 0 (the relative name) or - typed rows - puts a text into the entry with a
    wide WM_SETTEXT (not a keyboard), clicks OK and answers every box: the "add to archive?" question
    with the row's answer (Yes = Add, No = Overwrite), any other box Yes / OK. The Pack dialog shown
    again is cancelled.
    PASS = nothing fatal, the dialog closed, the new files under the row (src and tgt) are exactly
    the expected ones, the changed files (SHA-256) exactly the expected ones, the archive inspected
    holds / lacks the expected entries (suffix match), a refusal row showed a message, and a row
    with a question pattern was asked it.
      space-dir         folder ' report' (f.txt): ' report.zip'
      space-dir-exists  folder ' report' and an archive 'report.zip' (seed.txt) next to it:
                        ' report.zip'; 'report.zip' untouched (before: the "add to archive?" question
                        about 'report.zip', Add put the folder into it)
      space-add         folder ' report' and an archive ' report.zip' (seed.txt): the question names
                        ' report.zip', Add: it holds seed.txt and f.txt
      space-over        the same, Overwrite: ' report.zip' holds f.txt, not seed.txt; no aside left
      space-file        file ' notes.txt': ' notes.zip'
      space2-dir        folder '  two' (two spaces): '  two.zip'
      typed-space       folder 'plain', the entry ' typed.zip': ' typed.zip'
      typed-space-noext folder 'plain', the entry ' typed' (the dialog adds '.zip'): ' typed.zip'
      typed-spaces-only folder 'plain', the entry '   ' (the dialog adds '.zip'): '   .zip'
                        (before: '.zip')
      typed-space-dots  folder 'plain', the entry ' ..': refused ("The path specified is invalid."),
                        nothing created, nothing changed (before 317: the packer failed on the
                        parent folder; with the space kept and no refusal: a file ' ..')
      typed-space-dot   folder 'plain', the entry ' .': the same (' .')
      ctl-plain         folder 'plain': 'plain.zip' (control)
      ctl-abs-space     folder 'plain', the entry '<src>\ abs.zip' (absolute): ' abs.zip' (control)
      ctl-empty         folder 'plain', the entry '': refused (a message), nothing created
    Not driven: typing with a keyboard (WM_SETTEXT), the focus after packing, external archivers.
    Driver of 316's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1.
    Registry exported, restored and verified. Exit code = FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -eq $_ }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

. $Lib
Add-Type -AssemblyName System.IO.Compression, System.IO.Compression.FileSystem
if (-not ('Cb317' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class Cb317
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] static extern IntPtr SendBuf(IntPtr h, uint msg, IntPtr w, [Out] char[] l, uint flags, uint timeout, out IntPtr result);
    public static long Send(IntPtr h, uint msg, long w)
    {
        IntPtr res;
        if (SendMessageTimeoutW(h, msg, (IntPtr)w, IntPtr.Zero, 0, 5000, out res) == IntPtr.Zero) return -9;
        return res.ToInt64();
    }
    // CB_GETCOUNT, CB_GETLBTEXTLEN, CB_GETLBTEXT
    public static List<string> Items(IntPtr combo)
    {
        var l = new List<string>();
        long n = Send(combo, 0x0146, 0);
        for (long i = 0; i < n; i++)
        {
            long len = Send(combo, 0x0149, i);
            if (len < 0) { l.Add("<CB_ERR>"); continue; }
            var buf = new char[len + 1];
            IntPtr res;
            SendBuf(combo, 0x0148, (IntPtr)i, buf, 0, 5000, out res);
            int got = (int)res.ToInt64(); if (got < 0) got = 0; if (got > len) got = (int)len;
            l.Add(new string(buf, 0, got));
        }
        return l;
    }
}
'@
}
$Root = $TempRoot + '\tc317_pack'
$StartDir = $Root + '\start'
$PackKey = $RegKey + '\Settings\Packers & Unpackers\Custom Packers'
$CnfKey = $RegKey + '\Settings\Configuration\Confirmation'

function Vis([string]$s) { if ($s.Length -gt 60) { $s = '...(' + $s.Length + ') ' + $s.Substring($s.Length - 30) }; return ("'" + ($s -replace ' ', '<sp>') + "'") }
function Join-Vis($a) { if (@($a).Count) { return ((@($a) | ForEach-Object { Vis $_ }) -join ', ') } return 'none' }
# every file under $Dir: relative name -> SHA-256
function Snap([string]$Dir) {
    $h = @{}
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return $h }
    foreach ($f in [IO.Directory]::GetFiles($LP + $Dir, '*', [IO.SearchOption]::AllDirectories)) {
        $sha = [Security.Cryptography.SHA256]::Create()
        $st = [IO.File]::OpenRead($f)
        try { $h[$f.Substring(($LP + $Dir).Length + 1)] = [BitConverter]::ToString($sha.ComputeHash($st)) } finally { $st.Dispose(); $sha.Dispose() }
    }
    return $h
}
function Zip-Entries([string]$Zip) {
    try {
        $z = [IO.Compression.ZipFile]::OpenRead($LP + $Zip)
        try { return @($z.Entries | ForEach-Object { $_.FullName }) } finally { $z.Dispose() }
    }
    catch { return @('<not a readable zip: ' + $_.Exception.Message + '>') }
}
function Zip-Seed([string]$Zip) {
    $z = [IO.Compression.ZipFile]::Open($LP + $Zip, [IO.Compression.ZipArchiveMode]::Create)
    try { $w = New-Object IO.StreamWriter($z.CreateEntry('seed.txt').Open()); $w.Write('S'); $w.Dispose() } finally { $z.Dispose() }
}
function Start-TcPk([string]$Left, [string]$Right) {
    $a = @('-t', 'T317', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 2000
    return $p.Id
}
# answers every window except $Keep: the "add to archive?" question with $Answer (6 = Add, 7 =
# Overwrite), any other box Yes / OK; the Pack dialog shown again is cancelled; until idle
function ServePk([int]$Id, $Keep = @(), [double]$Seconds = 60, [int]$Answer = 6) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null; TimedOut = $false }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass -and $Keep -notcontains $_ -and [Drv098f]::IsWindowVisible($_) })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.0) { break }
            Start-Sleep -Milliseconds 100; continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv098f]::IsWindow($h)) { continue }
            $d = WinDesc $h
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            if (-not [Drv098f]::IsWindowEnabled($h)) { continue }
            if ([Drv098f]::Txt($h) -eq 'Pack' -and (Find-Ctl $h 210) -ne [IntPtr]::Zero) {   # the dialog, not a message box titled Pack
                [void]$r.Messages.Add('the Pack dialog again'); Close-Win $h; Start-Sleep -Milliseconds 500; continue
            }
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if (($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)) { continue }   # progress
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $seen.Remove($key)
            [void]$r.Messages.Add($d)
            $pick = $null
            $order = @(6, 1); if ($d -match 'already exists') { $order = @($Answer) }
            foreach ($want in $order) { if (-not $pick) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1 } }
            if ($pick) { Click $pick } else { Close-Win $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}
function Short([string]$s) {
    $s = $s -replace '\[Button id=\d+\] [^|]*(\||$)', ''
    $s = $s -replace '\[Static id=-?\d+\] ', ''
    if ($s.Length -gt 200) { $s = $s.Substring(0, 200) + '...' }
    return $s.Trim()
}
function Shown($r) { $m = (@($r.Messages | ForEach-Object { Short $_ }) -join ' || '); if ($m) { return $m } else { return 'nothing' } }

# one row. $Make: param($Src) -> @{ Pre = @{ <rel file under src> = <content> }; Seed = <rel zip under src
#   made with seed.txt> or $null; New = <the files expected new, rel to src>; Changed = <the files
#   expected changed, rel to src>; Arc = <the archive inspected, rel to src>; Has / HasNot = entry
#   suffixes it must / must not hold; Refuse = a message expected; AskRx = a pattern a box must match }.
# $Type (not $null): the text put into the entry instead of item 0 ('<src>' is replaced by the src path).
# $Answer: the answer to the "add to archive?" question (6 = Add, 7 = Overwrite).
function Pack-Row([string]$Case, $Type, [int]$Answer, [scriptblock]$Make) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $src = $d + '\src'
    $L = $d + '\tgt\L'
    NewDir $src; NewDir $L
    $t = & $Make $src
    foreach ($k in $t.Pre.Keys) { NewDir (Split-Path ($src + '\' + $k)); WriteFile ($src + '\' + $k) $t.Pre[$k] }
    if ($t.Seed) { Zip-Seed ($src + '\' + $t.Seed) }
    if ($null -ne $Type) { $Type = $Type.Replace('<src>', $src); if ($Type.Contains('\') -and -not $Type.StartsWith($src + '\')) { throw "typed path is not inside the fixture: $Type" } }
    & reg.exe add $PackKey /v 'Use Another Panel' /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add $CnfKey /v 'Add To Archive' /t REG_DWORD /d 1 /f | Out-Null
    $snap0 = Snap $d
    $id = 0; $fatal = $null; $before = Reports
    try {
        $id = Start-TcPk $src $L
        Key $id 0x24; Key $id 0x28
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id 850 15
        if ($dlg -eq [IntPtr]::Zero) { throw 'Pack (850) opened no window' }
        if ([Drv098f]::Txt($dlg) -ne 'Pack') { throw ("850 opened '{0}', not the Pack dialog" -f [Drv098f]::Txt($dlg)) }
        Start-Sleep -Milliseconds 400
        $combo = Find-Ctl $dlg 210
        if ($combo -eq [IntPtr]::Zero) { throw 'the archive-name combo box 210 was not found' }
        $items = @([Cb317]::Items($combo))
        if ($null -ne $Type) {
            if (-not [Drv098f]::SetText($combo, $Type, 5000)) { throw 'WM_SETTEXT into the entry failed' }
        }
        else {
            if ($items.Count -lt 1) { throw 'the combo box holds no item' }
            [void][Cb317]::Send($combo, 0x014E, 0)   # CB_SETCURSEL
        }
        Start-Sleep -Milliseconds 200
        $chosen = [Drv098f]::GetText($combo, 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = ServePk $id @($dlg) 60 $Answer
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
        if ($stayed -and -not $fatal) { Close-Win $dlg; Start-Sleep -Milliseconds 500; [void](ServePk $id @() 15) }
        Start-Sleep -Milliseconds 500
        $snap1 = Snap $d
        $new = @($snap1.Keys | Where-Object { -not $snap0.ContainsKey($_) } | Sort-Object)
        $changed = @($snap0.Keys | Where-Object { -not $snap1.ContainsKey($_) -or $snap1[$_] -ne $snap0[$_] } | Sort-Object)
        $wantNew = @($t.New | Where-Object { $_ } | ForEach-Object { 'src\' + $_ } | Sort-Object)
        $wantChg = @($t.Changed | Where-Object { $_ } | ForEach-Object { 'src\' + $_ } | Sort-Object)
        $c1 = ((@($new) -join '|') -ceq (@($wantNew) -join '|'))
        $c2 = ((@($changed) -join '|') -ceq (@($wantChg) -join '|'))
        $entries = @(); if ($t.Arc -and $snap1.ContainsKey('src\' + $t.Arc)) { $entries = @(Zip-Entries ($src + '\' + $t.Arc)) }
        $c3 = $true
        foreach ($h in @($t.Has | Where-Object { $_ })) { if (-not @($entries | Where-Object { $_.EndsWith($h) }).Count) { $c3 = $false } }
        foreach ($h in @($t.HasNot | Where-Object { $_ })) { if (@($entries | Where-Object { $_.EndsWith($h) }).Count) { $c3 = $false } }
        $c4 = (-not $t.Refuse) -or ((Shown $r) -ne 'nothing')
        $c5 = (-not $t.AskRx) -or (@($r.Messages | Where-Object { $_ -match $t.AskRx }).Count -gt 0)
        $ok = (-not $fatal) -and (-not $r.TimedOut) -and (-not $stayed) -and $c1 -and $c2 -and $c3 -and $c4 -and $c5
        $why = ''
        if (-not $ok) { $why = (" [expected new {0}; changed {1}; entries with {2}, without {3}; refusal expected {4}; asked {5}]" -f (Join-Vis $wantNew), (Join-Vis $wantChg), (Join-Vis $t.Has), (Join-Vis $t.HasNot), [bool]$t.Refuse, $t.AskRx) }
        Row $Case 'RUN' (V $ok) ("items: {0}; OK on {1}; dialog stayed: {2}; asked: {3}; new: {4}; changed: {5}; entries: {6}{7}{8}" -f (Join-Vis $items), (Vis $chosen), $stayed, (Shown $r), (Join-Vis $new), (Join-Vis $changed), (Join-Vis $entries), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }), $why)
    }
    catch {
        Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace)
        if ($id -and (Test-Alive $id)) { foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { Close-Win $h } }
    }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc317_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("pack317_probe (feature 317) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ("Fixture {0}" -f $Root)
    Out ''
    $plain = @{ 'plain\f.txt' = 'F' }
    Pack-Row 'space-dir' $null 6 { param($S) @{ Pre = @{ ' report\f.txt' = 'F' }; New = @(' report.zip'); Arc = ' report.zip'; Has = @('f.txt') } }
    Pack-Row 'space-dir-exists' $null 6 { param($S) @{ Pre = @{ ' report\f.txt' = 'F' }; Seed = 'report.zip'; New = @(' report.zip'); Arc = ' report.zip'; Has = @('f.txt'); HasNot = @('seed.txt') } }
    Pack-Row 'space-add' $null 6 { param($S) @{ Pre = @{ ' report\f.txt' = 'F' }; Seed = ' report.zip'; Changed = @(' report.zip'); Arc = ' report.zip'; Has = @('f.txt', 'seed.txt')
            AskRx = 'file " report\.zip" already exists' } }
    Pack-Row 'space-over' $null 7 { param($S) @{ Pre = @{ ' report\f.txt' = 'F' }; Seed = ' report.zip'; Changed = @(' report.zip'); Arc = ' report.zip'; Has = @('f.txt'); HasNot = @('seed.txt')
            AskRx = 'file " report\.zip" already exists' } }
    Pack-Row 'space-file' $null 6 { param($S) @{ Pre = @{ ' notes.txt' = 'N' }; New = @(' notes.zip'); Arc = ' notes.zip'; Has = @(' notes.txt') } }
    Pack-Row 'space2-dir' $null 6 { param($S) @{ Pre = @{ '  two\f.txt' = 'F' }; New = @('  two.zip'); Arc = '  two.zip'; Has = @('f.txt') } }
    Pack-Row 'typed-space' ' typed.zip' 6 { param($S) @{ Pre = $plain; New = @(' typed.zip'); Arc = ' typed.zip'; Has = @('f.txt') } }
    Pack-Row 'typed-space-noext' ' typed' 6 { param($S) @{ Pre = $plain; New = @(' typed.zip'); Arc = ' typed.zip'; Has = @('f.txt') } }
    Pack-Row 'typed-spaces-only' '   ' 6 { param($S) @{ Pre = $plain; New = @('   .zip'); Arc = '   .zip'; Has = @('f.txt') } }
    Pack-Row 'typed-space-dots' ' ..' 6 { param($S) @{ Pre = $plain; Refuse = $true; AskRx = 'path specified is invalid' } }
    Pack-Row 'typed-space-dot' ' .' 6 { param($S) @{ Pre = $plain; Refuse = $true; AskRx = 'path specified is invalid' } }
    Pack-Row 'ctl-plain' $null 6 { param($S) @{ Pre = $plain; New = @('plain.zip'); Arc = 'plain.zip'; Has = @('f.txt') } }
    Pack-Row 'ctl-abs-space' '<src>\ abs.zip' 6 { param($S) @{ Pre = $plain; New = @(' abs.zip'); Arc = ' abs.zip'; Has = @('f.txt') } }
    Pack-Row 'ctl-empty' '' 6 { param($S) @{ Pre = $plain; Refuse = $true; AskRx = '#32770 ''Pack''' } }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
