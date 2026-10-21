<#
.SYNOPSIS
    Feature 290 probe: copying a disk file or folder INTO a ZIP archive that holds names differing
    only in case (A.txt / a.txt, folders D / d) replaces only the member of the same exact name -
    the other twin keeps its content. A ZIP without such names asks and replaces as before.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\t.zip written by .NET ZipArchive
    (Windows PowerShell 5.1: "version made by" host 0 = MS-DOS / Windows; the row reports the host
    bytes it found); UNIX rows patch every central header's host byte to 3 (Unix); <row>\src - a
    disk folder with the one item to add (content NEW). The left panel (active) shows src, the
    right panel the archive (or a folder in it). Home, Down focuses the item, Copy (727); the Copy
    dialog OK, every overwrite question Yes (IDYES).
      Every twin row also asserts its overwrite questions: ADDFILE one, the others none.
      ADDDIR    D/x.txt=X, d/y.txt=Y; the right panel at <archive>\d; add x.txt.
                PASS = the archive holds D/x.txt=X, d/x.txt=NEW, d/y.txt=Y
      ADDFILE   A.txt=UPPER, a.txt=lower, z.txt; the right panel at <archive>; add a.txt.
                PASS = A.txt=UPPER, a.txt=NEW, z.txt - and one overwrite question
      ADDFOLDER D/x.txt=X, d/y.txt=Y; the right panel at <archive>; add the folder d (x.txt in it).
                PASS = D/x.txt=X, d/x.txt=NEW, d/y.txt=Y
      NEWNAME   A.txt, a.txt, b.txt=old (twins elsewhere); add B.txt (ZIP only). Known change of
                290: matched by exact name, so B.txt is added beside b.txt without a question.
                PASS = b.txt=old, B.txt=NEW
      CONTROL   README.txt=OLD, z.txt (no twins); add readme.txt. As before 290: one overwrite
                question, one member of that name (in either case) with NEW, z.txt.
                PASS = so; the row reports the stored spelling
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$Lib,
    [string[]]$Only
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

# $PSScriptRoot is empty in a parameter default (PS 5.1, feature 253) - computed here
if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$Root = $TempRoot + '\tc290'
$StartDir = $Root + '\start'

