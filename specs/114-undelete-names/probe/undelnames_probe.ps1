<#
.SYNOPSIS
    Feature 114 probe: the Undelete plug-in lists and restores deleted files under their own
    names - the FAT deletion marker (0xE5) and the 0x05 escape are applied to FAT short names
    only, never to a UTF-8 name; short names are read in the OEM code page; long names with an
    unpaired surrogate keep it. On the build of this feature (-Expect fixed) and on the build
    before it (-Expect before, Debug_x64_pre114, the control).

.DESCRIPTION
    Fixtures under %TEMP%\tc114_un (removed at the end): make_images.py writes a FAT12 and an
    exFAT disk image (ordinary files - no volume is opened, no admin needed) and expected.json.
    Each image is opened through Change Directory "del:<image>\{All Deleted Files}" (the
    plug-in's file-system path; the connect dialog's image route was driven by 104's und-image
    row), every listed file is selected and restored with F5 into an empty folder of the other
    panel, and the folder is
    compared with expected.json: name exactly (UTF-16, case included) and content.

    The "Damaged Filename" dialog (a FAT short name whose first byte was overwritten by the
    deletion marker) is answered by replacing the shown first character with U+010C; the FIRST
    prompt is answered with "All" (the same character for every damaged name).

    Rows (names for -Only):
      fat    fat114.ima. Per file: name and content as expected.json says. PROMPTS: the build of
             114 asks once ("$91D~1.TXT" - deleted U+597D.txt whose short name is the hash form
             191D~1.TXT, its long name cannot be linked back; All then names "$AA.TXT" and
             "$OO.TXT" too - a non-ASCII replacement
             character is remembered); the build before asked for every name that merely
             began with the byte 0xE5 and could not remember a non-ASCII "All" character.
             EXTRA: no file other than the expected ones in the target.
      exfat  exfat114.ima. Per file as above; PROMPTS: none (exFAT has no deletion marker in
             names - the build before asked for every name of U+5000..U+5FFF).
      dup    exfatdup114.ima: two deleted files of one 110-character CJK name (334 bytes of
             UTF-8). Restoring both numbers them first ("name (1).txt"), which wrote into a
             MAX_PATH + 50 stack buffer (the build before: "Stack around ... corrupted" in Debug);
             the build of 114: "Target path is too long" twice (answered Skip), nothing restored,
             no fatal window. With -Expect before this row PASSes when the fatal window appears
             (its END row then FAILs - the control).
    -Expect before: a file row PASSes when the build before gets it wrong exactly where
    expected.json says (defect_before) - the control that the probe sees the defect.
    NOT DRIVEN (recorded): NTFS (no image can be made without admin rights or a formatter -
    the NTFS path shares the fixed listing and restore code, see fix-log), volume mount points
    (mountvol / SetVolumeMountPoint need admin - verified by code and saltests), the connect
    dialog's volume list (a cross-process list view read), Restore Encrypted Files.

    MUST run through tools\run_on_hidden_desktop.ps1 (refuses on the Default desktop). Refuses
    while any tandemcommander.exe runs. HKCU\Software\Tandem Commander exported before,
    restored and SHA-256-verified after. Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string[]]$Only,
    [string]$Python = 'python'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or ($Only -contains $n) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('REFUSED: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 99 }
if (-not ('Desk114' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public static class Desk114
{
    [DllImport("user32.dll")] public static extern IntPtr GetThreadDesktop(uint threadId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("kernel32.dll")] public static extern uint GetOEMCP();
    [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)] public static extern bool GetUserObjectInformationW(IntPtr h, int index, StringBuilder info, int length, out int needed);
    public static string Name()
    {
        var sb = new StringBuilder(256); int needed;
        if (!GetUserObjectInformationW(GetThreadDesktop(GetCurrentThreadId()), 2, sb, sb.Capacity * 2, out needed)) return "";
        return sb.ToString();
    }
}
'@
}
$deskName = [Desk114]::Name()
if (-not $deskName -or $deskName -ieq 'Default' -or $deskName -ieq 'Winlogon') { Write-Output ("REFUSED: this probe must run on a hidden desktop (tools\run_on_hidden_desktop.ps1); the current desktop is '{0}'" -f $deskName); exit 98 }

. (Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1')

$Fixed = ($Expect -eq 'fixed')
$Root = $TempRoot + '\tc114_un'
$StartDir = $Root + '\start'
$ImgDir = $Root + '\img'
$CCaron = [string][char]0x010C
$AllDeleted = '{All Deleted Files}'

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Kid([IntPtr]$Dlg, [int]$CtlId, [string]$Cls) { return @([Drv098f]::Kids($Dlg) | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $CtlId -and ((-not $Cls) -or [Drv098f]::Cls($_) -eq $Cls) }) | Select-Object -First 1 }
function Start-P([string]$Left, [string]$Right) {
    $a = @('-t', 'T114', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1')
    $p = Start-Process -FilePath $Exe -ArgumentList $a -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    if ((Get-Process -Id $p.Id).Path -ine $Exe) { throw "pid $($p.Id) is not $Exe" }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Sync $p.Id
    Start-Sleep -Milliseconds 1500
    return $p.Id
}
function End-P([string]$Case, [int]$Id, $Before) {
    foreach ($h in @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })) { [void][Drv098f]::PostMessageW($h, 0x0010, [IntPtr]::Zero, [IntPtr]::Zero) }
    Start-Sleep -Milliseconds 800
    End-Row $Case $Id $null $Before
}
function Units([object[]]$u) { return -join ($u | ForEach-Object { [char][int]$_ }) }
# the names and contents of the files in a folder: name -> content (names exactly, lone surrogates included)
function Folder-Map([string]$dir) {
    # ordinal (case-sensitive) keys: a PowerShell @{} ignores case, and the first GUI run on the build
    # before took its 'mixed.txt' for the expected 'mixed.TXT' (the NT case-bit row)
    $m = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
    if (-not [IO.Directory]::Exists($LP + $dir)) { return $m }
    foreach ($e in [IO.Directory]::GetFiles($LP + $dir)) {
        $n = $e.Substring($e.LastIndexOf('\') + 1)
        $m[$n] = [IO.File]::ReadAllText($e, (New-Object Text.ASCIIEncoding))
    }
    return $m
}

# opens <image>\{All Deleted Files} in the active (left) panel: Change Directory with the plug-in path
function Open-Deleted([int]$Id, [string]$Image) {
    $target = 'del:' + $Image + '\' + $AllDeleted
    [void](Do-ChangeDir $Id $target)
    $r = Serve $Id 60 @(1, 6)
    if ($r.Fatal) { return @{ Ok = $false; How = 'change directory'; Facts = ('FATAL ' + $r.Fatal) } }
    Sync $Id
    $loc = Get-Loc $Id
    if ($loc -like ('*' + $AllDeleted)) { return @{ Ok = $true; How = 'change directory'; Facts = ('panel: ' + (Tail $loc 60) + '; windows: ' + (Msgs $r)) } }
    return @{ Ok = $false; How = 'change directory'; Facts = ('panel: ' + (Tail $loc 60) + '; windows: ' + (Msgs $r)) }
}

# restores the selection with F5 into the other panel; answers the Damaged Filename dialog (U+010C for the shown
# first character, All on the first one) and every other box (Yes / OK); returns what it saw
function Restore-All([int]$Id) {
    $res = [pscustomobject]@{ Prompts = New-Object System.Collections.ArrayList; Boxes = New-Object System.Collections.ArrayList; Fatal = $null; Target = $null; Answered = New-Object System.Collections.ArrayList }
    Post-Cmd (Get-Main $Id) 842; Start-Sleep -Milliseconds 1500; Sync $Id   # select all; the enablers refresh on idle (101)
    $dlg = Open-ByCmd $Id 727 15   # Copy (F5)
    if ($dlg -eq [IntPtr]::Zero) { $res.Fatal = 'Copy (727) opened no window'; return $res }
    $d0 = WinDesc $dlg
    if ($d0 -match $FatalRx) { $res.Fatal = $d0; return $res }
    $f = Find-Ctl $dlg 210
    if ($f -ne [IntPtr]::Zero) { $res.Target = [Drv098f]::GetText($f, 5000) }
    Click-Ok $dlg
    $seen = @{}; $idleSince = $null
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 120) {
        if (-not (Test-Alive $Id)) { $res.Fatal = 'the program ended'; break }
        $wins = @(Get-Tops $Id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })
        if (-not $wins.Count) {
            if ($null -eq $idleSince) { $idleSince = $sw.Elapsed.TotalSeconds }
            if ($sw.Elapsed.TotalSeconds - $idleSince -gt 2.5 -and [Drv098f]::IsWindowEnabled((Get-Main $Id))) { break }
            Start-Sleep -Milliseconds 150; continue
        }
        $idleSince = $null
        foreach ($h in $wins) {
            if (-not [Drv098f]::IsWindow($h)) { continue }
            $d = WinDesc $h
            if ($d -match $FatalRx) { $res.Fatal = $d; return $res }
            if (-not [Drv098f]::IsWindowEnabled($h)) { continue }
            $key = $h.ToInt64()
            if (-not $seen.ContainsKey($key)) { $seen[$key] = $sw.Elapsed.TotalSeconds; continue }
            if ($sw.Elapsed.TotalSeconds - [double]$seen[$key] -lt 0.6) { continue }
            $ed = Kid $h 1301 'Edit'; $all = Kid $h 1302 'Button'
            if ($ed -and $all) {
                $t = [Drv098f]::GetText($ed, 5000)
                [void]$res.Prompts.Add($t)
                $new = $CCaron; if ($t.Length -gt 1) { $new = $CCaron + $t.Substring(1) }
                [void][Drv098f]::SetText($ed, $new, 5000)
                [void]$res.Answered.Add($new)
                if ($res.Prompts.Count -eq 1) { Click $all } else { Click (Kid $h 1 'Button') }
                $seen.Remove($key); Start-Sleep -Milliseconds 700; continue
            }
            $btn = Buttons $h
            $ids = @($btn | ForEach-Object { [Drv098f]::GetDlgCtrlID($_) })
            if (($ids.Count -eq 1 -and $ids[0] -eq 2) -or ($ids.Count -eq 0)) { continue }   # progress
            [void]$res.Boxes.Add($d)
            $pick = $null
            foreach ($w in @(173, 6, 1)) { $pick = $btn | Where-Object { [Drv098f]::GetDlgCtrlID($_) -eq $w } | Select-Object -First 1; if ($pick) { break } }   # Skip (IDB_SKIP), Yes, OK
            if ($pick) { Click $pick } else { Close-Win $h }
            $seen.Remove($key); Start-Sleep -Milliseconds 600
        }
        Start-Sleep -Milliseconds 150
    }
    return $res
}

