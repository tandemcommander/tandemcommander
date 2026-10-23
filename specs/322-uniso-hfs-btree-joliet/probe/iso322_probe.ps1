<#
.SYNOPSIS
    Feature 322: valid disk images open in the ISO plug-in and a file is extracted under its whole
    name with its content - Joliet (IMAPI2) with ASCII and CJK names, Rock Ridge, plain ISO 9660,
    HFS+ alone and an ISO 9660 + HFS+ hybrid (xorriso 1.5.6 in WSL, probe\mkimg322.sh).

.DESCRIPTION
      J-ASCII   IMAPI2 image of top.txt: End, F5 (727) to the other panel - PASS = top.txt with 'TOP'
      J-CJK12   IMAPI2 image of one file named 12 CJK letters + '.txt': End, F5 - PASS = extracted
                under exactly that name with its content (before 322: the name cut)
      J-CJK40   the same with 40 CJK letters
      RR        xorriso ISO 9660 + Rock Ridge (rr.iso): End focuses top.txt, F5
      PLAIN     xorriso ISO 9660 only (plain.iso): End, F5 - TOP.TXT with 'TOP'
      RR-LONG   xorriso Rock Ridge image of a 200-letter name (rrlong.iso): End, F5 - PASS = the file
                extracted with its content; whether the Rock Ridge name was used is recorded
                (xorriso writes no 'RR' entry; the plug-in then lists the ISO 9660 name, also before 322)
      HFS       the HFS+ partition of hyb.iso alone: the volume folder TC322 (End, Enter), End
                focuses top.txt, F5 - PASS = top.txt with 'TOP'
      HYB       hyb.iso (ISO 9660 + Rock Ridge + Joliet + HFS+): opens, the program stays alive (the
                messages at the open are recorded)
    Every row also fails on a program exit, a bug report, a fatal window, or a main window that does
    not answer within 30 s (End-Row). The xorriso rows are NOT DRIVEN without WSL Ubuntu.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.
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
$Root = $TempRoot + '\tc322'
$StartDir = $Root + '\start'

