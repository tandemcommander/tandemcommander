<#
.SYNOPSIS
    Feature 089, User Story 1 (contracts/association-takeover.md C1, C2):
    after the program has started and saved its configuration, the stored
    archive associations are the same whatever configuration it started from.

.DESCRIPTION
    Drives the already built program (no rebuild, no source change) over a
    series of registry fixtures and reads back what it stored:

      A      the configuration found in the registry (expected: written by
             0.1.8 - 7zip plug-in Version 3, record "rar;r##" with the RAR
             archiver as packer and unpacker). When the registry is not in
             that shape, the association part is forced into it and a NOTE
             is printed.
      B      A + what a development build of feature 087 left after an
             UPDATE: plug-in Version 4, plug-in record "7z;rar;r##", the
             core record "rar;r##" (RAR/RAR) kept.
      B2     A + what a NEW installation of 087 left: plug-in Version 4,
             record "rar;r##" with unpacker = plug-in, packer = RAR,
             plug-in record "7z".
      B106   the 087 update shape on top of a configuration this build has
             already converted (current configuration version), with the
             plugins.ver counter reset so that the plug-ins are loaded at
             start - what a released update does.
      B106n  as B106 but the plugins.ver counter left alone: the plug-in is
             NOT loaded at start. Informational (never a failure): shows
             that the repair waits for the first load of the plug-in.
      C      no configuration at all (a first start).

    Per fixture: import, start (title prefix T089), wait until idle, plant a
    sentinel value in the association key, exit with WM_CLOSE, check that the
    sentinel is gone (= the exit rewrote the section), print and check the
    records, then start and exit a second time and compare.

    Registry layout (src/mainwnd2.cpp, src/pack3.cpp, src/plugins/7zip/7zip.cpp):
      HKCU\Software\Tandem Commander\0.1\Packers & Unpackers\Archive Association\<n>
          "Extension List"   REG_SZ     "rar;r##"
          "Packer Supported" REG_DWORD  0 / 1
          "Packer Index"     REG_DWORD  >= 0: external archiver (Predefined Packers\<index+1>)
          "Unpacker Index"   REG_DWORD  < 0 : plug-in, -(n) of Plugins\<n>  (-Index-1, Index zero-based)
      HKCU\Software\Tandem Commander\0.1\Plugins\<n>            "DLL" = "7zip\7zip.spl"
      HKCU\Software\Tandem Commander\0.1\Plugins Configuration\7zip   "Version" REG_DWORD

    SAFETY: HKCU\Software\Tandem Commander is exported first and restored in a
    finally block (delete, import, export again, compare line count and
    SHA-256). Only processes this script started are touched (by pid); only
    PostMessage is used, no SendInput. The user-interface language is not
    changed (a language change makes the program load every plug-in, which
    would hide what is being tested).

.PARAMETER Exe
    The program under test.

.NOTES
    Windows PowerShell 5.1. Exit code = number of failed checks.
#>
[CmdletBinding()]
param(
    [string]$Exe = 'D:\Projects\tandemcommander\build\tandemcommander\Debug_x64\tandemcommander.exe',
    [string]$WorkDir = (Join-Path $env:TEMP 'tc089_assoc'),
    [string[]]$Only = @()      # run only these fixtures (A, B, B2, B106, B106n, C)
)

$ErrorActionPreference = 'Stop'

