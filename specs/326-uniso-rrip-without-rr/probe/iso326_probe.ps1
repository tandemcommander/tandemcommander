<#
.SYNOPSIS
    Feature 326: the ISO plug-in reads Rock Ridge names of images without an 'RR' entry (xorriso,
    RRIP 1.12 - the volume is recognised by the SUSP 'SP' entry of the root's '.' record); images
    whose records start with 'RR', plain ISO 9660 and Joliet keep their names.

.DESCRIPTION
      RR         xorriso ISO 9660 + Rock Ridge (rr.iso): End focuses top.txt, F5 (727) to the other
                 panel - PASS = extracted under exactly 'top.txt' with 'TOP' (before 326: TOP.TXT)
      RR-DIR     rr.iso: Home, Down focuses the folder, F5 - PASS = 'folder\note.txt' (exact case)
      RR-LONG    rrlong.iso (one file of a 200-letter Rock Ridge name, continued in a CE area): End,
                 F5 - PASS = exactly that name with 'LONG' (before 326: 31 upper-case letters)
      OLDRR      oldrr.iso (xorriso -compliance old_rr): End, F5 - PASS = 'top.txt'
      LEGACY-RR  a copy of rr.iso patched by the probe: the root's SP check bytes broken (no SUSP on
                 the volume) and top.txt's first System Use entry PX renamed RR (as genisoimage
                 starts every record) - End, F5 - PASS = 'top.txt' (the 'RR' path, as before 326)
      LEGACY-DIR the same patched image: Home, Down, F5 - PASS = 'FOLDER' (no RR, no SP: the plain
                 ISO 9660 name, as before 326)
      SEMI       semi.iso (one file named 'semi;colon.txt'): End, F5 - PASS = exactly that name (a ';' in
                 a Rock Ridge name is not the ISO 9660 version suffix)
      PLAIN      plain.iso (no Rock Ridge): End, F5 - PASS = 'TOP.TXT' with 'TOP'
      J-ASCII    IMAPI2 ISO 9660 + Joliet image of top.txt: End, F5 - PASS = 'top.txt'
    Names are compared case-sensitively. Every row also fails on a program exit, a bug report, a
    fatal window, or a main window that does not answer within 30 s (End-Row). The xorriso rows are
    NOT DRIVEN without WSL Ubuntu (probe\mkimg326.sh).
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
$Root = $TempRoot + '\tc326'
$StartDir = $Root + '\start'

