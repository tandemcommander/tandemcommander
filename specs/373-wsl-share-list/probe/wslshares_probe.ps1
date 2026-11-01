<#
.SYNOPSIS
    Backlog item wsl-localhost-offers-no-share-list: does a server path of a non-SMB network
    provider (WSL: \\wsl.localhost, \\wsl$) offer its share list, and does a server that does not
    exist still end in one error without a longer wait?

.DESCRIPTION
    Rows (names for -Only); every row starts its own instance in English and ends it. No seam:
    the real route of feature 125 (NetShareEnum, then the network providers).

      W1  Change Directory \\wsl.localhost    : the list opens; the WSL distribution is picked
      W2  Change Directory \\wsl.localhost\   : the same
      W3  Change Directory \\wsl$             : the same (the older alias of the provider)
      W4  at \\wsl.localhost\<distro> : Backspace (the way up of feature 284), Esc in the list
      C1  Change Directory \\localhost        : the SMB route (local Server service) - control;
                                                Esc in the list
      N1  Change Directory \\<a name that does not exist> : one error box (53), no list; time
      U1  Change Directory \\192.0.2.1 (TEST-NET-1, never answers) : one error box, no list; time

    The distribution picked is "Ubuntu" when the provider lists it, else the first one; the
    expected list is read with WNetOpenEnumW by the probe itself (as the core does).

    With -Expect measure (default) the rows are INFO - the probe only records. With -Expect fixed:
      W1-W3  the list opens, the picked item opens -> location \\<server>\<distro>, no window
      W4     the list opens; Esc -> location \\wsl.localhost\<distro>, no window
      C1     the list opens; Esc -> the start folder, no window
      N1     one box naming the server and (53), no list, location = the start folder, < 15 s
      U1     one box naming the server, no list, location = the start folder, < 35 s (one
             network timeout is about 21 s here; a second one would be > 40 s)

    MUST run through tools\run_on_hidden_desktop.ps1; refuses while tandemcommander.exe runs;
    the product's registry key is exported, restored and SHA-256-verified. Exit code = FAIL rows.

.PARAMETER Exe   tandemcommander.exe under test
.PARAMETER Repo  the repository root (default: three levels above this script)
.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII. Opening the distribution starts it in WSL when
    it is stopped (as the same path does in File Explorer).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('measure', 'fixed')][string]$Expect = 'measure',
    [string]$OutFile,
    [string[]]$Only,
    [string]$Repo
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (-not $Repo) { $Repo = Join-Path $PSScriptRoot '..\..\..' }
$Repo = (Resolve-Path -LiteralPath $Repo).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $Repo 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
public static class WslNet373 {
  [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)]
  public class NETRESOURCE { public int dwScope; public int dwType; public int dwDisplayType; public int dwUsage; public string lpLocalName; public string lpRemoteName; public string lpComment; public string lpProvider; }
  [DllImport("mpr.dll", CharSet=CharSet.Unicode)] static extern int WNetOpenEnumW(int scope, int type, int usage, NETRESOURCE nr, out IntPtr h);
  [DllImport("mpr.dll", CharSet=CharSet.Unicode)] static extern int WNetEnumResourceW(IntPtr h, ref int count, IntPtr buf, ref int size);
  [DllImport("mpr.dll")] static extern int WNetCloseEnum(IntPtr h);
  // the disk containers of a server as the core asks for them (shares.cpp); names after the last '\'
  public static string[] Names(string server) {
    var list = new List<string>();
    var nr = new NETRESOURCE(); nr.dwScope = 2; nr.dwType = 1; nr.dwDisplayType = 2; nr.dwUsage = 2; nr.lpRemoteName = server;
    IntPtr h; if (WNetOpenEnumW(2, 1, 0, nr, out h) != 0) return list.ToArray();
    IntPtr buf = Marshal.AllocHGlobal(32768);
    int sz = Marshal.SizeOf(typeof(NETRESOURCE));
    while (true) {
      int c = -1, size = 32768;
      if (WNetEnumResourceW(h, ref c, buf, ref size) != 0) break;
      for (int i = 0; i < c; i++) {
        var r = (NETRESOURCE)Marshal.PtrToStructure(buf + i * sz, typeof(NETRESOURCE));
        if (r.lpRemoteName != null && r.dwType == 1) list.Add(r.lpRemoteName.Substring(r.lpRemoteName.LastIndexOf('\\') + 1));
      }
    }
    Marshal.FreeHGlobal(buf); WNetCloseEnum(h);
    list.Sort(StringComparer.OrdinalIgnoreCase);
    return list.ToArray();
  }
}
'@

