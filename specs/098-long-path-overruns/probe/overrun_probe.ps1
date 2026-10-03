<#
.SYNOPSIS
    Feature 098 probe: drive three long-path overruns found by the 097 review.

    D1  Navigate plain DISK folders very deep (walk in by Enter from a short
        entry point into a chain of 180-byte components) and watch for a
        run-time-check / crash window and a new crash report under
        %LOCALAPPDATA%\Tandem Commander.  Records the depth and approximate
        path byte length at which it first happens (CStatusWindow /
        BuildHotTrackItems, src\stswnd.cpp).  A second chain of 1-byte
        components tests whether it is the COUNT of components or the LENGTH.
    D2  Change Directory to a typed path to a normal FILE (not an archive) in
        a folder about 300 bytes deep: strcpy into shortenedPath[MAX_PATH]
        (src\fileswn3.cpp).  Expected product intent: go to the folder and
        focus the file.
    D3  Unpack a 7z archive that holds one item whose in-archive path is about
        1,100 bytes and whose data is corrupt (CRC error): the plug-in formats
        msg[1024] with the item path (src\plugins\7zip\extract.cpp).

    MUST be started through tools\run_on_hidden_desktop.ps1.  Refuses to run
    while a tandemcommander.exe other than -Exe is running.  The registry key
    HKCU\Software\Tandem Commander is exported before the first start and
    restored + SHA-256-verified at the end.  Scratch only under
    %TEMP%\tc098_overruns, removed by name.  Exit code = number of defects for
    which the drive could not run (fixtures); a confirmed overrun is a normal
    result, not a probe failure.

.PARAMETER Exe
    tandemcommander.exe of the build under test (Debug, /RTC1).
.PARAMETER Only
    d1,d1short,d2,d3 (default all).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python',
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue | Where-Object { $_.Path -ine $Exe })
if ($others.Count) { Write-Output ('NOT RUN: another tandemcommander.exe is running: ' + (($others | ForEach-Object { $_.Path }) -join '; ')); exit 3 }

if (-not ('Drv098' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class Drv098
{
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindowEnabled(IntPtr h);
    [DllImport("user32.dll")] public static extern bool IsWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] public static extern IntPtr SendTextTimeout(IntPtr h, uint msg, IntPtr w, string l, uint flags, uint timeout, out IntPtr result);
    [DllImport("kernel32.dll")] public static extern uint GetACP();
    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Txt(IntPtr h) { var s = new StringBuilder(8192); GetWindowTextW(h, s, 8192); return s.ToString(); }
    public static uint PidOf(IntPtr h) { uint q; GetWindowThreadProcessId(h, out q); return q; }
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
    public static bool Send(IntPtr h, uint msg, long w, long l, uint timeout)
    {
        IntPtr res;
        return SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, timeout, out res) != IntPtr.Zero;
    }
    public static bool SetText(IntPtr h, string s, uint timeout)
    {
        IntPtr res;
        return SendTextTimeout(h, 0x000C, IntPtr.Zero, s, 0, timeout, out res) != IntPtr.Zero;
    }
}
'@
}

