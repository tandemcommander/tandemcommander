<#
.SYNOPSIS
    Feature 253 probe: Change Attributes (748) on a junction changes the junction's own
    compression and times - never those of the junction's TARGET folder.

.DESCRIPTION
    Fixture per row (all under the probe's %TEMP% folder):
      <row>\in\j            a junction -> <row>\out\tgt (the junction itself is focused)
      <row>\out\tgt\T.TXT   the junction's target file
    The panel shows <row>\in; Home, End focus the last item; the Change Attributes dialog.
      COMP    Compressed set:      PASS = j compressed, tgt and T.TXT not
      UNCOMP  j and tgt compressed beforehand, Compressed cleared:
                                   PASS = j not compressed, tgt still compressed
      TIME    Modified date set to 2001-02-03 (tgt's times set to 2010 beforehand):
                                   PASS = j modified in 2001, tgt still 2010
      SUBC    <row>\in\sel holds OWN.TXT and the junction j; 'sel' focused, Compressed +
              Include subdirectories:
                                   PASS = sel, OWN.TXT and j compressed, tgt and T.TXT not
      PLAIN   (positive control) a plain folder p focused, Compressed + Modified date:
                                   PASS = p compressed, modified in 2001
      ENC     not driven: no EFS certificate may be created on the maintainer's machine.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib = (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. $Lib
if (-not ('Res253' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class Res253
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
    // FSCTL_SET_COMPRESSION on a folder; ownEntry = FILE_FLAG_OPEN_REPARSE_POINT (the junction itself)
    public static int Compress(string path, bool ownEntry, ushort state)
    {
        uint flags = 0x02000000u | (ownEntry ? 0x00200000u : 0u);
        IntPtr h = CreateFileW(path, 0x0001 | 0x0002, 3, IntPtr.Zero, 3, flags, IntPtr.Zero);
        if (h == (IntPtr)(-1)) return Marshal.GetLastWin32Error();
        int r; int e = 0;
        if (!DeviceIoControl(h, 0x9C040, ref state, 2, IntPtr.Zero, 0, out r, IntPtr.Zero)) e = Marshal.GetLastWin32Error();
        CloseHandle(h); return e;
    }
}
'@
}
$Root = $TempRoot + '\tc253'
$StartDir = $Root + '\start'
$script:Links = New-Object System.Collections.ArrayList
function Btn-Of([IntPtr]$Dlg, [int]$CtlId) { $b = @(Buttons $Dlg | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }); if ($b.Count) { return $b[0] }; return [IntPtr]::Zero }
function Set-Box([IntPtr]$Dlg, [int]$CtlId, [int]$State) {   # BM_SETCHECK; FALSE when the box is not there or not enabled
    $b = Btn-Of $Dlg $CtlId
    if ($b -eq [IntPtr]::Zero -or -not [Drv098f]::IsWindowEnabled($b)) { return $false }
    [void][Res253]::SendR($b, 0x00F1, $State, 0, 5000)
    return ([Res253]::SendR($b, 0x00F0, 0, 0, 5000) -eq $State)
}
function Ctl-Of([IntPtr]$Dlg, [int]$CtlId) { $c = @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId }); if ($c.Count) { return $c[0] }; return [IntPtr]::Zero }
function Attrs([string]$p) { return [IO.File]::GetAttributes($LP + $p) }
function IsComp([string]$p) { return ((Attrs $p) -band [IO.FileAttributes]::Compressed) -ne 0 }
function MYear([string]$p) { return [IO.Directory]::GetLastWriteTime($LP + $p).Year }   # the entry itself (no reparse followed by FindFirstFile)

