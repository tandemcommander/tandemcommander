<#
.SYNOPSIS
    Feature 388 probe: the Renamer's "Include subdirectories" never descends into a junction or a
    directory symbolic link - the link is listed as an item of its own (its name renamed like a
    folder of the selection), the files of its TARGET are never offered.

.DESCRIPTION
    Every row: a folder of the fixture, the Renamer opened on one panel item, the preview switched
    to full paths (CMD_FULLPATH 609), "Include subdirectories" (IDC_SUBDIRS 102) ticked, the
    preview's rows read (LVM_GETITEMTEXTW, column 0 = the full old name). Every link target lies
    INSIDE the fixture, but outside the selected folder.
      out       sel\a.txt, sel\sub\b.txt, junction sel\out -> tgt (o1, o2, o3).
                PASS = rows exactly a.txt, sub\b.txt, out; no row below tgt; no box
      loop      sel\a.txt, junction sel\loop -> sel (a loop).
                PASS = rows exactly a.txt, loop; no box (before: the same files once per level
                until the "too long path" box)
      selected  the junction jsel -> tgt (o1, o2) itself is the selected item.
                PASS = one row, jsel (as feature 213 treats a selected junction)
      symlink   sel\a.txt, directory symbolic link sel\sl -> tgt (mklink /D; NOT DRIVEN when the
                account may not create one). PASS = rows a.txt, sl
      mask      as "out", mask "*.txt": PASS = rows a.txt, sub\b.txt (the link's name does not
                match the mask)
      plain     control: sel\a.txt, sel\x\y\z.txt (plain folders). PASS = rows a.txt, x\y\z.txt
      rename    as "out", new name "n_$(OriginalName)", Start: PASS = sel\n_a.txt,
                sel\sub\n_b.txt, the junction renamed to sel\n_out (still a junction), tgt's
                files untouched (o1.txt, o2.txt, o3.txt)
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Links are removed as links (rmdir) before the fixture is deleted.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $PSScriptRoot '..\..\127-mixed-template-texts\probe\lvtext_lib.ps1')
if (-not ('Drv104' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
public static class Drv104
{
    [DllImport("user32.dll", SetLastError = true)] static extern IntPtr SendMessageTimeoutW(IntPtr h, uint msg, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr w, IntPtr l);
    public static long SendR(IntPtr h, uint msg, long w, long l)
    {
        IntPtr r; if (SendMessageTimeoutW(h, msg, (IntPtr)w, (IntPtr)l, 0, 5000, out r) == IntPtr.Zero) return -999; return r.ToInt64();
    }
    [DllImport("user32.dll")] static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
    [DllImport("kernel32.dll")] static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] static extern bool AttachThreadInput(uint a, uint b, bool attach);
    [DllImport("user32.dll")] static extern bool GetKeyboardState(byte[] k);
    [DllImport("user32.dll")] static extern bool SetKeyboardState(byte[] k);
    // a key with modifiers (bit 1 Ctrl, bit 2 Shift): the probe thread shares the target thread's
    // input state and sets the key-state table - no real key press (the 100/102 method)
    public static string ModKey(IntPtr target, int vk, int mods)
    {
        uint pid; uint tid = GetWindowThreadProcessId(target, out pid);
        uint me = GetCurrentThreadId();
        if (!AttachThreadInput(me, tid, true)) return "AttachThreadInput failed " + Marshal.GetLastWin32Error();
        var saved = new byte[256]; GetKeyboardState(saved);
        try
        {
            var k = (byte[])saved.Clone();
            if ((mods & 2) != 0) { k[0x10] = k[0xA0] = 0x80; }
            if ((mods & 1) != 0) { k[0x11] = k[0xA2] = 0x80; }
            if (!SetKeyboardState(k)) return "SetKeyboardState failed";
            PostMessageW(target, 0x0100, (IntPtr)vk, (IntPtr)1);
            IntPtr r; SendMessageTimeoutW(target, 0, IntPtr.Zero, IntPtr.Zero, 0, 3000, out r);
            Thread.Sleep(300);
            return "ok";
        }
        finally
        {
            SetKeyboardState(saved);
            PostMessageW(target, 0x0101, (IntPtr)vk, unchecked((IntPtr)0xC0000001));
            AttachThreadInput(me, tid, false);
        }
    }
}
'@
}

