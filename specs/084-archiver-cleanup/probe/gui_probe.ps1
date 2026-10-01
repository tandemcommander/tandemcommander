# 084 GUI probe: external archivers end to end (quickstart sections 2 and 5).
#
# Runs the given tandemcommander.exe (the build under test) against a THROW-AWAY
# configuration: HKCU\Software\Tandem Commander is exported first, every
# scenario starts from a deleted 0.1 key (or an imported fixture), and the
# export is imported back at the end and compared value by value.
#
# Scenarios (each prints PASS/FAIL lines; the probe ends with RESULT: OK/FAIL):
#   autoconfig  fresh registry; Archivers Autoconfiguration finds 7-Zip from its
#               registry entry / Program Files without a disk scan (OK enabled),
#               and stores the path
#   browse      sample.arj and a 7z archive renamed to .arj are browsed through
#               the 7-Zip console: names read back with "copy names to clipboard"
#   extract     F5 out of both archives; files compared with 7z.exe's own extraction
#   hidden      Pack dialog: no "RAR (WinRAR)" without WinRAR; Unpack dialog lists
#               "7-Zip" while 7z.exe is found and not after its path is broken
#   cancel      extraction of an encrypted archive makes 7z.exe wait for a
#               password; Cancel stops it (no 7z.exe left, no salspawn, no error)
#   migration   a 0.1.8 configuration (fixtures\cfg\cfg_a_defaults.reg + version
#               105) is migrated on start; checked against contract M1-M3; a
#               second start changes nothing
#
# Never touches a process it did not start; refuses to run while any
# tandemcommander.exe is running. ASCII, Windows PowerShell 5.1.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe',
    [string[]]$Scenario = @('autoconfig', 'browse', 'extract', 'hidden', 'cancel', 'migration'),
    [string]$Work = (Join-Path $env:TEMP 'tc084-gui')
)