$Root = $TempRoot + '\tcwslshares'
$StartDir = $Root + '\start'
$Fixed = ($Expect -eq 'fixed')
$MenuClass = 'PopupMenuClass'
$Distros = @([WslNet373]::Names('\\wsl.localhost'))
$Pick = -1
for ($i = 0; $i -lt $Distros.Count; $i++) { if ($Distros[$i] -ieq 'Ubuntu') { $Pick = $i } }
if ($Pick -lt 0 -and $Distros.Count) { $Pick = 0 }
$Distro = $(if ($Pick -ge 0) { $Distros[$Pick] } else { '' })
$NoSuch = 'nosuch-tc373-' + [Guid]::NewGuid().ToString('N').Substring(0, 8)
$NoAnswer = '192.0.2.1'

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function V2([bool]$ok) { if (-not $Fixed) { return 'INFO' }; return (V $ok) }
function Start-P {
    $a = @('-t', 'TSR', '-l', ('"{0}"' -f $StartDir), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    $r = Serve $p.Id 8
    if ($r.Messages.Count) { Out ('           at start: ' + (Msgs $r)) }
    return $p.Id
}
function Get-LocOf([int]$Id, [int]$Cmd) {
    if (-not (Test-Alive $Id)) { return '<gone>' }
    $dlg = Open-ByCmd $Id $Cmd
    if ($dlg -eq [IntPtr]::Zero) { return '<no dialog>' }
    $d = WinDesc $dlg
    if ($d -match $FatalRx) { return ('<FATAL ' + $d + '>') }
    $ctl = Find-Ctl $dlg 210
    $t = '<no field>'; if ($ctl -ne [IntPtr]::Zero) { $t = [Drv098f]::GetText($ctl, 5000) }
    Close-Win $dlg
    Start-Sleep -Milliseconds 300
    return $t
}
# the share list (PopupMenuClass) or an error box, whichever comes first; .Ms = time to it
function Wait-MenuOrBox([int]$Id, [double]$Seconds, [Diagnostics.Stopwatch]$Clock) {
    $res = [pscustomobject]@{ Menu = [IntPtr]::Zero; Box = $false; Ms = -1 }
    while ($Clock.Elapsed.TotalSeconds -lt $Seconds -and (Test-Alive $Id)) {
        $m = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq $MenuClass }) | Select-Object -First 1
        if ($m) { $res.Ms = $Clock.ElapsedMilliseconds; Start-Sleep -Milliseconds 500; $res.Menu = $m; return $res }
        $box = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and [Drv098f]::Txt($_) -ne '' -and @(Buttons $_).Count -ge 1 -and -not (@(Buttons $_).Count -eq 1 -and [Drv098f]::GetDlgCtrlID(@(Buttons $_)[0]) -eq 2) }) | Select-Object -First 1
        if ($box) { $res.Ms = $Clock.ElapsedMilliseconds; $res.Box = $true; return $res }
        Start-Sleep -Milliseconds 100
    }
    $res.Ms = $Clock.ElapsedMilliseconds
    return $res
}
function Menu-Key([IntPtr]$Menu, [int]$Vk) {
    [void][Drv098f]::PostMessageW($Menu, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv098f]::PostMessageW($Menu, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001)
    Start-Sleep -Milliseconds 250
}
function Key-Post([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    [void][Drv098f]::PostMessageW($l, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv098f]::PostMessageW($l, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001)
}
# Change Directory with $Text, without waiting for the dialog's answer (the list is modal)
function Post-ChangeDir([int]$Id, [string]$Text) {
    $dlg = Open-ByCmd $Id 862
    if ($dlg -eq [IntPtr]::Zero) { throw 'Change Directory (862) opened no window' }
    $ctl = Find-Ctl $dlg 210
    if ($ctl -eq [IntPtr]::Zero) { throw 'path field 210 not found' }
    [void][Drv098f]::SetText($ctl, $Text, 5000)
    if ([Drv098f]::GetText($ctl, 5000) -cne $Text) { throw 'the path field does not hold the text' }
    Click-Ok $dlg
}

# one row. $Act: 'cd' = Change Directory $Where; 'bs' = open $Where first, then Backspace.
# $Kind: 'pick' (Down x (Pick+1), Enter; expect $Expected), 'esc' (Esc; expect $Expected),
#        'error' (one box naming $Server and matching $ErrRx; location = $Expected), $MaxS = time limit
function Row-Wsl([string]$Case, [string]$Act, [string]$Where, [string]$Kind, [string]$Expected, [string]$Server, [string]$ErrRx = '', [double]$MaxS = 60) {
    if (-not (Want $Case)) { return }
    $before = Reports; $id = 0; $fatal = $null
    try {
        $id = Start-P
        if ($Act -eq 'bs') {
            [void](Do-ChangeDir $id $Where)
            $r0 = Serve $id 60
            Sync $id; Start-Sleep -Milliseconds 1500
            $l0 = Get-LocOf $id 862
            if ($l0 -ine $Where) { throw ("could not open {0}: location '{1}', windows: {2}" -f $Where, (Esc $l0), (Msgs $r0)) }
            $clock = [Diagnostics.Stopwatch]::StartNew()
            Key-Post $id 0x08
        }
        else {
            Post-ChangeDir $id $Where
            $clock = [Diagnostics.Stopwatch]::StartNew()
        }
        $w = Wait-MenuOrBox $id $MaxS $clock
        $hadMenu = ($w.Menu -ne [IntPtr]::Zero)
        if ($hadMenu) {
            if ($Kind -eq 'pick') { for ($k = 0; $k -le $Pick; $k++) { Menu-Key $w.Menu 0x28 }; Menu-Key $w.Menu 0x0D }
            else { Menu-Key $w.Menu 0x1B }
        }
        $r = Serve $id 90
        $fatal = $r.Fatal
        Sync $id; Start-Sleep -Milliseconds 1500
        $loc = Get-LocOf $id 862
        $facts = ("{0} '{1}': list opened {2} after {3} ms; error box {4}; windows: {5}; location '{6}'" -f $Act, (Esc $Where), $hadMenu, $w.Ms, $w.Box, (Msgs $r), (Esc $loc))
        $ok = -not $fatal
        switch ($Kind) {
            'pick'  { $ok = $ok -and $hadMenu -and $r.Messages.Count -eq 0 -and $loc -ieq $Expected }
            'esc'   { $ok = $ok -and $hadMenu -and $r.Messages.Count -eq 0 -and $loc -ieq $Expected }
            'error' {
                $box = @($r.Messages)
                $ok = $ok -and (-not $hadMenu) -and $box.Count -eq 1 -and ($box[0] -match [regex]::Escape('\\' + $Server)) -and ($ErrRx -eq '' -or $box[0] -match $ErrRx) -and $loc -ieq $Expected -and $w.Ms -lt ($MaxS * 1000)
            }
        }
        Row $Case 'ACT' (V2 $ok) $facts
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tcwslshares_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    NewDir $StartDir
    Set-Config
    Out ("wslshares_probe (backlog item wsl-localhost-offers-no-share-list), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; computer {2}; registry key existed {3}; export SHA-256 {4}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), $env:COMPUTERNAME, $existed, $regHash)
    Out ("WSL     : the provider lists {0} distribution(s): {1}; picked '{2}' (item {3})" -f $Distros.Count, ($Distros -join ', '), $Distro, ($Pick + 1))
    Out ("Plug-in : plugins\nethood\nethood.spl present next to the program: {0}" -f (Test-Path -LiteralPath (Join-Path (Split-Path $Exe) 'plugins\nethood\nethood.spl')))
    Out ''
    if ($Distro -eq '') {
        Row 'W*' 'ACT' 'NOT DRIVEN' 'no WSL distribution is listed by the provider on this computer'
    }
    else {
        Row-Wsl 'W1' 'cd' '\\wsl.localhost' 'pick' ('\\wsl.localhost\' + $Distro) 'wsl.localhost'
        Row-Wsl 'W2' 'cd' '\\wsl.localhost\' 'pick' ('\\wsl.localhost\' + $Distro) 'wsl.localhost'
        Row-Wsl 'W3' 'cd' '\\wsl$' 'pick' ('\\wsl$\' + $Distro) 'wsl$'
        Row-Wsl 'W4' 'bs' ('\\wsl.localhost\' + $Distro) 'esc' ('\\wsl.localhost\' + $Distro) 'wsl.localhost'
    }
    Row-Wsl 'C1' 'cd' '\\localhost' 'esc' $StartDir 'localhost'
    Row-Wsl 'N1' 'cd' ('\\' + $NoSuch) 'error' $StartDir $NoSuch '\(53\)' 15
    Row-Wsl 'U1' 'cd' ('\\' + $NoAnswer) 'error' $StartDir $NoAnswer '' 35
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    $ni = @($script:Rows | Where-Object { $_.Verdict -eq 'INFO' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}, INFO {3}. Left running: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $ni, $leftover.Count, $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
