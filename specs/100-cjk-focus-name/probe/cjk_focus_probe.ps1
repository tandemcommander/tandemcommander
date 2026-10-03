<#
.SYNOPSIS
    Feature 100 measurement: Change Directory (Shift+F7) with the full path of a
    FILE whose name holds a character outside the system code page - is the
    file focused, does F3 open it, and where does the viewer title "f?.txt"
    come from?

.DESCRIPTION
    Per case a folder %TEMP%\tc100_cjk\<case> with a.txt, f<X>.txt, z.txt
    (unique ASCII content each). X = U+0159 (inside code page 1250, control),
    U+65E5 (CJK), U+0416 (Cyrillic), U+1F600 (emoji, a surrogate pair).
    One instance per case, started in an empty folder (-l start -r start).

      CD     Change Directory (862): wide WM_SETTEXT of the file's full path
             into field 210; the field read back (WM_GETTEXT wide) must hold
             the text exactly, and IsWindowUnicode of the field is recorded.
      LOC    the panel location (the Change Directory field as it opens).
      FOCUS  the focused item's name, read losslessly: CM_RENAMEFILE (754)
             opens the rename dialog or the inline quick-rename edit, which is
             filled with the focused name; its text is read with WM_GETTEXT
             wide (IsWindowUnicode recorded) and the rename is cancelled.
             (Configured as "Quick Rename" dialog with a Unicode combo box.)
      F3     CM_VIEW (742): the viewer window: class, IsWindowUnicode,
             GetWindowTextW and InternalGetWindowText (the stored caption),
             any message box, which fixture file is held open (an exclusive
             open fails while held - the Code Viewer holds none), and the
             viewer's status bar: the line count (1 / 7 / 3) names the file
             whose content was read.
      NAV    the same file focused by plain navigation (Home + k x Down, the
             092 technique, identified by FOCUS), then FOCUS + F3 again.
      END    the disk still holds exactly the three files of the case.

    MUST run through tools\run_on_hidden_desktop.ps1. Refuses while another
    tandemcommander.exe runs. HKCU\Software\Tandem Commander exported before
    and restored + SHA-256-verified after. Scratch: %TEMP%\tc100_cjk (removed).

.NOTES
    Windows PowerShell 5.1; pure ASCII (names built from code points).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$OutFile
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