function Run-Image([string]$Case, [string]$ImageFile, $Exp) {
    $out = $Root + '\out_' + $Case; NewDir $out
    $id = 0; $before = Reports
    try {
        $id = Start-P $StartDir $out
        $o = Open-Deleted $id ($ImgDir + '\' + $ImageFile)
        Row $Case 'OPEN' (V $o.Ok) ("{0}: {1}" -f $o.How, $o.Facts)
        if (-not $o.Ok) { return }
        $r = Restore-All $id
        if ($r.Fatal) { Row $Case 'COPY' 'FAIL' ('FATAL ' + $r.Fatal + '; prompts ' + (($r.Prompts | ForEach-Object { Esc $_ }) -join ', ')); return }
        $map = Folder-Map $out
        $expNames = New-Object System.Collections.Hashtable ([StringComparer]::Ordinal)
        foreach ($e in $Exp.files) {
            $name = Units $e.units
            $expNames[$name] = $true
            $got = $null; if ($map.ContainsKey($name)) { $got = $map[$name] }
            $ok = ($null -ne $got) -and ($got -ceq $e.content)
            if ($Fixed) { $v = V $ok } else { $v = V ($ok -ne [bool]$e.defect_before) }
            $how = 'missing'; if ($null -ne $got) { if ($got -ceq $e.content) { $how = 'restored, content equal' } else { $how = 'restored, CONTENT DIFFERS' } }
            Row $Case $e.tag $v ("'{0}': {1}{2}" -f (Esc $name), $how, $(if (-not $Fixed) { '; the build before is expected to ' + $(if ($e.defect_before) { 'get it wrong' } else { 'get it right' }) } else { '' }))
        }
        $extra = @($map.Keys | Where-Object { -not $expNames.ContainsKey($_) } | Sort-Object)
        if ($Fixed) { $v = V ($extra.Count -eq 0) } else { $v = 'INFO' }
        Row $Case 'EXTRA' $v ("{0} file(s) not expected: {1}" -f $extra.Count, (($extra | ForEach-Object { "'" + (Esc $_) + "'" }) -join ', '))
        $expPrompts = @($Exp.prompts | ForEach-Object { Units $_ })
        $pr = @($r.Prompts)
        if ($expPrompts.Count -eq 0) {
            if ($Fixed) { $v = V ($pr.Count -eq 0) } else { $v = V ($pr.Count -gt 0) }
        }
        else {
            # the build of 114: one prompt, for the first damaged name in the restore order ($91D~1.TXT), All answers the rest
            $first = @($expPrompts | Sort-Object)[0]
            if ($Fixed) { $v = V ($pr.Count -eq 1 -and $pr[0] -ceq $first) } else { $v = V ($pr.Count -gt 1) }
        }
        Row $Case 'PROMPTS' $v ("Damaged Filename dialogs: {0} [{1}]; answered [{2}]; copy target '{3}'; other boxes: {4}" -f $pr.Count, (($pr | ForEach-Object { "'" + (Esc $_) + "'" }) -join ', '), (($r.Answered | ForEach-Object { Esc $_ }) -join ', '), (Tail $r.Target 40), $(if ($r.Boxes.Count) { $r.Boxes -join ' || ' } else { 'none' }))
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# two deleted files of one 110-character CJK name (334 bytes): restoring both numbers them
# (CFileList::RenameDuplicateFiles -> AddNumberSuffix), which wrote the name into a MAX_PATH + 50
# stack buffer; the target path is then too long for the plug-in's MAX_PATH buffers, so the build of
# 114 says "Target path is too long" twice (Skip) and restores nothing
function Run-Dup($Exp) {
    $Case = 'dup'
    $out = $Root + '\out_' + $Case; NewDir $out
    $id = 0; $before = Reports
    try {
        $id = Start-P $StartDir $out
        $o = Open-Deleted $id ($ImgDir + '\exfatdup114.ima')
        Row $Case 'OPEN' (V $o.Ok) ("{0}: {1}" -f $o.How, $o.Facts)
        if (-not $o.Ok) { return }
        $r = Restore-All $id
        $map = Folder-Map $out
        $tooLong = @($r.Boxes | Where-Object { $_ -match 'too long' }).Count
        $facts = ("{0}-byte name twice: fatal {1}; boxes {2} ('too long' {3}): {4}; files restored {5}" -f $Exp.name_bytes, $(if ($r.Fatal) { Esc $r.Fatal } else { 'none' }), $r.Boxes.Count, $tooLong, $(if ($r.Boxes.Count) { (($r.Boxes | ForEach-Object { Tail $_ 90 }) -join ' || ') } else { '-' }), $map.Count)
        if ($Fixed) { $v = V ((-not $r.Fatal) -and $tooLong -eq 2 -and $map.Count -eq 0) } else { $v = V ([bool]$r.Fatal) }
        Row $Case 'NUMBER' $v $facts
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-P $Case $id $before } }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc114_un_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir; NewDir $ImgDir
    $gen = & $Python (Join-Path $PSScriptRoot 'make_images.py') $ImgDir 2>&1
    $exp = Get-Content -LiteralPath ($ImgDir + '\expected.json') -Raw | ConvertFrom-Json
    Set-Config
    Out ("undelnames_probe (feature 114), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; ACP {1}; OEM {2} (images made for OEM {3}); desktop '{4}'; registry key existed {5}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [Drv098f]::GetACP(), [Desk114]::GetOEMCP(), $exp.oemcp, $deskName, $existed)
    Out ("Images  : {0}" -f (($gen | ForEach-Object { '' + $_ }) -join ' '))
    Out ''
    if (Want 'fat') { Run-Image 'fat' 'fat114.ima' $exp.fat }
    if (Want 'exfat') { Run-Image 'exfat' 'exfat114.ima' $exp.exfat }
    if (Want 'dup') { Run-Dup $exp.dup }
    if (-not $Only) {
        foreach ($nd in @('NTFS: no NTFS image can be made without admin rights or a formatter; the NTFS names take the same fixed listing / restore path (fs2.cpp) and the WTF-8 conversion (miscstr.cpp)',
                          'volume mount points: mountvol / SetVolumeMountPoint need admin rights; the W volume layer is verified by code reading and saltests (SalVolumePathsWToU8 / SalVolumePathWToU8)',
                          'the connect dialog volume list (LVM_*W): reading another process list view needs remote memory; see quickstart.md for the person step',
                          'Restore Encrypted Files (EFS backups): needs EFS-encrypted deleted files')) { Row 'nd' 'ROUTE' 'NOT DRIVEN' $nd }
    }
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
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, $leftover.Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