if (-not ('Iso322' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class Iso322
{
    // copies the IMAPI2 result stream (an IStream) into a file
    public static void Save(object stream, string path)
    {
        IStream s = (IStream)stream;
        using (FileStream f = File.Create(path))
        {
            byte[] buf = new byte[65536];
            IntPtr readPtr = Marshal.AllocCoTaskMem(4);
            try
            {
                while (true)
                {
                    s.Read(buf, buf.Length, readPtr);
                    int n = Marshal.ReadInt32(readPtr);
                    if (n <= 0) break;
                    f.Write(buf, 0, n);
                }
            }
            finally { Marshal.FreeCoTaskMem(readPtr); }
        }
    }
}
'@
}

function Make-Joliet([string]$SrcDir, [string]$IsoPath) {
    $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
    $fsi.FileSystemsToCreate = 3   # ISO 9660 + Joliet
    $fsi.VolumeName = 'TC322'
    $fsi.Root.AddTree($SrcDir, $false)
    $res = $fsi.CreateResultImage()
    [Iso322]::Save($res.ImageStream, $IsoPath)
}
function Cjk([int]$n) { return (-join (0..($n - 1) | ForEach-Object { [string][char](0x4E00 + 7 * $_) })) }
function WslPath([string]$p) { return ('/mnt/' + $p.Substring(0, 1).ToLower() + $p.Substring(2).Replace('\', '/')) }

# opens $Image in the left panel, runs $Keys (virtual keys) then F5 to $Tgt; returns the messages
function Extract-Row([string]$Case, [string]$Image, [string]$Tgt, [int[]]$Keys, [scriptblock]$Check) {
    $id = 0; $before = Reports; $save = $script:StartDir; $script:StartDir = $Tgt
    try {
        $id = Start-Tc $Image; $script:StartDir = $save
        $r0 = Serve $id 6 @(1)
        foreach ($k in $Keys) { Key $id $k; Start-Sleep -Milliseconds 400 }
        Start-Sleep -Milliseconds 500
        Post-Cmd (Get-Main $id) 727
        $r = Serve $id 30 @(1, 6)
        $res = & $Check
        Row $Case 'RUN' (V $res.Ok) ("{0}; at the open: {1}; F5: {2}" -f $res.Facts, (Tail (Msgs $r0) 150), (Tail (Msgs $r) 200))
        End-Row $Case $id $r.Fatal $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { $script:StartDir = $save; if ($id) { End-Row $Case $id $null $before } }
}
function Names([string]$Dir) { return @([IO.Directory]::GetFiles($Dir) | ForEach-Object { [IO.Path]::GetFileName($_) }) }
function Content([string]$Path) { try { return [IO.File]::ReadAllText($Path) } catch { return '<none>' } }

$backup = Join-Path $env:TEMP 'tc322_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso322_probe (feature 322) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    # --- Joliet (IMAPI2) ---
    $d = $Root + '\J-ASCII'; NewDir $d; NewDir "$d\src"; NewDir "$d\tgt"
    [IO.File]::WriteAllText("$d\src\top.txt", 'TOP')
    Make-Joliet "$d\src" "$d\a.iso"
    $tgt = "$d\tgt"
    Extract-Row 'J-ASCII' "$d\a.iso" $tgt @(0x24, 0x23) { $g = Content "$tgt\top.txt"; [pscustomobject]@{ Ok = ($g -ceq 'TOP'); Facts = ("extracted: {0}; content '{1}'" -f ((Names $tgt) -join ','), $g) } }

    foreach ($n in @(12, 40)) {
        $case = "J-CJK$n"; $d = $Root + '\' + $case; NewDir $d; NewDir "$d\src"; NewDir "$d\tgt"
        $name = (Cjk $n) + '.txt'
        [IO.File]::WriteAllText("$d\src\$name", "CJK$n")
        Make-Joliet "$d\src" "$d\a.iso"
        $tgt = "$d\tgt"; $want = $name; $wantC = "CJK$n"
        Extract-Row $case "$d\a.iso" $tgt @(0x24, 0x23) {
            $got = @(Names $tgt)
            $g = Content "$tgt\$want"
            [pscustomobject]@{ Ok = ($got.Count -eq 1 -and $got[0] -ceq $want -and $g -ceq $wantC); Facts = ("want {0} letters + .txt ({1} UTF-8 bytes); extracted names: {2} (UTF-16 lengths {3}); content '{4}'" -f $n, (U8Len $want), (($got | ForEach-Object { Esc $_ }) -join ','), (($got | ForEach-Object { $_.Length }) -join ','), $g) }
        }
    }

    # --- xorriso seeds (WSL) ---
    $s = $Root + '\seeds'; NewDir $s
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath (Join-Path $PSScriptRoot 'mkimg322.sh')) (WslPath $s) 2>&1
    $ErrorActionPreference = $old
    if (-not [IO.File]::Exists("$s\hyb.iso")) {
        foreach ($c in @('RR', 'PLAIN', 'RR-LONG', 'HFS', 'HYB')) { Row $c 'RUN' 'NOT DRIVEN' ('no xorriso image: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    }
    else {
        # the HFS+ partition alone: the bytes from the Apple_HFS partition start (block 60 of 2048 bytes)
        $hy = [IO.File]::ReadAllBytes("$s\hyb.iso")
        $vh = 60 * 2048 + 1024
        $hfsOk = ($hy[0] -eq 0x45 -and $hy[1] -eq 0x52 -and $hy[$vh] -eq 0x48 -and $hy[$vh + 1] -eq 0x2B)
        Out ("seeds: {0}; HFS+ volume header at {1}: {2}" -f (((Names $s) | Sort-Object) -join ','), $vh, $hfsOk)
        if ($hfsOk) { [IO.File]::WriteAllBytes("$s\hfs.iso", $hy[(60 * 2048)..($hy.Length - 1)]) }

        foreach ($c in @(@('RR', 'rr.iso', 'top.txt'), @('PLAIN', 'plain.iso', 'TOP.TXT'))) {
            $case = $c[0]; $d = $Root + '\' + $case; NewDir $d; NewDir "$d\tgt"; $tgt = "$d\tgt"; $want = $c[2]
            Extract-Row $case "$s\$($c[1])" $tgt @(0x24, 0x23) { $g = Content "$tgt\$want"; [pscustomobject]@{ Ok = ($g -ceq 'TOP'); Facts = ("extracted: {0}; content of {1} '{2}'" -f ((Names $tgt) -join ','), $want, $g) } }
        }
        $d = $Root + '\RR-LONG'; NewDir $d; NewDir "$d\tgt"; $tgt = "$d\tgt"; $long = 'z' + ('r' * 195) + '.txt'
        # the plug-in reads Rock Ridge only with an 'RR' entry (genisoimage writes it; xorriso's RRIP 1.12
        # does not - also before 322, an Inbox item): the file must come out whole under the name it lists
        Extract-Row 'RR-LONG' "$s\rrlong.iso" $tgt @(0x24, 0x23) { $got = @(Names $tgt); $g = '<none>'; if ($got.Count -eq 1) { $g = Content ($tgt + '\' + $got[0]) }; [pscustomobject]@{ Ok = ($got.Count -eq 1 -and $g -ceq 'LONG'); Facts = ("one file extracted with its content {0}; the Rock Ridge name used {1}; extracted name lengths: {2}" -f ($g -ceq 'LONG'), ($got.Count -eq 1 -and $got[0] -ceq $long), (($got | ForEach-Object { $_.Length }) -join ',')) } }
        if (-not $hfsOk) { Row 'HFS' 'RUN' 'NOT DRIVEN' 'the hybrid seed has another layout than measured' }
        else {
            $d = $Root + '\HFS'; NewDir $d; NewDir "$d\tgt"; $tgt = "$d\tgt"
            Extract-Row 'HFS' "$s\hfs.iso" $tgt @(0x24, 0x23, 0x0D, 0x24, 0x23) { $g = Content "$tgt\top.txt"; [pscustomobject]@{ Ok = ($g -ceq 'TOP'); Facts = ("extracted: {0}; content '{1}'" -f ((Names $tgt) -join ','), $g) } }
        }
        $id = 0; $before = Reports
        try {
            $id = Start-Tc "$s\hyb.iso"
            $r0 = Serve $id 8 @(1)
            # the open shows the Xbox reader's "Cannot read sector #00000020." on this image also
            # before 322 (xdvdfs.cpp - another reader; an Inbox item): recorded, not a verdict here
            Row 'HYB' 'RUN' (V (-not $r0.Died -and -not $r0.Fatal)) ("location '{0}'; at the open: {1}" -f (Tail (Get-Loc $id) 60), (Tail (Msgs $r0) 200))
            End-Row 'HYB' $id $r0.Fatal $before; $id = 0
        }
        catch { Row 'HYB' 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
        finally { if ($id) { End-Row 'HYB' $id $null $before } }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
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
