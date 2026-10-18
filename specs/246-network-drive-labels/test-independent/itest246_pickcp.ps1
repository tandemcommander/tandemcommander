<#
.SYNOPSIS
    Feature 246 independent test, targeted: picking a remembered, unavailable network drive whose
    remote path holds characters outside the system code page (Cyrillic + CJK), named and unnamed,
    in the fixed build (seam: RESTORE line) and in the baseline (comparison).
.NOTES
    Run through tools\run_on_hidden_desktop.ps1. Windows PowerShell 5.1, pure ASCII.
    Backs up / restores HKCU\Software\Tandem Commander; removes every mapping, HKCU\Network key,
    MountPoints2 key and folder it created and verifies against a snapshot.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Fixed,
    [Parameter(Mandatory = $true)][string]$Baseline,
    [Parameter(Mandatory = $true)][string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Fixed = (Resolve-Path -LiteralPath $Fixed).Path
$Baseline = (Resolve-Path -LiteralPath $Baseline).Path
if (@(Get-Process tandemcommander -ErrorAction SilentlyContinue).Count) { Write-Output 'NOT RUN: tandemcommander.exe already runs'; exit 3 }
$Exe = $Fixed
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
. (Join-Path $repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not ('Tst246p' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Tst246p
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public class NETRESOURCE { public int dwScope, dwType, dwDisplayType, dwUsage; public string lpLocalName, lpRemoteName, lpComment, lpProvider; }
    [DllImport("mpr.dll", CharSet = CharSet.Unicode)] static extern int WNetAddConnection2W(NETRESOURCE nr, string pwd, string user, int flags);
    [DllImport("mpr.dll", CharSet = CharSet.Unicode)] static extern int WNetCancelConnection2W(string name, int flags, bool force);
    [DllImport("mpr.dll", CharSet = CharSet.Unicode)] static extern int WNetGetConnectionW(string local, StringBuilder remote, ref int len);
    [DllImport("kernel32.dll")] public static extern uint GetLogicalDrives();
    public static int Map(string letter, string remote, bool remember) { var nr = new NETRESOURCE(); nr.dwType = 1; nr.lpLocalName = letter; nr.lpRemoteName = remote; return WNetAddConnection2W(nr, null, null, remember ? 1 : 0); }
    public static int Cancel(string letter, bool forget) { return WNetCancelConnection2W(letter, forget ? 1 : 0, true); }
    public static string Conn(string letter, out int res) { var sb = new StringBuilder(4096); int len = 4096; res = WNetGetConnectionW(letter, sb, ref len); return sb.ToString(); }
    public static bool Listed(char letter) { return (GetLogicalDrives() & (1u << (char.ToUpperInvariant(letter) - 'A'))) != 0; }
}
'@
}

$Root = $TempRoot + '\tc246test'
$Fx = $Root + '\fx'
$StartDir = $Root + '\start'
$RegBackup = $Root + '\reg_backup.reg'
$Dump = $Root + '\dump_pick.txt'
$MP2 = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2'
$CfgKey = 'HKCU\Software\Tandem Commander\0.1\Configuration'
$Utf8 = New-Object Text.UTF8Encoding($false)
$script:Fails = 0
$script:Lines = New-Object System.Collections.ArrayList
function RowV([string]$Case, [string]$Step, [bool]$Ok, [string]$Facts) { $v = V $Ok; if (-not $Ok) { $script:Fails++ }; Row $Case $Step $v $Facts }
function KeyOf([string]$Remote) { return '##' + $Remote.Substring(2).TrimEnd('\').Replace('\', '#') }
function Snap {
    $s = [ordered]@{}
    $s.Network = @(Get-ChildItem 'HKCU:\Network' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName } | Sort-Object) -join ','
    $s.MP2 = @(Get-ChildItem $MP2 -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like '##*' } | ForEach-Object { $_.PSChildName } | Sort-Object) -join '|'
    $s.Drives = '{0:X8}' -f [Tst246p]::GetLogicalDrives()
    $s.NetUse = @((& net.exe use 2>&1) | Where-Object { $_ -match '\\\\' } | ForEach-Object { ($_ -replace '\s+', ' ').Trim() }) -join ' ; '
    return $s
}
function Dump-Lines { if (-not (Test-Path -LiteralPath $Dump)) { return @() }; $fs = New-Object IO.FileStream($Dump, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite); try { $t = (New-Object IO.StreamReader($fs, $Utf8)).ReadToEnd() } finally { $fs.Dispose() }; return @($t -split "`r`n" | Where-Object { $_ -ne '' }) }
function Bar-Idx([string]$Letter) {
    $mask = [Tst246p]::GetLogicalDrives()
    foreach ($n in @(Get-ChildItem 'HKCU:\Network' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName.ToUpper() })) { $mask = $mask -bor (1 -shl ([int][char]$n[0] - 65)) }
    $i = 0; for ($c = 0; $c -lt 26; $c++) { if ($mask -band (1 -shl $c)) { if ([string][char](65 + $c) -eq $Letter) { return $i }; $i++ } }
    return -1
}
function Start-P([string]$Path, [bool]$Seam) {
    if (@(Get-Process tandemcommander -ErrorAction SilentlyContinue).Count) { throw 'another instance runs' }
    & reg.exe add $CfgKey /v 'Show Drive Bar' /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add $CfgKey /v 'Show Drive Bar2' /t REG_DWORD /d 0 /f | Out-Null
    if ($Seam) { $env:TC_PROBE_DRIVES_DUMP = $Dump } else { Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue }
    $p = Start-Process -FilePath $Path -ArgumentList @('-t', 'T246P', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1') -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'no main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 1500
    [void](Serve $p.Id 6)
    Post-Cmd (Get-Main $p.Id) 756   # two drive bars
    Start-Sleep -Milliseconds 1500; [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    return $p.Id
}
function Close-P([int]$Id) {
    if (-not (Test-Alive $Id)) { return 'gone' }
    [void][Drv098f]::PostMessageW((Get-Main $Id), 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) { Start-Sleep -Milliseconds 200 }
    if (Test-Alive $Id) { Kill-Mine $Id; return 'killed' }
    return ('exit ' + (ExitCodeOf $Id))
}

$snapBefore = Snap
Out ("246 pick (code page) test; fixed {0}; baseline {1}" -f $Fixed, $Baseline)
Out ("snapshot before: drives {0}; HKCU\Network [{1}]; net use [{2}]" -f $snapBefore.Drives, $snapBefore.Network, $snapBefore.NetUse)
$existed = $false; $regOk = $true
$Mapped = New-Object System.Collections.ArrayList
$MyKeys = New-Object System.Collections.ArrayList
$before = Reports
try {
    if (Test-Path -LiteralPath $Root) { Remove-Item -LiteralPath $Root -Recurse -Force }
    [void](New-Item -ItemType Directory -Path $Fx, $StartDir -Force)
    $existed = Backup-Reg $RegBackup
    if (-not $existed) { throw 'no product registry key' }
    Set-Config
    $Cyr = [string]([char]0x0410) + [char]0x0440 + [char]0x0445 + [char]0x0438 + [char]0x0432
    $Cjk = [string]([char]0x4E2D) + [char]0x6587 + [char]0x6863
    $free = @(); foreach ($c in [char[]]'ZYXWVUTSRQPONMLKJIH') { if (-not [Tst246p]::Listed($c) -and -not (Test-Path ('HKCU:\Network\' + $c))) { $free += [string]$c } }
    $D = @(
        @{ Case = 'Q1'; Dir = ('unnamed_' + $Cjk + '_' + $Cyr); Name = $null; Letter = $free[0] },
        @{ Case = 'Q2'; Dir = ('named_' + $Cyr); Name = 'Named CP'; Letter = $free[1] }
    )
    foreach ($e in $D) {
        $dir = Join-Path $Fx $e.Dir
        [void](New-Item -ItemType Directory -Path $dir -Force)
        [IO.File]::WriteAllText((Join-Path $dir ('marker_' + $e.Case + '.txt')), $e.Case)
        $e.Remote = '\\localhost\C$' + $dir.Substring(2)
        $r = [Tst246p]::Map(($e.Letter + ':'), $e.Remote, $true); if ($r -ne 0) { throw ('map failed ' + $r) }
        [void]$Mapped.Add($e.Letter)
        [void]$MyKeys.Add((KeyOf $e.Remote))
        if ($e.Name) { $k = $MP2 + '\' + (KeyOf $e.Remote); if (-not (Test-Path -LiteralPath $k)) { [void](New-Item -Path $MP2 -Name (KeyOf $e.Remote) -Force) }; Set-ItemProperty -LiteralPath $k -Name '_LabelFromReg' -Value $e.Name -Type String }
        Out ("  fixture {0}: {1}: -> {2}; name {3}" -f $e.Case, $e.Letter, (Esc $e.Remote), $e.Name)
    }
    foreach ($build in @('fixed', 'baseline')) {
        foreach ($e in $D) { [void][Tst246p]::Cancel(($e.Letter + ':'), $false) }   # remembered, unavailable
        $rr = 0; foreach ($e in $D) { [void][Tst246p]::Conn(($e.Letter + ':'), [ref]$rr); Out ("  [{0}] {1}: listed {2}; WNetGetConnection {3}" -f $build, $e.Letter, [Tst246p]::Listed($e.Letter[0]), $rr) }
        $id = Start-P $(if ($build -eq 'fixed') { $Fixed } else { $Baseline }) ($build -eq 'fixed')
        foreach ($e in $D) {
            $idx = Bar-Idx $e.Letter
            $mark = (Dump-Lines).Count
            $sw = [Diagnostics.Stopwatch]::StartNew()
            Post-Cmd (Get-Main $id) (3500 + $idx)
            $r = Serve $id 40
            $el = $sw.Elapsed.TotalSeconds
            $l = Dump-Lines; $dl = @(); if ($l.Count -gt $mark) { $dl = @($l[$mark..($l.Count - 1)]) }
            $rest = @($dl | Where-Object { $_ -like ('RESTORE ' + $e.Letter + ' *') -or $_ -like ('NORESTORE ' + $e.Letter + ' *') })
            $listed = [Tst246p]::Listed($e.Letter[0])
            $loc = Get-Loc $id
            $okLoc = $loc -like ($e.Letter + ':\*')
            $facts = ("{0}: idx {1}; seam: '{2}'; listed after {3}; panel '{4}'; {5:N1} s; windows: {6}" -f $e.Letter, $idx, (Esc ($rest -join ' / ')), $listed, (Esc $loc), $el, (Msgs $r))
            if ($build -eq 'fixed') {
                $exact = $rest.Count -ge 1 -and $rest[0] -ceq ('RESTORE ' + $e.Letter + ' ' + $e.Remote)
                # round 2: accepted as out of scope (pre-existing, baseline identical; FR-009 reworded) -> INFO
                Row ('PK-' + $e.Case) 'FIXED' 'INFO' (('reconnected exactly: {0}; ' -f ($exact -and $listed -and $okLoc -and $r.Messages.Count -eq 0)) + $facts)
            }
            else { Row ('PK-' + $e.Case) 'BASE' 'INFO' $facts }
        }
        $fatal = Fatal-Win $id
        $cl = Close-P $id
        Row ('PK-' + $build) 'END' $(if ($null -eq $fatal -and $cl -eq 'exit 0x00000000') { 'PASS' } else { $script:Fails++; 'FAIL' }) ("fatal {0}; {1}" -f $fatal, $cl)
    }
    $rep = Take-Reports $before
    RowV 'PK' 'REPORTS' ($rep.Count -eq 0) ("new crash reports: {0}" -f $rep.Count)
}
catch { $script:Fails++; Out ('TEST ERROR: ' + $_.Exception.Message + ' at ' + $_.InvocationInfo.PositionMessage) }
finally {
    foreach ($p in $Started) { if (Test-Alive $p) { Kill-Mine $p } }
    Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue
    foreach ($l in $Mapped) { [void][Tst246p]::Cancel(($l + ':'), $true); if ($snapBefore.Network -split ',' -notcontains $l) { Remove-Item -LiteralPath ('HKCU:\Network\' + $l) -Recurse -Force -ErrorAction SilentlyContinue } }
    for ($pass = 0; $pass -lt 3; $pass++) {
        foreach ($k in @($MyKeys) + @(Get-ChildItem $MP2 -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like '##*tc246test*' -and ($snapBefore.MP2 -split '\|') -notcontains $_.PSChildName } | ForEach-Object { $_.PSChildName })) { Remove-Item -LiteralPath ($MP2 + '\' + $k) -Recurse -Force -ErrorAction SilentlyContinue }
        Start-Sleep -Milliseconds 1500
    }
    if ($existed) { $regOk = Restore-Reg $RegBackup $existed }
    try { if (Test-Path -LiteralPath $Fx) { Remove-Item -LiteralPath $Fx -Recurse -Force } } catch { Out ('cleanup: ' + $_.Exception.Message) }
    $snapAfter = Snap
    $same = ($snapAfter.Network -eq $snapBefore.Network) -and ($snapAfter.MP2 -eq $snapBefore.MP2) -and ($snapAfter.Drives -eq $snapBefore.Drives) -and ($snapAfter.NetUse -eq $snapBefore.NetUse)
    if (-not $same) { $script:Fails++ }
    Out ("cleanup verified: {0} (drives {1}->{2}; HKCU\Network [{3}]->[{4}]; MountPoints2 equal {5}; net use [{6}]->[{7}]); registry restored: {8}" -f $same, $snapBefore.Drives, $snapAfter.Drives, $snapBefore.Network, $snapAfter.Network, ($snapAfter.MP2 -eq $snapBefore.MP2), $snapBefore.NetUse, $snapAfter.NetUse, $regOk)
    Out ("RESULT: {0} FAIL row(s)" -f $script:Fails)
    [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, $Utf8)
}
exit $script:Fails