# $Boxes: @{ id = state } (IDC_COMPRESSED 246, IDC_RECURSESUBDIRS 248); $Date: set IDC_ATTR_MODIFIED_DATE 250 to 2001-02-03;
# $Prepare: scriptblock run on the fixture; $Shape: 'j' (the junction itself), 'sel' (a folder holding the junction), 'plain'
function Run-Case([string]$Case, [string]$Shape, [hashtable]$Boxes, [scriptblock]$Check, [scriptblock]$Prepare = $null, [switch]$Date) {
    if (-not (Want $Case)) { return }
    $d = $Root + '\' + $Case
    NewDir $d; NewDir "$d\in"; NewDir "$d\out"; NewDir "$d\out\tgt"
    [IO.File]::WriteAllText($LP + "$d\out\tgt\T.TXT", "target`r`nline`r`n")
    if ($Shape -eq 'plain') { NewDir "$d\in\p"; [IO.File]::WriteAllText($LP + "$d\in\p\P.TXT", "plain") }
    else {
        if ($Shape -eq 'sel') { NewDir "$d\in\sel"; [IO.File]::WriteAllText($LP + "$d\in\sel\OWN.TXT", "own`r`nline`r`n") }
        $j = $(if ($Shape -eq 'sel') { "$d\in\sel\j" } else { "$d\in\j" })
        $o = & cmd.exe /c ("mklink /J `"{0}`" `"{1}`"" -f $j, "$d\out\tgt") 2>&1
        if (-not [IO.Directory]::Exists($j)) { Row $Case 'RUN' 'NOT DRIVEN' ('no junction: ' + (($o | ForEach-Object { "$_" }) -join ' ')); return }
        [void]$script:Links.Add($j)
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
        if ($Date) { $dateRes = [Res253]::SetDate((Ctl-Of $dlg 250), 2001, 2, 3) }
        Click-Ok $dlg
        $r = Serve $id 30 @(1, 6)
        End-Row $Case $id $null $before; $id = 0
        $res = & $Check $d
        $setAll = ($set.Count -eq $Boxes.Count) -and (-not $Date -or $dateRes -ne 0)
        Row $Case 'RUN' (V ($res[0] -and $setAll)) ("{0}; boxes set {1} of {2}; date {3}; dialog: {4}; windows: {5}" -f $res[1], $set.Count, $Boxes.Count, $dateRes, (Tail $dlgDesc 60), (Msgs $r))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc253_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("attrs_link253_probe (feature 253) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    Run-Case 'COMP' 'j' @{ 246 = 1 } {
        param($d)
        $j = IsComp "$d\in\j"; $t = IsComp "$d\out\tgt"; $tf = IsComp "$d\out\tgt\T.TXT"
        @(($j -and -not $t -and -not $tf), ("the junction compressed {0}; target tgt compressed {1}; T.TXT compressed {2}" -f $j, $t, $tf))
    }
    Run-Case 'UNCOMP' 'j' @{ 246 = 0 } {
        param($d)
        $j = IsComp "$d\in\j"; $t = IsComp "$d\out\tgt"
        @((-not $j -and $t), ("the junction compressed {0}; target tgt compressed {1}" -f $j, $t))
    } {
        param($d)
        $e1 = [Res253]::Compress($LP + "$d\out\tgt", $false, 1); $e2 = [Res253]::Compress($LP + "$d\in\j", $true, 1)
        Out ("UNCOMP     fixture: tgt compressed err {0} ({1}); the junction compressed err {2} ({3})" -f $e1, (IsComp "$d\out\tgt"), $e2, (IsComp "$d\in\j"))
    }
    Run-Case 'TIME' 'j' @{} {
        param($d)
        $jy = MYear "$d\in\j"; $ty = MYear "$d\out\tgt"
        @((($jy -eq 2001) -and ($ty -eq 2010)), ("the junction modified in {0}; target tgt modified in {1}" -f $jy, $ty))
    } {
        param($d)
        $t2010 = [DateTime]::new(2010, 6, 15, 12, 0, 0)
        [IO.Directory]::SetLastWriteTime($LP + "$d\out\tgt", $t2010); [IO.Directory]::SetCreationTime($LP + "$d\out\tgt", $t2010)
        Out ("TIME       fixture: tgt modified in {0}; the junction modified in {1}" -f (MYear "$d\out\tgt"), (MYear "$d\in\j"))
    } -Date
    Run-Case 'SUBC' 'sel' @{ 246 = 1; 248 = 1 } {
        param($d)
        $s = IsComp "$d\in\sel"; $o = IsComp "$d\in\sel\OWN.TXT"; $j = IsComp "$d\in\sel\j"; $t = IsComp "$d\out\tgt"; $tf = IsComp "$d\out\tgt\T.TXT"
        @(($s -and $o -and $j -and -not $t -and -not $tf), ("sel compressed {0}; OWN.TXT {1}; the junction {2}; target tgt {3}; T.TXT {4}" -f $s, $o, $j, $t, $tf))
    }
    Run-Case 'PLAIN' 'plain' @{ 246 = 1 } {
        param($d)
        $p = IsComp "$d\in\p"; $py = MYear "$d\in\p"
        @(($p -and ($py -eq 2001)), ("the folder p compressed {0}; modified in {1}" -f $p, $py))
    } $null -Date
    if (Want 'ENC') { Row 'ENC' 'RUN' 'NOT DRIVEN' 'encrypting would create an EFS certificate in the user''s store (none exists); the refusal is checked by saltests and code reading' }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    # the junctions first (rmdir removes a junction only), then the fixture
    foreach ($l in @($script:Links)) { if ([IO.Directory]::Exists($l)) { [void](& cmd.exe /c ("rmdir `"{0}`"" -f $l) 2>&1) } }
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