if (-not ('Drv100' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Drv100
{
    [DllImport("user32.dll")] public static extern bool IsWindowUnicode(IntPtr h);
    [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int InternalGetWindowText(IntPtr h, StringBuilder s, int n);
    public static string Internal(IntPtr h) { var s = new StringBuilder(4000); InternalGetWindowText(h, s, 4000); return s.ToString(); }
}
'@
}

# own scratch (the library's tc098_fix names are not used)
$Root = $TempRoot + '\tc100_cjk'
$StartDir = $Root + '\start'

function Start-Tc100([string]$Left) {
    $a = @('-t', 'T100', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $StartDir), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    [void][Drv098f]::Send((Get-Main $p.Id), 0, 0, 0, 20000)
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }

# the focused item's name, read from the rename editor (dialog or inline edit); cancelled again
function Read-Focus([int]$Id) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 754
    $dlg = [IntPtr]::Zero; $edit = [IntPtr]::Zero
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 6 -and $dlg -eq [IntPtr]::Zero -and $edit -eq [IntPtr]::Zero) {
        foreach ($h in (Get-Tops $Id)) { if ($known -notcontains $h -and [Drv098f]::Cls($h) -eq '#32770') { $dlg = $h } }
        if ($dlg -eq [IntPtr]::Zero) {
            $e = @([Drv098f]::Kids((Get-LeftList $Id)) | Where-Object { [Drv098f]::Cls($_) -ieq 'Edit' -and [Drv098f]::IsWindowVisible($_) })
            if ($e.Count) { $edit = $e[0] }
        }
        Start-Sleep -Milliseconds 100
    }
    if ($dlg -ne [IntPtr]::Zero) {
        Start-Sleep -Milliseconds 300
        $ed = @([Drv098f]::Kids($dlg) | Where-Object { @('Edit', 'ComboBox') -contains [Drv098f]::Cls($_) -and [Drv098f]::IsWindowVisible($_) }) | Select-Object -First 1
        if (-not $ed) { $t = 'dialog without an edit: ' + (WinDesc $dlg); Close-Win $dlg; return [pscustomobject]@{ Name = $null; How = $t } }
        $name = [Drv098f]::GetText($ed, 5000)
        $how = ("rename dialog '{0}', {1} unicode={2}" -f [Drv098f]::Txt($dlg), [Drv098f]::Cls($ed), [Drv100]::IsWindowUnicode($ed))
        Post-Cmd $dlg 2
        $sw.Restart(); while ($sw.Elapsed.TotalSeconds -lt 4 -and [Drv098f]::IsWindow($dlg)) { Start-Sleep -Milliseconds 100 }
        if ([Drv098f]::IsWindow($dlg)) { Close-Win $dlg }
        Sync $Id
        return [pscustomobject]@{ Name = $name; How = $how }
    }
    if ($edit -ne [IntPtr]::Zero) {
        $name = [Drv098f]::GetText($edit, 5000)
        $how = ("inline edit unicode={0}" -f [Drv100]::IsWindowUnicode($edit))
        [void][Drv098f]::PostMessageW($edit, 0x0100, [IntPtr]0x1B, [IntPtr]1)   # WM_KEYDOWN VK_ESCAPE
        [void][Drv098f]::PostMessageW($edit, 0x0101, [IntPtr]0x1B, [IntPtr]0xC0000001)
        $sw.Restart(); while ($sw.Elapsed.TotalSeconds -lt 3 -and [Drv098f]::IsWindow($edit) -and [Drv098f]::IsWindowVisible($edit)) { Start-Sleep -Milliseconds 100 }
        if ([Drv098f]::IsWindow($edit) -and [Drv098f]::IsWindowVisible($edit)) { [void][Drv098f]::PostMessageW($edit, 0x0102, [IntPtr]0x1B, [IntPtr]1); Start-Sleep -Milliseconds 500 }
        Sync $Id
        return [pscustomobject]@{ Name = $name; How = $how }
    }
    return [pscustomobject]@{ Name = $null; How = 'no rename editor appeared' }
}

# F3 on the focused item
function Read-F3([int]$Id, [string]$Dir, [string[]]$Files) {
    $known = Get-Tops $Id
    Post-Cmd (Get-Main $Id) 742
    $w = Wait-NewWin $Id $known 15
    if ($w -eq [IntPtr]::Zero) { return 'no window opened' }
    Start-Sleep -Milliseconds 1500
    $cls = [Drv098f]::Cls($w)
    if ($cls -eq '#32770') { $t = 'MESSAGE ' + (WinDesc $w); Close-Win $w; return $t }
    $held = @()
    foreach ($f in $Files) {
        try { $s = [IO.File]::Open((Join-Path $Dir $f), 'Open', 'Read', 'None'); $s.Close() } catch { $held += (Esc $f) }
    }
    $status = (@([Drv098f]::Kids($w) | Where-Object { [Drv098f]::Cls($_) -eq 'Static' } | ForEach-Object { [Drv098f]::Txt($_) } | Where-Object { $_ }) -join ' / ')
    $r = ("class '{0}' unicode={1}; GetWindowTextW '{2}'; InternalGetWindowText '{3}'; held open: [{4}]; status bar '{5}' (a.txt 1 line, f-file 7, z.txt 3)" -f $cls, [Drv100]::IsWindowUnicode($w), (Esc ([Drv098f]::Txt($w))), (Esc ([Drv100]::Internal($w))), ($held -join ','), (Esc $status))
    [void][Drv098f]::PostMessageW($w, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero)
    $sw = [Diagnostics.Stopwatch]::StartNew(); while ($sw.Elapsed.TotalSeconds -lt 5 -and [Drv098f]::IsWindow($w)) { Start-Sleep -Milliseconds 100 }
    Sync $Id
    return $r
}

