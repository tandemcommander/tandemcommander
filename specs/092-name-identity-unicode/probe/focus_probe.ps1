<#
.SYNOPSIS
    Feature 092, stage S2 (User Story 1): "the cursor follows a name" - the
    look-ups of ONE item by name in a panel, driven in two builds.

.DESCRIPTION
    Runs the same scenarios against -OldExe (built before feature 092: the
    code-page byte fold, StrICmp) and -NewExe (the file system's rule,
    SalNameEqualOrdinalCI) and prints what each build did.

    The colliding pair: h-circumflex (U+0125, UTF-8 C4 A5) and L-acute
    (U+0139, UTF-8 C4 B9). The script first PROVES the collision on this
    machine: CharLowerA(0xA5) == CharLowerA(0xB9) in the system code page
    (1250: both give 0xB9), so the old byte fold saw two different letters
    as one name. If they do not collide (another code page) the collision
    scenarios are reported as NOT APPLICABLE. The case pair: C-caron
    U+010C (C4 8C) / c-caron U+010D (C4 8D): the byte fold maps 8C -> 9C
    and 8D -> 9D, so the old build saw one name as two.

    How the focus is observed (no person, no SendInput):
      file       CM_VIEW (742) -> the title of the new viewer window names the file
      directory  Enter -> the main window title names the directory entered
    Folders used for Enter contain ONLY directories (Enter on a file would
    start an associated program).

    Scenarios (each on a fresh instance: -t T092F -l <folder> -r <empty> -p 1)
      F1    go up lands on the directory just left; dirs aaa, h^, L', mmm, zzz
            (CommonRefresh, suggestedFocusName). Every directory is entered
            (Home, k x Down, Enter), left with Backspace, and Enter again
            must enter the same one. Both builds are right here: an exact
            match always won over a folded one, and the name asked for is
            the exact name of the directory just left.
      F1r   refresh keeps the focus on a directory of the colliding pair
            (RefreshDirectory, old focus by name): Home, k x Down,
            CM_LEFTREFRESH (724), Enter.
      F1p   the panel path spelled in the other case: disk has directory
            "C-caron", the instance starts in "...\c-caron"; go up; Enter.
            Does not discriminate: both builds correct the spelling of the
            path to the disk's when they enter it (the title shows it).
      F2    the focus follows a change of case: C-caron.txt focused, two files
            are added before it in name order (the index shifts), then the
            file is renamed OUTSIDE the program to c-caron.txt, refresh, F3.
            Then back (c -> C) with the focus put on it again first.
            The rename is ONE MoveFileW call, not two steps through a
            temporary name: the panel refreshes itself on change
            notifications, and a refresh between two steps would see the
            temporary name and lose the focus in BOTH builds.
      F2x   refresh keeps the focus on a FILE of the colliding pair
            (h^.txt, L'.txt): focus each in turn, refresh, F3.
      F4    Quick Rename (CM_RENAMEFILE 754, the Rename dialog) of
            "Cla'nek.txt" (C-caron) to "cla'nek.txt" (c-caron): afterwards
            the focus is on the renamed file and the disk has the new name.
      F1c / F1pc / F2c / F4c   the same with plain ASCII names (controls).

    Verdicts: for the NEW build PASS = the focus is on the right item.
    For the OLD build PASS = it did what is recorded in $OldExpect below
    (the defect where the old code has one, the correct result where it
    never had one - e.g. an exact match always won over a folded match, so
    "go up" with BOTH colliding directories present was right before, too).

    SAFETY: only processes started here are addressed, by pid; messages go
    only to windows of those pids; no SendInput. HKCU\Software\Tandem
    Commander is exported to %TEMP%\tc092_focus_backup.reg before the first
    start and restored and verified (SHA-256 of a second export) at the end.
    The only value changed for the run is the exit confirmation. The test
    folder %TEMP%\tc092_focus is removed.

.PARAMETER OldExe
    tandemcommander.exe built before feature 092.
.PARAMETER NewExe
    tandemcommander.exe built from the feature 092 tree.
.PARAMETER Only
    Run only the named scenarios, e.g. -Only F1,F2.

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII (names are built from
    character codes). Exit code = number of FAIL lines (+1 if the registry
    restore could not be verified).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$OldExe,
    [Parameter(Mandatory = $true)][string]$NewExe,
    [string[]]$Only
)

$ErrorActionPreference = 'Stop'
$OldExe = (Resolve-Path -LiteralPath $OldExe).Path
$NewExe = (Resolve-Path -LiteralPath $NewExe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() }) }

