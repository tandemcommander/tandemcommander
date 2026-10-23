<#
.SYNOPSIS
    Feature 327: every name the ISO plug-in lists - ISO 9660, Joliet, UDF, HFS+, Xbox (XDVDFS) and
    the volume label folders of a hybrid - is made safe before extraction (feature 087's rule).

.DESCRIPTION
    Each set is one crafted image holding a folder 'set' (or 'SET') with names Windows must not take
    as they are: a name with '..\..\' (would be written two levels up), '12:30...' (an NTFS stream),
    'con...' (a device name), a trailing dot, a '/' inside the name, a folder '..\..\<x>' holding
    inner.txt, and a plain top.txt (control). The probe focuses the folder (Home, Down; VOL: End),
    F5 (727) to the other panel, then checks below the extracted 'set' folder:
      <SET> <name>   PASS = the safe name exists with its content (a '\' '/' ':' -> '_', a trailing
                     dot -> '_', a device name gets a '_' prefix)
      <SET> OUTSIDE  PASS = no file was written outside the extracted 'set' folder
      <SET> STREAMS  PASS = no extracted file carries an alternate data stream
      <SET> END      the program ends normally (no report, no fatal window)
    Sets: PLAIN (ISO 9660 identifiers, xorriso -rockridge off -joliet off, patched by img327.py),
    JOLIET (IMAPI2 ISO 9660 + Joliet, patched), UDF (IMAPI2 UDF, patched), XBOX (built by img327.py),
    HFS (xorriso ISO 9660 + Rock Ridge + HFS+ hybrid with the Linux names; the folder 'HFS (...)' is
    extracted), VOL (the same hybrid, its primary volume identifier patched to 'v\..\..\w': the folder
    'ISO (v_.._.._w)' must hold the set). PLAIN, HFS and VOL are NOT DRIVEN without WSL Ubuntu.
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
$Root = $TempRoot + '\tc327'
$StartDir = $Root + '\start'
$Img = Join-Path $PSScriptRoot 'img327.py'

if (-not ('Iso327' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
public static class Iso327
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

# $Kinds: 3 = ISO 9660 + Joliet, 4 = UDF
function Make-Imapi([string]$SrcDir, [string]$IsoPath, [int]$Kinds) {
    $fsi = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
    $fsi.FileSystemsToCreate = $Kinds
    $fsi.VolumeName = 'TC327'
    $fsi.Root.AddTree($SrcDir, $false)
    $res = $fsi.CreateResultImage()
    [Iso327]::Save($res.ImageStream, $IsoPath)
}
function WslPath([string]$p) { return ('/mnt/' + $p.Substring(0, 1).ToLower() + $p.Substring(2).Replace('\', '/')) }
function RunPy([string[]]$PyArgs) {
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & python -I $Img @PyArgs 2>&1
    $code = $LASTEXITCODE
    $ErrorActionPreference = $old
    Out ('img327.py {0}: exit {1}: {2}' -f $PyArgs[0], $code, (($o | ForEach-Object { "$_" }) -join '; '))
    return ($code -eq 0)
}
function Src-Unicode([string]$Dir, [string]$Tag) {
    NewDir "$Dir\set\jfolderx"
    WriteFile "$Dir\set\jjjjjjjjjj.txt" ($Tag + 'ESC')
    WriteFile "$Dir\set\jcolonaaa.txt" ($Tag + 'COLON')
    WriteFile "$Dir\set\jdevaaa.txt" ($Tag + 'DEV')
    WriteFile "$Dir\set\jtdotaaaa.txt" ($Tag + 'TDOT')
    WriteFile "$Dir\set\jslashaa.txt" ($Tag + 'SLASH')
    WriteFile "$Dir\set\jfolderx\inner.txt" 'INNER'
    WriteFile "$Dir\set\top.txt" 'TOP'
}
# every file below $Dir (long-path safe), as paths relative to $Dir
function Files-Under([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return @() }
    return @([IO.Directory]::GetFiles($LP + $Dir, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($LP.Length + $Dir.Length + 1) })
}
function Clear-ReadOnly([string]$Dir) {
    if (-not [IO.Directory]::Exists($LP + $Dir)) { return }
    foreach ($f in [IO.Directory]::GetFiles($LP + $Dir, '*', [IO.SearchOption]::AllDirectories)) { try { [IO.File]::SetAttributes($f, [IO.FileAttributes]::Normal) } catch { } }
}

# opens $Image, runs $Keys, F5 to $d\tgt; then the rows of the set: $Base is the extracted 'set'
# folder relative to tgt, $Want maps a name relative to it to its content
function Extract-Set([string]$Case, [string]$Image, [int[]]$Keys, [string]$Base, [hashtable]$Want) {
    $d = $Root + '\' + $Case; NewDir $d; $tgt = "$d\tgt"; NewDir $tgt
    $id = 0; $before = Reports; $save = $script:StartDir; $script:StartDir = $tgt
    try {
        $id = Start-Tc $Image; $script:StartDir = $save
        $r0 = Serve $id 6 @(1)
        foreach ($k in $Keys) { Key $id $k; Start-Sleep -Milliseconds 400 }
        Start-Sleep -Milliseconds 500
        Post-Cmd (Get-Main $id) 727
        # an "Error Creating File" box (a name Windows refuses) is answered Skip (173): every name is tried
        $r = Serve $id 40 @(1, 6, 173)
        $all = @(Files-Under $d)
        Out ("{0}: at the open: {1}; F5: {2}" -f $Case, (Tail (Msgs $r0) 200), (Tail (Msgs $r) 300))
        Out ("{0}: extracted below the row folder: {1}" -f $Case, (($all | ForEach-Object { Esc $_ }) -join ' | '))
        $baseRel = 'tgt\' + $Base
        foreach ($n in ($Want.Keys | Sort-Object)) {
            $p = "$d\$baseRel\$n"; $got = '<none>'
            if ([IO.File]::Exists($LP + $p)) { $got = [IO.File]::ReadAllText($LP + $p) }
            Row ("{0} {1}" -f $Case, $n) 'NAME' (V ($got -ceq $Want[$n] -and ($all -ccontains "$baseRel\$n"))) ("want '{0}' with '{1}'; content '{2}'" -f (Esc "$Base\$n"), $Want[$n], $got)
        }
        $out = @($all | Where-Object { -not $_.StartsWith($baseRel + '\', [StringComparison]::Ordinal) })
        Row "$Case OUTSIDE" 'CHECK' (V ($out.Count -eq 0 -and $all.Count -gt 0)) ("files outside '{0}': {1}" -f (Esc $Base), $(if ($out.Count) { ($out | ForEach-Object { Esc $_ }) -join ' | ' } else { 'none' }))
        $streams = @()
        foreach ($f in $all) {
            try { $streams += @(Get-Item -LiteralPath ($LP + "$d\$f") -Stream * -ErrorAction Stop | Where-Object { $_.Stream -ne ':$DATA' } | ForEach-Object { (Esc $f) + ':' + $_.Stream }) } catch { }
        }
        Row "$Case STREAMS" 'CHECK' (V ($streams.Count -eq 0)) ("alternate streams: {0}" -f $(if ($streams.Count) { $streams -join ' | ' } else { 'none' }))
        End-Row $Case $id $r.Fatal $before; $id = 0
    }
    catch { Row $Case 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { $script:StartDir = $save; if ($id) { End-Row $Case $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc327_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { Clear-ReadOnly $Root; [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("iso327_probe (feature 327) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed)
    Out ''
    $s = $Root + '\seeds'; NewDir $s
    $uni = @{ '.._.._jesc.txt' = 'ESC'; '12_30jaaa.txt' = 'COLON'; '_con.txtjaaa' = 'DEV'; 'jtrailaaaaa__' = 'TDOT'; 'j_slasha.txt' = 'SLASH'; '.._.._jd\inner.txt' = 'INNER'; 'top.txt' = 'TOP' }

    # --- Joliet and UDF (IMAPI2) ---
    foreach ($c in @(@('JOLIET', 3, 'joliet', 'J'), @('UDF', 4, 'udf', 'U'))) {
        $case = $c[0]; $src = "$s\src$case"
        Src-Unicode $src $c[3]
        Make-Imapi $src "$s\$case.raw.iso" $c[1]
        if (-not (RunPy @('patch', "$s\$case.raw.iso", "$s\$case.iso", $c[2]))) { Row $case 'RUN' 'NOT DRIVEN' 'a placeholder was not found in the IMAPI2 image'; continue }
        $want = @{}; foreach ($k in $uni.Keys) { $v = $uni[$k]; if ($v -ne 'INNER' -and $v -ne 'TOP') { $v = $c[3] + $v }; $want[$k] = $v }
        Extract-Set $case "$s\$case.iso" @(0x24, 0x28) 'set' $want
    }

    # --- Xbox (built) ---
    if (RunPy @('xbox', "$s\xbox.iso")) {
        Extract-Set 'XBOX' "$s\xbox.iso" @(0x24, 0x28) 'set' @{ '.._.._xesc.txt' = 'XESC'; '12_30x.txt' = 'XCOLON'; '_con.txt' = 'XDEV'; 'xtrail_' = 'XTDOT'; 'x_slash.txt' = 'XSLASH'; '.._.._xd\inner.txt' = 'INNER'; 'top.txt' = 'TOP' }
    }
    else { Row 'XBOX' 'RUN' 'NOT DRIVEN' 'img327.py xbox failed' }

    # --- xorriso seeds (WSL): plain ISO 9660, ISO 9660 + Rock Ridge + HFS+ hybrid ---
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $mk = & wsl -d Ubuntu -- sh (WslPath (Join-Path $PSScriptRoot 'mkimg327.sh')) (WslPath $s) 2>&1
    $ErrorActionPreference = $old
    if (-not [IO.File]::Exists("$s\plain0.iso") -or -not [IO.File]::Exists("$s\hfs.iso")) {
        foreach ($c in @('PLAIN', 'HFS', 'VOL')) { Row $c 'RUN' 'NOT DRIVEN' ('no xorriso image: ' + (($mk | ForEach-Object { "$_" }) -join ' ')) }
    }
    else {
        if (RunPy @('patch', "$s\plain0.iso", "$s\plain.iso", 'plain')) {
            Extract-Set 'PLAIN' "$s\plain.iso" @(0x24, 0x28) 'SET' @{ '.._.._ESC1.T' = 'PESC'; '12_30AAA.TXT' = 'PCOLON'; '_CON.TXTAAAAA' = 'PDEV'; 'TRAILAAAAA__' = 'PTDOT'; '1_2FFFFF.TXT' = 'PSLASH'; '.._.._D\INNER.TXT' = 'INNER'; 'TOP.TXT' = 'TOP' }
        }
        else { Row 'PLAIN' 'RUN' 'NOT DRIVEN' 'a placeholder was not found in plain0.iso' }
        $hfs = @{ '.._.._hesc.txt' = 'HESC'; '12_30h.txt' = 'HCOLON'; '_con.txt' = 'HDEV'; 'htrail_' = 'HTDOT'; '.._.._hd\inner.txt' = 'INNER'; 'top.txt' = 'TOP' }
        Extract-Set 'HFS' "$s\hfs.iso" @(0x24, 0x28) 'HFS (TC327)\set' $hfs
        if (RunPy @('vol', "$s\hfs.iso", "$s\vol.iso")) {
            # the Rock Ridge names of the ISO 9660 side (made safe by feature 326) are the same safe names
            Extract-Set 'VOL' "$s\vol.iso" @(0x24, 0x23) 'ISO (v_.._.._w)\set' $hfs
        }
        else { Row 'VOL' 'RUN' 'NOT DRIVEN' 'img327.py vol failed' }
    }
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $Root)) { Clear-ReadOnly $Root; [IO.Directory]::Delete($LP + $Root, $true) } } catch { Out ('Fixture: ' + $_.Exception.Message) }
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $nn = @($script:Rows | Where-Object { $_.Verdict -eq 'NOT DRIVEN' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, NOT DRIVEN {2}. Left running: {3}; fixture removed: {4}; registry restored+identical: {5}" -f $np, $nf, $nn, @($Started | Where-Object { Test-Alive $_ }).Count, (-not [IO.Directory]::Exists($LP + $Root)), $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
