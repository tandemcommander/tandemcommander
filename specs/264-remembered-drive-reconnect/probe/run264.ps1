<#
.SYNOPSIS
    Feature 264 probe: reconnecting a remembered, disconnected network drive whose remote path
    holds characters outside the code page or is long, from the drive bar (CDrivesList::ExecuteItem)
    and from a panel path change (CheckAndRestoreNetworkConnection); fixed build and, as the
    negative control, the baseline build.
.NOTES
    Run through tools\run_on_hidden_desktop.ps1. Windows PowerShell 5.1, pure ASCII. Extends
    specs\246-network-drive-labels\test-independent\itest246_pickcp.ps1 (style of
    specs\241-pack-long-nested-folder\probe\pack241_probe.ps1).
    Backs up / restores HKCU\Software\Tandem Commander; removes every mapping, HKCU\Network key,
    MountPoints2 key and folder it created and verifies against a snapshot. Fixture under %TEMP%.
    Rows:
      Q1  unnamed, CJK + Cyrillic          fixed: reconnected exactly       baseline: not (negative control)
      Q2  named, Cyrillic                  fixed: reconnected exactly       baseline: not
      L1  259 characters, Cyrillic tail    fixed: reconnected exactly       baseline: not
      A1  ASCII                            both: reconnected (control: the fixture works, nothing regressed)
      U1  saved path on a missing server   fixed: the exact path is tried, the Windows error is shown, not listed
      P1  panel path change to a Q1-type disconnected drive   fixed: reconnected, panel there; baseline: not
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Baseline = '',
    [Parameter(Mandatory = $true)][string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Baseline) { $Baseline = (Resolve-Path -LiteralPath ([Environment]::ExpandEnvironmentVariables($Baseline))).Path }