if (-not ('Drv092F' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;

public static class Drv092F
{
    public delegate bool EnumProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr parent, EnumProc cb, IntPtr l);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
    [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
    [DllImport("user32.dll")] public static extern int GetDlgCtrlID(IntPtr h);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    [DllImport("user32.dll", SetLastError = true)] public static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] public static extern IntPtr SendTextTimeout(IntPtr h, uint msg, IntPtr w, string l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Unicode, EntryPoint = "SendMessageTimeoutW")] public static extern IntPtr SendGetText(IntPtr h, uint msg, IntPtr w, StringBuilder l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern IntPtr CharLowerA(IntPtr c);
    [DllImport("kernel32.dll")] public static extern uint GetACP();
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool MoveFileW(string a, string b);

    public static string Cls(IntPtr h) { var s = new StringBuilder(256); GetClassNameW(h, s, 256); return s.ToString(); }
    public static string Txt(IntPtr h) { var s = new StringBuilder(4096); GetWindowTextW(h, s, 4096); return s.ToString(); }
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
    // synchronous send; false on timeout
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
    public static string GetText(IntPtr h, uint timeout)   // WM_GETTEXT: GetWindowText does not read another process's control
    {
        IntPtr res; var sb = new StringBuilder(2048);
        SendGetText(h, 0x000D, (IntPtr)2048, sb, 0, timeout, out res);
        return sb.ToString();
    }
    public static int Lower(int b) { return (int)CharLowerA((IntPtr)b).ToInt64(); }
}
'@
}

$MainClass = 'TandemCommanderMainWindowVer01'
$RegKey = 'HKCU\Software\Tandem Commander'
$Started = New-Object System.Collections.ArrayList
$script:Results = @()
$script:Fail = 0
$script:Dialogs = @()

# ---- names (built from character codes: the script stays ASCII) -------------
function S([int[]]$codes) { return -join ($codes | ForEach-Object { [char]$_ }) }
$Hc = S 0x125          # h with circumflex   UTF-8 C4 A5
$La = S 0x139          # L with acute        UTF-8 C4 B9
$Cup = S 0x10C          # C with caron        UTF-8 C4 8C
$Clo = S 0x10D          # c with caron        UTF-8 C4 8D
$aa = S 0xE1           # a with acute
$ClanekU = $Cup + 'l' + $aa + 'nek.txt'
$ClanekL = $Clo + 'l' + $aa + 'nek.txt'
function Show([string]$s) {   # a name with its code points, for a console that may not print it
    if ($null -eq $s) { return '<null>' }
    $non = @($s.ToCharArray() | Where-Object { [int]$_ -gt 127 } | ForEach-Object { 'U+{0:X4}' -f [int]$_ })
    if ($non.Count) { return ("'{0}' [{1}]" -f $s, ($non -join ' ')) } else { return "'$s'" }
}

# What the OLD build is expected to do: $true = correct focus, $false = the defect.
# Measured on the pre-feature Release build, system code page 1250 (see fix-log).
$OldExpect = @{
    'F1' = $true; 'F1r' = $false; 'F1p' = $true; 'F2' = $false; 'F2x' = $false; 'F4' = $true
    'F1c' = $true; 'F1pc' = $true; 'F2c' = $true; 'F4c' = $true
}

function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }
function Report([string]$Scn, [string]$Build, $Correct, [string]$Facts) {
    if ($null -eq $Correct) { $v = 'FAIL'; $script:Fail++; $what = 'NOT DRIVEN' }
    elseif ($Build -eq 'NEW') { if ($Correct) { $v = 'PASS'; $what = 'correct' } else { $v = 'FAIL'; $script:Fail++; $what = 'WRONG FOCUS' } }
    else {
        $exp = $OldExpect[$Scn]
        if ($Correct -eq $exp) { $v = 'PASS' } else { $v = 'FAIL'; $script:Fail++ }
        if ($Correct) { $what = 'correct' } else { $what = 'old defect shown' }
        if ($Correct -ne $exp) { $what += ' (UNEXPECTED for the old build)' }
    }
    $line = "{0,-5} {1} {2}  {3}: {4}" -f $Scn, $Build, $v, $what, $Facts
    Write-Host $line
    $script:Results += $line
}