if (-not ('Drv089' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Drv089
{
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll", EntryPoint = "GetWindowLongW")] public static extern int GetWindowLong(IntPtr h, int idx);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);

    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Txt(IntPtr h) { var s = new StringBuilder(2048); GetWindowTextW(h, s, 2048); return s.ToString(); }
    public static uint PidOf(IntPtr h) { uint q; GetWindowThreadProcessId(h, out q); return q; }

    // visible top-level windows of ONE process
    public static List<IntPtr> Top(uint pid)
    {
        var l = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr p) { uint q; GetWindowThreadProcessId(h, out q); if (q == pid && IsWindowVisible(h)) l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    public static List<IntPtr> Kids(IntPtr parent)
    {
        var l = new List<IntPtr>();
        EnumChildWindows(parent, delegate(IntPtr h, IntPtr p) { l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
}
'@
}

$MainClass = 'TandemCommanderMainWindowVer01'
$RegRoot = 'HKCU\Software\Tandem Commander'
$NetRoot = 'Software\Tandem Commander'
$NetCfg = "$NetRoot\0.1"
$NetAssoc = "$NetCfg\Packers & Unpackers\Archive Association"
$NetPredef = "$NetCfg\Packers & Unpackers\Predefined Packers"
$Net7z = "$NetCfg\Plugins Configuration\7zip"
$Sentinel = 'Tc089ProbeSentinel'
$RarUid = 2          # CArchiverConfig UID of "RAR (WinRAR console)", index 1 (feature 084)

$script:Fail = 0
$script:Started = New-Object System.Collections.ArrayList
$script:Prompts = New-Object System.Collections.ArrayList
$script:Results = @{}

function Check([string]$Fx, [string]$What, [bool]$Ok, [string]$Detail = '') {
    if ($Ok) { Write-Host ("  PASS [{0}] {1}" -f $Fx, $What) }
    else { $script:Fail++; Write-Host ("  FAIL [{0}] {1}{2}" -f $Fx, $What, $(if ($Detail) { " -- $Detail" } else { '' })) }
}
function Note([string]$m) { Write-Host ("  note: {0}" -f $m) }

# ---- registry ---------------------------------------------------------------

function Reg-Run([string[]]$a) {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & reg.exe @a 2>&1 | ForEach-Object { $_.ToString() }
    $code = $LASTEXITCODE
    $ErrorActionPreference = $prev
    return [pscustomobject]@{ Code = $code; Out = ($out -join ' ') }
}
function Key-Exists([string]$sub) { $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($sub); if ($k) { $k.Close(); return $true }; return $false }
function Get-Val([string]$sub, [string]$name) {
    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($sub)
    if (-not $k) { return $null }
    try { return $k.GetValue($name, $null) } finally { $k.Close() }
}
function Set-Dword([string]$sub, [string]$name, [int]$v) {
    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($sub, $true)
    if (-not $k) { throw "registry key not found: $sub" }
    try { $k.SetValue($name, $v, [Microsoft.Win32.RegistryValueKind]::DWord) } finally { $k.Close() }
}
function Set-Str([string]$sub, [string]$name, [string]$v) {
    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($sub, $true)
    if (-not $k) { throw "registry key not found: $sub" }
    try { $k.SetValue($name, $v, [Microsoft.Win32.RegistryValueKind]::String) } finally { $k.Close() }
}

# 1-based position of the 7zip plug-in in Plugins\<n>; its association index is -n
function Get-7zPos {
    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey("$NetCfg\Plugins")
    if (-not $k) { return 0 }
    try {
        foreach ($n in $k.GetSubKeyNames()) {
            $s = $k.OpenSubKey($n); $dll = [string]$s.GetValue('DLL', ''); $s.Close()
            if ($dll -ieq '7zip\7zip.spl') { return [int]$n }
        }
    } finally { $k.Close() }
    return 0
}
function Get-PluginDll([int]$pos) { $d = Get-Val "$NetCfg\Plugins\$pos" 'DLL'; if ($d) { return [string]$d }; return "?$pos" }
function Get-ArchiverName([int]$index) {
    $t = Get-Val "$NetPredef\$($index + 1)" 'Packer Executable'; $u = Get-Val "$NetPredef\$($index + 1)" 'Packer UID'
    return ("'{0}' (UID {1})" -f $t, $u)
}

# the association records in stored order
function Get-Assoc {
    $r = @()
    $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($NetAssoc)
    if (-not $k) { return $r }
    try {
        foreach ($n in ($k.GetSubKeyNames() | Sort-Object { [int]$_ })) {
            $s = $k.OpenSubKey($n)
            $r += [pscustomobject]@{ N = [int]$n; Ext = [string]$s.GetValue('Extension List', ''); Supported = [int]$s.GetValue('Packer Supported', -99)
                Packer = [int]$s.GetValue('Packer Index', -99); Unpacker = [int]$s.GetValue('Unpacker Index', -99) }
            $s.Close()
        }
    } finally { $k.Close() }
    return $r
}
function Describe-Index([int]$i) { if ($i -lt 0) { return ("{0} = plug-in {1}" -f $i, (Get-PluginDll (-$i))) }; return ("{0} = archiver {1}" -f $i, (Get-ArchiverName $i)) }
# one line per record; plug-in references by DLL name so that fixtures can be compared
function Canon($recs) {
    $l = @()
    foreach ($x in $recs) {
        $p = if ($x.Supported -eq 0) { '-' } elseif ($x.Packer -lt 0) { 'plugin:' + (Get-PluginDll (-$x.Packer)) } else { 'archiver:' + $x.Packer }
        $u = if ($x.Unpacker -lt 0) { 'plugin:' + (Get-PluginDll (-$x.Unpacker)) } else { 'archiver:' + $x.Unpacker }
        $l += ("{0} | supported={1} | packer={2} | unpacker={3}" -f $x.Ext, $x.Supported, $p, $u)
    }
    return $l
}
function Raw($recs) { return @($recs | ForEach-Object { "{0}: {1} | {2} | {3} | {4}" -f $_.N, $_.Ext, $_.Supported, $_.Packer, $_.Unpacker }) }
function Has-Ext([string]$list, [string]$e) { return (@($list.ToLower().Split(';')) -contains $e.ToLower()) }

function Print-State([string]$Fx, [string]$Stage) {
    $recs = Get-Assoc; $pos = Get-7zPos
    Write-Host ("  [{0}] {1}: configuration version {2}, 7zip plug-in = Plugins\{3} (association index {4}), 7zip Version = {5}, Plugins.ver (x64) = {6}" -f `
            $Fx, $Stage, (Get-Val "$NetCfg\Version" 'Configuration'), $pos, (-$pos), (Get-Val $Net7z 'Version'), (Get-Val "$NetCfg\Configuration" 'Plugins.ver Version (x64)'))
    foreach ($x in $recs) {
        if ((Has-Ext $x.Ext 'rar') -or (Has-Ext $x.Ext 'r##') -or (Has-Ext $x.Ext '7z') -or ($pos -gt 0 -and ($x.Unpacker -eq - $pos -or $x.Packer -eq - $pos))) {
            Write-Host ("      rec {0,-2} ext='{1}' packer-supported={2} packer=[{3}] unpacker=[{4}]" -f $x.N, $x.Ext, $x.Supported, (Describe-Index $x.Packer), (Describe-Index $x.Unpacker))
        }
    }
}

function Backup-Registry([string]$File) {
    if (-not (Key-Exists $NetRoot)) { return $false }
    $r = Reg-Run @('export', $RegRoot, $File, '/y')
    if ($r.Code -ne 0) { throw "reg export failed: $($r.Out)" }
    return $true
}
function Restore-Registry([string]$File, [bool]$Existed) {
    [void](Reg-Run @('delete', $RegRoot, '/f'))
    if (-not $Existed) { Write-Host 'Registry   : the key did not exist before - deleted'; return (-not (Key-Exists $NetRoot)) }
    $r = Reg-Run @('import', $File)
    if ($r.Code -ne 0) { Write-Host "Registry   : IMPORT FAILED ($($r.Out)) - restore by hand from $File"; return $false }
    $check = "$File.check"
    [void](Reg-Run @('export', $RegRoot, $check, '/y'))
    $a = @(Get-Content -LiteralPath $File -Encoding Unicode); $b = @(Get-Content -LiteralPath $check -Encoding Unicode)
    $ha = (Get-FileHash -LiteralPath $File).Hash; $hb = (Get-FileHash -LiteralPath $check).Hash
    $same = ($a.Count -eq $b.Count) -and ($ha -eq $hb)
    Write-Host ("Registry   : restored from {0}; {1} lines vs {2}; SHA-256 {3} / {4}; identical={5}" -f $File, $a.Count, $b.Count, $ha.Substring(0, 16), $hb.Substring(0, 16), $same)
    Remove-Item -LiteralPath $check -Force
    return $same
}
# loads a fixture file (or nothing = no configuration) into the registry
function Import-Fixture([string]$File) {
    [void](Reg-Run @('delete', $RegRoot, '/f'))
    if (Key-Exists $NetRoot) { throw 'could not delete the configuration key' }
    if ($File) { $r = Reg-Run @('import', $File); if ($r.Code -ne 0) { throw "reg import failed: $($r.Out)" } }
}
function Save-Fixture([string]$File) { $r = Reg-Run @('export', $RegRoot, $File, '/y'); if ($r.Code -ne 0) { throw "reg export failed: $($r.Out)" } }

# ---- process and windows ----------------------------------------------------

function Get-MainWnd([int]$Id) { foreach ($h in [Drv089]::Top([uint32]$Id)) { if ([Drv089]::Cls($h) -eq $MainClass) { return $h } }; return [IntPtr]::Zero }
function Get-Dialogs([int]$Id) { return @([Drv089]::Top([uint32]$Id) | Where-Object { [Drv089]::Cls($_) -eq '#32770' }) }
function Dialog-Text([IntPtr]$H) {
    $parts = @()
    foreach ($c in [Drv089]::Kids($H)) { $t = [Drv089]::Txt($c); if ($t) { $parts += ("[{0} {1}] {2}" -f [Drv089]::Cls($c), [Drv089]::GetDlgCtrlID($c), ($t -replace '\s+', ' ')) } }
    return ("title='{0}' :: {1}" -f [Drv089]::Txt($H), ($parts -join ' | '))
}
# records a dialog of OUR pid and presses its default button (BM_CLICK is posted)
function Answer-Dialog([int]$Id, [IntPtr]$H, [string]$Fx, [string]$Phase, $Seen) {
    if ([Drv089]::PidOf($H) -ne [uint32]$Id) { return }
    $btns = @([Drv089]::Kids($H) | Where-Object { [Drv089]::Cls($_) -eq 'Button' -and [Drv089]::IsWindowVisible($_) -and (([Drv089]::GetWindowLong($_, -16) -band 0xF) -le 1) })
    $def = $btns | Where-Object { ([Drv089]::GetWindowLong($_, -16) -band 0xF) -eq 1 } | Select-Object -First 1
    if (-not $def) { $def = $btns | Select-Object -First 1 }
    $key = $H.ToInt64()
    if (-not $Seen.ContainsKey($key)) {
        $Seen[$key] = 1
        $line = ("[{0}] {1}: {2} -> pressed '{3}' (id {4})" -f $Fx, $Phase, (Dialog-Text $H), $(if ($def) { [Drv089]::Txt($def) } else { 'WM_CLOSE' }), $(if ($def) { [Drv089]::GetDlgCtrlID($def) } else { 0 }))
        [void]$script:Prompts.Add($line); Write-Host "  prompt $line"
    }
    if ($def) { [void][Drv089]::PostMessageW($def, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
    else { [void][Drv089]::PostMessageW($H, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
}

# Starts the program and waits until it is idle: main window visible and
# enabled, no dialog, and next to no CPU time used over three samples.
function Start-Tc([string]$Fx, [string]$Dir) {
    $a = @('-t', 'T089', '-l', ('"{0}"' -f $Dir), '-r', ('"{0}"' -f $Dir))
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    $null = $p.Handle
    [void]$script:Started.Add($p.Id)
    $seen = @{}
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $quiet = 0; $lastCpu = -1.0; $mainAt = -1.0
    while ($sw.Elapsed.TotalSeconds -lt 120) {
        Start-Sleep -Milliseconds 700
        if ($p.HasExited) { throw "the program ended during start-up (exit code $($p.ExitCode))" }
        $dl = Get-Dialogs $p.Id
        foreach ($d in $dl) { Answer-Dialog $p.Id $d $Fx 'start' $seen }
        $m = Get-MainWnd $p.Id
        $p.Refresh(); $cpu = $p.TotalProcessorTime.TotalMilliseconds
        if ($m -ne [IntPtr]::Zero -and $mainAt -lt 0) { $mainAt = $sw.Elapsed.TotalSeconds }
        if ($m -ne [IntPtr]::Zero -and [Drv089]::IsWindowEnabled($m) -and $dl.Count -eq 0 -and $lastCpu -ge 0 -and ($cpu - $lastCpu) -lt 60) { $quiet++ } else { $quiet = 0 }
        $lastCpu = $cpu
        if ($quiet -ge 4 -and ($sw.Elapsed.TotalSeconds - $mainAt) -ge 4) { break }
    }
    if ((Get-MainWnd $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ($quiet -lt 4) { Note 'the program did not become idle within 120 s - continuing' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    return $p
}

# A normal exit: WM_CLOSE to the main window. Returns $true when the process ended by itself.
function Exit-Tc($p, [string]$Fx) {
    $m = Get-MainWnd $p.Id
    if ($m -eq [IntPtr]::Zero) { throw 'no main window to close' }
    [void][Drv089]::PostMessageW($m, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $seen = @{}
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 90 -and -not $p.HasExited) {
        foreach ($d in (Get-Dialogs $p.Id)) { Answer-Dialog $p.Id $d $Fx 'exit' $seen }
        Start-Sleep -Milliseconds 300
    }
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; Start-Sleep -Seconds 1; return $false }
    $p.WaitForExit()
    return $true
}
function Stop-AllStarted {
    foreach ($id in @($script:Started)) {
        $q = Get-Process -Id $id -ErrorAction SilentlyContinue
        if ($q -and $q.Path -ieq $Exe) { Write-Host "  (killing leftover pid $id)"; Stop-Process -Id $id -Force -ErrorAction SilentlyContinue }
    }
}

# One start-and-exit. Proves the exit saved the association section by a
# sentinel value planted while the program runs (the save clears the key).
function Run-Once([string]$Fx, [string]$Stage) {
    $p = Start-Tc $Fx $script:PanelDir
    $planted = $false
    if (Key-Exists $NetAssoc) { Set-Dword $NetAssoc $Sentinel 1; $planted = $true }
    $ended = Exit-Tc $p $Fx
    Check $Fx "$Stage : the program ended by itself after WM_CLOSE (exit code $(if ($ended) { $p.ExitCode } else { 'killed' }))" $ended
    if ($planted) { Check $Fx "$Stage : the exit rewrote the association section (sentinel value gone)" ($null -eq (Get-Val $NetAssoc $Sentinel)) }
    else { Check $Fx "$Stage : the exit created the association section (there was none while running)" (Key-Exists $NetAssoc) }
    if ($null -ne (Get-Val $NetAssoc $Sentinel)) {
        $k = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($NetAssoc, $true); $k.DeleteValue($Sentinel, $false); $k.Close()
    }
}

# the checks of contract C2 on what the registry holds now
function Check-Assoc([string]$Fx, [bool]$Hard = $true) {
    $recs = Get-Assoc; $pos = Get-7zPos; $ok = $true
    $c = { param($what, $cond, $detail) if ($Hard) { Check $Fx $what $cond $detail } else { Write-Host ("  info [{0}] {1}: {2}{3}" -f $Fx, $what, $(if ($cond) { 'yes' } else { 'NO' }), $(if ($detail -and -not $cond) { " -- $detail" } else { '' })) } }
    & $c 'the 7zip plug-in is registered (Plugins\<n>, DLL 7zip\7zip.spl)' ($pos -gt 0) ''
    $rar = @($recs | Where-Object { (Has-Ext $_.Ext 'rar') -or (Has-Ext $_.Ext 'r##') })
    & $c 'exactly one record claims rar / r##' ($rar.Count -eq 1) ("found {0}: {1}" -f $rar.Count, ((Raw $rar) -join ' ; '))
    if ($rar.Count -ge 1) {
        $r = $rar | Where-Object { $_.Unpacker -eq - $pos -and $_.Packer -ge 0 } | Select-Object -First 1
        if (-not $r) { $r = $rar[0] }
        & $c "that record's extensions are 'rar;r##'" ($r.Ext -eq 'rar;r##') "is '$($r.Ext)'"
        & $c "its unpacker is the 7zip plug-in (Unpacker Index = $(-$pos))" ($r.Unpacker -eq - $pos) "is $($r.Unpacker)"
        $uid = Get-Val "$NetPredef\$($r.Packer + 1)" 'Packer UID'
        & $c 'its packer is the RAR external archiver (Packer Index = 1, Packer UID 2)' ($r.Packer -eq 1 -and $uid -eq $RarUid) "Packer Index $($r.Packer), UID $uid"
        & $c 'its "Packer Supported" is 1' ($r.Supported -eq 1) "is $($r.Supported)"
    }
    $own = @($recs | Where-Object { $_.Unpacker -eq - $pos -and $_.Supported -eq 1 -and $_.Packer -eq - $pos })
    & $c "the plug-in's own record (packer and unpacker = the plug-in) is one record, '7z' only" ($own.Count -eq 1 -and $own[0].Ext -eq '7z') ((Raw $own) -join ' ; ')
    $v = Get-Val $Net7z 'Version'
    & $c "the 7zip plug-in's stored Version is 5" ($v -eq 5) "is $v"
}

function Run-Fixture([string]$Fx, [string]$File, [bool]$Hard = $true) {
    Write-Host ''
    Write-Host ("=== fixture {0} ===" -f $Fx)
    Import-Fixture $File
    if ($File) { Print-State $Fx 'before' } else { Write-Host "  [$Fx] before: no HKCU\Software\Tandem Commander key" }
    Run-Once $Fx 'run 1'
    Print-State $Fx 'after run 1'
    [void](Reg-Run @('export', "$RegRoot\0.1\Packers & Unpackers\Archive Association", (Join-Path $WorkDir "assoc_${Fx}_run1.reg"), '/y'))
    Check-Assoc $Fx $Hard
    $raw1 = Raw (Get-Assoc); $canon1 = Canon (Get-Assoc)
    $script:Results[$Fx] = $canon1
    $after1 = Join-Path $WorkDir "state_${Fx}_run1.reg"; Save-Fixture $after1

    Run-Once $Fx 'run 2'
    [void](Reg-Run @('export', "$RegRoot\0.1\Packers & Unpackers\Archive Association", (Join-Path $WorkDir "assoc_${Fx}_run2.reg"), '/y'))
    $raw2 = Raw (Get-Assoc)
    $d = Compare-Object $raw1 $raw2 -SyncWindow 0
    $same = (-not $d) -and ($raw1.Count -eq $raw2.Count)
    $h1 = (Get-FileHash (Join-Path $WorkDir "assoc_${Fx}_run1.reg")).Hash; $h2 = (Get-FileHash (Join-Path $WorkDir "assoc_${Fx}_run2.reg")).Hash
    if ($Hard) {
        Check $Fx ("a second start and exit changes nothing in the association records ({0} records; export SHA-256 {1} / {2})" -f $raw2.Count, $h1.Substring(0, 12), $h2.Substring(0, 12)) ($same -and $h1 -eq $h2) (($d | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }) -join ' ; ')
        Check $Fx 'the 7zip Version is still 5 after the second run' ((Get-Val $Net7z 'Version') -eq 5) "is $(Get-Val $Net7z 'Version')"
    }
    else { Write-Host ("  info [{0}] second run: records unchanged = {1}; 7zip Version = {2}" -f $Fx, ($same -and $h1 -eq $h2), (Get-Val $Net7z 'Version')) }
    return $after1
}

# ---- fixture construction (on the registry as it stands) --------------------

# the record 0.1.8 ships: 'rar;r##' with an external archiver; $null when absent
function Find-CoreRar { return (Get-Assoc | Where-Object { (Has-Ext $_.Ext 'rar') -and $_.Unpacker -ge 0 } | Select-Object -First 1) }
function Find-Own7z([int]$pos) { return (Get-Assoc | Where-Object { $_.Unpacker -eq - $pos -and (Has-Ext $_.Ext '7z') } | Select-Object -First 1) }

# 087 development build after an UPDATE: the plug-in's record joined by rar;r##, the core record RAR/RAR
function Make-Joined {
    $pos = Get-7zPos
    $rar = Get-Assoc | Where-Object { Has-Ext $_.Ext 'rar' } | Select-Object -First 1
    $own = Find-Own7z $pos
    if (-not $rar -or -not $own) { throw 'cannot build the joined shape: no rar record or no 7z record of the plug-in' }
    Set-Dword "$NetAssoc\$($rar.N)" 'Unpacker Index' 1
    Set-Dword "$NetAssoc\$($rar.N)" 'Packer Index' 1
    Set-Dword "$NetAssoc\$($rar.N)" 'Packer Supported' 1
    Set-Str "$NetAssoc\$($own.N)" 'Extension List' '7z;rar;r##'
    Set-Dword $Net7z 'Version' 4
}
# 087 development build, NEW installation: rar;r## already taken over
function Make-TakenOver {
    $pos = Get-7zPos
    $rar = Get-Assoc | Where-Object { Has-Ext $_.Ext 'rar' } | Select-Object -First 1
    $own = Find-Own7z $pos
    if (-not $rar -or -not $own) { throw 'cannot build the taken-over shape' }
    Set-Dword "$NetAssoc\$($rar.N)" 'Unpacker Index' (-$pos)
    Set-Dword "$NetAssoc\$($rar.N)" 'Packer Index' 1
    Set-Dword "$NetAssoc\$($rar.N)" 'Packer Supported' 1
    Set-Str "$NetAssoc\$($own.N)" 'Extension List' '7z'
    Set-Dword $Net7z 'Version' 4
}

# ---- main -------------------------------------------------------------------

if (-not (Test-Path -LiteralPath $Exe)) { Write-Host "FAIL: exe not found: $Exe"; exit 1 }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$script:PanelDir = Join-Path $WorkDir 'panel'
New-Item -ItemType Directory -Force -Path $script:PanelDir | Out-Null
[IO.File]::WriteAllText((Join-Path $script:PanelDir 'readme.txt'), 'feature 089 association probe')

$others = @(Get-Process -Name tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count -gt 0) {
    Write-Host ("WARNING: {0} other tandemcommander process(es) running (pid {1}); they are not touched, but if one saves its configuration during the run the results are unreliable." -f $others.Count, (($others | ForEach-Object { $_.Id }) -join ', '))
}

$backup = Join-Path $WorkDir ("backup_{0}.reg" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$existed = Backup-Registry $backup
Write-Host ("Program    : {0}" -f $Exe)
Write-Host ("Registry   : backup {0} (key existed: {1})" -f $backup, $existed)
function Want([string]$fx) { return ($Only.Count -eq 0 -or $Only -contains $fx) }

$restored = $false
try {
    if (-not $existed) {
        Check 'A' 'a stored configuration exists to derive fixtures A, B, B2 from' $false 'no HKCU\Software\Tandem Commander key; only fixture C can run'
    }
    else {
        # ---- fixture A: is the stored configuration 0.1.8-shaped? ----
        $fxA = Join-Path $WorkDir 'fixture_A.reg'
        $pos = Get-7zPos; $v = Get-Val $Net7z 'Version'; $core = Find-CoreRar; $own = Find-Own7z $pos
        $cfgVer = Get-Val "$NetCfg\Version" 'Configuration'
        Write-Host ''
        Write-Host '=== fixture A precondition: the stored configuration ==='
        Print-State 'A' 'as found'
        $isA = ($v -eq 3) -and $core -and ($core.Ext -eq 'rar;r##') -and ($core.Packer -eq $core.Unpacker) -and $own -and ($own.Ext -eq '7z') -and ($cfgVer -lt 106)
        if ($isA) { Write-Host ("  the stored configuration IS 0.1.8-shaped (configuration version {0} < 106, 7zip Version 3, 'rar;r##' with RAR as packer and unpacker, plug-in record '7z')" -f $cfgVer) }
        else {
            Note 'the stored configuration is NOT 0.1.8-shaped; the association part is forced into that shape (record rar;r## = RAR/RAR, plug-in record 7z, 7zip Version 3, plugins.ver counter 0). The core configuration version is left as found.'
            $rar = Get-Assoc | Where-Object { Has-Ext $_.Ext 'rar' } | Select-Object -First 1
            if ($rar -and $own) {
                Set-Str "$NetAssoc\$($rar.N)" 'Extension List' 'rar;r##'
                Set-Dword "$NetAssoc\$($rar.N)" 'Unpacker Index' 1; Set-Dword "$NetAssoc\$($rar.N)" 'Packer Index' 1; Set-Dword "$NetAssoc\$($rar.N)" 'Packer Supported' 1
                Set-Str "$NetAssoc\$($own.N)" 'Extension List' '7z'
                Set-Dword $Net7z 'Version' 3
                Set-Dword "$NetCfg\Configuration" 'Plugins.ver Version (x64)' 0
            }
            else { Check 'A' 'shape A can be constructed (a rar record and a 7z record of the plug-in exist)' $false '' }
        }
        Save-Fixture $fxA

        # ---- B and B2 are derived from A ----
        $fxB = Join-Path $WorkDir 'fixture_B.reg'; Import-Fixture $fxA; Make-Joined; Save-Fixture $fxB
        $fxB2 = Join-Path $WorkDir 'fixture_B2.reg'; Import-Fixture $fxA; Make-TakenOver; Save-Fixture $fxB2

        $afterA = $null
        if (Want 'A') { $afterA = Run-Fixture 'A' $fxA }
        if (Want 'B') { [void](Run-Fixture 'B' $fxB) }
        if (Want 'B2') { [void](Run-Fixture 'B2' $fxB2) }

        # ---- B106 / B106n: the 087 update shape on a configuration this build already converted ----
        if ($afterA -and ((Want 'B106') -or (Want 'B106n'))) {
            $fxB106 = Join-Path $WorkDir 'fixture_B106.reg'; $fxB106n = Join-Path $WorkDir 'fixture_B106n.reg'
            Import-Fixture $afterA; Make-Joined; Save-Fixture $fxB106n
            Set-Dword "$NetCfg\Configuration" 'Plugins.ver Version (x64)' 0; Save-Fixture $fxB106
            if (Want 'B106') { [void](Run-Fixture 'B106' $fxB106) }
            if (Want 'B106n') {
                [void](Run-Fixture 'B106n' $fxB106n $false)
                Note 'B106n is informational: with an unchanged plugins.ver counter the plug-in is not loaded at start, so its Connect (and the repair) waits for its first use.'
            }
        }
    }

    if (Want 'C') { [void](Run-Fixture 'C' $null) }

    # ---- the fixtures against each other ----
    Write-Host ''
    Write-Host '=== comparison between fixtures (plug-ins by DLL name) ==='
    $ref = $script:Results['A']
    if ($ref) {
        foreach ($fx in @('B', 'B2', 'B106')) {
            if ($script:Results.ContainsKey($fx)) {
                $d = Compare-Object $ref $script:Results[$fx] -SyncWindow 0
                Check $fx "all association records equal those of fixture A, in the same order ($($ref.Count) records)" ((-not $d) -and $ref.Count -eq $script:Results[$fx].Count) (($d | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }) -join ' ; ')
            }
        }
        if ($script:Results.ContainsKey('C')) {
            $pick = { param($l) @($l | Where-Object { $_ -match '^(7z|rar;r##) \|' -or $_ -match '(^|;)(rar|r##|7z)(;| )' }) }
            $ra = & $pick $ref; $rc = & $pick $script:Results['C']
            $d = Compare-Object $ra $rc
            Check 'C' 'the rar and 7z records equal those of fixture A' ((-not $d) -and $ra.Count -eq $rc.Count) (($d | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" }) -join ' ; ')
            $d2 = Compare-Object $ref $script:Results['C']
            if ($d2) { Write-Host '  info: other differences between A (the maintainer''s configuration, converted) and C (defaults); "<=" only in A, "=>" only in C:'; $d2 | ForEach-Object { Write-Host ("      {0} {1}" -f $_.SideIndicator, $_.InputObject) } }
            else { Write-Host '  info: A and C hold the same set of records' }
        }
        Write-Host '  records after fixture A:'; $ref | ForEach-Object { Write-Host "      $_" }
    }
    if ($script:Results.ContainsKey('C')) { Write-Host '  records after fixture C:'; $script:Results['C'] | ForEach-Object { Write-Host "      $_" } }
}
catch {
    $script:Fail++
    Write-Host ("FAIL: the probe stopped: {0}" -f $_.Exception.Message)
    Write-Host $_.ScriptStackTrace
}
finally {
    Stop-AllStarted
    $restored = Restore-Registry $backup $existed
    if (-not $restored) { $script:Fail++; Write-Host "FAIL: the registry is NOT identical to the backup - restore by hand: reg delete `"$RegRoot`" /f & reg import `"$backup`"" }
    else { Write-Host '  PASS registry restored and identical to the backup' }
}

Write-Host ''
Write-Host ("Prompts answered: {0}" -f $script:Prompts.Count)
$script:Prompts | ForEach-Object { Write-Host "  $_" }
Write-Host ("RESULT: {0}" -f $(if ($script:Fail -eq 0) { 'PASS' } else { "FAIL ($($script:Fail))" }))
exit $script:Fail