if (@(Get-Process tandemcommander -ErrorAction SilentlyContinue).Count) { Write-Output 'NOT RUN: tandemcommander.exe already runs'; exit 3 }
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
. (Join-Path $repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not ('Tst264' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Tst264
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

$Root = $TempRoot + '\tc264p'
$Fx = $Root + '\fx'
$StartDir = $Root + '\start'
$RegBackup = $Root + '\reg_backup.reg'
$Dump = $Root + '\dump.txt'
$MP2 = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2'
$CfgKey = 'HKCU\Software\Tandem Commander\0.1\Configuration'
$NoHost = '\\tc264-no-such-host\share'
$Utf8 = New-Object Text.UTF8Encoding($false)
$script:Fails = 0
$script:Lines = New-Object System.Collections.ArrayList
function RowV([string]$Case, [string]$Step, [bool]$Ok, [string]$Facts) { $v = V $Ok; if (-not $Ok) { $script:Fails++ }; Row $Case $Step $v $Facts }
function KeyOf([string]$Remote) { return '##' + $Remote.Substring(2).TrimEnd('\').Replace('\', '#') }
function Snap {
    $s = [ordered]@{}
    $s.Network = @(Get-ChildItem 'HKCU:\Network' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName } | Sort-Object) -join ','
    $s.MP2 = @(Get-ChildItem $MP2 -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -like '##*' } | ForEach-Object { $_.PSChildName } | Sort-Object) -join '|'
    $s.Drives = '{0:X8}' -f [Tst264]::GetLogicalDrives()
    $s.NetUse = @((& net.exe use 2>&1) | Where-Object { $_ -match '\\\\' } | ForEach-Object { ($_ -replace '\s+', ' ').Trim() }) -join ' ; '
    return $s
}
function Dump-Lines { if (-not (Test-Path -LiteralPath $Dump)) { return @() }; $fs = New-Object IO.FileStream($Dump, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite); try { $t = (New-Object IO.StreamReader($fs, $Utf8)).ReadToEnd() } finally { $fs.Dispose() }; return @($t -split "`r`n" | Where-Object { $_ -ne '' }) }
function Bar-Idx([string]$Letter) {
    $mask = [Tst264]::GetLogicalDrives()
    foreach ($n in @(Get-ChildItem 'HKCU:\Network' -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName.ToUpper() })) { $mask = $mask -bor (1 -shl ([int][char]$n[0] - 65)) }
    $i = 0; for ($c = 0; $c -lt 26; $c++) { if ($mask -band (1 -shl $c)) { if ([string][char](65 + $c) -eq $Letter) { return $i }; $i++ } }
    return -1
}
function Start-P([string]$Path) {
    if (@(Get-Process tandemcommander -ErrorAction SilentlyContinue).Count) { throw 'another instance runs' }
    & reg.exe add $CfgKey /v 'Show Drive Bar' /t REG_DWORD /d 0 /f | Out-Null
    & reg.exe add $CfgKey /v 'Show Drive Bar2' /t REG_DWORD /d 0 /f | Out-Null
    $env:TC_PROBE_DRIVES_DUMP = $Dump
    $p = Start-Process -FilePath $Path -ArgumentList @('-t', 'T264', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1') -PassThru
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
# a folder under the fixture whose remote path (\\localhost\C$\...) is exactly 'len' characters,
# ending in 'tail'
function Make-Long([int]$Len, [string]$Tail) {
    $base = $Fx + '\long'
    $pre = '\\localhost\C$' + $base.Substring(2) + '\'
    $dir = $base
    $left = $Len - $pre.Length
    while ($left -gt 120) { $dir = $dir + '\' + ('p' * 100); $left -= 101 }
    $dir = $dir + '\' + ('q' * ($left - $Tail.Length)) + $Tail
    return $dir
}
# remembered connections of the fixture made "not connected" again (kept remembered); U1 gets
# its saved path pointed at a server that does not exist
function Disconnect-All($D) {
    foreach ($e in $D) { [void][Tst264]::Cancel(($e.Letter + ':'), $false) }
    foreach ($e in $D) { if ($e.Case -eq 'U1') { Set-ItemProperty -LiteralPath ('HKCU:\Network\' + $e.Letter) -Name 'RemotePath' -Value $NoHost -Type String } }
    $rr = 0
    foreach ($e in $D) { $c = [Tst264]::Conn(($e.Letter + ':'), [ref]$rr); Out ("  {0} {1}: listed {2}; WNetGetConnectionW {3} '{4}'" -f $e.Case, $e.Letter, [Tst264]::Listed($e.Letter[0]), $rr, (Tail $c 60)) }
}
function Seam-For([string]$Letter, [int]$Mark) {
    $l = Dump-Lines; $dl = @(); if ($l.Count -gt $Mark) { $dl = @($l[$Mark..($l.Count - 1)]) }
    return @($dl | Where-Object { $_ -like ('RESTORE ' + $Letter + ' *') -or $_ -like ('NORESTORE ' + $Letter + ' *') })
}

$snapBefore = Snap
Out ("264 probe; fixed {0}; baseline {1}" -f $Exe, $(if ($Baseline) { $Baseline } else { '-' }))
Out ("snapshot before: drives {0}; HKCU\Network [{1}]; net use [{2}]" -f $snapBefore.Drives, $snapBefore.Network, $snapBefore.NetUse)
$existed = $false; $regOk = $true
$Mapped = New-Object System.Collections.ArrayList
$MyKeys = New-Object System.Collections.ArrayList
$before = Reports
try {
    # an earlier interrupted run leaves its registry backup here: never delete it unrestored
    if (Test-Path -LiteralPath $RegBackup) { throw ('a registry backup of an earlier run exists - restore it first: ' + $RegBackup) }
    if (Test-Path -LiteralPath $Root) { cmd.exe /c rd /s /q ('\\?\' + $Root) | Out-Null }
    [void](New-Item -ItemType Directory -Path $Fx, $StartDir -Force)
    $existed = Backup-Reg $RegBackup
    if (-not $existed) { throw 'no product registry key' }
    Set-Config
    $Cyr = [string]([char]0x0410) + [char]0x0440 + [char]0x0445 + [char]0x0438 + [char]0x0432
    $Cjk = [string]([char]0x4E2D) + [char]0x6587 + [char]0x6863
    $free = @(); foreach ($c in [char[]]'ZYXWVUTSRQPONMLKJIH') { if (-not [Tst264]::Listed($c) -and -not (Test-Path ('HKCU:\Network\' + $c))) { $free += [string]$c } }
    if ($free.Count -lt 6) { throw 'not enough free drive letters' }
    $D = @(
        @{ Case = 'Q1'; Dir = ($Fx + '\unnamed_' + $Cjk + '_' + $Cyr); Name = $null; Letter = $free[0] },
        @{ Case = 'Q2'; Dir = ($Fx + '\named_' + $Cyr); Name = 'Named 264'; Letter = $free[1] },
        @{ Case = 'L1'; Dir = (Make-Long 259 ('_' + $Cyr)); Name = $null; Letter = $free[2] },
        @{ Case = 'A1'; Dir = ($Fx + '\ascii_only'); Name = $null; Letter = $free[3] },
        @{ Case = 'U1'; Dir = ($Fx + '\unreachable_' + $Cyr); Name = $null; Letter = $free[4] },
        @{ Case = 'P1'; Dir = ($Fx + '\panel_' + $Cjk + '_' + $Cyr); Name = $null; Letter = $free[5] }
    )
    foreach ($e in $D) {
        if (-not $e.Dir.StartsWith($Fx + '\')) { throw ('fixture outside the root: ' + $e.Dir) }
        [void](New-Item -ItemType Directory -Path ('\\?\' + $e.Dir) -Force)
        [IO.File]::WriteAllText(('\\?\' + $e.Dir + '\marker_' + $e.Case + '.txt'), $e.Case)
        $e.Remote = '\\localhost\C$' + $e.Dir.Substring(2)
        $r = [Tst264]::Map(($e.Letter + ':'), $e.Remote, $true); if ($r -ne 0) { throw ('map failed ' + $r + ' for ' + $e.Case) }
        [void]$Mapped.Add($e.Letter)
        [void]$MyKeys.Add((KeyOf $e.Remote))
        if ($e.Name) { $k = $MP2 + '\' + (KeyOf $e.Remote); if (-not (Test-Path -LiteralPath $k)) { [void](New-Item -Path $MP2 -Name (KeyOf $e.Remote) -Force) }; Set-ItemProperty -LiteralPath $k -Name '_LabelFromReg' -Value $e.Name -Type String }
        Out ("  fixture {0}: {1}: -> ({2} characters) {3}; name {4}" -f $e.Case, $e.Letter, $e.Remote.Length, (Tail $e.Remote 80), $e.Name)
    }
    [void]$MyKeys.Add((KeyOf $NoHost))
    $builds = @(@{ Name = 'fixed'; Path = $Exe })
    if ($Baseline) { $builds += @{ Name = 'baseline'; Path = $Baseline } }
    foreach ($b in $builds) {
        $isFixed = $b.Name -eq 'fixed'
        $tag = $(if ($isFixed) { 'FIXED' } else { 'BASE' })
        # --- picks in the drive bar (CDrivesList::ExecuteItem)
        Disconnect-All $D
        $id = Start-P $b.Path
        foreach ($e in @($D | Where-Object { $_.Case -ne 'P1' })) {
            $idx = Bar-Idx $e.Letter
            $mark = (Dump-Lines).Count
            $sw = [Diagnostics.Stopwatch]::StartNew()
            Post-Cmd (Get-Main $id) (3500 + $idx)
            $r = Serve $id 60
            $el = $sw.Elapsed.TotalSeconds
            $rest = @(Seam-For $e.Letter $mark)   # @(): a single line would be unrolled to a string
            $listed = [Tst264]::Listed($e.Letter[0])
            $loc = Get-Loc $id
            $okLoc = $loc -like ($e.Letter + ':\*')
            $wanted = $(if ($e.Case -eq 'U1') { $NoHost } else { $e.Remote })
            $exact = $rest.Count -ge 1 -and $rest[0] -ceq ('RESTORE ' + $e.Letter + ' ' + $wanted)
            $facts = ("{0}: idx {1}; seam exact {2} '{3}'; listed after {4}; panel '{5}'; {6:N1} s; windows: {7}" -f $e.Letter, $idx, $exact, (Tail ($rest -join ' / ') 70), $listed, (Tail $loc 40), $el, (Msgs $r))
            $reconnected = $listed -and $okLoc -and $r.Messages.Count -eq 0 -and $null -eq $r.Fatal
            if ($e.Case -eq 'U1') {
                $winErr = @($r.Messages | Where-Object { $_ -match '\(\d+\) ' }).Count -ge 1
                if ($isFixed) { RowV $e.Case $tag ($exact -and -not $listed -and -not $okLoc -and $winErr -and $null -eq $r.Fatal) ("Windows error shown {0}; {1}" -f $winErr, $facts) }
                else { Row $e.Case $tag 'INFO' ("Windows error shown {0}; {1}" -f $winErr, $facts) }
            }
            elseif ($e.Case -eq 'A1') { RowV $e.Case $tag ($reconnected -and ($exact -or -not $isFixed)) ("reconnected {0}; {1}" -f $reconnected, $facts) }
            elseif ($isFixed) { RowV $e.Case $tag ($reconnected -and $exact) ("reconnected {0}; {1}" -f $reconnected, $facts) }
            else { RowV $e.Case ($tag + '-NEG') (-not $reconnected) ("negative control (must not reconnect): reconnected {0}; {1}" -f $reconnected, $facts) }
        }
        $fatal = Fatal-Win $id
        $cl = Close-P $id
        RowV ('PICK-' + $b.Name) 'END' ($null -eq $fatal -and $cl -eq 'exit 0x00000000') ("fatal {0}; {1}" -f $fatal, $cl)
        # --- a panel path change to a disconnected remembered drive (CheckAndRestoreNetworkConnection)
        Disconnect-All $D
        $id = Start-P $b.Path
        $e = $D | Where-Object { $_.Case -eq 'P1' }
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $typed = Do-ChangeDir $id ($e.Letter + ':\')
        $r = Serve $id 60
        $el = $sw.Elapsed.TotalSeconds
        $listed = [Tst264]::Listed($e.Letter[0])
        $loc = Get-Loc $id
        $okLoc = $loc -like ($e.Letter + ':\*')
        $reconnected = $listed -and $okLoc -and $r.Messages.Count -eq 0 -and $null -eq $r.Fatal
        $facts = ("{0}: typed {1}; listed after {2}; panel '{3}'; {4:N1} s; windows: {5}" -f $e.Letter, $typed, $listed, (Tail $loc 40), $el, (Msgs $r))
        $c = 0; $conn = [Tst264]::Conn(($e.Letter + ':'), [ref]$c)
        $exactConn = $conn -ceq $e.Remote
        if ($isFixed) { RowV 'P1' $tag ($reconnected -and $exactConn) ("reconnected {0}; connected to the exact path {1}; {2}" -f $reconnected, $exactConn, $facts) }
        else { RowV 'P1' ($tag + '-NEG') (-not $reconnected) ("negative control (must not reconnect): reconnected {0}; {1}" -f $reconnected, $facts) }
        $fatal = Fatal-Win $id
        $cl = Close-P $id
        RowV ('PANEL-' + $b.Name) 'END' ($null -eq $fatal -and $cl -eq 'exit 0x00000000') ("fatal {0}; {1}" -f $fatal, $cl)
    }
    $rep = Take-Reports $before
    RowV 'ALL' 'REPORTS' ($rep.Count -eq 0) ("new crash reports: {0}" -f $rep.Count)
}
catch { $script:Fails++; Out ('TEST ERROR: ' + $_.Exception.Message + ' at ' + $_.InvocationInfo.PositionMessage) }
finally {
    foreach ($p in $Started) { try { if (Test-Alive $p) { Kill-Mine $p } } catch { Out ('cleanup: ' + $_.Exception.Message) } }
    Remove-Item Env:\TC_PROBE_DRIVES_DUMP -ErrorAction SilentlyContinue
    # the product's key first: nothing below may keep it from being restored
    if ($existed) {
        try { $regOk = Restore-Reg $RegBackup $existed; if ($regOk) { Remove-Item -LiteralPath $RegBackup -Force } }
        catch { $regOk = $false; Out ('Registry: RESTORE FAILED - restore by hand from ' + $RegBackup + ': ' + $_.Exception.Message) }
    }
    foreach ($l in $Mapped) {
        try { [void][Tst264]::Cancel(($l + ':'), $true); if ($snapBefore.Network -split ',' -notcontains $l) { Remove-Item -LiteralPath ('HKCU:\Network\' + $l) -Recurse -Force -ErrorAction SilentlyContinue } }
        catch { Out ('cleanup: ' + $_.Exception.Message) }
    }
    for ($pass = 0; $pass -lt 3; $pass++) {
        # a key name longer than 255 characters cannot exist (the L1 path's) and makes Remove-Item throw
        foreach ($k in @($MyKeys | Where-Object { $_.Length -le 255 }) + @(Get-ChildItem $MP2 -ErrorAction SilentlyContinue | Where-Object { ($_.PSChildName -like '##*tc264p*' -or $_.PSChildName -like '##tc264-no-such-host*') -and ($snapBefore.MP2 -split '\|') -notcontains $_.PSChildName } | ForEach-Object { $_.PSChildName })) {
            try { Remove-Item -LiteralPath ($MP2 + '\' + $k) -Recurse -Force -ErrorAction SilentlyContinue } catch { Out ('cleanup: ' + $_.Exception.Message) }
        }
        Start-Sleep -Milliseconds 1500
    }
    try { if (Test-Path -LiteralPath $Fx) { cmd.exe /c rd /s /q ('\\?\' + $Fx) | Out-Null } } catch { Out ('cleanup: ' + $_.Exception.Message) }
    $snapAfter = Snap
    $same = ($snapAfter.Network -eq $snapBefore.Network) -and ($snapAfter.MP2 -eq $snapBefore.MP2) -and ($snapAfter.Drives -eq $snapBefore.Drives) -and ($snapAfter.NetUse -eq $snapBefore.NetUse) -and -not (Test-Path -LiteralPath $Fx)
    if (-not $same) { $script:Fails++ }
    Out ("cleanup verified: {0} (drives {1}->{2}; HKCU\Network [{3}]->[{4}]; MountPoints2 equal {5}; net use [{6}]->[{7}]; fixture removed {8}); registry restored: {9}" -f $same, $snapBefore.Drives, $snapAfter.Drives, $snapBefore.Network, $snapAfter.Network, ($snapAfter.MP2 -eq $snapBefore.MP2), $snapBefore.NetUse, $snapAfter.NetUse, (-not (Test-Path -LiteralPath $Fx)), $regOk)
    Out ("RESULT: {0} FAIL row(s)" -f $script:Fails)
    [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, $Utf8)
}
exit $script:Fails