# ---- registry ---------------------------------------------------------------
function Backup-TcRegistry([string]$File) {
    & cmd.exe /c "reg query `"$RegKey`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { return $false }
    & cmd.exe /c "reg export `"$RegKey`" `"$File`" /y >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { throw 'reg export failed' }
    return $true
}
function Restore-TcRegistry([string]$File, [bool]$Existed) {
    & cmd.exe /c "reg delete `"$RegKey`" /f >nul 2>&1"
    if (-not $Existed) { Write-Host 'Registry: the key did not exist before - deleted'; return $true }
    & cmd.exe /c "reg import `"$File`" >nul 2>&1"
    if ($LASTEXITCODE -ne 0) { Write-Host "Registry: IMPORT FAILED - restore by hand from $File"; return $false }
    $check = "$File.check"
    & cmd.exe /c "reg export `"$RegKey`" `"$check`" /y >nul 2>&1"
    $ha = (Get-FileHash -LiteralPath $File).Hash; $hb = (Get-FileHash -LiteralPath $check).Hash
    Write-Host ("Registry: restored; identical={0}; SHA-256 {1} / {2}" -f ($ha -eq $hb), $ha.Substring(0, 16), $hb.Substring(0, 16))
    Remove-Item -LiteralPath $check -Force
    return ($ha -eq $hb)
}

# ---- process and windows ----------------------------------------------------
function Test-Alive([int]$Id) { return [bool](Get-Process -Id $Id -ErrorAction SilentlyContinue) }
function Get-Main([int]$Id) {
    foreach ($h in [Drv092F]::Top([uint32]$Id)) { if ([Drv092F]::Cls($h) -eq $MainClass) { return $h } }
    return [IntPtr]::Zero
}
function Get-Tops([int]$Id) { return @([Drv092F]::Top([uint32]$Id)) }
function Sync([int]$Id) {
    $m = Get-Main $Id
    if ($m -eq [IntPtr]::Zero) { throw 'no main window' }
    if (-not [Drv092F]::Send($m, 0, 0, 0, 20000)) { throw 'the main thread does not answer' }
}
function Get-DialogText([IntPtr]$H) {
    $parts = @()
    foreach ($c in [Drv092F]::Kids($H)) {
        $t = [Drv092F]::Txt($c)
        if ($t) { $parts += ("[{0} id={1}] {2}" -f [Drv092F]::Cls($c), [Drv092F]::GetDlgCtrlID($c), ($t -replace '\s+', ' ')) }
    }
    return ($parts -join ' | ')
}
# records and closes every dialog of the pid that nobody asked for
function Clear-Dialogs([int]$Id, [string]$Where) {
    foreach ($h in (Get-Tops $Id)) {
        if ([Drv092F]::Cls($h) -eq '#32770') {
            $d = ("{0}: dialog '{1}': {2}" -f $Where, [Drv092F]::Txt($h), (Get-DialogText $h))
            Write-Host "       UNEXPECTED $d"
            $script:Dialogs += $d
            [void][Drv092F]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
            Start-Sleep -Milliseconds 500
        }
    }
}

