<#
.SYNOPSIS
    Feature 272 probe: Change Attributes (748) on a FILE symbolic link changes the link's own
    compression and times - never those of the link's TARGET file.

.DESCRIPTION
    Fixture per row (all under the probe's %TEMP% folder):
      <row>\in\f.txt        a file symbolic link -> <row>\out\T.TXT (the link itself is focused)
      <row>\out\T.TXT       the link's target file
    The panel shows <row>\in; Home, End focus the last item; the Change Attributes dialog.
      COMP     Compressed set:      PASS = f.txt compressed, T.TXT not
      UNCOMP   f.txt and T.TXT compressed beforehand, Compressed cleared:
                                    PASS = f.txt not compressed, T.TXT still compressed
      TIME     Modified date set to 2001-02-03 (T.TXT's times set to 2010 beforehand):
                                    PASS = f.txt modified in 2001, T.TXT still 2010
      SUBC     <row>\in\sel holds OWN.TXT and the link f.txt; 'sel' focused, Compressed +
               Include subdirectories:
                                    PASS = sel, OWN.TXT and f.txt compressed, T.TXT not
      PLAIN    (positive control) a plain file p.txt focused, Compressed + Modified date:
                                    PASS = p.txt compressed, modified in 2001
      NONLINK  (control) a file R.TXT with a third-party reparse tag (not a name surrogate - not a
               link) focused, Compressed set: it keeps the former way (opened without
               FILE_FLAG_OPEN_REPARSE_POINT, which no filter handles here):
                                    PASS = R.TXT not compressed, an "Error Changing Compression" box shown
      ENC      not driven: no EFS certificate may be created on the maintainer's machine.
    File symbolic links are made with SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE (Developer
    Mode); a row whose link cannot be made is NOT DRIVEN.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
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
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
if (-not ('Res272' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Res272
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr OpenProcess(uint access, bool inherit, uint pid);
    [DllImport("kernel32.dll", SetLastError = true)] static extern IntPtr VirtualAllocEx(IntPtr p, IntPtr a, IntPtr size, uint type, uint protect);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool VirtualFreeEx(IntPtr p, IntPtr a, IntPtr size, uint type);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool WriteProcessMemory(IntPtr p, IntPtr a, byte[] b, IntPtr size, out IntPtr written);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool CloseHandle(IntPtr h);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern IntPtr CreateFileW(string n, uint acc, uint share, IntPtr sa, uint disp, uint flags, IntPtr t);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool DeviceIoControl(IntPtr h, uint code, ref ushort inb, int inSize, IntPtr outb, int outSize, out int ret, IntPtr ov);
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool DeviceIoControl(IntPtr h, uint code, byte[] inb, int inSize, IntPtr outb, int outSize, out int ret, IntPtr ov);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    static extern bool CreateSymbolicLinkW(string link, string target, uint flags);
    public static long SendR(IntPtr h, uint msg, long w, long l, uint timeout) { IntPtr r; SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 2, timeout, out r); return r.ToInt64(); }
    // DTM_SETSYSTEMTIME GDT_VALID with the SYSTEMTIME in the target process (the pointer is not marshalled)
    public static long SetDate(IntPtr h, int y, int mo, int d)
    {
        uint pid; GetWindowThreadProcessId(h, out pid);
        IntPtr p = OpenProcess(0x0008 | 0x0010 | 0x0020, false, pid);
        if (p == IntPtr.Zero) return -1;
        IntPtr mem = VirtualAllocEx(p, IntPtr.Zero, (IntPtr)64, 0x3000, 0x04);
        long res = -2;
        if (mem != IntPtr.Zero)
        {
            byte[] st = new byte[16];
            BitConverter.GetBytes((ushort)y).CopyTo(st, 0); BitConverter.GetBytes((ushort)mo).CopyTo(st, 2);
            BitConverter.GetBytes((ushort)d).CopyTo(st, 6); BitConverter.GetBytes((ushort)12).CopyTo(st, 8);
            IntPtr wr;
            if (WriteProcessMemory(p, mem, st, (IntPtr)16, out wr)) res = SendR(h, 0x1002, 0, mem.ToInt64(), 5000);
            VirtualFreeEx(p, mem, IntPtr.Zero, 0x8000);
        }
        CloseHandle(p);
        return res;
    }
    // a file symbolic link (SYMBOLIC_LINK_FLAG_ALLOW_UNPRIVILEGED_CREATE); 0 or the error
    public static int FileLink(string link, string target)
    {
        if (CreateSymbolicLinkW(link, target, 2)) return 0;
        return Marshal.GetLastWin32Error();
    }
    // FSCTL_SET_COMPRESSION on a file; ownEntry = FILE_FLAG_OPEN_REPARSE_POINT (the link itself)
    public static int Compress(string path, bool ownEntry, ushort state)
    {
        uint flags = 0x02000000u | (ownEntry ? 0x00200000u : 0u);
        IntPtr h = CreateFileW(path, 0x0001 | 0x0002, 3, IntPtr.Zero, 3, flags, IntPtr.Zero);
        if (h == (IntPtr)(-1)) return Marshal.GetLastWin32Error();
        int r; int e = 0;
        if (!DeviceIoControl(h, 0x9C040, ref state, 2, IntPtr.Zero, 0, out r, IntPtr.Zero)) e = Marshal.GetLastWin32Error();
        CloseHandle(h); return e;
    }
    // FSCTL_SET_REPARSE_POINT with a third-party tag (REPARSE_GUID_DATA_BUFFER; not a name surrogate)
    public static int SetForeignTag(string path)
    {
        IntPtr h = CreateFileW(path, 0x40000000u | 0x80000000u, 0, IntPtr.Zero, 3, 0x02200000u, IntPtr.Zero);
        if (h == (IntPtr)(-1)) return Marshal.GetLastWin32Error();
        byte[] b = new byte[8 + 16 + 4];
        BitConverter.GetBytes(0x00000123u).CopyTo(b, 0);
        BitConverter.GetBytes((ushort)4).CopyTo(b, 4);
        new Guid("8f1b3c52-7a2e-4d1b-9a77-2720c0ffee72").ToByteArray().CopyTo(b, 8);
        b[24] = 0x54; b[25] = 0x43; b[26] = 0x32; b[27] = 0x37;
        int r; int e = 0;
        if (!DeviceIoControl(h, 0x900A4, b, b.Length, IntPtr.Zero, 0, out r, IntPtr.Zero)) e = Marshal.GetLastWin32Error();
        CloseHandle(h); return e;
    }
}
'@
}
$Root = $TempRoot + '\tc272'
$StartDir = $Root + '\start'
function Btn-Of([IntPtr]$Dlg, [int]$CtlId) { $b = @(Buttons $Dlg | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }); if ($b.Count) { return $b[0] }; return [IntPtr]::Zero }
function Set-Box([IntPtr]$Dlg, [int]$CtlId, [int]$State) {   # BM_SETCHECK; FALSE when the box is not there or not enabled
    $b = Btn-Of $Dlg $CtlId
    if ($b -eq [IntPtr]::Zero -or -not [Drv098f]::IsWindowEnabled($b)) { return $false }
    [void][Res272]::SendR($b, 0x00F1, $State, 0, 5000)
    return ([Res272]::SendR($b, 0x00F0, 0, 0, 5000) -eq $State)
}
function Ctl-Of([IntPtr]$Dlg, [int]$CtlId) { $c = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }); if ($c.Count) { return $c[0] }; return [IntPtr]::Zero }
function Attrs([string]$p) { return [IO.File]::GetAttributes($LP + $p) }   # the entry itself (a link is not followed)
function IsComp([string]$p) { return ((Attrs $p) -band [IO.FileAttributes]::Compressed) -ne 0 }
function MYear([string]$p) { return [IO.File]::GetLastWriteTime($LP + $p).Year }   # the entry itself (GetFileAttributesEx)