# writes the entries (name -> content, '/'-separated names) into a new ZIP; Unix: host byte 3
function Make-Zip([string]$Zip, [System.Collections.Specialized.OrderedDictionary]$Entries, [bool]$Unix) {
    $fs = [IO.File]::Open($Zip, [IO.FileMode]::CreateNew)
    try {
        $za = New-Object System.IO.Compression.ZipArchive($fs, [System.IO.Compression.ZipArchiveMode]::Create)
        foreach ($k in $Entries.Keys) {
            $e = $za.CreateEntry($k)
            $w = New-Object IO.StreamWriter($e.Open(), (New-Object Text.ASCIIEncoding))
            $w.Write([string]$Entries[$k]); $w.Dispose()
        }
        $za.Dispose()
    }
    finally { $fs.Dispose() }
    $b = [IO.File]::ReadAllBytes($Zip)
    $hosts = New-Object System.Collections.ArrayList
    for ($i = 0; $i + 46 -le $b.Length; $i++) {
        if ($b[$i] -eq 0x50 -and $b[$i + 1] -eq 0x4B -and $b[$i + 2] -eq 1 -and $b[$i + 3] -eq 2) {
            if ($Unix) { $b[$i + 5] = 3 }
            [void]$hosts.Add([int]$b[$i + 5])
        }
    }
    if ($Unix) { [IO.File]::WriteAllBytes($Zip, $b) }
    return ('host ' + (@($hosts | Sort-Object -Unique) -join '/') + ' in ' + $hosts.Count + ' central headers')
}
# the archive's file entries as 'name=content', sorted ordinally (case kept)
function Zip-Content([string]$Zip) {
    $za = [System.IO.Compression.ZipFile]::OpenRead($Zip)
    try {
        $l = New-Object System.Collections.Generic.List[string]
        foreach ($e in $za.Entries) {
            if ($e.FullName.EndsWith('/')) { continue }
            $r = New-Object IO.StreamReader($e.Open())
            $l.Add($e.FullName.Replace('\', '/') + '=' + $r.ReadToEnd()); $r.Dispose()
        }
        $a = $l.ToArray(); [Array]::Sort($a, [StringComparer]::Ordinal)
        return $a
    }
    finally { $za.Dispose() }
}
function Start-Arc([string]$Left, [string]$Right) {
    $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T290', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1') -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 2000
    [void](Serve $p.Id 10)
    return $p.Id
}

function Run-Case([string]$Kind, [string]$Case) {
    $name = $Kind + '-' + $Case
    if (-not (Want $name)) { return }
    $d = $Root + '\' + $name
    $src = $d + '\src'
    $arc = $d + '\t.zip'
    $e = New-Object System.Collections.Specialized.OrderedDictionary
    $right = $arc
    $want = @()
    try {
        NewDir $d; NewDir $src
        switch ($Case) {
            'ADDDIR' {
                $e['D/x.txt'] = 'X'; $e['d/y.txt'] = 'Y'; WriteFile ($src + '\x.txt') 'NEW'; $right = $arc + '\d'
                $want = @('D/x.txt=X', 'd/x.txt=NEW', 'd/y.txt=Y')
            }
            'ADDFILE' {
                $e['A.txt'] = 'UPPER'; $e['a.txt'] = 'lower'; $e['z.txt'] = 'z'; WriteFile ($src + '\a.txt') 'NEW'
                $want = @('A.txt=UPPER', 'a.txt=NEW', 'z.txt=z')
            }
            'ADDFOLDER' {
                $e['D/x.txt'] = 'X'; $e['d/y.txt'] = 'Y'; NewDir ($src + '\d'); WriteFile ($src + '\d\x.txt') 'NEW'
                $want = @('D/x.txt=X', 'd/x.txt=NEW', 'd/y.txt=Y')
            }
            'NEWNAME' {
                $e['A.txt'] = 'UPPER'; $e['a.txt'] = 'lower'; $e['b.txt'] = 'old'; WriteFile ($src + '\B.txt') 'NEW'
                $want = @('A.txt=UPPER', 'B.txt=NEW', 'a.txt=lower', 'b.txt=old')
            }
            'CONTROL' { $e['README.txt'] = 'OLD'; $e['z.txt'] = 'z'; WriteFile ($src + '\readme.txt') 'NEW' }
        }
        $hostInfo = Make-Zip $arc $e ($Kind -eq 'UNIX')
    }
    catch { Row $name 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports
    try {
        $id = Start-Arc $src $right
        Key $id 0x24; Key $id 0x28   # Home, Down: the one item of src focused (past "..")
        Start-Sleep -Milliseconds 500
        Post-Cmd (Get-Main $id) 727
        $r = Serve $id 40 @(1, 6)
        $msgs = Msgs $r
        End-Row $name $id $null $before; $id = 0
        $questions = @($r.Messages | Where-Object { $_ -match 'Confirm File Overwrite' }).Count
        $got = @(Zip-Content $arc)
        if ($Case -eq 'CONTROL') {
            $readme = @($got | Where-Object { $_ -like 'readme.txt=*' })   # -like ignores case
            $ok = ($got.Count -eq 2) -and ($got -ccontains 'z.txt=z') -and ($readme.Count -eq 1) -and ($readme[0] -match '=NEW$') -and ($questions -eq 1)
        }
        else {
            $ok = ($got.Count -eq $want.Count)
            foreach ($w in $want) { if (-not ($got -ccontains $w)) { $ok = $false } }
            # review 290: every row asserts its questions - ADDFILE one (for a.txt), the others none
            $wantQ = $(if ($Case -eq 'ADDFILE') { 1 } else { 0 })
            if ($questions -ne $wantQ) { $ok = $false }
        }
        Row $name 'RUN' (V $ok) ("archive: {0}; questions: {1}; {2}; windows: {3}" -f $(if ($got.Count) { $got -join ',' } else { 'nothing' }), $questions, $hostInfo, (Tail $msgs 220))
    }
    catch { Row $name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $name $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc290_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("zip290_probe (feature 290) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    foreach ($c in @('CONTROL', 'ADDDIR', 'ADDFILE', 'ADDFOLDER', 'NEWNAME')) { Run-Case 'ZIP' $c }
    foreach ($c in @('CONTROL', 'ADDDIR', 'ADDFILE', 'ADDFOLDER')) { Run-Case 'UNIX' $c }
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
}
exit $nf