$Root = $TempRoot + '\tc388_ren'
$StartDir = $Root + '\start'
$Links = New-Object System.Collections.ArrayList   # every link made, removed as a link at the end

function Put([string]$p, [string]$text) { [IO.File]::WriteAllText($LP + $p, $text, (New-Object Text.ASCIIEncoding)) }
function Cmd([string]$c) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & cmd.exe /c $c 2>&1; $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    return [pscustomobject]@{ Rc = $rc; Text = (($o | ForEach-Object { "$_" }) -join ' ') }
}
function Make-Link([string]$Kind, [string]$Link, [string]$Target) {   # Kind: /J or /D
    if (-not $Link.StartsWith($Root + '\') -or -not $Target.StartsWith($Root + '\')) { throw "link outside the fixture: $Link -> $Target" }
    $r = Cmd ('mklink {0} "{1}" "{2}"' -f $Kind, $Link, $Target)
    if ($r.Rc -eq 0) { [void]$Links.Add($Link); return '' }
    return ('mklink ' + $Kind + ' refused: ' + $r.Text)
}
function Remove-Links {
    for ($i = $Links.Count - 1; $i -ge 0; $i--) {
        $l = $Links[$i]
        if ([IO.Directory]::Exists($l)) {
            $a = [IO.File]::GetAttributes($l)
            if (($a -band [IO.FileAttributes]::ReparsePoint) -ne 0) { [void](Cmd ('rmdir "{0}"' -f $l)) }
        }
    }
}
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Start-P([string]$Left) {
    $a = @('-t', 'T388', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function Edit-Of([IntPtr]$Combo) { return @([Drv098f]::Kids($Combo) | Where-Object { [Drv098f]::Cls($_) -eq 'Edit' }) | Select-Object -First 1 }
function Type-Into([IntPtr]$Edit, [string]$Text) { foreach ($ch in $Text.ToCharArray()) { [void][Drv104]::PostMessageW($Edit, 0x0102, [IntPtr][int]$ch, [IntPtr]1) } }
function Wait-Text([IntPtr]$H, [int]$Len, [double]$Seconds = 6) {
    $sw = [Diagnostics.Stopwatch]::StartNew(); $t = ''
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) { Start-Sleep -Milliseconds 250; $t2 = [Drv098f]::GetText($H, 5000); if ($t2.Length -ge $Len -or ($t2 -ceq $t -and $sw.Elapsed.TotalSeconds -gt 2)) { return $t2 }; $t = $t2 }
    return $t
}
# answers every box of the instance: the ids in $Want, else close; records the texts; stops when
# no box is shown for 2 s (windows in $Ignore are not boxes)
function Answer([int]$Id, [double]$Seconds = 20, [int[]]$WantIds = @(7, 2), $Ignore = @()) {
    $r = [pscustomobject]@{ Messages = New-Object System.Collections.ArrayList; Fatal = $null }
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $Seconds) {
        if (-not (Test-Alive $Id)) { break }
        $boxes = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $Ignore -notcontains $_ -and [Drv098f]::IsWindowEnabled($_) })
        if (-not $boxes.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.0) { break }
            Start-Sleep -Milliseconds 150; continue
        }
        $idleSince = $null
        foreach ($b in $boxes) {
            $key = $b.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - $seen[$key] -lt 0.7) { continue }
            $seen.Remove($key)
            $d = WinDesc $b
            if ($d -match $FatalRx) { $r.Fatal = $d; return $r }
            [void]$r.Messages.Add($d)
            $btn = $null
            foreach ($w in $WantIds) { $btn = Buttons $b | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1; if ($btn) { break } }
            if ($btn) { Click $btn } else { Close-Win $b }
            Start-Sleep -Milliseconds 600
        }
    }
    return $r
}
function Msgs2($r) { if ($r.Messages.Count) { return ($r.Messages -join ' || ') } else { return 'no box' } }
function End-P([string]$Case, [int]$Id, $Before) {
    foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { [void][Drv098f]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    Start-Sleep -Milliseconds 800
    [void](Answer $Id 6 @(6, 1))
    End-Row $Case $Id $null $Before
}
function Is-Renamer([IntPtr]$H) { return ([Drv098f]::Cls($H) -eq '#32770') -and ((Kid $H 101 'ComboBox') -ne $null) -and ((Kid $H 106 'ComboBox') -ne $null) }
function Close-Renamer([int]$Id, [IntPtr]$Dlg) {
    if (-not [Drv098f]::IsWindow($Dlg)) { return }
    Post-Cmd $Dlg 2
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 8 -and [Drv098f]::IsWindow($Dlg)) {
        $q = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -eq '#32770' -and $_ -ne $Dlg -and [Drv098f]::IsWindowEnabled($_) })
        foreach ($b in $q) { $y = Buttons $b | Where-Object { @(6, 1) -contains [Drv098f]::GetDlgCtrlID($_) } | Select-Object -First 1; if ($y) { Click $y } }
        Start-Sleep -Milliseconds 300
    }
}
function Set-Mask([IntPtr]$Dlg, [string]$Mask) {
    $mc = Kid $Dlg 101 'ComboBox'
    [void][Drv098f]::SetText($mc, '', 5000); Type-Into (Edit-Of $mc) $Mask
    [void](Wait-Text $mc $Mask.Length)
    Start-Sleep -Milliseconds 2000
}
# the preview's rows: column 0 (the old name; full paths after CMD_FULLPATH)
function Preview-Rows([IntPtr]$Dlg) {
    $lv = Kid $Dlg 104 $null
    if (-not $lv) { return $null }
    $n = [LvText127]::Count($lv)
    $rows = @()
    for ($i = 0; $i -lt $n -and $i -lt 400; $i++) { $rows += [LvText127]::Cell($lv, $i, 0) }
    return [pscustomobject]@{ Count = $n; Rows = $rows }
}