# $Boxes: @{ id = state } (IDC_COMPRESSED 246, IDC_RECURSESUBDIRS 248); $Date: set IDC_ATTR_MODIFIED_DATE 250 to 2001-02-03;
# $Prepare: scriptblock run on the fixture; $Shape: 'f' (the link itself), 'sel' (a folder holding the link), 'plain', 'nonlink'
function Run-Case([string]$Case, [string]$Shape, [hashtable]$Boxes, [scriptblock]$Check, [scriptblock]$Prepare = $null, [switch]$Date) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    NewDir $d; NewDir "$d\in"; NewDir "$d\out"
    [IO.File]::WriteAllText($LP + "$d\out\T.TXT", "target`r`nline`r`n")
    if ($Shape -eq 'plain') { [IO.File]::WriteAllText($LP + "$d\in\p.txt", "plain`r`nline`r`n") }
    elseif ($Shape -eq 'nonlink') {
        [IO.File]::WriteAllText($LP + "$d\in\R.TXT", "foreign`r`nline`r`n")
        $e = [Res272]::SetForeignTag("$d\in\R.TXT")
        if ($e -ne 0) { Row $Case 'RUN' 'NOT DRIVEN' ('no foreign reparse tag: error ' + $e); return }
    }
    else {
        if ($Shape -eq 'sel') { NewDir "$d\in\sel"; [IO.File]::WriteAllText($LP + "$d\in\sel\OWN.TXT", "own`r`nline`r`n") }
        $f = $(if ($Shape -eq 'sel') { "$d\in\sel\f.txt" } else { "$d\in\f.txt" })
        $e = [Res272]::FileLink($f, "$d\out\T.TXT")
        if ($e -ne 0 -or -not [IO.File]::Exists($f)) { Row $Case 'RUN' 'NOT DRIVEN' ('no file symbolic link: error ' + $e + ' (Developer Mode or the privilege needed)'); return }
    }
    if ($Prepare) { & $Prepare $d }
    $id = 0; $before = Reports
    try {
        $id = Start-Tc "$d\in"
        [void](Serve $id 10)
        Key $id 0x24; Key $id 0x23
        Start-Sleep -Milliseconds 500
        $dlg = Open-ByCmd $id 748 10
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'RUN' 'NOT DRIVEN' 'command 748 opened no dialog'; return }
        $dlgDesc = WinDesc $dlg
        $set = @($Boxes.Keys | Where-Object { Set-Box $dlg $_ $Boxes[$_] })
        $dateRes = 'not set'
        if ($Date) { $dateRes = [Res272]::SetDate((Ctl-Of $dlg 250), 2001, 2, 3) }
        Click-Ok $dlg
        $r = Serve $id 30 @(1, 6)
        End-Row $Case $id $null $before; $id = 0
        $res = & $Check $d $r
        $setAll = ($set.Count -eq $Boxes.Count) -and (-not $Date -or $dateRes -ne 0)
        Row $Case 'RUN' (V ($res[0] -and $setAll)) ("{0}; boxes set {1} of {2}; date {3}; dialog: {4}; windows: {5}" -f $res[1], $set.Count, $Boxes.Count, $dateRes, (Tail $dlgDesc 60), (Msgs $r))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc272_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("attrs_flink272_probe (feature 272) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    Run-Case 'COMP' 'f' @{ 246 = 1 } {
        param($d, $r)
        $l = IsComp "$d\in\f.txt"; $t = IsComp "$d\out\T.TXT"
        @(($l -and -not $t), ("the link compressed {0}; target T.TXT compressed {1}" -f $l, $t))
    }
    Run-Case 'UNCOMP' 'f' @{ 246 = 0 } {
        param($d, $r)
        $l = IsComp "$d\in\f.txt"; $t = IsComp "$d\out\T.TXT"
        @((-not $l -and $t), ("the link compressed {0}; target T.TXT compressed {1}" -f $l, $t))
    } {
        param($d)
        $e1 = [Res272]::Compress($LP + "$d\out\T.TXT", $false, 1); $e2 = [Res272]::Compress($LP + "$d\in\f.txt", $true, 1)
        Out ("UNCOMP     fixture: T.TXT compressed err {0} ({1}); the link compressed err {2} ({3})" -f $e1, (IsComp "$d\out\T.TXT"), $e2, (IsComp "$d\in\f.txt"))
    }
    Run-Case 'TIME' 'f' @{} {
        param($d, $r)
        $ly = MYear "$d\in\f.txt"; $ty = MYear "$d\out\T.TXT"
        @((($ly -eq 2001) -and ($ty -eq 2010)), ("the link modified in {0}; target T.TXT modified in {1}" -f $ly, $ty))
    } {
        param($d)
        $t2010 = [DateTime]::new(2010, 6, 15, 12, 0, 0)
        [IO.File]::SetLastWriteTime($LP + "$d\out\T.TXT", $t2010); [IO.File]::SetCreationTime($LP + "$d\out\T.TXT", $t2010)
        Out ("TIME       fixture: T.TXT modified in {0}; the link modified in {1}" -f (MYear "$d\out\T.TXT"), (MYear "$d\in\f.txt"))
    } -Date
    Run-Case 'SUBC' 'sel' @{ 246 = 1; 248 = 1 } {
        param($d, $r)
        $s = IsComp "$d\in\sel"; $o = IsComp "$d\in\sel\OWN.TXT"; $l = IsComp "$d\in\sel\f.txt"; $t = IsComp "$d\out\T.TXT"
        @(($s -and $o -and $l -and -not $t), ("sel compressed {0}; OWN.TXT {1}; the link {2}; target T.TXT {3}" -f $s, $o, $l, $t))
    }
    Run-Case 'PLAIN' 'plain' @{ 246 = 1 } {
        param($d, $r)
        $p = IsComp "$d\in\p.txt"; $py = MYear "$d\in\p.txt"
        @(($p -and ($py -eq 2001)), ("p.txt compressed {0}; modified in {1}" -f $p, $py))
    } $null -Date
    Run-Case 'NONLINK' 'nonlink' @{ 246 = 1 } {
        param($d, $r)
        $c = IsComp "$d\in\R.TXT"; $err = @($r.Messages | Where-Object { $_ -match 'Error Changing Compression' }).Count -gt 0
        @(((-not $c) -and $err), ("R.TXT (foreign tag) compressed {0}; 'Error Changing Compression' shown {1}" -f $c, $err))
    }
    if (Want 'ENC') { Row 'ENC' 'RUN' 'NOT DRIVEN' 'encrypting would create an EFS certificate in the user''s store (none exists); the refusal is checked by saltests and code reading' }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    # File.Delete / Directory.Delete remove a file symbolic link or a reparse file itself, never its target
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