$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$fixtures = Join-Path $here 'fixtures'

Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Drv084
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
    [DllImport("user32.dll")] public static extern IntPtr GetDlgItem(IntPtr h, int id);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll")] public static extern IntPtr SendMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll", CharSet = CharSet.Unicode, EntryPoint = "SendMessageW")] public static extern IntPtr SendMessageSb(IntPtr h, uint msg, IntPtr w, StringBuilder l);

    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Txt(IntPtr h) { var s = new StringBuilder(1024); GetWindowTextW(h, s, 1024); return s.ToString(); }
    public static List<IntPtr> Top(uint pid)
    {
        var l = new List<IntPtr>();
        EnumWindows(delegate(IntPtr h, IntPtr p) { uint q; GetWindowThreadProcessId(h, out q); if (q == pid) l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    public static List<IntPtr> Kids(IntPtr parent)
    {
        var l = new List<IntPtr>();
        EnumChildWindows(parent, delegate(IntPtr h, IntPtr p) { l.Add(h); return true; }, IntPtr.Zero);
        return l;
    }
    // the texts of a combo box (CB_GETCOUNT / CB_GETLBTEXTLEN / CB_GETLBTEXT)
    public static List<string> ComboItems(IntPtr combo)
    {
        var l = new List<string>();
        int n = (int)SendMessageW(combo, 0x0146, IntPtr.Zero, IntPtr.Zero);
        for (int i = 0; i < n; i++)
        {
            int len = (int)SendMessageW(combo, 0x0149, (IntPtr)i, IntPtr.Zero);
            var sb = new StringBuilder(len + 2);
            SendMessageSb(combo, 0x0148, (IntPtr)i, sb);
            l.Add(sb.ToString());
        }
        return l;
    }
}
'@

$MainClass = 'TandemCommanderMainWindowVer01'
$regRoot = 'HKCU\Software\Tandem Commander'
$regCfg = "$regRoot\0.1"
$failures = New-Object System.Collections.ArrayList
$script:backup = $null
$script:proc = $null

function Note([string]$m) { Write-Host ("gui084: {0}" -f $m) }
function Pass([string]$m) { Write-Host ("gui084: PASS - {0}" -f $m) }
function Bad([string]$m) { [void]$failures.Add($m); Write-Host ("gui084: FAIL - {0}" -f $m) }
function Check([bool]$cond, [string]$m) { if ($cond) { Pass $m } else { Bad $m } }

function Reg([string[]]$regArgs) {
    $prev = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $out = & reg.exe @regArgs 2>&1 | ForEach-Object { $_.ToString() }
    $code = $LASTEXITCODE; $ErrorActionPreference = $prev
    return @{ Code = $code; Out = ($out -join ' ') }
}

# "section :: name" -> data of a .reg export (continuation lines joined)
function Read-Reg([string]$file) {
    $map = [ordered]@{}
    $section = ''; $pending = $null
    foreach ($line in (Get-Content -LiteralPath $file -Encoding Unicode)) {
        if ($null -ne $pending) { $pending += $line.TrimStart(); if ($pending.EndsWith('\')) { $pending = $pending.TrimEnd('\'); continue }; $line = $pending; $pending = $null }
        elseif ($line.EndsWith('\')) { $pending = $line.TrimEnd('\'); continue }
        if ($line -match '^\[(.+)\]$') { $section = $Matches[1]; $map["$section ::"] = '<key>'; continue }
        if ($line -match '^(@|".*?")=(.*)$') { $map["$section :: $($Matches[1])"] = $Matches[2] }
    }
    return $map
}

function Restore-Registry {
    if (-not $script:backup) { return }
    Note ("restoring registry from {0}" -f $script:backup)
    [void](Reg @('delete', $regRoot, '/f'))
    $r = Reg @('import', $script:backup)
    if ($r.Code -ne 0) { Bad ("reg import failed: {0} - BACKUP KEPT AT {1}" -f $r.Out, $script:backup); return }
    $check = Join-Path $Work 'restored-check.reg'
    [void](Reg @('export', $regRoot, $check, '/y'))
    $a = Read-Reg $script:backup; $b = Read-Reg $check; $diff = 0
    foreach ($k in (@($a.Keys) + @($b.Keys) | Sort-Object -Unique)) { if ($a[$k] -ne $b[$k]) { $diff++; Write-Host ("  DIFF {0}" -f $k) } }
    if ($diff -eq 0) { Note ("registry restored and verified ({0} keys/values)" -f $a.Count) }
    else { Bad ("restored registry differs in {0} entries - BACKUP KEPT AT {1}" -f $diff, $script:backup) }
}

function Stop-Tc {
    if ($script:proc -and -not $script:proc.HasExited) {
        try { Stop-Process -Id $script:proc.Id -Force -ErrorAction SilentlyContinue } catch { }
        Start-Sleep -Seconds 1
    }
    $script:proc = $null
}

function Finish {
    Stop-Tc
    Restore-Registry
    if ($failures.Count -eq 0) { Write-Host 'RESULT: OK'; exit 0 }
    Write-Host ("RESULT: FAIL - {0} problem(s)" -f $failures.Count)
    $failures | ForEach-Object { Write-Host ("  - {0}" -f $_) }
    exit 1
}

function Get-Main { foreach ($h in [Drv084]::Top([uint32]$script:proc.Id)) { if ([Drv084]::Cls($h) -eq $MainClass) { return $h } }; return [IntPtr]::Zero }

function Get-Dialogs {
    $l = @()
    foreach ($h in [Drv084]::Top([uint32]$script:proc.Id)) {
        if ([Drv084]::IsWindowVisible($h) -and [Drv084]::Cls($h) -eq '#32770') { $l += $h }
    }
    return $l
}

function Dialog-Text([IntPtr]$h) {
    $t = @()
    foreach ($c in [Drv084]::Kids($h)) { if ([Drv084]::Cls($c) -eq 'Static') { $t += [Drv084]::Txt($c) } }
    return ($t -join ' | ')
}

# answers every visible dialog with its OK button (first-run questions)
function Dismiss-All([int]$seconds = 3) {
    $end = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $end) {
        foreach ($d in (Get-Dialogs)) {
            Note ("dialog '{0}': {1} - OK" -f [Drv084]::Txt($d), (Dialog-Text $d))
            $ok = [Drv084]::GetDlgItem($d, 1)
            if ($ok -eq [IntPtr]::Zero) { $ok = [Drv084]::GetDlgItem($d, 6) } # IDYES
            if ($ok -ne [IntPtr]::Zero) { [void][Drv084]::PostMessageW($ok, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
            Start-Sleep -Milliseconds 500
        }
        Start-Sleep -Milliseconds 250
    }
}

function Start-Tc([string]$left, [string]$right) {
    Stop-Tc
    $a = @('-t', 'T084')
    if ($left) { $a += @('-l', ('"{0}"' -f $left)) }
    if ($right) { $a += @('-r', ('"{0}"' -f $right)) }
    $script:proc = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Get-Main) -eq [IntPtr]::Zero) {
        Dismiss-All 1
        if ($script:proc.HasExited) { throw ("tandemcommander exited during start (code {0})" -f $script:proc.ExitCode) }
    }
    if ((Get-Main) -eq [IntPtr]::Zero) { throw 'main window did not appear' }
    Start-Sleep -Seconds 3
    Dismiss-All 2
}

function Close-Tc {
    $m = Get-Main
    if ($m -ne [IntPtr]::Zero) { [void][Drv084]::PostMessageW($m, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 20 -and -not $script:proc.HasExited) { Dismiss-All 1 }
    if (-not $script:proc.HasExited) { Bad 'tandemcommander did not exit on WM_CLOSE'; Stop-Tc } else { $script:proc = $null }
}

function Command([int]$id, [int]$waitMs = 1500) {
    [void][Drv084]::PostMessageW((Get-Main), 0x0111, [IntPtr]$id, [IntPtr]::Zero)
    Start-Sleep -Milliseconds $waitMs
}

function Find-Dialog([string]$titleLike, [int]$seconds = 10) {
    $end = (Get-Date).AddSeconds($seconds)
    while ((Get-Date) -lt $end) {
        foreach ($d in (Get-Dialogs)) { if ([Drv084]::Txt($d) -like $titleLike) { return $d } }
        Start-Sleep -Milliseconds 250
    }
    return [IntPtr]::Zero
}

function Click([IntPtr]$dlg, [int]$id) {
    $b = [Drv084]::GetDlgItem($dlg, $id)
    if ($b -eq [IntPtr]::Zero) { throw "control $id not found" }
    [void][Drv084]::PostMessageW($b, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)
    Start-Sleep -Milliseconds 800
}

# the names of all items in the active panel (select all, copy names, unselect)
function Panel-Names {
    Command 842 500   # CM_ACTIVESELECTALL
    Set-Clipboard -Value ''
    Command 710 800   # CM_CLIPCOPYNAME
    $t = Get-Clipboard -Raw
    Command 844 300   # CM_ACTIVEUNSELECTALL
    if ($null -eq $t) { return @() }
    return @($t -split "`r?`n" | Where-Object { $_ -ne '' } | Sort-Object)
}

function Tree-Hashes([string]$root) {
    $map = @{}
    if (-not (Test-Path -LiteralPath $root)) { return $map }
    foreach ($f in (Get-ChildItem -LiteralPath $root -Recurse -File)) {
        $rel = $f.FullName.Substring($root.Length).TrimStart('\')
        $map[$rel] = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
    }
    return $map
}

function Compare-Trees([string]$got, [string]$ref, [string]$what) {
    $a = Tree-Hashes $got; $b = Tree-Hashes $ref
    $diff = @()
    foreach ($k in (@($a.Keys) + @($b.Keys) | Sort-Object -Unique)) { if ($a[$k] -ne $b[$k]) { $diff += $k } }
    Check ($diff.Count -eq 0 -and $b.Count -gt 0) ("{0}: {1} files identical to 7z.exe's own extraction{2}" -f $what, $b.Count, $(if ($diff.Count) { ' - differ: ' + ($diff -join ', ') } else { '' }))
}

function Set-7zPath([string]$path) {
    # Predefined Packers\<n> with Packer UID 13 (7-Zip)
    foreach ($k in (Get-ChildItem "Registry::$regCfg\Packers & Unpackers\Predefined Packers" -ErrorAction SilentlyContinue)) {
        if ((Get-ItemProperty -LiteralPath $k.PSPath -Name 'Packer UID' -ErrorAction SilentlyContinue).'Packer UID' -eq 13) {
            Set-ItemProperty -LiteralPath $k.PSPath -Name 'Packer Executable' -Value $path
            return $true
        }
    }
    return $false
}

# ---------------------------------------------------------------------------
if (-not (Test-Path -LiteralPath $Exe)) { Bad "exe not found: $Exe"; Finish }
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (Get-Process -Name tandemcommander -ErrorAction SilentlyContinue) { Write-Host 'gui084: tandemcommander.exe is running - close it first'; Write-Host 'RESULT: FAIL'; exit 1 }
if (Test-Path -LiteralPath $Work) { Remove-Item -LiteralPath $Work -Recurse -Force }
New-Item -ItemType Directory -Force -Path $Work | Out-Null

$script:backup = Join-Path $Work ("tc-backup-{0}.reg" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$r = Reg @('export', $regRoot, $script:backup, '/y')
if ($r.Code -ne 0) { $script:backup = $null; Bad ("registry backup failed: {0}" -f $r.Out); Finish }
Copy-Item -LiteralPath $script:backup -Destination (Join-Path $env:TEMP 'tc084-last-registry-backup.reg') -Force
Note ("registry backed up to {0} (copy in %TEMP%\tc084-last-registry-backup.reg)" -f $script:backup)

try {
    # test data in a path with a space and a Czech character
    $data = Join-Path $Work ('data ' + [char]0x0159)   # "data r-caron", built here so the script stays ASCII
    New-Item -ItemType Directory -Force -Path $data | Out-Null
    Copy-Item -LiteralPath (Join-Path $fixtures 'arj\sample.arj') -Destination $data
    Copy-Item -LiteralPath (Join-Path $fixtures '7z\unicode.7z') -Destination (Join-Path $data 'unicode.arj')
    $plain = Join-Path $Work 'plain'; New-Item -ItemType Directory -Force -Path $plain | Out-Null
    Set-Content -LiteralPath (Join-Path $plain 'a.txt') -Value 'x' -Encoding ASCII

    [void](Reg @('delete', $regCfg, '/f'))

    if ($Scenario -contains 'autoconfig' -or $Scenario -contains 'browse' -or $Scenario -contains 'extract' -or $Scenario -contains 'hidden' -or $Scenario -contains 'cancel') {
        Note '--- autoconfig'
        Start-Tc $plain $plain
        Command 685 500   # CM_AUTOCONFIG
        $dlg = Find-Dialog '*Autoconfiguration*'
        if ($dlg -eq [IntPtr]::Zero) { Bad 'Archivers Autoconfiguration dialog did not open' }
        else {
            Start-Sleep -Seconds 1
            Check ([Drv084]::IsWindowEnabled([Drv084]::GetDlgItem($dlg, 1))) 'Autoconfiguration: OK is enabled without a disk scan (7-Zip found from registry / Program Files)'
            Click $dlg 1
            Dismiss-All 2
        }
        Close-Tc
        $exp = Join-Path $Work 'after-autoconfig.reg'
        [void](Reg @('export', "$regCfg\Packers & Unpackers", $exp, '/y'))
        $m = Read-Reg $exp
        $sevenPath = ($m.GetEnumerator() | Where-Object { $_.Key -like '*Predefined Packers*Packer Executable*' -and $_.Value -like '*7z.exe*' } | Select-Object -First 1).Value
        Check ($null -ne $sevenPath) ("Autoconfiguration stored the 7-Zip path: {0}" -f $sevenPath)
        $hasArj = @($m.GetEnumerator() | Where-Object { $_.Key -like '*Archive Association*Extension List*' -and $_.Value -eq '"arj"' }).Count
        Check ($hasArj -eq 1) ("exactly one 'arj' association after Autoconfiguration (found {0})" -f $hasArj)
    }

    if ($Scenario -contains 'browse' -or $Scenario -contains 'extract') {
        Note '--- browse + extract'
        foreach ($case in @(@{ Name = 'sample.arj'; Ref = (Join-Path $fixtures 'arj\sample.arj') }, @{ Name = 'unicode.arj'; Ref = (Join-Path $fixtures '7z\unicode.7z') })) {
            $arc = Join-Path $data $case.Name
            $out = Join-Path $Work ('out ' + $case.Name)
            $ref = Join-Path $Work ('ref ' + $case.Name)
            New-Item -ItemType Directory -Force -Path $out | Out-Null
            & $SevenZip x -y "-o$ref" $case.Ref | Out-Null
            $expected = @(Get-ChildItem -LiteralPath $ref | ForEach-Object { $_.Name } | Sort-Object)
            Start-Tc $arc $out
            $names = Panel-Names
            Check (($names -join '|') -eq ($expected -join '|')) ("{0}: panel shows {1} items = 7-Zip's top level [{2}]" -f $case.Name, $names.Count, ($names -join ', '))
            if ($Scenario -contains 'extract') {
                Command 842 500   # select all
                Command 727 500   # CM_COPYFILES (F5)
                $cp = Find-Dialog '*'
                if ($cp -ne [IntPtr]::Zero) { Note ("copy dialog '{0}'" -f [Drv084]::Txt($cp)); Click $cp 1 }
                Start-Sleep -Seconds 4
                Dismiss-All 2
                Compare-Trees $out $ref $case.Name
                $spawn = @(Get-Process -Name salspawn -ErrorAction SilentlyContinue).Count
                Check ($spawn -eq 0) 'no salspawn process'
            }
            Close-Tc
        }
    }

    if ($Scenario -contains 'hidden') {
        Note '--- hidden'
        Start-Tc $data $plain
        Command 850 500   # CM_PACK
        $dlg = Find-Dialog '*'
        if ($dlg -ne [IntPtr]::Zero) {
            $items = [Drv084]::ComboItems([Drv084]::GetDlgItem($dlg, 511))   # IDC_PACKER
            Note ("Pack dialog offers: {0}" -f ($items -join ' | '))
            Check (-not ($items -match 'RAR|DOS|Win32|1\.44')) 'Pack dialog: no RAR without WinRAR, no DOS/Win32/1.44MB entries'
            Click $dlg 2
        } else { Bad 'Pack dialog did not open' }
        Close-Tc
        # Unpack dialog on sample.arj: the focus goes to the first file
        Start-Tc $data $plain
        $lists = @([Drv084]::Kids((Get-Main)) | Where-Object { [Drv084]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv084]::IsWindowVisible($_) })
        foreach ($vk in 0x24, 0x28) { [void][Drv084]::PostMessageW($lists[0], 0x0100, [IntPtr]$vk, [IntPtr]1); Start-Sleep -Milliseconds 300 } # Home, Down
        Command 851 500   # CM_UNPACK
        $dlg = Find-Dialog '*'
        if ($dlg -ne [IntPtr]::Zero) {
            $items = [Drv084]::ComboItems([Drv084]::GetDlgItem($dlg, 511))
            Note ("Unpack dialog offers: {0}" -f ($items -join ' | '))
            Check ($items -contains '7-Zip') 'Unpack dialog offers 7-Zip while 7z.exe is found'
            Click $dlg 2
        } else { Bad 'Unpack dialog did not open' }
        Close-Tc
        Check (Set-7zPath 'C:\does not exist\7z.exe') 'broke the stored 7-Zip path'
        Start-Tc $data $plain
        foreach ($vk in 0x24, 0x28) { $lists = @([Drv084]::Kids((Get-Main)) | Where-Object { [Drv084]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv084]::IsWindowVisible($_) }); [void][Drv084]::PostMessageW($lists[0], 0x0100, [IntPtr]$vk, [IntPtr]1); Start-Sleep -Milliseconds 300 }
        Command 851 500
        $dlg = Find-Dialog '*'
        if ($dlg -ne [IntPtr]::Zero) {
            $items = [Drv084]::ComboItems([Drv084]::GetDlgItem($dlg, 511))
            Note ("Unpack dialog offers: {0}" -f ($items -join ' | '))
            Check (-not ($items -contains '7-Zip')) 'Unpack dialog hides 7-Zip when 7z.exe is not found'
            Click $dlg 2
        } else { Bad 'Unpack dialog did not open (missing 7-Zip)' }
        Close-Tc
        [void](Set-7zPath $SevenZip)
    }

    if ($Scenario -contains 'cancel') {
        Note '--- cancel'
        $encDir = Join-Path $Work 'enc'; New-Item -ItemType Directory -Force -Path $encDir | Out-Null
        $src = Join-Path $Work 'encsrc'; New-Item -ItemType Directory -Force -Path $src | Out-Null
        Set-Content -LiteralPath (Join-Path $src 'secret.txt') -Value 'secret' -Encoding ASCII
        & $SevenZip a -psecret (Join-Path $encDir 'enc.7z') (Join-Path $src 'secret.txt') | Out-Null
        Move-Item -LiteralPath (Join-Path $encDir 'enc.7z') -Destination (Join-Path $encDir 'enc.arj')
        $out = Join-Path $Work 'out enc'; New-Item -ItemType Directory -Force -Path $out | Out-Null
        Start-Tc (Join-Path $encDir 'enc.arj') $out
        Command 842 500
        Command 727 500
        $cp = Find-Dialog '*'
        if ($cp -ne [IntPtr]::Zero) { Click $cp 1 }
        Start-Sleep -Seconds 3
        $tcPid = $script:proc.Id
        $kids = @(Get-CimInstance Win32_Process -Filter "ParentProcessId=$tcPid")
        Check (@($kids | Where-Object { $_.Name -eq '7z.exe' }).Count -eq 1) ("7z.exe is a direct child of tandemcommander.exe and waits (children: {0})" -f (($kids | ForEach-Object { $_.Name }) -join ', '))
        # the wait window: a top-level window of the process with a Cancel button (IDCANCEL)
        $wait = $null
        foreach ($h in [Drv084]::Top([uint32]$tcPid)) {
            if ([Drv084]::IsWindowVisible($h) -and [Drv084]::Cls($h) -ne $MainClass -and [Drv084]::GetDlgItem($h, 2) -ne [IntPtr]::Zero) { $wait = $h }
        }
        if ($null -eq $wait) { Bad 'wait window with a Cancel button not found' }
        else {
            Click $wait 2
            Start-Sleep -Seconds 2
            $left = @(Get-CimInstance Win32_Process -Filter "Name='7z.exe'" | Where-Object { $_.ParentProcessId -eq $tcPid }).Count
            Check ($left -eq 0) 'Cancel stopped 7z.exe'
            $dlgs = @(Get-Dialogs)
            Check ($dlgs.Count -eq 0) ("no message after Cancel of an unpack{0}" -f $(if ($dlgs.Count) { ': ' + (($dlgs | ForEach-Object { Dialog-Text $_ }) -join ' / ') } else { '' }))
            Check (@(Get-ChildItem -LiteralPath $out -Recurse -File).Count -eq 0) 'nothing was written to the target'
        }
        Close-Tc
    }

    if ($Scenario -contains 'migration') {
        Note '--- migration'
        $fx = Join-Path $fixtures 'cfg\cfg_a_defaults.reg'
        if (-not (Test-Path -LiteralPath $fx)) { Bad "fixture missing: $fx (run make_cfg_fixtures.ps1 first)" }
        else {
            [void](Reg @('delete', $regCfg, '/f'))
            $r = Reg @('import', $fx)
            [void](Reg @('add', "$regCfg\Version", '/v', 'Configuration', '/t', 'REG_DWORD', '/d', '105', '/f'))
            Check ($r.Code -eq 0) 'imported the 0.1.8 configuration'
            $before = Join-Path $Work 'mig-before.reg'
            [void](Reg @('export', $regCfg, $before, '/y'))
            Start-Tc $plain $plain
            Close-Tc
            $after = Join-Path $Work 'mig-after.reg'
            [void](Reg @('export', $regCfg, $after, '/y'))
            $m = Read-Reg $after
            $pu = $m.GetEnumerator() | Where-Object { $_.Key -like '*Packers & Unpackers*' }
            $text = ($pu | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "`n"
            Check (-not ($text -match '(?i)Jar32bit|Jar16bit|Rar16bit|Arj32bit|Arj16bit|Ace32bit|Ace16bit|Lha16bit|UC216bit|Zip32bit|Zip16bit|Unzip16bit')) 'M1: no entry calls a removed archiver'
            Check (-not ($text -match 'v1440')) 'M1: no floppy-volume preset'
            Check ($text -match 'RAR \(WinRAR\)') 'M1b: the default RAR packer was rewritten'
            Check (-not ($text -match '(?i)x -scol')) 'M1c: the default RAR unpacker was removed'
            Check ($text -match 'SevenZipExecutable') 'M1d: the 7-Zip unpacker was added'
            $exts = @($pu | Where-Object { $_.Key -like '*Extension List*' } | ForEach-Object { $_.Value })
            Note ("associations: {0}" -f ($exts -join ' '))
            Check (-not ($exts -match '^"(j|uc2|ace;c##|arj;a##|lzh)"$')) 'M2: no association of a removed archiver'
            Check (($exts -contains '"rar;r##"') -and ($exts -contains '"arj"') -and ($exts -contains '"lzh;lha"')) 'M2/M3: rar;r## kept, arj and lzh;lha added'
            $ver = (Get-ItemProperty -LiteralPath "Registry::$regCfg\Version" -Name Configuration).Configuration
            Check ($ver -eq 106) "configuration version is now $ver"
            # M5: nothing outside Packers & Unpackers changed except the allow-list
            $b = Read-Reg $before; $allow = '(?i)Packers & Unpackers|\\Version ::|LastPluginVer|ShowSLGIncomplete|\\Plugins|Window|Panel|Position|History'
            $other = @()
            foreach ($k in (@($b.Keys) + @($m.Keys) | Sort-Object -Unique)) { if ($b[$k] -ne $m[$k] -and $k -notmatch $allow) { $other += $k } }
            Note ("changes outside the archiver configuration (not allow-listed): {0}" -f $(if ($other.Count) { $other -join '; ' } else { 'none' }))
            # idempotence
            Start-Tc $plain $plain
            Close-Tc
            $again = Join-Path $Work 'mig-again.reg'
            [void](Reg @('export', "$regCfg\Packers & Unpackers", $again, '/y'))
            $first = Join-Path $Work 'mig-first-pu.reg'
            [void](Reg @('export', "$regCfg\Packers & Unpackers", $first, '/y'))
            $x = Read-Reg $again; $y = Read-Reg (Join-Path $Work 'mig-after.reg')
            $d = 0
            foreach ($k in $x.Keys) { if ($y.Contains($k) -and $x[$k] -ne $y[$k]) { $d++ } }
            Check ($d -eq 0) 'a second start changes nothing in the archiver configuration'
        }
    }
}
catch {
    Bad ("probe error: {0}" -f $_.Exception.Message)
}
Finish