# opens the Renamer on the panel item $Item of folder $Folder (the folder holds only that item)
function Open-RenamerOnItem([int]$Id, [string]$Folder) {
    $known = Get-Tops $Id
    [void](Do-ChangeDir $Id $Folder); Start-Sleep -Milliseconds 400; Sync $Id
    Key $Id 0x23; Start-Sleep -Milliseconds 300; Key $Id 0x2D; Start-Sleep -Milliseconds 300; Sync $Id   # End, Insert
    [void][Drv104]::ModKey((Get-LeftList $Id), 0x52, 3)   # Ctrl+Shift+R
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 15) {
        $w = @(Get-Tops $Id | Where-Object { $known -notcontains $_ -and (Is-Renamer $_) }) | Select-Object -First 1
        if ($w) { Start-Sleep -Milliseconds 1200; return $w }
        Start-Sleep -Milliseconds 200
    }
    return [IntPtr]::Zero
}

# one row: $Setup returns @{ Folder; Expect (full names, sorted); Forbid (a prefix no row may
# have); Mask; NewName; Check = { -> @(ok, facts) } } or @{ Skip = '<why>' }
function Run-Link([string]$Case, [scriptblock]$Setup) {
    if (-not (Want $Case)) { return }
    $c = & $Setup
    if ($c.Skip) { Row $Case 'RUN' 'NOT DRIVEN' $c.Skip; return }
    $id = 0; $before = Reports
    try {
        $id = Start-P $c.Folder
        $dlg = Open-RenamerOnItem $id $c.Folder
        if ($dlg -eq [IntPtr]::Zero) { Row $Case 'RUN' 'FAIL' 'the Renamer dialog did not open'; return }
        [void][Drv098f]::PostMessageW($dlg, 0x0111, [IntPtr]609, [IntPtr]::Zero); Start-Sleep -Milliseconds 1000   # CMD_FULLPATH
        if ($c.Mask) { Set-Mask $dlg $c.Mask }
        $sb = Kid $dlg 102 'Button'
        [void][Drv098f]::PostMessageW($sb, 0x00F5, [IntPtr]::Zero, [IntPtr]::Zero)   # BM_CLICK: ticks "Include subdirectories"
        Start-Sleep -Milliseconds 2500
        $ans = Answer $id 25 @(2, 1) @($dlg)
        $checked = [Drv104]::SendR($sb, 0x00F0, 0, 0)   # BM_GETCHECK (unticked again after a failed listing)
        $pv = Preview-Rows $dlg
        $rows = @($pv.Rows | Sort-Object)
        $exp = @($c.Expect | Sort-Object)
        $same = (($rows -join '|') -ceq ($exp -join '|'))
        $leak = @($rows | Where-Object { $c.Forbid -and $_.StartsWith($c.Forbid) })
        $texts = Msgs2 $ans
        $ok = $same -and ($leak.Count -eq 0) -and ($texts -eq 'no box') -and ($checked -eq 1) -and -not $ans.Fatal
        $shown = $(if ($rows.Count -le 12) { ($rows | ForEach-Object { Tail $_ 60 }) -join ', ' } else { (($rows | Select-Object -First 6 | ForEach-Object { Tail $_ 60 }) -join ', ') + ', ...' })
        $facts = ("rows {0} (expected {1}); below the link target {2}; subdirectories ticked {3}; boxes: {4}; rows: {5}" -f $pv.Count, $exp.Count, $leak.Count, $checked, (Tail $texts 160), $shown)
        if ($c.NewName -and $ok) {
            # back to file-name mode (CMD_FILENAMES 607): in full-path mode a plain new name is "Not valid full path"
            [void][Drv098f]::PostMessageW($dlg, 0x0111, [IntPtr]607, [IntPtr]::Zero); Start-Sleep -Milliseconds 1000
            $nn = Kid $dlg 106 'ComboBox'
            [void][Drv098f]::SetText($nn, $c.NewName, 5000)
            Start-Sleep -Milliseconds 1500
            Click (Kid $dlg 1 'Button')
            Start-Sleep -Milliseconds 1500
            $ans2 = Answer $id 20 @(6, 1) @($dlg)
            $res = & $c.Check
            $ok = $res[0] -and -not $ans2.Fatal
            $facts = $facts + ('; rename boxes: {0}; on disk: {1}' -f (Msgs2 $ans2), $res[1])
        }
        elseif ($c.NewName) {
            $facts = $facts + '; (not renamed: the listing was wrong)'
        }
        Row $Case 'RUN' (V $ok) $facts
        Close-Renamer $id $dlg
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

function Run-Cases {
    Run-Link 'out' {
        $d = $Root + '\out'; $t = $Root + '\out-tgt'; NewDir "$d\sel\sub"; NewDir $t
        Put "$d\sel\a.txt" 'A'; Put "$d\sel\sub\b.txt" 'B'; Put "$t\o1.txt" '1'; Put "$t\o2.txt" '2'; Put "$t\o3.txt" '3'
        $e = Make-Link '/J' "$d\sel\out" $t; if ($e) { return @{ Skip = $e } }
        @{ Folder = $d; Expect = @("$d\sel\a.txt", "$d\sel\sub\b.txt", "$d\sel\out"); Forbid = "$d\sel\out\" }
    }
    Run-Link 'loop' {
        $d = $Root + '\loop'; NewDir "$d\sel"; Put "$d\sel\a.txt" 'A'
        $e = Make-Link '/J' "$d\sel\loop" "$d\sel"; if ($e) { return @{ Skip = $e } }
        @{ Folder = $d; Expect = @("$d\sel\a.txt", "$d\sel\loop"); Forbid = "$d\sel\loop\" }
    }
    Run-Link 'selected' {
        $d = $Root + '\selected'; $t = $Root + '\selected-tgt'; NewDir $d; NewDir $t
        Put "$t\o1.txt" '1'; Put "$t\o2.txt" '2'
        $e = Make-Link '/J' "$d\jsel" $t; if ($e) { return @{ Skip = $e } }
        @{ Folder = $d; Expect = @("$d\jsel"); Forbid = "$d\jsel\" }
    }
    Run-Link 'symlink' {
        $d = $Root + '\symlink'; $t = $Root + '\symlink-tgt'; NewDir "$d\sel"; NewDir $t
        Put "$d\sel\a.txt" 'A'; Put "$t\o1.txt" '1'
        $e = Make-Link '/D' "$d\sel\sl" $t; if ($e) { return @{ Skip = $e } }
        @{ Folder = $d; Expect = @("$d\sel\a.txt", "$d\sel\sl"); Forbid = "$d\sel\sl\" }
    }
    Run-Link 'mask' {
        $d = $Root + '\mask'; $t = $Root + '\mask-tgt'; NewDir "$d\sel\sub"; NewDir $t
        Put "$d\sel\a.txt" 'A'; Put "$d\sel\sub\b.txt" 'B'; Put "$t\o1.txt" '1'; Put "$t\o2.txt" '2'
        $e = Make-Link '/J' "$d\sel\out" $t; if ($e) { return @{ Skip = $e } }
        @{ Folder = $d; Mask = '*.txt'; Expect = @("$d\sel\a.txt", "$d\sel\sub\b.txt"); Forbid = "$d\sel\out\" }
    }
    Run-Link 'plain' {
        $d = $Root + '\plain'; NewDir "$d\sel\x\y"
        Put "$d\sel\a.txt" 'A'; Put "$d\sel\x\y\z.txt" 'Z'
        @{ Folder = $d; Expect = @("$d\sel\a.txt", "$d\sel\x\y\z.txt"); Forbid = $null }
    }
    Run-Link 'rename' {
        $d = $Root + '\rename'; $t = $Root + '\rename-tgt'; NewDir "$d\sel\sub"; NewDir $t
        Put "$d\sel\a.txt" 'A'; Put "$d\sel\sub\b.txt" 'B'; Put "$t\o1.txt" '1'; Put "$t\o2.txt" '2'; Put "$t\o3.txt" '3'
        $e = Make-Link '/J' "$d\sel\out" $t; if ($e) { return @{ Skip = $e } }
        [void]$Links.Add("$d\sel\n_out")   # the renamed link, removed as a link too
        @{ Folder = $d; Expect = @("$d\sel\a.txt", "$d\sel\sub\b.txt", "$d\sel\out"); Forbid = "$d\sel\out\"; NewName = 'n_$(OriginalName)'
           Check = {
               $nl = "$d\sel\n_out"
               $isLink = [IO.Directory]::Exists($nl) -and (([IO.File]::GetAttributes($nl) -band [IO.FileAttributes]::ReparsePoint) -ne 0)
               $tg = ((@([IO.Directory]::GetFiles($t) | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object)) -join ',')
               $okA = [IO.File]::Exists("$d\sel\n_a.txt") -and [IO.File]::Exists("$d\sel\sub\n_b.txt")
               @(($okA -and $isLink -and $tg -ceq 'o1.txt,o2.txt,o3.txt'), ("n_a.txt + sub\n_b.txt {0}; n_out a junction {1}; target holds {2} (expected o1.txt,o2.txt,o3.txt)" -f $okA, $isLink, $tg))
           }.GetNewClosure() }
    }
}

$backup = Join-Path $env:TEMP 'tc388_ren_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { throw "the fixture $Root exists (an interrupted run?): remove its links with rmdir, then the folder" }
    NewDir $StartDir
    Set-Config
    Out 'ren_link_probe (feature 388)'
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ''
    Run-Cases
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { Remove-Links } catch { Out ("Fixture: could not remove a link: " + $_.Exception.Message) }
    $linksLeft = @($Links | Where-Object { [IO.Directory]::Exists($_) -and (([IO.File]::GetAttributes($_) -band [IO.FileAttributes]::ReparsePoint) -ne 0) })
    if ($linksLeft.Count -eq 0) {
        try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    }
    else { Out ("Fixture: links left, folder kept: " + ($linksLeft -join '; ')) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
