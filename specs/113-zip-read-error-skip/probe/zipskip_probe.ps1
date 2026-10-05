<#
.SYNOPSIS
    Feature 113 probe: a member is deleted only if the file replacing it is stored. A file being
    added into an archive that cannot be opened or read while packing, answered Skip / Skip all /
    Cancel (or a cancelled progress), must leave the member it was to replace in the archive.

.DESCRIPTION
    Derived from specs\110-zip-plugin-name-matching\probe\zipname_probe.ps1 (same driving, same
    registry handling). Every case: an archive written by zipskip.py (ZIP: plain, ZipCrypto,
    AES-256 members, zip64 central records, data descriptors, comments, extra blocks, Unix host;
    7z through 7z.exe), member i holding "content-of-member-<i>", source files holding
    "content-of-source-<tag>" (or random bytes). One instance of -Exe per case, on the hidden
    desktop. F5 (727) / F6 (728) of everything in the left panel (the source folder) into the
    archive shown in the right panel.
    Read errors are made by this script while the operation runs:
      open   the source held open by this script for writing (FileShare ReadWrite+Delete): the ZIP
             overwrite question still opens it, the packing (FILE_SHARE_READ) does not - "cannot open"
      range  the source held open for reading with a byte-range lock from 1 MB on: it opens, the
             read of the locked range fails - an I/O error in the middle of the file
    Windows answered:
      "Confirm File Overwrite" (buttons 6 / 173)  from the case's Answers (6 Yes, 185 All, 173 Skip)
      the error dialog (has Retry = 4)             from the case's Err list: S Skip, A Skip all,
                                                    C Cancel, R release the locks then Retry,
                                                    SC Skip when offered, else Cancel; buttons recorded
      the ZIP options dialog (edits 107 / 108)      Encrypt (106) + method (121 ZIP 2.0 / 123 AES-256)
                                                    + password pass113, when the case asks for it
      the progress window                           Cancel after CancelProgress seconds, when asked
      anything else                                 OK / Yes
    The archive is read back by zipskip.py (own reader: structure, overlaps, CRC / AES MAC, every
    entry decoded; Python's zipfile as a second opinion; 7z.exe for 7z). A row PASSes when the
    file entries are exactly the expected set (name -> content tag), the archive checks clean, the
    members listed in Keep are byte-identical to before (local header + data + descriptor, and
    the central record except its offset), the files in Disk are still on disk unchanged, the
    files in Gone are gone (a Move), and the counts of questions / error dialogs match.
    Expectations are this feature's rule; the build before shows the losses.
    -Scratch <folder>: fixtures and the registry backup go there (default %TEMP%\tc113).
    MUST be started through tools\run_on_hidden_desktop.ps1 (refuses the Default desktop).
    Refuses to run while another tandemcommander.exe is running. HKCU\Software\Tandem Commander
    exported before, restored and verified after. Pure ASCII; Windows PowerShell 5.1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python',
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe',
    [string]$Scratch = ''
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }
# only on a desktop of its own (tools\run_on_hidden_desktop.ps1), never on the user's (as 112's probe)
if (-not ('Desk113' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Desk113
{
    [DllImport("user32.dll")] public static extern IntPtr GetThreadDesktop(uint threadId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool GetUserObjectInformationW(IntPtr h, int index, StringBuilder info, int length, out int needed);
    public static string Name()
    {
        var sb = new StringBuilder(256); int needed;
        if (!GetUserObjectInformationW(GetThreadDesktop(GetCurrentThreadId()), 2, sb, sb.Capacity * 2, out needed)) return "";
        return sb.ToString();
    }
}
'@
}
$deskName = [Desk113]::Name()
if (-not $deskName -or $deskName -ieq 'Default' -or $deskName -ieq 'Winlogon') { Write-Output ("NOT RUN: this probe must run on a hidden desktop (tools\run_on_hidden_desktop.ps1); the current desktop is '{0}'" -f $deskName); exit 3 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not $Scratch) { $Scratch = $TempRoot + '\tc113' }
$Scratch = [IO.Path]::GetFullPath($Scratch).TrimEnd('\')
$Root = $Scratch + '\zs'
$StartDir = $Root
$RegCfg = 'HKCU\Software\Tandem Commander\0.1'
$RegZip = "$RegCfg\Plugins Configuration\ZIP"
$Password = 'pass113'
$ZipSkip = Join-Path $PSScriptRoot 'zipskip.py'
$script:Table = New-Object System.Collections.ArrayList
$script:LockStreams = New-Object System.Collections.ArrayList

function Set-ProbeConfig {
    & cmd.exe /c "reg query `"$RegCfg\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    & reg.exe add "$RegCfg\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
    & reg.exe add "$RegCfg\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add "$RegCfg\Configuration\Confirmation" /v 'Close Archive' /t REG_DWORD /d 1 /f | Out-Null
    return $true
}
# per case: the ZIP plug-in's "temporary copy" option and its options dialog (read at plug-in load)
function Set-ZipConfig([int]$Backup, [int]$ShowOptions) {
    & reg.exe add $RegZip /v 'Backup ZIP' /t REG_DWORD /d $Backup /f | Out-Null
    & reg.exe add $RegZip /v 'Show Extended Options' /t REG_DWORD /d $ShowOptions /f | Out-Null
}

function Invoke-ZipSkip([string]$Verb, $Spec) {
    $file = Join-Path $Root 'spec.json'
    [IO.File]::WriteAllText($file, (ConvertTo-Json $Spec -Depth 6 -Compress), $Utf8)
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $Python $ZipSkip $Verb $file 2>&1
    $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0) { throw ("zipskip.py $Verb failed: " + (($o | ForEach-Object { "$_" }) -join ' ')) }
    return @($o | ForEach-Object { "$_" })
}

# ---- locks held by this script while the operation runs -------------------------------------
function Lock-Source([string]$Path, [string]$Mode, [long]$At) {
    $share = [IO.FileShare]::ReadWrite -bor [IO.FileShare]::Delete
    if ($Mode -eq 'open') {
        $fs = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, $share)
    }
    else {
        $fs = [IO.File]::Open($Path, [IO.FileMode]::Open, [IO.FileAccess]::Read, $share)
        $fs.Lock($At, $fs.Length - $At)
    }
    [void]$script:LockStreams.Add($fs)
}
function Release-Locks {
    foreach ($fs in @($script:LockStreams)) { try { $fs.Dispose() } catch { } }
    $script:LockStreams.Clear()
}

function Start-Two([string]$Left, [string]$Right) {
    $a = @('-t', 'T113', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 2500
    return $p.Id
}

# serves the windows of the operation (see the header)
function Drive([int]$Id, [int[]]$Answers, [string[]]$Err, $Enc, [double]$CancelProgress, [double]$Seconds = 120) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null; TimedOut = $false; Q = 0; E = 0; SkipOffered = 0
        Options = 0; ProgressSeen = $false; ProgressCancelled = $null
    }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($true) {
        if ($sw.Elapsed.TotalSeconds -gt $Seconds) { $r.TimedOut = $true; break }
        if (-not (Test-Alive $Id)) { break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.5) { break }
            Start-Sleep -Milliseconds 100; continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv098f]::IsWindow($h)) { continue }
            $d = WinDesc $h
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            if (-not [Drv098f]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if (($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)) {   # progress
                if ($ids.Count -eq 1) { $r.ProgressSeen = $true }
                if ($CancelProgress -gt 0 -and $ids.Count -eq 1 -and $null -eq $r.ProgressCancelled -and
                    $sw.Elapsed.TotalSeconds - [double]$seen[$key] -ge $CancelProgress) {
                    $r.ProgressCancelled = $sw.Elapsed.TotalSeconds
                    [void]$r.Messages.Add(('PROGRESS CANCELLED at {0:N1} s' -f $sw.Elapsed.TotalSeconds))
                    Click $btn[0]
                }
                continue
            }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $seen.Remove($key)
            if ($ids -contains 173 -and $ids -contains 6) {   # overwrite question
                $a = 6; if ($r.Q -lt $Answers.Count) { $a = $Answers[$r.Q] }
                $r.Q++
                $q = ("Q{0}: {1} -> {2}" -f $r.Q, (FullText $h), @{ 6 = 'Yes'; 185 = 'All'; 173 = 'Skip'; 174 = 'Skip All'; 2 = 'Cancel' }[$a])
                [void]$r.Messages.Add($q)
                $b = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $a } | Select-Object -First 1
                if ($b) { Click $b } else { Close-Win $h }
                Start-Sleep -Milliseconds 500; continue
            }
            if ((Find-Ctl $h 107) -ne [IntPtr]::Zero -and (Find-Ctl $h 108) -ne [IntPtr]::Zero) {   # ZIP options
                $r.Options++
                if ($Enc) {
                    $kid = { param($n) @([Drv098f]::Kids($h) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $n }) | Select-Object -First 1 }
                    Click (& $kid 106); Start-Sleep -Milliseconds 400; [void][Drv098f]::Send($h, 0, 0, 0, 5000)
                    Click (& $kid ([int]$Enc)); Start-Sleep -Milliseconds 300; [void][Drv098f]::Send($h, 0, 0, 0, 5000)
                    [void][Drv098f]::SetText((Find-Ctl $h 107), $Password, 5000)
                    [void][Drv098f]::SetText((Find-Ctl $h 108), $Password, 5000)
                    [void]$r.Messages.Add(('OPTIONS: encrypt, method {0}' -f $Enc))
                }
                else { [void]$r.Messages.Add('OPTIONS: OK') }
                Click-Ok $h; Start-Sleep -Milliseconds 500; continue
            }
            if ($ids -contains 4) {   # the error dialog (Retry ...)
                $want = 'C'; if ($r.E -lt $Err.Count) { $want = $Err[$r.E] }
                $r.E++
                if ($ids -contains 173) { $r.SkipOffered++ }
                $pickId = 2
                switch ($want) {
                    'S' { $pickId = 173 }
                    'A' { $pickId = 174 }
                    'C' { $pickId = 2 }
                    'R' { Release-Locks; Start-Sleep -Milliseconds 300; $pickId = 4 }
                    'SC' { if ($ids -contains 173) { $pickId = 173 } else { $pickId = 2 } }
                }
                $b = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $pickId } | Select-Object -First 1
                if (-not $b) { $b = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq 2 } | Select-Object -First 1; $pickId = 2 }
                [void]$r.Messages.Add(("E{0}: buttons {1}: {2} -> {3}" -f $r.E, ($ids -join ','), (FullText $h), $pickId))
                if ($b) { Click $b } else { Close-Win $h }
                Start-Sleep -Milliseconds 500; continue
            }
            [void]$r.Messages.Add($d)
            $pick = $btn | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1
            if ($pick) { Click $pick } else { Close-Win $h }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 150
    }
    return $r
}
function DMsgs($r) { if ($r.Messages.Count) { return ((@($r.Messages | ForEach-Object { if ($_.Length -gt 300) { $_.Substring(0, 300) + '...' } else { $_ } })) -join ' || ') } else { return 'no window' } }