$MainClass = 'TandemCommanderMainWindowVer01'
$RegKey = 'HKCU\Software\Tandem Commander'
$SystemClasses = @('UAC_InputIndicatorOverlayWnd', 'UAC Input Indicator')
$Started = New-Object System.Collections.ArrayList
$script:Procs = @{}
$script:Lines = New-Object System.Collections.ArrayList
$LP = '\\?\'
$Utf8 = New-Object Text.UTF8Encoding($false)
$ReportDir = Join-Path $env:LOCALAPPDATA 'Tandem Commander'
$TempRoot = [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')
$Root = $TempRoot + '\tc098_overruns'
$FatalRx = 'Run-Time Check|Debug Error|Assertion|Runtime Library|Stack around|bug report|abnormal|has stopped|Unhandled exception|buffer overrun|Microsoft Visual C'

function Out([string]$s) { Write-Host $s; [void]$script:Lines.Add($s) }
function Esc([string]$s) {
    if ($null -eq $s) { return '<null>' }
    $sb = New-Object Text.StringBuilder
    foreach ($c in $s.ToCharArray()) { if ([int]$c -ge 32 -and [int]$c -lt 127) { [void]$sb.Append($c) } else { [void]$sb.AppendFormat('\u{0:X4}', [int]$c) } }
    return $sb.ToString()
}
function U8Len([string]$s) { return $Utf8.GetByteCount($s) }
function Test-Alive([int]$Id) { return [bool](Get-Process -Id $Id -ErrorAction SilentlyContinue) }
function Get-Tops([int]$Id) { return @([Drv098]::Top([uint32]$Id) | Where-Object { $SystemClasses -notcontains [Drv098]::Cls($_) }) }
function Get-Main([int]$Id) { foreach ($h in [Drv098]::Top([uint32]$Id)) { if ([Drv098]::Cls($h) -eq $MainClass) { return $h } }; return [IntPtr]::Zero }
function FullText([IntPtr]$H) {
    $parts = @()
    foreach ($c in [Drv098]::Kids($H)) { $t = [Drv098]::Txt($c); if ($t -and [Drv098]::IsWindowVisible($c)) { $parts += ("[{0} id={1}] {2}" -f [Drv098]::Cls($c), [Drv098]::GetDlgCtrlID($c), (Esc ($t -replace '\s+', ' '))) } }
    $r = ($parts -join ' | '); if ($r.Length -gt 500) { $r = $r.Substring(0, 500) + '...' }; return $r
}
function WinDesc([IntPtr]$H) { return ("[{0} '{1}'] {2}" -f [Drv098]::Cls($H), (Esc ([Drv098]::Txt($H))), (FullText $H)) }
function Is-Fatal([string]$d) { return ($d -match $FatalRx) }
function Reports { return @(Get-ChildItem -LiteralPath $ReportDir -Filter 'TC*.TXT' -ErrorAction SilentlyContinue | ForEach-Object { $_.Name }) }
function Post-Cmd([IntPtr]$H, [int]$C) { [void][Drv098]::PostMessageW($H, 0x0111, [IntPtr]$C, [IntPtr]::Zero) }
function Get-LeftList([int]$Id) {
    $m = Get-Main $Id
    $lists = @([Drv098]::Kids($m) | Where-Object { [Drv098]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv098]::IsWindowVisible($_) })
    if ($lists.Count -lt 1) { throw 'panel list window not found' }
    return $lists[0]
}
function PostKey([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    [void][Drv098]::PostMessageW($l, 0x0100, [IntPtr]$Vk, [IntPtr]1)
    [void][Drv098]::PostMessageW($l, 0x0101, [IntPtr]$Vk, [IntPtr]0xC0000001L)
}

function Backup-Reg([string]$File) {
    & cmd.exe /c "reg query `"$RegKey`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    & cmd.exe /c "reg export `"$RegKey`" `"$File`" /y >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw 'reg export failed' }
    return $true
}
function Restore-Reg([string]$File, [bool]$Existed) {
    & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"
    if (-not $Existed) { Out 'Registry: key did not exist before - deleted'; return $true }
    & cmd.exe /c "reg import `"$File`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { Out "Registry: IMPORT FAILED - restore by hand from $File"; return $false }
    $check = "$File.check"
    & cmd.exe /c "reg export `"$RegKey`" `"$check`" /y >nul 2>&1"
    $ha = (Get-FileHash -LiteralPath $File).Hash; $hb = (Get-FileHash -LiteralPath $check).Hash
    Out ("Registry: restored; identical={0}; SHA-256 before {1} / after {2}" -f ($ha -eq $hb), $ha, $hb)
    Remove-Item -LiteralPath $check -Force
    return ($ha -eq $hb)
}
function Set-Config {
    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    $fresh = ($LASTEXITCODE -ne 0)
    if (-not $fresh) {
        & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d 'english.slg' /f | Out-Null
        & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null
    }
    return $fresh
}

function Start-Tc([string]$Dir) {
    $a = @('-t', 'T098'); if ($Dir) { $a += @('-l', ('"{0}"' -f $Dir)) }; $a += @('-r', ('"{0}"' -f $TempRoot), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 2500
    return $p.Id
}
function Kill-Mine([int]$Id) {
    if (-not (Test-Alive $Id)) { return }
    if ($Started -notcontains $Id) { throw "pid $Id was not started by this probe" }
    Stop-Process -Id $Id -Force; Start-Sleep -Milliseconds 700
}
function Stop-Tc([int]$Id) {
    if (-not (Test-Alive $Id)) { return }
    $m = Get-Main $Id
    if ($m -ne [IntPtr]::Zero) { [void][Drv098]::PostMessageW($m, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15 -and (Test-Alive $Id)) {
        foreach ($h in (Get-Tops $Id)) { if ([Drv098]::Cls($h) -eq '#32770') { foreach ($b in @([Drv098]::Kids($h) | Where-Object { @(1, 6) -contains [Drv098]::GetDlgCtrlID($_) })) { [void][Drv098]::PostMessageW($b, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) } } }
        Start-Sleep -Milliseconds 200
    }
    if (Test-Alive $Id) { Kill-Mine $Id }
}
# collect fatal windows + new crash reports of the pid; returns descriptor or $null
function Check-Fatal([int]$Id, $BeforeReports) {
    $fatal = $null
    if (Test-Alive $Id) {
        foreach ($h in (Get-Tops $Id)) {
            $cls = [Drv098]::Cls($h)
            if ($cls -eq $MainClass) { continue }
            $d = WinDesc $h
            if (Is-Fatal $d) { $fatal = 'WINDOW ' + $d; break }
        }
    }
    $now = Reports
    $new = @($now | Where-Object { $BeforeReports -notcontains $_ })
    if ($new.Count -and -not $fatal) { $fatal = 'CRASH REPORT ' + ($new -join ',') }
    elseif ($new.Count) { $fatal += ' + CRASH REPORT ' + ($new -join ',') }
    return $fatal
}
function Read-NewReports($BeforeReports) {
    $new = @((Reports) | Where-Object { $BeforeReports -notcontains $_ })
    foreach ($n in $new) {
        $p = Join-Path $ReportDir $n
        Out ("---- crash report $n (head) ----")
        try { Get-Content -LiteralPath $p -TotalCount 60 | ForEach-Object { Out ('  ' + (Esc $_)) } } catch { Out ('  (could not read: ' + $_.Exception.Message + ')') }
        Out '---- end ----'
    }
}
function Remove-NewReports($BeforeReports) {
    foreach ($n in @((Reports) | Where-Object { $BeforeReports -notcontains $_ })) { Remove-Item -LiteralPath (Join-Path $ReportDir $n) -Force -ErrorAction SilentlyContinue }
}
# Change Directory (862) -> field 210 wide WM_SETTEXT -> OK; returns the field text held
function Do-ChangeDir([int]$Id, [string]$Text) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 862
    $dlg = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 8 -and $dlg -eq [IntPtr]::Zero) { foreach ($h in (Get-Tops $Id)) { if ($known -notcontains $h) { $dlg = $h; break } }; Start-Sleep -Milliseconds 100 }
    if ($dlg -eq [IntPtr]::Zero) { throw 'Change Directory opened no window' }
    Start-Sleep -Milliseconds 300
    $ctl = @([Drv098]::Kids($dlg) | Where-Object { [Drv098]::GetDlgCtrlID($_) -eq 210 -and @('ComboBox', 'Edit') -contains [Drv098]::Cls($_) }) | Select-Object -First 1
    if (-not $ctl) { throw 'path field (210) not found' }
    [void][Drv098]::SetText($ctl, $Text, 5000)
    $ok = @([Drv098]::Kids($dlg) | Where-Object { [Drv098]::GetDlgCtrlID($_) -eq 1 -and [Drv098]::Cls($_) -eq 'Button' }) | Select-Object -First 1
    if ($ok) { [void][Drv098]::PostMessageW($ok, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
    Start-Sleep -Milliseconds 900
}

# ---- fixtures ---------------------------------------------------------------
function Make-Chain([string]$BaseAbs, [int]$Comp, [int]$Levels) {
    # one linear chain BaseAbs\<comp>\<comp>\...  ($Levels deep); returns array of cumulative absolute paths
    $seg = 'p' * $Comp
    $cur = $BaseAbs
    $paths = @()
    [void][IO.Directory]::CreateDirectory($LP + $cur)
    for ($i = 0; $i -lt $Levels; $i++) { $cur = $cur + '\' + $seg; [void][IO.Directory]::CreateDirectory($LP + $cur); $paths += $cur }
    return $paths
}

# ---- D1: deep disk navigation -----------------------------------------------
# entryBytes stays <=519 so Change Directory can reach it; then walk in by Enter
function Run-D1([string]$Tag, [int]$Comp) {
    Out ''
    Out ("=== D1 ($Tag): walk into a chain of $Comp-byte components ===")
    $base = $Root + '\d1' + $Tag
    # build chain long enough to pass ~9000 bytes
    $levels = [int]([Math]::Ceiling(9200 / ($Comp + 1))) + 2
    $paths = Make-Chain $base $Comp $levels
    # entry: deepest cumulative path whose length <= 500 bytes
    $entryIdx = -1
    for ($i = 0; $i -lt $paths.Count; $i++) { if ((U8Len $paths[$i]) -le 500) { $entryIdx = $i } }
    if ($entryIdx -lt 0) { Out 'FIXTURE: first component already over 500 bytes'; return 1 }
    $entry = $paths[$entryIdx]
    Out ("chain: $levels levels of $Comp bytes; deepest built = {0} bytes; entry (<=500) = {1} bytes at level {2}" -f (U8Len $paths[-1]), (U8Len $entry), ($entryIdx + 1))
    $id = 0
    try {
        $before = Reports
        $id = Start-Tc $entry
        $f = Check-Fatal $id $before
        if ($f) { Out ("FATAL at entry (level {0}, {1} bytes): {2}" -f ($entryIdx + 1), (U8Len $entry), $f); Read-NewReports $before; return 0 }
        # walk in: End selects the last item (the single subfolder), Enter descends
        $lvl = $entryIdx + 1
        for ($i = $entryIdx + 1; $i -lt $paths.Count; $i++) {
            if (-not (Test-Alive $id)) { Out ("PROCESS DIED before level {0}" -f ($i + 1)); break }
            PostKey $id 0x23      # End
            Start-Sleep -Milliseconds 120
            PostKey $id 0x0D      # Enter
            Start-Sleep -Milliseconds 350
            $lvl = $i + 1
            $f = Check-Fatal $id $before
            if ($f) {
                Out ("FATAL at level {0} (target path {1} bytes): {2}" -f $lvl, (U8Len $paths[$i]), $f)
                Read-NewReports $before
                return 0
            }
        }
        Out ("NO FATAL: reached level {0} (~{1} bytes), process alive = {2}" -f $lvl, (U8Len $paths[[Math]::Min($lvl, $paths.Count) - 1]), (Test-Alive $id))
        return 0
    }
    finally { if ($id) { $b2 = Reports; Stop-Tc $id; Remove-NewReports $before } }
}

# ---- D2: Change Directory to a file path ------------------------------------
function Run-D2 {
    Out ''
    Out '=== D2: Change Directory to a normal FILE at ~300 bytes ==='
    $base = $Root + '\d2'
    # a folder whose absolute path is ~300 bytes, holding f.txt
    $seg = 'q' * 180
    $dir = $base + '\' + $seg
    $need = 300 - (U8Len $dir)
    if ($need -gt 0) { $dir = $dir + '\' + ('r' * ($need - 1)) }
    [void][IO.Directory]::CreateDirectory($LP + $dir)
    $file = $dir + '\f.txt'
    [IO.File]::WriteAllText($LP + $file, "hello`r`n", (New-Object Text.ASCIIEncoding))
    Out ("file full path = {0} bytes: {1}" -f (U8Len $file), (Esc ('...' + $file.Substring([Math]::Max(0, $file.Length - 40)))))
    if ((U8Len $file) -gt 519) { Out 'FIXTURE: file path over 519 bytes, cannot type it in Change Directory'; return 1 }
    $id = 0
    try {
        $before = Reports
        $id = Start-Tc $TempRoot
        Do-ChangeDir $id $file
        Start-Sleep -Milliseconds 600
        $f = Check-Fatal $id $before
        if ($f) { Out ("FATAL: $f"); Read-NewReports $before; return 0 }
        $title = ''; if (Test-Alive $id) { $title = [Drv098]::Txt((Get-Main $id)) }
        Out ("NO FATAL: process alive = {0}; main title (tail) = {1}" -f (Test-Alive $id), (Esc ('...' + $title.Substring([Math]::Max(0, $title.Length - 40)))))
        return 0
    }
    finally { if ($id) { Stop-Tc $id; Remove-NewReports $before } }
}

# ---- D3: 7z with a long internal path, corrupt, unpack ----------------------
function Run-D3 {
    Out ''
    Out '=== D3: unpack a 7z whose corrupt item has a ~1100-byte internal path ==='
    if (-not (Test-Path -LiteralPath $SevenZip)) { Out "FIXTURE: 7z.exe not at $SevenZip"; return 1 }
    $base = $Root + '\d3'
    $panel = $base + '\panel'
    [void][IO.Directory]::CreateDirectory($panel)
    # stage: build a nested folder tree so the stored relative path of the file is ~1100 bytes
    $stage = $base + '\stage'
    $seg = 'L' * 120   # 9 levels of 120 + name ~ 1100 bytes
    $rel = (@(1..9 | ForEach-Object { $seg }) -join '\') + '\corruptdata.bin'
    $full = $stage + '\' + $rel
    $parent = [IO.Path]::GetDirectoryName($LP + $full)
    [void][IO.Directory]::CreateDirectory($parent)
    # store-only (-mx0) so one flipped byte becomes a CRC error on that item
    $bytes = New-Object byte[] 4096
    (New-Object Random).NextBytes($bytes)
    [IO.File]::WriteAllBytes($LP + $full, $bytes)
    $arc = $panel + '\deep.7z'
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    Push-Location -LiteralPath ($LP + $stage)
    try { $o = & $SevenZip a -t7z -mx0 $arc ($seg + '\*') -r 2>&1; $rc = $LASTEXITCODE } finally { Pop-Location; $ErrorActionPreference = $old }
    if ($rc -ne 0) { Out ('FIXTURE: 7z a failed: ' + ($o -join ' ')); return 1 }
    # report the stored internal path length
    $ErrorActionPreference = 'Continue'; $listing = & $SevenZip l -slt $arc 2>&1; $ErrorActionPreference = $old
    $pathLine = @($listing | Where-Object { $_ -match '^Path = .*corruptdata' }) | Select-Object -First 1
    if ($pathLine) { $stored = ($pathLine -replace '^Path = ', ''); Out ("stored internal path = {0} bytes" -f (U8Len $stored)) }
    # corrupt: flip bytes in the middle of the archive's compressed/stored stream
    $raw = [IO.File]::ReadAllBytes($arc)
    for ($i = [int]($raw.Length / 2); $i -lt [int]($raw.Length / 2) + 64 -and $i -lt $raw.Length; $i++) { $raw[$i] = $raw[$i] -bxor 0xFF }
    [IO.File]::WriteAllBytes($arc, $raw)
    # verify 7z itself now reports a data/CRC error
    $ErrorActionPreference = 'Continue'; $t = & $SevenZip t $arc 2>&1; $trc = $LASTEXITCODE; $ErrorActionPreference = $old
    Out ("7z t after corruption: rc=$trc (" + (($t | Where-Object { $_ -match 'ERROR|CRC|Data' }) -join '; ') + ')')
    $out = $base + '\out'; [void][IO.Directory]::CreateDirectory($out)
    $id = 0
    try {
        $before = Reports
        $id = Start-Tc $panel
        PostKey $id 0x23      # End: the archive
        Start-Sleep -Milliseconds 300
        # CM_UNPACK = 851
        $known = Get-Tops $id
        Post-Cmd (Get-Main $id) 851
        $dlg = [IntPtr]::Zero; $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 10 -and $dlg -eq [IntPtr]::Zero) { foreach ($h in (Get-Tops $id)) { if ($known -notcontains $h) { $dlg = $h; break } }; Start-Sleep -Milliseconds 100 }
        if ($dlg -eq [IntPtr]::Zero) {
            $f = Check-Fatal $id $before
            if ($f) { Out ("FATAL opening Unpack: $f"); Read-NewReports $before; return 0 }
            Out 'NO UNPACK DIALOG (and no fatal) - could not drive'; return 1
        }
        Start-Sleep -Milliseconds 300
        $ctl = @([Drv098]::Kids($dlg) | Where-Object { [Drv098]::GetDlgCtrlID($_) -eq 210 -and @('ComboBox', 'Edit') -contains [Drv098]::Cls($_) }) | Select-Object -First 1
        if ($ctl) { [void][Drv098]::SetText($ctl, $out, 5000) }
        $ok = @([Drv098]::Kids($dlg) | Where-Object { [Drv098]::GetDlgCtrlID($_) -eq 1 -and [Drv098]::Cls($_) -eq 'Button' }) | Select-Object -First 1
        if ($ok) { [void][Drv098]::PostMessageW($ok, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
        # serve: answer the CRC error dialog (Delete/Keep/Cancel) if it appears; watch for fatal
        $sw = [Diagnostics.Stopwatch]::StartNew()
        $sawPrompt = $false
        while ($sw.Elapsed.TotalSeconds -lt 30) {
            if (-not (Test-Alive $id)) { break }
            $f = Check-Fatal $id $before
            if ($f) { Out ("FATAL during unpack: $f"); Read-NewReports $before; return 0 }
            foreach ($h in (Get-Tops $id)) {
                if ([Drv098]::Cls($h) -eq $MainClass) { continue }
                if (-not [Drv098]::IsWindowEnabled($h)) { continue }
                $btns = @([Drv098]::Kids($h) | Where-Object { [Drv098]::Cls($_) -eq 'Button' -and [Drv098]::IsWindowVisible($_) })
                $ids = @($btns | ForEach-Object { [Drv098]::GetDlgCtrlID($_) })
                if (($ids.Count -eq 1 -and $ids[0] -eq 2) -or $ids.Count -eq 0) { continue }   # progress
                $sawPrompt = $true
                Out ('dialog during unpack: ' + (WinDesc $h))
                $pick = $btns | Where-Object { @(1, 6, 7) -contains [Drv098]::GetDlgCtrlID($_) } | Select-Object -First 1
                if ($pick) { [void][Drv098]::PostMessageW($pick, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) } else { [void][Drv098]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
                Start-Sleep -Milliseconds 400
            }
            Start-Sleep -Milliseconds 150
        }
        Out ("NO FATAL: unpack finished; process alive = {0}; saw a prompt = {1}" -f (Test-Alive $id), $sawPrompt)
        return 0
    }
    finally { if ($id) { Stop-Tc $id; Remove-NewReports $before } }
}

# ---- main -------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc098_backup.reg'
$existed = Backup-Reg $backup
$restored = $false
$fixFail = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    [void][IO.Directory]::CreateDirectory($Root)
    $fresh = Set-Config
    Out ("overrun_probe (feature 098)")
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; config key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098]::GetACP(), $existed)

    if (Want 'd1')      { $fixFail += Run-D1 'big' 180 }
    if (Want 'd1short') { $fixFail += Run-D1 'short' 1 }
    if (Want 'd2')      { $fixFail += Run-D2 }
    if (Want 'd3')      { $fixFail += Run-D3 }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    Out ''
    Out ("=== end === left running: {0}; fixture removed: {1}; registry restored+identical: {2}; fixture failures: {3}" -f $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored, $fixFail)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $fixFail