if (-not ('Iso326' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class Iso326
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
    $fsi.VolumeName = 'TC326'
    $fsi.Root.AddTree($SrcDir, $false)
    $res = $fsi.CreateResultImage()
    [Iso326]::Save($res.ImageStream, $IsoPath)
}
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
function Dirs([string]$Dir) { return @([IO.Directory]::GetDirectories($Dir) | ForEach-Object { [IO.Path]::GetFileName($_) }) }
function Content([string]$Path) { try { return [IO.File]::ReadAllText($Path) } catch { return '<none>' } }
function Le32($b, [long]$o) { return [long]$b[$o] -bor ([long]$b[$o + 1] -shl 8) -bor ([long]$b[$o + 2] -shl 16) -bor ([long]$b[$o + 3] -shl 24) }
function Ascii($b, [long]$o, [int]$n) { return [Text.Encoding]::ASCII.GetString($b, $o, $n) }

# a copy of rr.iso as genisoimage-like legacy: the root's SP check bytes broken, top.txt's first
# System Use entry renamed RR; returns a description, $null when the layout is not the measured one
function Make-Legacy([string]$Src, [string]$Dst) {
    $b = [IO.File]::ReadAllBytes($Src)
    $pvd = 16 * 2048
    if ($b[$pvd] -ne 1 -or (Ascii $b ($pvd + 1) 5) -cne 'CD001') { return $null }
    $dir = (Le32 $b ($pvd + 156 + 2)) * 2048
    # the '.' record: identifier length 1 -> its System Use area at 34
    if ($b[$dir + 32] -ne 1 -or (Ascii $b ($dir + 34) 2) -cne 'SP' -or $b[$dir + 38] -ne 0xBE -or $b[$dir + 39] -ne 0xEF) { return $null }
    $b[$dir + 38] = 0; $b[$dir + 39] = 0
    $o = $dir; $done = $false
    while ($o -lt $dir + 2048 -and $b[$o] -ne 0) {
        $fil = $b[$o + 32]
        if ($fil -eq 9 -and (Ascii $b ($o + 33) 9) -ceq 'TOP.TXT;1') {
            $su = $o + 33 + $fil   # odd length: no padding byte
            if ((Ascii $b $su 2) -cne 'PX') { return $null }
            $b[$su] = [byte][char]'R'; $b[$su + 1] = [byte][char]'R'; $done = $true
        }
        $o += $b[$o]
    }
    if (-not $done) { return $null }
    [IO.File]::WriteAllBytes($Dst, $b)
    return ("root directory at {0}: SP check bytes cleared, TOP.TXT;1 first entry PX -> RR" -f $dir)
}

$backup = Join-Path $env:TEMP 'tc326_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso326_probe (feature 326) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''

    # --- xorriso seeds (WSL) ---
    $s = $Root + '\seeds'; NewDir $s
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath (Join-Path $PSScriptRoot 'mkimg326.sh')) (WslPath $s) 2>&1
    $ErrorActionPreference = $old
    if (-not [IO.File]::Exists("$s\rr.iso")) {
        foreach ($c in @('RR', 'RR-DIR', 'RR-LONG', 'SEMI', 'OLDRR', 'LEGACY-RR', 'LEGACY-DIR', 'PLAIN')) { Row $c 'RUN' 'NOT DRIVEN' ('no xorriso image: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    }
    else {
        $legacy = Make-Legacy "$s\rr.iso" "$s\legacy.iso"
        Out ("seeds: {0}; legacy.iso: {1}" -f (((Names $s) | Sort-Object) -join ','), $legacy)

        foreach ($c in @(@('RR', 'rr.iso', 'top.txt'), @('OLDRR', 'oldrr.iso', 'top.txt'), @('PLAIN', 'plain.iso', 'TOP.TXT'), @('LEGACY-RR', 'legacy.iso', 'top.txt'))) {
            $case = $c[0]; $want = $c[2]
            if (-not [IO.File]::Exists("$s\$($c[1])")) { Row $case 'RUN' 'NOT DRIVEN' ("no {0}" -f $c[1]); continue }
            $d = $Root + '\' + $case; NewDir $d; NewDir "$d\tgt"; $tgt = "$d\tgt"
            Extract-Row $case "$s\$($c[1])" $tgt @(0x24, 0x23) { $got = @(Names $tgt); $g = Content "$tgt\$want"; [pscustomobject]@{ Ok = ($got.Count -eq 1 -and $got[0] -ceq $want -and $g -ceq 'TOP'); Facts = ("want '{0}'; extracted: {1}; content '{2}'" -f $want, ($got -join ','), $g) } }
        }
        foreach ($c in @(@('RR-DIR', 'rr.iso', 'folder'), @('LEGACY-DIR', 'legacy.iso', 'FOLDER'))) {
            $case = $c[0]; $want = $c[2]
            if (-not [IO.File]::Exists("$s\$($c[1])")) { Row $case 'RUN' 'NOT DRIVEN' ("no {0}" -f $c[1]); continue }
            $d = $Root + '\' + $case; NewDir $d; NewDir "$d\tgt"; $tgt = "$d\tgt"
            Extract-Row $case "$s\$($c[1])" $tgt @(0x24, 0x28) {
                $got = @(Dirs $tgt); $inner = @(); $g = '<none>'
                if ($got.Count -eq 1) { $inner = @(Names ($tgt + '\' + $got[0])); $g = Content ($tgt + '\' + $got[0] + '\note.txt') }
                $wantInner = 'note.txt'; if ($want -ceq 'FOLDER') { $wantInner = 'NOTE.TXT' }
                [pscustomobject]@{ Ok = ($got.Count -eq 1 -and $got[0] -ceq $want -and $inner.Count -eq 1 -and $inner[0] -ceq $wantInner -and $g -ceq 'NOTE'); Facts = ("want '{0}\{1}'; extracted folders: {2}; inside: {3}; content '{4}'" -f $want, $wantInner, ($got -join ','), ($inner -join ','), $g) }
            }
        }
        $d = $Root + '\RR-LONG'; NewDir $d; NewDir "$d\tgt"; $tgt = "$d\tgt"; $long = 'z' + ('r' * 195) + '.txt'
        Extract-Row 'RR-LONG' "$s\rrlong.iso" $tgt @(0x24, 0x23) { $got = @(Names $tgt); $g = '<none>'; if ($got.Count -eq 1) { $g = Content ($tgt + '\' + $got[0]) }; [pscustomobject]@{ Ok = ($got.Count -eq 1 -and $got[0] -ceq $long -and $g -ceq 'LONG'); Facts = ("the Rock Ridge name used {0}; content '{1}'; extracted name lengths: {2}" -f ($got.Count -eq 1 -and $got[0] -ceq $long), $g, (($got | ForEach-Object { $_.Length }) -join ',')) } }
        if (-not [IO.File]::Exists("$s\semi.iso")) { Row 'SEMI' 'RUN' 'NOT DRIVEN' 'no semi.iso' }
        else {
            $d = $Root + '\SEMI'; NewDir $d; NewDir "$d\tgt"; $tgt = "$d\tgt"; $semi = 'semi;colon.txt'
            Extract-Row 'SEMI' "$s\semi.iso" $tgt @(0x24, 0x23) { $got = @(Names $tgt); $g = '<none>'; if ($got.Count -eq 1) { $g = Content ($tgt + '\' + $got[0]) }; [pscustomobject]@{ Ok = ($got.Count -eq 1 -and $got[0] -ceq $semi -and $g -ceq 'SEMI'); Facts = ("want '{0}'; extracted: {1}; content '{2}'" -f $semi, ($got -join ','), $g) } }
        }
    }

    # --- Joliet (IMAPI2) ---
    $d = $Root + '\J-ASCII'; NewDir $d; NewDir "$d\src"; NewDir "$d\tgt"
    [IO.File]::WriteAllText("$d\src\top.txt", 'TOP')
    Make-Joliet "$d\src" "$d\a.iso"
    $tgt = "$d\tgt"
    Extract-Row 'J-ASCII' "$d\a.iso" $tgt @(0x24, 0x23) { $got = @(Names $tgt); $g = Content "$tgt\top.txt"; [pscustomobject]@{ Ok = ($got.Count -eq 1 -and $got[0] -ceq 'top.txt' -and $g -ceq 'TOP'); Facts = ("extracted: {0}; content '{1}'" -f ($got -join ','), $g) } }
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
