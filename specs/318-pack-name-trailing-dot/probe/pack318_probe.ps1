<#
.SYNOPSIS
    Feature 318 probe: the Pack dialog (Alt+F5, CM_PACK 850) refuses an archive name whose last part
    the file system would not keep as typed - a trailing dot or space ('report.', 'report.zip '), or a
    reserved device name ('CON.zip', 'con' + '.zip', 'NUL .zip', 'COM1.zip', 'lpt9.tar.zip') - with
    "The path specified is invalid." and the dialog again. Before 318 the ZIP plug-in (which writes
    through \\?\ paths, so Windows does not trim the name) created such a file literally.

.DESCRIPTION
    Fixture per row: <row>\src (the left panel, active) holding the folder 'plain' (f.txt), and
    <row>\tgt\L (the right panel). "Use the other panel for packing" is off (Packers & Unpackers\Custom
    Packers, 'Use Another Panel' = 0, the default) and the "add to an existing archive" question is on
    (Confirmation\Add To Archive = 1, the default); both written before the start. Home, Down focuses
    'plain'; Alt+F5 (850) opens the Pack dialog; the row picks item 0 or puts a text into the
    archive-name entry (combo box 210) with a wide WM_SETTEXT (not a keyboard), clicks OK and answers
    every box Yes / OK; the Pack dialog shown again is cancelled.
    PASS = nothing fatal, the dialog closed, the new files under the row exactly the expected ones,
    no file changed, the archive inspected holds the expected entry, a refusal row showed the
    expected message. Each new file is also opened through its plain (non-\\?\) path - reported as
    'plain open: yes/no' (a fact, not a verdict).
      Refused (nothing created):
      trail-dot        'report.'           (the dialog adds no extension: the name has a dot)
      trail-dots       'report.zip..'
      trail-space      'report.zip '
      trail-dot-space  'report. '
      dev-con          'CON.zip'
      dev-con-noext    'con'               (the dialog adds '.zip': 'con.zip')
      dev-nul-space    'NUL .zip'
      dev-com1         'COM1.zip'
      dev-lpt9-2ext    'lpt9.tar.zip'
      dev-com-sup      'COM<superscript 1>.zip'
      abs-trail-dot    '<src>\abs.'        (an absolute name - the same rule)
      abs-dev          '<src>\prn.zip'
      space-dots       ' ..'               (feature 317 - stays refused)
      Packed (controls):
      ctl-plain        item 0: 'plain.zip'
      ctl-mid-dot      'report.v1.zip'
      ctl-console      'CONSOLE.zip'       (a device name only as a prefix)
      ctl-con-word     'con bla.zip'       (not a device name: a word follows)
      ctl-com10        'COM10.zip'         (two digits: not a device)
      ctl-lead-space   ' typed.zip'        (feature 317 - keeps the leading space)
      ctl-dot-start    '.cfg.zip'
      ctl-empty        '' : "Empty name has no sense here." (unchanged)
    Not driven: typing with a keyboard (WM_SETTEXT), external archivers.
    Driver of 317's probe (098's library). MUST run through tools\run_on_hidden_desktop.ps1.
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
if (-not ('Cb318' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class Cb318
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
$Root = $TempRoot + '\tc318_pack'
$StartDir = $Root + '\start'
$PackKey = $RegKey + '\0.1\Packers & Unpackers\Custom Packers'
$CnfKey = $RegKey + '\0.1\Configuration\Confirmation'
$Sup1 = [string][char]0x00B9   # superscript one

function Vis([string]$s) { if ($s.Length -gt 60) { $s = '...(' + $s.Length + ') ' + $s.Substring($s.Length - 30) }; $s = $s -replace ' ', '<sp>'; $s = $s.Replace($Sup1, '<sup1>'); return ("'" + $s + "'") }
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
# can a program that uses the plain Win32 path (no \\?\) open the file?
function Plain-Open([string]$Path) {
    try { $s = [IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite'); try { $b = $s.ReadByte(); return ('yes (first byte {0})' -f $b) } finally { $s.Dispose() } }
    catch { return ('no: ' + $_.Exception.GetType().Name) }
}
function Start-TcPk([string]$Left, [string]$Right) {
    $a = @('-t', 'T318', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
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
# answers every window except $Keep: any box Yes / OK; the Pack dialog shown again is cancelled; until idle
function ServePk([int]$Id, $Keep = @(), [double]$Seconds = 60) {
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
            foreach ($want in @(6, 1)) { if (-not $pick) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $want } | Select-Object -First 1 } }
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

# one row. $Type: $null = item 0, else the text put into the entry ('<src>' is replaced by the src path).
# $Arc: the archive expected (rel to src) - $null = a refusal: nothing created, $AskRx shown.
function Pack-Row([string]$Case, $Type, $Arc, [string]$AskRx) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    $src = $d + '\src'
    $L = $d + '\tgt\L'
    NewDir ($src + '\plain'); NewDir $L
    WriteFile ($src + '\plain\f.txt') 'F'
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
        $items = @([Cb318]::Items($combo))
        if ($null -ne $Type) {
            if (-not [Drv098f]::SetText($combo, $Type, 5000)) { throw 'WM_SETTEXT into the entry failed' }
        }
        else {
            if ($items.Count -lt 1) { throw 'the combo box holds no item' }
            [void][Cb318]::Send($combo, 0x014E, 0)   # CB_SETCURSEL
        }
        Start-Sleep -Milliseconds 200
        $chosen = [Drv098f]::GetText($combo, 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = ServePk $id @($dlg) 60
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $stayed = [Drv098f]::IsWindow($dlg) -and [Drv098f]::IsWindowVisible($dlg)
        if ($stayed -and -not $fatal) { Close-Win $dlg; Start-Sleep -Milliseconds 500; [void](ServePk $id @() 15) }
        Start-Sleep -Milliseconds 500
        $snap1 = Snap $d
        $new = @($snap1.Keys | Where-Object { -not $snap0.ContainsKey($_) } | Sort-Object)
        $changed = @($snap0.Keys | Where-Object { -not $snap1.ContainsKey($_) -or $snap1[$_] -ne $snap0[$_] } | Sort-Object)
        $wantNew = @(); if ($Arc) { $wantNew = @('src\' + $Arc) }
        $c1 = ((@($new) -join '|') -ceq (@($wantNew) -join '|'))
        $c2 = ($changed.Count -eq 0)
        $entries = @(); if ($Arc -and $snap1.ContainsKey('src\' + $Arc)) { $entries = @(Zip-Entries ($src + '\' + $Arc)) }
        $c3 = (-not $Arc) -or (@($entries | Where-Object { $_.EndsWith('f.txt') }).Count -gt 0)
        $c4 = (-not $AskRx) -or (@($r.Messages | Where-Object { $_ -match $AskRx }).Count -gt 0)
        $plain = @($new | ForEach-Object { (Vis $_) + ' plain open: ' + (Plain-Open ($d + '\' + $_)) })
        $ok = (-not $fatal) -and (-not $r.TimedOut) -and (-not $stayed) -and $c1 -and $c2 -and $c3 -and $c4
        $why = ''
        if (-not $ok) { $why = (" [expected new {0}; no change; message '{1}']" -f (Join-Vis $wantNew), $AskRx) }
        Row $Case 'RUN' (V $ok) ("OK on {0}; dialog stayed: {1}; asked: {2}; new: {3}; changed: {4}; entries: {5}; {6}{7}{8}" -f (Vis $chosen), $stayed, (Shown $r), (Join-Vis $new), (Join-Vis $changed), (Join-Vis $entries), ($plain -join '; '), $(if ($r.TimedOut) { '; TIMED OUT' } else { '' }), $why)
    }
    catch {
        Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace)
        if ($id -and (Test-Alive $id)) { foreach ($h in @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { Close-Win $h } }
    }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- main --------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc318_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("pack318_probe (feature 318) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}; OS {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed, [Environment]::OSVersion.VersionString)
    Out ("Fixture {0}" -f $Root)
    Out ''
    $inv = 'path specified is invalid'
    Pack-Row 'trail-dot' 'report.' $null $inv
    Pack-Row 'trail-dots' 'report.zip..' $null $inv
    Pack-Row 'trail-space' 'report.zip ' $null $inv
    Pack-Row 'trail-dot-space' 'report. ' $null $inv
    Pack-Row 'dev-con' 'CON.zip' $null $inv
    Pack-Row 'dev-con-noext' 'con' $null $inv
    Pack-Row 'dev-nul-space' 'NUL .zip' $null $inv
    Pack-Row 'dev-com1' 'COM1.zip' $null $inv
    Pack-Row 'dev-lpt9-2ext' 'lpt9.tar.zip' $null $inv
    Pack-Row 'dev-com-sup' ('COM' + $Sup1 + '.zip') $null $inv
    Pack-Row 'abs-trail-dot' '<src>\abs.' $null $inv
    Pack-Row 'abs-dev' '<src>\prn.zip' $null $inv
    Pack-Row 'space-dots' ' ..' $null $inv
    Pack-Row 'ctl-plain' $null 'plain.zip' $null
    Pack-Row 'ctl-mid-dot' 'report.v1.zip' 'report.v1.zip' $null
    Pack-Row 'ctl-console' 'CONSOLE.zip' 'CONSOLE.zip' $null
    Pack-Row 'ctl-con-word' 'con bla.zip' 'con bla.zip' $null
    Pack-Row 'ctl-com10' 'COM10.zip' 'COM10.zip' $null
    Pack-Row 'ctl-lead-space' ' typed.zip' ' typed.zip' $null
    Pack-Row 'ctl-dot-start' '.cfg.zip' '.cfg.zip' $null
    Pack-Row 'ctl-empty' '' $null 'Empty name has no sense'
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