function Run-Case([string]$Case, [string]$X) {
    $dir = $Root + '\' + $Case
    NewDir $dir
    $fx = 'f' + $X + '.txt'
    $files = @('a.txt', $fx, 'z.txt')
    # unique content: the line count tells which file the viewer read (its status bar shows it)
    $nLines = @{ 'a.txt' = 1; 'z.txt' = 3 }; $nLines[$fx] = 7
    foreach ($f in $files) { [IO.File]::WriteAllText($LP + $dir + '\' + $f, ((1..$nLines[$f] | ForEach-Object { 'CONTENT-' + $Case + '-' + (Esc $f) + '-line' + $_ }) -join "`r`n"), (New-Object Text.ASCIIEncoding)) }
    $id = 0; $fatal = $null; $before = Reports
    try {
        $id = Start-Tc100 $StartDir
        $full = $dir + '\' + $fx
        $held = Do-ChangeDir $id $full
        $r = Serve $id 20
        $fatal = $r.Fatal
        $ctlU = '?'
        Row $Case 'CD' (V $held) ("field held the typed text exactly: {0}; typed {1}; windows after OK: {2}" -f $held, (Esc $full), (Msgs $r))
        $loc = Get-Loc $id
        Row $Case 'LOC' (V ($loc.TrimEnd('\') -ceq $dir)) ("panel location {0}" -f (Esc $loc))
        $fo = Read-Focus $id
        Row $Case 'FOCUS' (V ($fo.Name -ceq $fx)) ("focused name {0} via {1} (expected {2})" -f (Esc $fo.Name), $fo.How, (Esc $fx))
        $v = Read-F3 $id $dir $files
        Row $Case 'F3' 'INFO' $v
        # navigation: Home + k Down until the rename editor shows the file
        $k = -1
        for ($i = 0; $i -le 4; $i++) {
            Key $id 0x24; for ($j = 0; $j -lt $i; $j++) { Key $id 0x28 }
            Sync $id
            $f2 = Read-Focus $id
            if ($f2.Name -ceq $fx) { $k = $i; break }
        }
        Row $Case 'NAV' (V ($k -ge 0)) ("focused by Home + {0} x Down (rename editor read back {1})" -f $k, (Esc $f2.Name))
        if ($k -ge 0) { Row $Case 'NAVF3' 'INFO' (Read-F3 $id $dir $files) }
        $disk = @([IO.Directory]::GetFiles($LP + $dir) | ForEach-Object { [IO.Path]::GetFileName($_) } | Sort-Object)
        $same = (($disk -join '|') -ceq ((@($files) | Sort-Object) -join '|'))
        Row $Case 'DISK' (V $same) ("files on disk: {0}" -f (($disk | ForEach-Object { Esc $_ }) -join ', '))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $Case $id $fatal $before } }
}

# ---- main --------------------------------------------------------------------
$others = @(Get-Process -Name 'tandemcommander' -ErrorAction SilentlyContinue)
if ($others.Count) { Out ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }
$backup = Join-Path $env:TEMP 'tc100_cjk_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("cjk_focus_probe (feature 100)")
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; registry key existed {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), $existed)
    Out ''
    Run-Case 'c0r' ([string][char]0x0159)
    Run-Case 'c1ri' ([string][char]0x65E5)
    Run-Case 'c2zh' ([string][char]0x4E2D)
    Run-Case 'c3cyr' ([string][char]0x0416)
    Run-Case 'c4emo' ([char]::ConvertFromUtf32(0x1F600))
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ("Fixture: could not delete $Root : " + $_.Exception.Message) }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}. Left running: {2}; fixture removed: {3}; registry restored+identical: {4}" -f $np, $nf, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