function Start-Tc([string]$Exe, [string]$Left, [string]$Right) {
    $a = @('-t', 'T092F', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 2500     # plug-ins, panels, icon readers
    Sync $p.Id
    Clear-Dialogs $p.Id 'start'
    return $p.Id
}
function Stop-Tc([int]$Id) {
    if (-not (Test-Alive $Id)) { return }
    if ($Started -notcontains $Id) { throw "pid $Id was not started by this probe" }
    foreach ($h in (Get-Tops $Id)) { if ([Drv092F]::Cls($h) -ne $MainClass) { [void][Drv092F]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) } }
    Start-Sleep -Milliseconds 300
    $m = Get-Main $Id
    if ($m -ne [IntPtr]::Zero) { [void][Drv092F]::PostMessageW($m, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 30 -and (Test-Alive $Id)) {
        foreach ($h in (Get-Tops $Id)) {
            if ([Drv092F]::Cls($h) -eq '#32770') {
                $d = ("exit: dialog '{0}': {1}" -f [Drv092F]::Txt($h), (Get-DialogText $h))
                if ($script:Dialogs -notcontains $d) { $script:Dialogs += $d; Write-Host "       UNEXPECTED $d" }
                $yes = [Drv092F]::Kids($h) | Where-Object { [Drv092F]::GetDlgCtrlID($_) -eq 6 } | Select-Object -First 1
                if ($yes) { [void][Drv092F]::PostMessageW($yes, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero) }
                else { [void][Drv092F]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
            }
        }
        Start-Sleep -Milliseconds 200
    }
    if (Test-Alive $Id) { Write-Host "       (pid $Id did not exit in 30 s - ended by pid)"; Stop-Process -Id $Id -Force; Start-Sleep -Milliseconds 500 }
}

# ---- driving ----------------------------------------------------------------
function Get-LeftList([int]$Id) {
    $m = Get-Main $Id
    $lists = @([Drv092F]::Kids($m) | Where-Object { [Drv092F]::Cls($_) -eq 'SalamanderItemsBox' -and [Drv092F]::IsWindowVisible($_) })
    if ($lists.Count -lt 1) { throw 'panel list window not found' }
    return $lists[0]
}
# a key to the left panel's list, handled before the call returns
function Key([int]$Id, [int]$Vk) {
    $l = Get-LeftList $Id
    if (-not [Drv092F]::Send($l, 0x0100, $Vk, 1, 20000)) { throw "key 0x$('{0:X}' -f $Vk) timed out" }
    [void][Drv092F]::Send($l, 0x0101, $Vk, 0xC0000001, 20000)
}
function Cmd([int]$Id, [int]$C) {
    if (-not [Drv092F]::Send((Get-Main $Id), 0x0111, $C, 0, 30000)) { throw "command $C timed out" }
}
function Go-Index([int]$Id, [int]$K) {
    Key $Id 0x24                                   # VK_HOME
    for ($i = 0; $i -lt $K; $i++) { Key $Id 0x28 } # VK_DOWN
}
function Refresh([int]$Id) { Cmd $Id 724; Start-Sleep -Milliseconds 300; Sync $Id }   # CM_LEFTREFRESH
function Title([int]$Id) { return [Drv092F]::Txt((Get-Main $Id)) }

# The main window and the viewers show their titles through the system code
# page, so a letter outside it arrives best-fitted (U+0125 reads "h" under
# 1250). A candidate is therefore looked for in both forms.
$script:AcpEnc = [Text.Encoding]::GetEncoding([int][Drv092F]::GetACP())
function Shown([string]$s) { return $script:AcpEnc.GetString($script:AcpEnc.GetBytes($s)) }

# which of the candidate names does the title name? (ordinal, the longest first)
function Identify([string]$Text, [string[]]$Cands) {
    $sorted = @($Cands | Sort-Object { $_.Length } -Descending)
    foreach ($pat in @('\{0}', ' - {0} - ', ' {0} ', '{0}')) {
        foreach ($c in $sorted) {
            foreach ($f in @($c, (Shown $c))) {
                if ($Text.IndexOf(($pat -f $f), [StringComparison]::Ordinal) -ge 0) { return $c }
            }
        }
    }
    return $null
}

# F3 on the focused item: the name the viewer's title carries, or $null.
# The viewer is closed again; the focus in the panel is not moved.
function Focused-File([int]$Id, [string[]]$Cands) {
    $known = Get-Tops $Id
    Cmd $Id 742                                    # CM_VIEW
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $name = $null; $title = ''
    while ($sw.Elapsed.TotalSeconds -lt 4 -and -not $name) {
        foreach ($h in (Get-Tops $Id)) {
            if ($known -notcontains $h) {
                $title = [Drv092F]::Txt($h)
                $n = Identify $title $Cands
                if ($n) { $name = $n; $script:LastViewerTitle = $title; break }
            }
        }
        if (-not $name) { Start-Sleep -Milliseconds 100 }
    }
    if (-not $name) { $script:LastViewerTitle = $title }
    # close whatever opened
    foreach ($h in (Get-Tops $Id)) {
        if ($known -notcontains $h) {
            if ([Drv092F]::Cls($h) -eq '#32770') { $d = ("F3: dialog '{0}': {1}" -f [Drv092F]::Txt($h), (Get-DialogText $h)); $script:Dialogs += $d; Write-Host "       UNEXPECTED $d" }
            [void][Drv092F]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
        }
    }
    $sw.Restart()
    while ($sw.Elapsed.TotalSeconds -lt 5 -and @(Get-Tops $Id | Where-Object { $known -notcontains $_ }).Count) { Start-Sleep -Milliseconds 100 }
    Sync $Id
    return $name
}

# puts the focus on the file $Name by position only (Home, k x Down), checked with F3
function Focus-File([int]$Id, [string]$Name, [string[]]$Cands, [int]$Max) {
    for ($k = 0; $k -le $Max; $k++) {
        Go-Index $Id $k
        if ((Focused-File $Id $Cands) -ceq $Name) { return $k }
    }
    throw ("could not put the focus on " + (Show $Name))
}

# Enter on the focused directory: the candidate the main title names afterwards
function Enter-Dir([int]$Id, [string[]]$Cands) {
    Key $Id 0x0D                                   # VK_RETURN
    Start-Sleep -Milliseconds 250; Sync $Id
    $script:LastTitle = Title $Id
    return (Identify $script:LastTitle $Cands)
}
function Go-Up([int]$Id) { Key $Id 0x08; Start-Sleep -Milliseconds 250; Sync $Id }   # VK_BACK

function Rename-Outside([string]$Dir, [string]$From, [string]$To) {
    if (-not [Drv092F]::MoveFileW((Join-Path $Dir $From), (Join-Path $Dir $To))) { throw "MoveFileW failed: $([Runtime.InteropServices.Marshal]::GetLastWin32Error())" }
    $now = @([IO.Directory]::GetFiles($Dir) | ForEach-Object { [IO.Path]::GetFileName($_) })
    if ($now -cnotcontains $To) { throw ("the disk does not show " + (Show $To)) }
}
function New-Dirs([string]$Dir, [string[]]$Names) {
    [void][IO.Directory]::CreateDirectory($Dir)
    foreach ($n in $Names) { [void][IO.Directory]::CreateDirectory((Join-Path $Dir $n)) }
}
function New-Files([string]$Dir, [string[]]$Names) {
    [void][IO.Directory]::CreateDirectory($Dir)
    foreach ($n in $Names) { [IO.File]::WriteAllText((Join-Path $Dir $n), "feature 092 focus probe`r`n", [Text.Encoding]::ASCII) }
}

# ---- scenarios --------------------------------------------------------------

# F1 / F1c: every directory: enter, Backspace, Enter again -> the same one.
# F1r (inside the same instance): Home + k Down, refresh, Enter -> the same one.
function Scn-GoUp([string]$Exe, [string]$Build, [string]$Scn, [string]$Dir, [string[]]$Names, [string[]]$Pair, [string]$RefreshScn) {
    $id = 0
    try {
        $id = Start-Tc $Exe $Dir $script:Empty
        Write-Host ("       title at start: {0}" -f (Title $id))
        $map = @{}; $facts = @(); $ok = $true
        for ($k = 1; $k -le $Names.Count; $k++) {
            Go-Index $id $k
            $d = Enter-Dir $id $Names
            if (-not $d) { throw "index ${k}: Enter did not enter a known directory; title: $($script:LastTitle)" }
            $t1 = $script:LastTitle
            $map[$d] = $k
            Go-Up $id
            $back = Enter-Dir $id $Names
            $t2 = $script:LastTitle
            if ($back) { Cmd $id 824; Start-Sleep -Milliseconds 250; Sync $id }   # CM_LPARENTDIR: back to the folder
            else {
                # Enter was on ".." (or nothing known): we are in the parent of the test folder or still in it
                if ((Title $id) -notlike "*$(Split-Path -Leaf $Dir)*") { throw "left the test folder; title: $(Title $id)" }
            }
            if ($back -cne $d) { $ok = $false }
            if ($Pair -ccontains $d -or $back -cne $d) { $facts += ("left {0} -> focus on {1} (titles: [{2}] then [{3}])" -f (Show $d), (Show $back), $t1, $t2) }
            Clear-Dialogs $id $Scn
        }
        $order = ($map.GetEnumerator() | Sort-Object Value | ForEach-Object { $_.Name }) -join ', '
        Report $Scn $Build $ok ("panel order: {0}; {1}" -f $order, ($facts -join '; '))

        if ($RefreshScn -and (Want $RefreshScn)) {
            $facts = @(); $ok = $true
            foreach ($d in $Pair) {
                Go-Index $id $map[$d]
                Refresh $id
                $got = Enter-Dir $id $Names
                if ($got) { Cmd $id 824; Start-Sleep -Milliseconds 250; Sync $id }
                if ($got -cne $d) { $ok = $false }
                $facts += ("focus on {0} (index {1}), refresh -> Enter entered {2} (title [{3}])" -f (Show $d), $map[$d], (Show $got), $script:LastTitle)
            }
            Report $RefreshScn $Build $ok ($facts -join '; ')
        }
    }
    catch { Report $Scn $Build $null $_.Exception.Message }
    finally { if ($id) { Stop-Tc $id } }
}

# F1p / F1pc: the panel starts in <Dir>\<Typed>, the disk has <OnDisk>; go up; Enter.
function Scn-PathCase([string]$Exe, [string]$Build, [string]$Scn, [string]$Dir, [string[]]$Names, [string]$OnDisk, [string]$Typed) {
    $id = 0
    try {
        $id = Start-Tc $Exe (Join-Path $Dir $Typed) $script:Empty
        $t0 = Title $id
        $kept = ($t0.IndexOf(' - ' + $Typed + ' - ',[StringComparison]::Ordinal) -ge 0)
        Go-Up $id
        $t1 = Title $id
        $got = Enter-Dir $id $Names
        $facts = ("started in {0}; title [{1}] (spelling kept: {2}); after Backspace [{3}]; Enter entered {4} (title [{5}])" -f (Show $Typed), $t0, $kept, $t1, (Show $got), $script:LastTitle)
        Report $Scn $Build ($got -ceq $OnDisk) $facts
    }
    catch { Report $Scn $Build $null $_.Exception.Message }
    finally { if ($id) { Stop-Tc $id } }
}

# F2 / F2c: focus on <Upper>; add two files before it; rename outside to <Lower>; refresh; F3. Then back.
function Scn-CaseChange([string]$Exe, [string]$Build, [string]$Scn, [string]$Dir, [string]$Upper, [string]$Lower) {
    $id = 0
    try {
        # every run starts from the same disk state
        if ([IO.Directory]::Exists($Dir)) { [IO.Directory]::Delete($Dir, $true) }
        New-Files $Dir @('b1.txt', 'b2.txt', $Upper, 'm1.txt', 'z1.txt')
        $cands = @('b0.txt', 'b1.txt', 'b2.txt', 'b3.txt', 'm1.txt', 'z1.txt', $Upper, $Lower)
        $id = Start-Tc $Exe $Dir $script:Empty
        $k = Focus-File $id $Upper $cands 6
        $facts = @(("focus on {0} at index {1}" -f (Show $Upper), $k))
        New-Files $Dir @('b0.txt', 'b3.txt')
        Start-Sleep -Milliseconds 1200; Refresh $id
        $s = Focused-File $id $cands
        $facts += ("two files added + refresh -> F3 shows {0}" -f (Show $s))
        if ($s -cne $Upper) { throw ("sanity: adding files moved the focus to " + (Show $s)) }

        Rename-Outside $Dir $Upper $Lower
        Start-Sleep -Milliseconds 1200; Refresh $id
        $a = Focused-File $id $cands
        $facts += ("renamed outside to {0} + refresh -> F3 shows {1} (viewer title [{2}])" -f (Show $Lower), (Show $a), $script:LastViewerTitle)

        $k2 = Focus-File $id $Lower $cands 8
        Rename-Outside $Dir $Lower $Upper
        Start-Sleep -Milliseconds 1200; Refresh $id
        $b = Focused-File $id $cands
        $facts += ("focus put on {0} (index {1}); renamed back to {2} + refresh -> F3 shows {3} (viewer title [{4}])" -f (Show $Lower), $k2, (Show $Upper), (Show $b), $script:LastViewerTitle)
        Clear-Dialogs $id $Scn
        Report $Scn $Build (($a -ceq $Lower) -and ($b -ceq $Upper)) ($facts -join '; ')
    }
    catch { Report $Scn $Build $null $_.Exception.Message }
    finally { if ($id) { Stop-Tc $id } }
}

# F2x: files of the colliding pair: focus each, refresh, F3.
function Scn-PairRefresh([string]$Exe, [string]$Build, [string]$Scn, [string]$Dir, [string[]]$Pair, [string[]]$Cands) {
    $id = 0
    try {
        $id = Start-Tc $Exe $Dir $script:Empty
        $facts = @(); $ok = $true
        foreach ($n in $Pair) {
            $k = Focus-File $id $n $Cands 6
            Refresh $id
            $got = Focused-File $id $Cands
            if ($got -cne $n) { $ok = $false }
            $facts += ("focus on {0} (index {1}), refresh -> F3 shows {2} (viewer title [{3}])" -f (Show $n), $k, (Show $got), $script:LastViewerTitle)
        }
        Clear-Dialogs $id $Scn
        Report $Scn $Build $ok ($facts -join '; ')
    }
    catch { Report $Scn $Build $null $_.Exception.Message }
    finally { if ($id) { Stop-Tc $id } }
}

# F4 / F4c: Quick Rename in the program (the Rename dialog).
function Scn-QuickRename([string]$Exe, [string]$Build, [string]$Scn, [string]$Dir, [string]$From, [string]$To) {
    $id = 0
    try {
        if ([IO.Directory]::Exists($Dir)) { [IO.Directory]::Delete($Dir, $true) }
        New-Files $Dir @('b1.txt', 'b2.txt', $From, 'z1.txt', 'z2.txt')
        $cands = @('b1.txt', 'b2.txt', 'z1.txt', 'z2.txt', $From, $To)
        $id = Start-Tc $Exe $Dir $script:Empty
        $k = Focus-File $id $From $cands 6
        $known = Get-Tops $id
        [void][Drv092F]::PostMessageW((Get-Main $id), 0x0111, [IntPtr]754, [IntPtr]::Zero)   # CM_RENAMEFILE (modal: posted)
        $dlg = [IntPtr]::Zero
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 6 -and $dlg -eq [IntPtr]::Zero) {
            foreach ($h in (Get-Tops $id)) { if ($known -notcontains $h -and [Drv092F]::Cls($h) -eq '#32770') { $dlg = $h } }
            Start-Sleep -Milliseconds 100
        }
        $how = ''
        if ($dlg -ne [IntPtr]::Zero) {
            $how = ("dialog '{0}'" -f [Drv092F]::Txt($dlg))
            $edit = [Drv092F]::Kids($dlg) | Where-Object { [Drv092F]::Cls($_) -eq 'Edit' } | Select-Object -First 1
            if (-not $edit) { throw "the rename dialog has no edit control: $(Get-DialogText $dlg)" }
            $before = [Drv092F]::GetText($edit, 5000)
            if (-not [Drv092F]::SetText($edit, $To, 5000)) { throw 'WM_SETTEXT timed out' }
            $how += (", edit held {0}, set to {1}" -f (Show $before), (Show ([Drv092F]::GetText($edit, 5000))))
            $okBtn = [Drv092F]::Kids($dlg) | Where-Object { [Drv092F]::GetDlgCtrlID($_) -eq 1 -and [Drv092F]::Cls($_) -eq 'Button' } | Select-Object -First 1
            if (-not $okBtn) { throw 'the rename dialog has no OK button' }
            [void][Drv092F]::PostMessageW($okBtn, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)   # BM_CLICK
        }
        else {
            # the inline edit: a child 'Edit' of the panel list
            $edit = [Drv092F]::Kids((Get-LeftList $id)) | Where-Object { [Drv092F]::Cls($_) -eq 'Edit' } | Select-Object -First 1
            if (-not $edit) { throw 'neither a rename dialog nor an inline edit appeared' }
            $how = 'inline edit'
            if (-not [Drv092F]::SetText($edit, $To, 5000)) { throw 'WM_SETTEXT timed out' }
            [void][Drv092F]::PostMessageW($edit, 0x0102, [IntPtr]0x0D, [IntPtr]1)   # WM_CHAR Enter
        }
        $sw.Restart()
        while ($sw.Elapsed.TotalSeconds -lt 5 -and $dlg -ne [IntPtr]::Zero -and (Get-Tops $id) -contains $dlg) { Start-Sleep -Milliseconds 100 }
        Start-Sleep -Milliseconds 1500; Sync $id
        Clear-Dialogs $id $Scn
        $disk = @([IO.Directory]::GetFiles($Dir) | ForEach-Object { [IO.Path]::GetFileName($_) })
        $onDisk = ($disk -ccontains $To)
        $got = Focused-File $id $cands
        $facts = ("focus on {0} (index {1}); {2}; disk now has {3}: {4}; F3 shows {5} (viewer title [{6}])" -f (Show $From), $k, $how, (Show $To), $onDisk, (Show $got), $script:LastViewerTitle)
        Report $Scn $Build (($got -ceq $To) -and $onDisk) $facts
    }
    catch { Report $Scn $Build $null $_.Exception.Message }
    finally { if ($id) { Stop-Tc $id } }
}

# ---------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc092_focus_backup.reg'
$root = Join-Path $env:TEMP 'tc092_focus'
$script:Empty = Join-Path $root 'empty'
$existed = Backup-TcRegistry $backup
$regOk = $false
try {
    # ---- the collision, proven on this machine ----
    $acp = [Drv092F]::GetACP()
    $lA5 = [Drv092F]::Lower(0xA5); $lB9 = [Drv092F]::Lower(0xB9); $l8C = [Drv092F]::Lower(0x8C); $l8D = [Drv092F]::Lower(0x8D)
    $collide = ($lA5 -eq $lB9)
    Write-Host ("System code page {0}. Byte fold (CharLowerA): A5 -> {1:X2}, B9 -> {2:X2}  => U+0125 (C4 A5) and U+0139 (C4 B9) {3}." -f $acp, $lA5, $lB9, $(if ($collide) { 'COLLIDE' } else { 'do NOT collide here' }))
    Write-Host ("                                         8C -> {0:X2}, 8D -> {1:X2}  => U+010C (C4 8C) and U+010D (C4 8D) {2} under the byte fold." -f $l8C, $l8D, $(if ($l8C -eq $l8D) { 'are equal' } else { 'DIFFER' }))
    $u = [Text.Encoding]::UTF8
    Write-Host ("UTF-8: {0} = {1}; {2} = {3}; {4} = {5}; {6} = {7}" -f (Show $Hc), [BitConverter]::ToString($u.GetBytes($Hc)), (Show $La), [BitConverter]::ToString($u.GetBytes($La)), (Show $Cup), [BitConverter]::ToString($u.GetBytes($Cup)), (Show $Clo), [BitConverter]::ToString($u.GetBytes($Clo)))

    # ---- folders ----
    if ([IO.Directory]::Exists($root)) { [IO.Directory]::Delete($root, $true) }
    [void][IO.Directory]::CreateDirectory($script:Empty)
    $dF1 = Join-Path $root 'D1';  $nF1 = @('aaa', ($Hc + '-dir'), ($La + '-dir'), 'mmm', 'zzz');    New-Dirs $dF1 $nF1
    $dF1c = Join-Path $root 'D1c'; $nF1c = @('aaa', 'hhh', 'LLL', 'mmm', 'zzz'); New-Dirs $dF1c $nF1c
    $dF1p = Join-Path $root 'D3';  $nF1p = @('aaa', $Cup, 'zzz');               New-Dirs $dF1p $nF1p
    $dF2 = Join-Path $root 'P2'; $dF2c = Join-Path $root 'P2c'
    $dF2x = Join-Path $root 'P4'; $nF2x = @('b1.txt', ($Hc + '.txt'), ($La + '.txt'), 'z1.txt'); New-Files $dF2x $nF2x
    $dF4 = Join-Path $root 'P5'; $dF4c = Join-Path $root 'P5c'

    & cmd.exe /c "reg query `"$RegKey\0.1\Configuration`" >nul 2>&1"
    if ($LASTEXITCODE -eq 0) { & reg.exe add "$RegKey\0.1\Configuration\Confirmation" /v 'Close Salamander' /t REG_DWORD /d 0 /f | Out-Null }

    foreach ($b in @(@('OLD', $OldExe), @('NEW', $NewExe))) {
        $build = $b[0]; $exe = $b[1]
        Write-Host ''
        Write-Host ("=== {0}: {1}  ({2:yyyy-MM-dd HH:mm:ss}) ===" -f $build, $exe, (Get-Item -LiteralPath $exe).LastWriteTime)
        if (Want 'F1')   { Scn-GoUp $exe $build 'F1' $dF1 $nF1 @(($Hc + '-dir'), ($La + '-dir')) 'F1r' }
        elseif (Want 'F1r') { Scn-GoUp $exe $build 'F1' $dF1 $nF1 @(($Hc + '-dir'), ($La + '-dir')) 'F1r' }
        if (Want 'F1p')  { Scn-PathCase $exe $build 'F1p' $dF1p $nF1p $Cup $Clo }
        if (Want 'F2')   { Scn-CaseChange $exe $build 'F2' $dF2 ($Cup + '.txt') ($Clo + '.txt') }
        if (Want 'F2x')  { Scn-PairRefresh $exe $build 'F2x' $dF2x @(($Hc + '.txt'), ($La + '.txt')) $nF2x }
        if (Want 'F4')   { Scn-QuickRename $exe $build 'F4' $dF4 $ClanekU $ClanekL }
        if (Want 'F1c')  { Scn-GoUp $exe $build 'F1c' $dF1c $nF1c @('hhh', 'LLL') $null }
        if (Want 'F1pc') { Scn-PathCase $exe $build 'F1pc' $dF1c $nF1c 'LLL' 'lll' }
        if (Want 'F2c')  { Scn-CaseChange $exe $build 'F2c' $dF2c 'K.txt' 'k.txt' }
        if (Want 'F4c')  { Scn-QuickRename $exe $build 'F4c' $dF4c 'Report.txt' 'report.txt' }
    }
}
finally {
    foreach ($s in @($Started)) { try { Stop-Tc $s } catch { Write-Host "  (stop $s : $($_.Exception.Message))" } }
    $left = @($Started | Where-Object { Test-Alive $_ }).Count
    for ($k = 0; $k -lt 10 -and [IO.Directory]::Exists($root); $k++) {
        try { [IO.Directory]::Delete($root, $true) } catch { Start-Sleep -Milliseconds 500 }
    }
    $regOk = Restore-TcRegistry $backup $existed
    Write-Host ''
    Write-Host '=== summary ==='
    $script:Results | ForEach-Object { Write-Host $_ }
    Write-Host ("Unexpected dialogs: {0}" -f $script:Dialogs.Count)
    $script:Dialogs | ForEach-Object { Write-Host "  $_" }
    Write-Host ("Test processes left: {0}; test folder left: {1}" -f $left, [IO.Directory]::Exists($root))
    if (-not $regOk) { $script:Fail++ }
    Write-Host ("Failures: {0}" -f $script:Fail)
}
exit $script:Fail
