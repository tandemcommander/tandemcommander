<#
.SYNOPSIS
    Feature 301 probe: a subst drive whose target is long or outside the code page - is its target read whole,
    or does the program work with a '?' / cut path?

.DESCRIPTION
    A free drive letter is substed (DefineDosDeviceW, as subst.exe does) to a fixture folder that
    holds a junction J (its target holds precious.txt). The program starts on the fixture's start
    folder, goes to <letter>:\J and back (J focused), then:
      DEL   F8 on J (Recycle Bin off), the question answered No: PASS = the question names a junction (the program
            told it is a link) and nothing was deleted
      INFO  Drive Information (752) on <letter>:\ - the drive type line (551): PASS = no '?' and the
            subst target whole, or no part of it
      VOL   the same dialog's mount point (571) and volume GUID (572): PASS = the target's drive root
            and a \\?\Volume{...}\ name (review 1 of 301: the volume checks of a refused target)
      MOVE  a second start, left panel <letter>:\a, right <letter>:\J; F6 of a\f.txt, OK: PASS =
            moved, with the same file id (a rename - the program judged one volume, not copy + delete)
    Cases (the fixture folder path, %TEMP%\tc301\...):
      SHORT  the control: an ASCII folder
      CJK    80 CJK letters - about 120 UTF-16 units, 280 bytes of UTF-8 (subst.exe takes it)
      LONG   over MAX_PATH UTF-16 units (DefineDosDeviceW takes it, subst.exe does not)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    The subst definitions are removed at the end. Exit code = number of FAIL rows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
if (-not ('SubstP' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class SubstP
{
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool DefineDosDeviceW(uint flags, string dev, string target);
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern uint QueryDosDeviceW(string dev, StringBuilder buf, uint max);
    [DllImport("kernel32.dll")] public static extern uint GetACP();
    [StructLayout(LayoutKind.Sequential)]
    public struct BHFI { public uint Attr, C1, C2, A1, A2, W1, W2, Vol, SizeHi, SizeLo, Links, IdxHi, IdxLo; }
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern Microsoft.Win32.SafeHandles.SafeFileHandle CreateFileW(string name, uint access, uint share, IntPtr sa, uint disp, uint flags, IntPtr tmpl);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool GetFileInformationByHandle(Microsoft.Win32.SafeHandles.SafeFileHandle h, out BHFI info);
    public static string FileId(string path)
    {
        using (var h = CreateFileW(path, 0x80, 7, IntPtr.Zero, 3, 0x02000000, IntPtr.Zero))
        {
            BHFI i;
            if (h.IsInvalid || !GetFileInformationByHandle(h, out i)) return null;
            return i.Vol.ToString("X8") + ":" + i.IdxHi.ToString("X8") + i.IdxLo.ToString("X8");
        }
    }
}
'@
}
$Root = $TempRoot + '\tc301'
$StartDir = $Root + '\start'
$ConfKey = 'HKCU:\Software\Tandem Commander\0.1\Configuration'
$Cjk = -join (1..80 | ForEach-Object { [char](0x4E00 + $_) })
$script:Defined = New-Object System.Collections.ArrayList

function Cmd([string]$c) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & cmd.exe /c $c 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    return [pscustomobject]@{ Rc = $rc; Text = (($o | ForEach-Object { "$_" }) -join ' ') }
}
function Free-Letter {
    foreach ($c in 'ZYXWVUTSRQP'.ToCharArray()) {
        $sb = New-Object Text.StringBuilder 1100
        if ([SubstP]::QueryDosDeviceW("${c}:", $sb, 1024) -eq 0) { return [string]$c }
    }
    throw 'no free drive letter'
}