function Quit([int]$Id) {
    $notes = @()
    if (-not (Test-Alive $Id)) { return 'not running' }
    [void][Drv098f]::PostMessageW((Get-Main $Id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) {
        foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' })) { $d = WinDesc $h; if ($d -notmatch 'monitored handles') { $notes += ('at exit: ' + $d) }; $b = Buttons $h | Where-Object { @(1, 6) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($b) { Click $b } }
        Start-Sleep -Milliseconds 200
    }
    if (Test-Alive $Id) { Kill-Mine $Id; $notes += 'did not exit in 30 s - ended by the probe' }
    Start-Sleep -Milliseconds 500
    return ('exit ' + (ExitCodeOf $Id) + $(if ($notes.Count) { '; ' + ($notes -join ' || ') } else { '' }))
}

function Parse-Read($Read) {
    $m = New-Object 'System.Collections.Generic.Dictionary[string,object]'   # ordinal: ax.txt / Ax.txt / AX.txt are three
    foreach ($l in $Read) {
        $x = [regex]::Match($l, '^ENTRY (.*) kind=(\w+) tag=(\S+) enc=(\S+) ok=(\d) cd=(\S+) lh=(\S+)$')
        if ($x.Success) { $m[$x.Groups[1].Value] = [pscustomobject]@{ Kind = $x.Groups[2].Value; Tag = $x.Groups[3].Value; Enc = $x.Groups[4].Value; Ok = $x.Groups[5].Value; Cd = $x.Groups[6].Value; Lh = $x.Groups[7].Value } }
    }
    return , $m
}

function Run-Case($c) {
    if (-not (Want $c.N)) { return }
    $dir = $Root + '\' + $c.N
    [void][IO.Directory]::CreateDirectory($dir)
    $kind = 'zip'; if ($c.Kind) { $kind = $c.Kind }
    $arc = $dir + '\arc.' + $kind
    $src = $dir + '\src'
    [void][IO.Directory]::CreateDirectory($src)
    $files = @(); foreach ($s in @($c.Src)) { if ($s) { $files += @{ path = ($src + '\' + $s.P); tag = $s.T; size = $s.Size; random = $s.Random } } }
    $spec = @{ arc = $arc; kind = $kind; pw = $Password; sevenzip = $SevenZip; members = @($c.Members); files = $files }
    [void](Invoke-ZipSkip 'make' $spec)
    $before = Parse-Read (Invoke-ZipSkip 'read' $spec)
    $diskHash = @{}; foreach ($s in @($c.Src)) { if ($s) { $diskHash[$s.P] = (Get-FileHash -LiteralPath ($src + '\' + $s.P)).Hash } }
    $tmpBefore = @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp'))
    $rep = Reports
    Out ''
    Out ("--- {0} [{1}, {2}{3}] {4}" -f $c.N, $c.Route, $kind, $(if ($kind -eq 'zip') { $(if ($c.Backup -eq 0) { ', in-place' } else { ', temporary copy' }) } else { '' }), $c.What)
    $row = [ordered]@{ Case = $c.N; Route = $c.Route; Verdict = 'NOT DRIVEN'; Facts = ''; Why = '' }
    $id = 0
    try {
        $backup = 1; if ($null -ne $c.Backup) { $backup = $c.Backup }
        Set-ZipConfig $backup $(if ($c.Enc) { 1 } else { 0 })
        foreach ($l in @($c.Locks)) { if ($l) { $at = 1048576; if ($l.At) { $at = $l.At }; Lock-Source ($src + '\' + $l.P) $l.M $at } }
        $answers = @(); if ($c.Answers) { $answers = @($c.Answers) }
        $err = @(); if ($c.Err) { $err = @($c.Err) }
        $cancelAt = 0.0; if ($c.CancelProgress) { $cancelAt = [double]$c.CancelProgress }
        $id = Start-Two $src $arc
        $r0 = Drive $id @() @() $null 0 6; if ($r0.Messages.Count) { Out ('   at start: ' + (DMsgs $r0)) }
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 600
        $dlg = Open-ByCmd $id $(if ($c.Route -eq 'move') { 728 } else { 727 })
        if ($dlg -eq [IntPtr]::Zero) { throw 'Copy/Move opened no window' }
        $t = [Drv098f]::GetText((Find-Ctl $dlg 210), 5000)
        Click-Ok $dlg; Start-Sleep -Milliseconds 400
        $r = Drive $id $answers $err $c.Enc $cancelAt 180
        Out ("   {0} target '{1}'; windows: {2}" -f $(if ($c.Route -eq 'move') { 'F6' } else { 'F5' }), (Tail $t 60), (DMsgs $r))
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        if ($fatal) { throw ('FATAL ' + $fatal) }
        $ex = Quit $id
        Release-Locks
        $newRep = @((Reports) | Where-Object { $rep -notcontains $_ })
        foreach ($n in $newRep) { Remove-Item -LiteralPath (Join-Path $ReportDir $n) -Force -ErrorAction SilentlyContinue }
        $read = Invoke-ZipSkip 'read' $spec
        foreach ($l in $read) { Out ('          ' + $l) }
        $after = Parse-Read $read
        $why = @()
        $chk = @($read | Where-Object { $_ -like 'CHECK *' })
        if (-not $chk.Count -or $chk[0] -ne 'CHECK ok') { $why += ('archive check: ' + ($chk -join ' ')) }
        $zf = @($read | Where-Object { $_ -like 'ZIPFILE *' })
        if ($zf.Count -and $zf[0] -ne 'ZIPFILE ok') { $why += ('zipfile: ' + $zf[0]) }
        $got = @(); foreach ($k in $after.Keys) { $e = $after[$k]; if ($e.Kind -ne 'file') { continue }; if ($e.Ok -eq '1') { $got += ('{0}={1}' -f $k, $e.Tag) } else { $got += ('{0}=CORRUPT' -f $k) } }
        $exp = @($c.Expect)
        foreach ($e in $exp) { if (@($got | Where-Object { [string]::Equals($_, $e, [StringComparison]::Ordinal) }).Count -ne 1) { $why += ('expected ' + $e) } }
        foreach ($g in $got) { if (@($exp | Where-Object { [string]::Equals($_, $g, [StringComparison]::Ordinal) }).Count -ne 1) { $why += ('unexpected ' + $g) } }
        foreach ($k in @($c.Keep)) {
            if (-not $k) { continue }
            if (-not $before.ContainsKey($k) -or -not $after.ContainsKey($k)) { $why += ('keep ' + $k + ': not in the archive'); continue }
            if ($before[$k].Lh -ne $after[$k].Lh) { $why += ('keep ' + $k + ': member bytes changed') }
            if ($before[$k].Cd -ne $after[$k].Cd) { $why += ('keep ' + $k + ': central record changed (offset excluded)') }
        }
        foreach ($p in @($c.Disk)) {
            if (-not $p) { continue }
            $f = $src + '\' + $p
            if (-not [IO.File]::Exists($f)) { $why += ('source ' + $p + ' gone from disk') }
            elseif ((Get-FileHash -LiteralPath $f).Hash -ne $diskHash[$p]) { $why += ('source ' + $p + ' changed') }
        }
        foreach ($p in @($c.Gone)) { if ($p -and [IO.File]::Exists($src + '\' + $p)) { $why += ('source ' + $p + ' not deleted by the Move') } }
        if ($null -ne $c.Q -and $r.Q -ne $c.Q) { $why += ("{0} overwrite question(s), expected {1}" -f $r.Q, $c.Q) }
        if ($null -ne $c.E -and $r.E -ne $c.E) { $why += ("{0} error dialog(s), expected {1}" -f $r.E, $c.E) }
        if ($c.NoSkip -and $r.SkipOffered) { $why += ('Skip offered in {0} error dialog(s)' -f $r.SkipOffered) }
        if ($c.Enc -and $r.Options -lt 1) { $why += 'the ZIP options dialog did not appear' }
        if ($cancelAt -gt 0 -and $null -eq $r.ProgressCancelled) { $why += 'NOT DRIVEN: the operation ended before the progress could be cancelled' }
        if ($r.TimedOut) { $why += 'timed out' }
        if ($newRep.Count) { $why += "$($newRep.Count) crash report(s)" }
        if ($ex -notmatch '^exit 0x00000000') { $why += $ex }
        if (@($why | Where-Object { $_ -like 'NOT DRIVEN*' }).Count) { $row.Verdict = 'NOT DRIVEN' }
        elseif ($why.Count) { $row.Verdict = 'FAIL' } else { $row.Verdict = 'PASS' }
        $row.Facts = ('{0} | Q={1} E={2}' -f (($got | Sort-Object) -join ' '), $r.Q, $r.E)
        $row.Why = ($why -join '; ')
        Out ("   END: {0}" -f $ex)
        Out ("   VERDICT: {0} {1}" -f $row.Verdict, $row.Why)
    }
    catch {
        Out ('   exception: ' + $_.Exception.Message); $row.Why = 'NOT DRIVEN: ' + $_.Exception.Message
    }
    finally {
        Release-Locks
        if ($id -and (Test-Alive $id)) { Kill-Mine $id }
        Start-Sleep -Milliseconds 300
        foreach ($t in @([IO.Directory]::GetDirectories($TempRoot, 'SAL*.tmp') | Where-Object { $tmpBefore -notcontains $_ })) {
            Out ("   left in the temp folder by the test instance, removed: {0}" -f [IO.Path]::GetFileName($t))
            try { [IO.Directory]::Delete($t, $true) } catch { }
        }
        $stray = @([IO.Directory]::GetFiles($dir, 'Sal*.tmp'))   # the ZIP plug-in's temporary archive copy
        if ($stray.Count) { Out ('   temporary archive copy left beside the archive: ' + (($stray | ForEach-Object { [IO.Path]::GetFileName($_) }) -join ', ')) }
        [void]$script:Table.Add([pscustomobject]$row)
    }
}

# ---- main ---------------------------------------------------------------------
$backupDir = $Scratch + '\reg'
[void][IO.Directory]::CreateDirectory($backupDir)
$backupFile = Join-Path $backupDir 'backup.reg'
$existed = Backup-Reg $backupFile
$restored = $false
try {
    if ([IO.Directory]::Exists($Root)) { [IO.Directory]::Delete($Root, $true) }
    [void][IO.Directory]::CreateDirectory($Root)
    $cfg = Set-ProbeConfig
    Out ("zipskip_probe (feature 113) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; desktop '{2}'" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $deskName)
    if (-not $cfg) { throw 'no stored configuration - the probe cannot configure the program' }
    if (-not (Test-Path -LiteralPath $SevenZip)) { Out ("7-Zip   : {0} not found - the 7z rows are not driven" -f $SevenZip) }
    function M([string]$n) { return @{ name = $n } }
    function MX([string]$n, [hashtable]$x) { $h = @{ name = $n }; foreach ($k in $x.Keys) { $h[$k] = $x[$k] }; return $h }
    function SR([string]$p, [string]$t = 'S1', [long]$size = 0, [bool]$rnd = $false) { return @{ P = $p; T = $t; Size = $size; Random = $rnd } }
    $big = 2097152          # 2 MB: the range lock starts at 1 MB
    $huge = 134217728       # 128 MB random: packing takes long enough to cancel the progress
    function LO([string]$p) { return @{ P = $p; M = 'open' } }
    function LR([string]$p) { return @{ P = $p; M = 'range' } }
    $cases = @(
        # ---- ZIP, temporary-copy mode (the default): the replaced member is copied back
        @{ N = 't_open_skip'; Route = 'copy'; What = 'F5 x.txt (cannot be opened while packing) into {x, y}: Yes, Skip'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt'), (SR 'other.txt' 'S2')); Locks = @((LO 'x.txt')); Answers = @(6); Err = @('S'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt') },
        @{ N = 't_open_skipall'; Route = 'copy'; What = 'as t_open_skip, Skip all'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt'), (SR 'other.txt' 'S2')); Locks = @((LO 'x.txt')); Answers = @(6); Err = @('A'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt') },
        @{ N = 't_open_cancel'; Route = 'copy'; What = 'as t_open_skip, Cancel'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt'), (SR 'other.txt' 'S2')); Locks = @((LO 'x.txt')); Answers = @(6); Err = @('C'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2'); Keep = @('x.txt', 'y.txt') },
        @{ N = 't_open_retry'; Route = 'copy'; What = 'as t_open_skip, the file released, Retry'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt'), (SR 'other.txt' 'S2')); Locks = @((LO 'x.txt')); Answers = @(6); Err = @('R'); Q = 1; E = 1; Expect = @('x.txt=sS1', 'y.txt=m2', 'other.txt=sS2') },
        @{ N = 't_read_skip'; Route = 'copy'; What = 'F5 x.txt (2 MB, read error at 1 MB) into {x, y}: Yes, Skip'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Answers = @(6); Err = @('S'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt') },
        @{ N = 't_read_skipall'; Route = 'copy'; What = 'as t_read_skip, Skip all'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Answers = @(6); Err = @('A'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt') },
        @{ N = 't_read_cancel'; Route = 'copy'; What = 'as t_read_skip, Cancel'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Answers = @(6); Err = @('C'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2'); Keep = @('x.txt', 'y.txt') },
        @{ N = 't_two'; Route = 'copy'; What = 'F5 x.txt (cannot be opened) and z.txt (read error) into {x, z, y}: Yes, Yes, Skip, Skip'; Members = @((M 'x.txt'), (M 'z.txt'), (M 'y.txt')); Src = @((SR 'x.txt'), (SR 'z.txt' 'S3' $big), (SR 'other.txt' 'S2')); Locks = @((LO 'x.txt'), (LR 'z.txt')); Answers = @(6, 6); Err = @('S', 'S'); Q = 2; E = 2; Expect = @('x.txt=m1', 'z.txt=m2', 'y.txt=m3', 'other.txt=sS2'); Keep = @('x.txt', 'z.txt') },
        @{ N = 't_three'; Route = 'copy'; What = 'F5 ax.txt (cannot be opened) into {ax, Ax, AX}: All, Skip - the three members it replaces come back'; Members = @((M 'ax.txt'), (M 'Ax.txt'), (M 'AX.txt')); Src = @((SR 'ax.txt'), (SR 'other.txt' 'S2')); Locks = @((LO 'ax.txt')); Answers = @(185); Err = @('S'); Q = 1; E = 1; Expect = @('ax.txt=m1', 'Ax.txt=m2', 'AX.txt=m3', 'other.txt=sS2'); Keep = @('ax.txt', 'Ax.txt', 'AX.txt') },
        @{ N = 't_move'; Route = 'move'; What = 'F6 x.txt (cannot be opened) into {x, y}: Yes, Skip - x stays in the archive and on disk'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt'), (SR 'other.txt' 'S2')); Locks = @((LO 'x.txt')); Answers = @(6); Err = @('S'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt'); Disk = @('x.txt'); Gone = @('other.txt') },
        @{ N = 't_zip64'; Route = 'copy'; What = 'members with zip64 central records (offset in the zip64 block), x read error, Skip'; Members = @((MX 'x.txt' @{ z64 = $true }), (MX 'y.txt' @{ z64 = $true })); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Answers = @(6); Err = @('S'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt', 'y.txt') },
        @{ N = 't_zc'; Route = 'copy'; What = 'x.txt a ZipCrypto member, x read error, Skip - it comes back and still opens'; Members = @((MX 'x.txt' @{ enc = 'zipcrypto' }), (M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Answers = @(6); Err = @('S'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt') },
        @{ N = 't_aes'; Route = 'copy'; What = 'x.txt an AES-256 member, x read error, Skip'; Members = @((MX 'x.txt' @{ enc = 'aes256' }), (M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Answers = @(6); Err = @('S'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt') },
        @{ N = 't_desc'; Route = 'copy'; What = 'x.txt with a data descriptor, a comment and a time-stamp block, x read error, Skip'; Members = @((MX 'x.txt' @{ desc = $true; comment = 'member comment'; xtra = $true }), (M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Answers = @(6); Err = @('S'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt') },
        @{ N = 't_unix'; Route = 'copy'; What = 'a Unix ZIP {x, y}, x cannot be opened, Skip'; Members = @((MX 'x.txt' @{ host = 'unix' }), (MX 'y.txt' @{ host = 'unix' })); Src = @((SR 'x.txt'), (SR 'other.txt' 'S2')); Locks = @((LO 'x.txt')); Answers = @(6); Err = @('S'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt') },
        @{ N = 't_normal'; Route = 'copy'; What = 'control: F5 x.txt into {x, y}, Yes, no error'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt'), (SR 'other.txt' 'S2')); Answers = @(6); Q = 1; E = 0; Expect = @('x.txt=sS1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('y.txt') },
        @{ N = 't_new_skip'; Route = 'copy'; What = 'control: F5 x.txt (not in the archive, read error) into {y}, Skip'; Members = @((M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Err = @('S'); Q = 0; E = 1; Expect = @('y.txt=m1', 'other.txt=sS2'); Keep = @('y.txt') },
        @{ N = 't_progress'; Route = 'copy'; What = 'control: F5 x.txt (128 MB) into {x, y}, Yes, the progress cancelled'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt' 'S1' $huge $true)); Answers = @(6); CancelProgress = 1.0; Q = 1; Expect = @('x.txt=m1', 'y.txt=m2'); Keep = @('x.txt', 'y.txt') },
        # ---- ZIP, files added with encryption (the options dialog)
        @{ N = 'e_aes_new_skip'; Route = 'copy'; What = 'F5 x.txt (read error) and other.txt into {y} with AES-256, Skip - x must not be stored'; Members = @((M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Enc = 123; Err = @('S'); Q = 0; E = 1; Expect = @('y.txt=m1', 'other.txt=sS2'); Keep = @('y.txt') },
        @{ N = 'e_aes_new_cancel'; Route = 'copy'; What = 'as e_aes_new_skip, Cancel - the operation ends'; Members = @((M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Enc = 123; Err = @('C'); Q = 0; E = 1; Expect = @('y.txt=m1'); Keep = @('y.txt') },
        @{ N = 'e_aes_move'; Route = 'move'; What = 'F6 x.txt (read error) and other.txt into {y} with AES-256, Skip - x stays on disk'; Members = @((M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Enc = 123; Err = @('S'); Q = 0; E = 1; Expect = @('y.txt=m1', 'other.txt=sS2'); Disk = @('x.txt'); Gone = @('other.txt') },
        @{ N = 'e_aes_repl'; Route = 'copy'; What = 'F5 x.txt (read error) into {x, y} with AES-256: Yes, Skip - the plain member comes back'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Enc = 123; Answers = @(6); Err = @('S'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt') },
        @{ N = 'e_zc_new_skip'; Route = 'copy'; What = 'control: as e_aes_new_skip with ZIP 2.0 encryption'; Members = @((M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Enc = 121; Err = @('S'); Q = 0; E = 1; Expect = @('y.txt=m1', 'other.txt=sS2'); Keep = @('y.txt') },
        # ---- ZIP, in-place mode (no temporary copy): packed first, the stored files' members deleted after
        @{ N = 'i_normal'; Route = 'copy'; Backup = 0; What = 'F5 x.txt into {a, x, b, c}, Yes: the compaction moves the added files'; Members = @((M 'a.txt'), (M 'x.txt'), (M 'b.txt'), (M 'c.txt')); Src = @((SR 'x.txt'), (SR 'other.txt' 'S2')); Answers = @(6); Q = 1; E = 0; Expect = @('a.txt=m1', 'x.txt=sS1', 'b.txt=m3', 'c.txt=m4', 'other.txt=sS2'); Keep = @('a.txt', 'b.txt', 'c.txt') },
        @{ N = 'i_two'; Route = 'copy'; Backup = 0; What = 'F5 x.txt and z.txt into {x, a, z, b}, Yes, Yes: two regions'; Members = @((M 'x.txt'), (M 'a.txt'), (M 'z.txt'), (M 'b.txt')); Src = @((SR 'x.txt'), (SR 'z.txt' 'S3' $big), (SR 'other.txt' 'S2')); Answers = @(6, 6); Q = 2; E = 0; Expect = @('x.txt=sS1', 'a.txt=m2', 'z.txt=sS3', 'b.txt=m4', 'other.txt=sS2'); Keep = @('a.txt', 'b.txt') },
        @{ N = 'i_open_skip'; Route = 'copy'; Backup = 0; What = 'F5 x.txt (cannot be opened) into {x, y}: Yes, Skip'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt'), (SR 'other.txt' 'S2')); Locks = @((LO 'x.txt')); Answers = @(6); Err = @('S'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt') },
        @{ N = 'i_read_skip'; Route = 'copy'; Backup = 0; What = 'F5 x.txt (read error) into {x, y}: Yes, Skip'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Answers = @(6); Err = @('S'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt') },
        @{ N = 'i_read_cancel'; Route = 'copy'; Backup = 0; What = 'as i_read_skip, Cancel'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Answers = @(6); Err = @('C'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2'); Keep = @('x.txt', 'y.txt') },
        @{ N = 'i_open_cancel'; Route = 'copy'; Backup = 0; What = 'as i_open_skip, Cancel'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt'), (SR 'other.txt' 'S2')); Locks = @((LO 'x.txt')); Answers = @(6); Err = @('C'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2'); Keep = @('x.txt', 'y.txt') },
        @{ N = 'i_mixed'; Route = 'copy'; Backup = 0; What = 'F5 x.txt (cannot be opened) and z.txt into {x, a, z}: Yes, Yes, Skip'; Members = @((M 'x.txt'), (M 'a.txt'), (M 'z.txt')); Src = @((SR 'x.txt'), (SR 'z.txt' 'S3'), (SR 'other.txt' 'S2')); Locks = @((LO 'x.txt')); Answers = @(6, 6); Err = @('S'); Q = 2; E = 1; Expect = @('x.txt=m1', 'a.txt=m2', 'z.txt=sS3', 'other.txt=sS2'); Keep = @('x.txt', 'a.txt') },
        @{ N = 'i_move'; Route = 'move'; Backup = 0; What = 'F6 x.txt (cannot be opened) into {x, y}: Yes, Skip'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt'), (SR 'other.txt' 'S2')); Locks = @((LO 'x.txt')); Answers = @(6); Err = @('S'); Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2', 'other.txt=sS2'); Keep = @('x.txt'); Disk = @('x.txt'); Gone = @('other.txt') },
        @{ N = 'i_zip64'; Route = 'copy'; Backup = 0; What = 'F5 y.txt into {x, y, z} with zip64 central records, Yes'; Members = @((MX 'x.txt' @{ z64 = $true }), (MX 'y.txt' @{ z64 = $true }), (MX 'z.txt' @{ z64 = $true })); Src = @((SR 'y.txt'), (SR 'other.txt' 'S2')); Answers = @(6); Q = 1; E = 0; Expect = @('x.txt=m1', 'y.txt=sS1', 'z.txt=m3', 'other.txt=sS2'); Keep = @('x.txt', 'z.txt') },
        @{ N = 'i_progress'; Route = 'copy'; Backup = 0; What = 'F5 x.txt (128 MB) into {x, y}, Yes, the progress cancelled'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt' 'S1' $huge $true)); Answers = @(6); CancelProgress = 1.0; Q = 1; Expect = @('x.txt=m1', 'y.txt=m2'); Keep = @('x.txt', 'y.txt') },
        @{ N = 'i_aes_new_skip'; Route = 'copy'; Backup = 0; What = 'F5 x.txt (read error) and other.txt into {y} with AES-256, Skip'; Members = @((M 'y.txt')); Src = @((SR 'x.txt' 'S1' $big), (SR 'other.txt' 'S2')); Locks = @((LR 'x.txt')); Enc = 123; Err = @('S'); Q = 0; E = 1; Expect = @('y.txt=m1', 'other.txt=sS2'); Keep = @('y.txt') },
        # ---- 7-Zip plug-in: a replacing file cannot be skipped (Retry / Cancel), a skipped file is not deleted by a Move
        @{ N = 's_repl'; Kind = '7z'; Route = 'copy'; What = 'F5 x.txt (cannot be opened) into a 7z {x, y}: Yes, Skip if offered, else Cancel'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt'), (SR 'other.txt' 'S2')); Locks = @((LO 'x.txt')); Answers = @(6); Err = @('SC'); NoSkip = $true; Q = 1; E = 1; Expect = @('x.txt=m1', 'y.txt=m2') },
        @{ N = 's_repl_retry'; Kind = '7z'; Route = 'copy'; What = 'as s_repl, the file released, Retry'; Members = @((M 'x.txt'), (M 'y.txt')); Src = @((SR 'x.txt'), (SR 'other.txt' 'S2')); Locks = @((LO 'x.txt')); Answers = @(6); Err = @('R'); Q = 1; E = 1; Expect = @('x.txt=sS1', 'y.txt=m2', 'other.txt=sS2') },
        @{ N = 's_move_new'; Kind = '7z'; Route = 'move'; What = 'F6 n.txt (not in the archive, cannot be opened) and other.txt into a 7z {y}: Skip - n.txt stays on disk'; Members = @((M 'y.txt')); Src = @((SR 'n.txt' 'S3'), (SR 'other.txt' 'S2')); Locks = @((LO 'n.txt')); Err = @('S'); Q = 0; E = 1; Expect = @('y.txt=m1', 'other.txt=sS2'); Disk = @('n.txt'); Gone = @('other.txt') }
    )
    foreach ($c in $cases) {
        if ($c.Kind -eq '7z' -and -not (Test-Path -LiteralPath $SevenZip)) { if (Want $c.N) { [void]$script:Table.Add([pscustomobject]@{ Case = $c.N; Route = $c.Route; Verdict = 'NOT DRIVEN'; Facts = ''; Why = 'no 7z.exe' }) }; continue }
        Run-Case $c
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    Release-Locks
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 500
    $restored = Restore-Reg $backupFile $existed
    if ($restored -and (Test-Path -LiteralPath $backupFile)) { Remove-Item -LiteralPath $backupFile -Force }
    if ($restored -and (Test-Path -LiteralPath $backupDir)) { Remove-Item -LiteralPath $backupDir -Recurse -Force }
    try { if ([IO.Directory]::Exists($Root)) { [IO.Directory]::Delete($Root, $true) } } catch { Out ("Fixture : could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    Out ''
    Out '=== summary ==='
    foreach ($t in $script:Table) { Out ('{0,-16} {1,-5} {2,-10} {3}{4}' -f $t.Case, $t.Route, $t.Verdict, $t.Facts, $(if ($t.Why) { ' | ' + $t.Why } else { '' })) }
    $np = @($script:Table | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Table | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Table | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ("TOTAL: {0} PASS / {1} FAIL / {2} NOT DRIVEN" -f $np, $nf, $nn)
    Out ("Left running: {0}; fixture removed: {1}; registry restored+identical: {2}" -f $leftover.Count, (-not [IO.Directory]::Exists($Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit 0