function Run-Case([string]$Case, [string]$Folder, [string]$Target) {
    $id = 0; $before = Reports; $drv = $null
    try {
        NewDir $Folder; NewDir $Target; WriteFile "$Target\precious.txt" 'PRECIOUS'
        NewDir "$Folder\a"; WriteFile "$Folder\a\f.txt" 'MOVE ME'
        $j = "$Folder\J"
        $r = Cmd ("mklink /J `"\\?\{0}`" `"{1}`"" -f $j, $Target)
        if (-not [IO.Directory]::Exists($LP + $j)) { Row $Case 'SETUP' 'NOT DRIVEN' ('mklink /J refused: ' + $r.Text); return }
        $drv = Free-Letter
        if (-not [SubstP]::DefineDosDeviceW(0, "${drv}:", $Folder)) { Row $Case 'SETUP' 'NOT DRIVEN' ('DefineDosDeviceW failed ' + [Runtime.InteropServices.Marshal]::GetLastWin32Error()); $drv = $null; return }
        [void]$script:Defined.Add(@($drv, $Folder))
        Out ("{0}: {1}: -> folder of {2} UTF-16 units / {3} UTF-8 bytes" -f $Case, $drv, $Folder.Length, (U8Len $Folder))
        $id = Start-Tc $StartDir
        [void](Do-ChangeDir $id "${drv}:\J")
        Start-Sleep -Milliseconds 300
        $loc = Get-Loc $id
        if ($loc -like '*\J') { Key $id 0x08; Start-Sleep -Milliseconds 600 }   # Backspace: up, J focused
        $loc2 = Get-Loc $id
        # DEL: F8, the question answered No (7)
        Post-Cmd (Get-Main $id) 729
        $res = Serve $id 20 @(7)
        $m = Msgs $res
        Start-Sleep -Milliseconds 500
        $kept = [IO.File]::Exists($LP + "$Target\precious.txt") -and [IO.Directory]::Exists($LP + $j)
        $isJunction = $m -match 'junction|spojen'   # IDS_QUESTION_JUNCTION (English / Czech UI)
        Row $Case 'DEL' (V ($isJunction -and $kept)) ("location '{0}'; the question names a junction {1}; J and the target's file kept {2}; windows: {3}" -f (Tail $loc2 30), $isJunction, $kept, (Tail $m 200))
        # INFO: Drive Information, the drive type line
        $dlg = Open-ByCmd $id 752
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'INFO' 'FAIL' 'Drive Information opened no window' }
        else {
            $ctl = Find-Ctl $dlg 551
            $t = '<no control>'; if ($ctl -ne [IntPtr]::Zero) { $t = [Drv098f]::GetText($ctl, 5000) }
            $d = WinDesc $dlg
            $mp = '<no control>'; $c = Find-Ctl $dlg 571; if ($c -ne [IntPtr]::Zero) { $mp = [Drv098f]::GetText($c, 5000) }
            $gu = '<no control>'; $c = Find-Ctl $dlg 572; if ($c -ne [IntPtr]::Zero) { $gu = [Drv098f]::GetText($c, 5000) }
            Close-Win $dlg; Start-Sleep -Milliseconds 400
            $whole = $t.Contains($Folder)
            $none = -not $t.Contains($Root)
            # a target the program can represent is shown whole; the long one whole or not at all
            $ok = ($d -notmatch $FatalRx) -and (-not $t.Contains('?')) -and ($whole -or ($Case -eq 'LONG' -and $none))
            Row $Case 'INFO' (V $ok) ("type line {0} chars, target whole {1}, no part of it {2}, '?' {3}: '{4}'; dialog: {5}" -f $t.Length, $whole, $none, $t.Contains('?'), (Tail $t 120), (Tail $d 300))
            $okVol = ($mp -ieq $Folder.Substring(0, 3)) -and ($gu -match '^\\\\\?\\Volume\{[0-9a-fA-F-]+\}\\$')
            Row $Case 'VOL' (V $okVol) ("mount point '{0}' (expected '{1}'), volume '{2}'" -f (Tail $mp 60), $Folder.Substring(0, 3), (Tail $gu 60))
        }
        End-Row $Case $id $null $before; $id = 0
        # MOVE: left <letter>:\a, right <letter>:\J - F6 of f.txt
        $src = "$Folder\a\f.txt"; $dst = "$Target\f.txt"
        $idBefore = [SubstP]::FileId($LP + $src)
        $before = Reports
        $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T301', '-l', ('"{0}:\a"' -f $drv), '-r', ('"{0}:\J"' -f $drv), '-p', '1') -PassThru
        [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p; $id = $p.Id
        $sw = [Diagnostics.Stopwatch]::StartNew()
        while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $id) -and (Get-Main $id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
        try { [void]$p.WaitForInputIdle(30000) } catch { }
        Start-Sleep -Milliseconds 2000
        $locL = Get-Loc $id
        Key $id 0x24; Key $id 0x28   # Home, Down: ".." then f.txt
        Start-Sleep -Milliseconds 400
        Post-Cmd (Get-Main $id) 728  # F6 Move
        $res = Serve $id 30 @(1, 6)
        Start-Sleep -Milliseconds 800
        $moved = [IO.File]::Exists($LP + $dst) -and -not [IO.File]::Exists($LP + $src)
        $idAfter = $(if ($moved) { [SubstP]::FileId($LP + $dst) } else { $null })
        $renamed = $moved -and $idBefore -and ($idBefore -eq $idAfter)
        Row $Case 'MOVE' (V $renamed) ("left '{0}'; moved {1}; file id {2} -> {3} (same = a rename); windows: {4}" -f (Tail $locL 30), $moved, $idBefore, $idAfter, (Tail (Msgs $res) 200))
        End-Row $Case $id $null $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) { End-Row $Case $id $null $before }
        if ($drv) { [void][SubstP]::DefineDosDeviceW(6, "${drv}:", $Folder) }   # DDD_REMOVE_DEFINITION | DDD_EXACT_MATCH_ON_REMOVE
    }
}

$backup = Join-Path $env:TEMP 'tc301_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
$cases = @(
    @('SHORT', ($Root + '\s'), ($Root + '\t1')),
    @('CJK', ($Root + '\' + $Cjk), ($Root + '\t2')),
    @('LONG', ($Root + '\' + ('a' * 200) + '\' + ('b' * 100)), ($Root + '\t3'))
)
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Set-ItemProperty -Path $ConfKey -Name 'Use Recycle Bin' -Value 0 -Type DWord   # the program's own question
    Out ("subst_probe (feature 301) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [SubstP]::GetACP())
    Out ''
    foreach ($c in $cases) { Run-Case $c[0] $c[1] $c[2] }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    foreach ($d in @($script:Defined)) { [void][SubstP]::DefineDosDeviceW(6, ($d[0] + ':'), $d[1]) }
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    # junctions first (a recursive delete must not follow them), then the fixture
    foreach ($c in $cases) { $j = $c[1] + '\J'; if ([IO.Directory]::Exists($LP + $j)) { [void](Cmd ("rmdir `"\\?\{0}`"" -f $j)) } }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $left = @($script:Defined | Where-Object { $sb = New-Object Text.StringBuilder 1100; [SubstP]::QueryDosDeviceW(($_[0] + ':'), $sb, 1024) -ne 0 }).Count
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; subst left defined: {4}; fixture removed: {5}; registry restored+identical: {6}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, $left, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
