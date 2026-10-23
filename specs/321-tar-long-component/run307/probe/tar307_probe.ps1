<#
.SYNOPSIS
    Feature 307 (backlog item opening-a-tar-whose-member-name-has-a-300-letter-component): an archive
    member whose name the panel listing cannot hold never crashes the program; the tar plug-in refuses
    a GNU long name it cannot list the way feature 306 refuses a PAX path.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\t.<ext> made by mktar307.py (next to this
    script; Python tarfile GNU format, zipfile, or the installed 7-Zip) and <row>\tgt, an empty folder.
    The left panel opens the archive, the right panel shows tgt; Select All (842), Copy (727, dialogs
    answered OK). CJK(n) = n letters U+4E00, U+4E01, ...
      GNU-TOOLONG  CJK(300).txt (904 bytes, 304 UTF-16 units) as a GNU long name, then ok.txt 'K'
                                                       -> "(206)" message at open, tgt holds only ok.txt
      GNU-DEEP     a.txt, 12 folders of 200 letters + f.txt (folder part 2411 bytes), ok.txt
                                                       -> "(206)" at open, tgt a.txt + ok.txt
      GNU-255      CJK(251).txt (255 UTF-16 units, 757 bytes) at the root     -> that name, 'M'
      GNU-255DIR   folder CJK(255) (765 bytes), CJK(255)/in.txt, ok.txt       -> "(206)" at open, tgt ok.txt
      GNU-LONG     d*100/e*100/f*96.txt as a GNU long name (regression)       -> that path, 'L'
      ZIP-TOOLONG  t.zip with CJK(300).txt and ok.txt (Python zipfile)       -> no crash; recorded
      7Z-TOOLONG   t.7z with CJK(300).txt and ok.txt (7z.exe -si<name>)       -> no crash; recorded
      GNU-DIR100   an empty top-level folder CJK(100) (300 bytes), ok.txt (review 1 SHOULD: 0.1.10 listed it)
                                                       -> no message, tgt holds the folder and ok.txt
    Open-only rows, with "Simple Icons In Archives" = 1 (review 1 MUST: the icon code copies the
    extension + 4 zero bytes into a 780-byte buffer); the archive is opened, nothing is copied:
      CPIO-778     newc cpio: "." + 777 letters (778 bytes, under the listing's 780) and ok.txt
                                                       -> no crash, the archive opens
      CPIO-TOOLONG newc cpio: CJK(300).txt and ok.txt -> no crash (the listing refuses the entry)
    A crash is the END row's FAIL (a bug report / a stray error window). For the ZIP / 7Z rows the RUN
    row passes when the archive opened or a message was shown at open (never silent); what was
    extracted is recorded. Every row first reads the panel's path: Copy runs only inside the archive.
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\306-tar-pax-headers\probe\pax306_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib,
    [string]$Python = 'python',
    [string]$SevenZip = 'C:\Program Files\7-Zip\7z.exe'
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $Lib) { $Lib = Join-Path $Here '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
$Root = $TempRoot + '\tc307'
$StartDir = $Root + '\start'
$MkTar = Join-Path $Here 'mktar307.py'

function Cjk([int]$n, [int]$start = 0x4E00) { $sb = New-Object Text.StringBuilder; for ($i = 0; $i -lt $n; $i++) { [void]$sb.Append([char]($start + $i)) }; return $sb.ToString() }
function Start-Arc([string]$Left, [string]$Right) {
    $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'T307', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1') -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 2000
    $r = Serve $p.Id 10
    $script:OpenMsgs = Msgs $r
    return $p.Id
}
# the files under tgt, relative, '/'-separated
function Tgt-Files([string]$Tgt) {
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Content([string]$Tgt, [string]$Rel) { return [IO.File]::ReadAllText($LP + $Tgt + '\' + $Rel.Replace('/', '\')) }
function Short([string]$s) { if ($s.Length -le 24) { return $s }; return ('{0}..[{1} chars]..{2}' -f $s.Substring(0, 8), $s.Length, $s.Substring($s.Length - 8)) }
function Esc-Names($files) { return (@($files | ForEach-Object { Esc (Short $_) }) -join ', ') }

function Run-Row([string]$name) {
    if (-not (Want $name)) { return }
    $d = $Root + '\' + $name
    $ext = switch -wildcard ($name) { 'ZIP-*' { 'zip' } '7Z-*' { '7z' } 'CPIO-*' { 'cpio' } default { 'tar' } }
    $tgt = $d + '\tgt'; $arc = $d + '\t.' + $ext
    $longPath = ('d' * 100) + '/' + ('e' * 100) + '/' + ('f' * 96) + '.txt'
    # expected: relative path -> content
    $want = [ordered]@{}; $need206 = $false; $observe = $false; $openOnly = $false; $wantDir = $null
    switch ($name) {
        'GNU-TOOLONG' { $want['ok.txt'] = 'K'; $need206 = $true }
        'GNU-DEEP' { $want['a.txt'] = 'a'; $want['ok.txt'] = 'K'; $need206 = $true }
        'GNU-255' { $want[(Cjk 251) + '.txt'] = 'M' }
        'GNU-255DIR' { $want['ok.txt'] = 'K'; $need206 = $true }
        'GNU-LONG' { $want[$longPath] = 'L' }
        'GNU-DIR100' { $want['ok.txt'] = 'K'; $wantDir = (Cjk 100) }
        'CPIO-778' { $openOnly = $true }
        'CPIO-TOOLONG' { $openOnly = $true; $observe = $true }
        default { $observe = $true }
    }
    try {
        NewDir $d; NewDir $tgt
        $o = & $Python -I $MkTar $name $arc $SevenZip 2>&1
        if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($arc)) { throw ('archive not made, exit ' + $LASTEXITCODE + ': ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
    }
    catch { Row $name 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports
    try {
        if (-not $arc.StartsWith($Root + '\') -or -not $tgt.StartsWith($Root + '\')) { throw ('path outside the fixture: ' + $arc) }
        $id = Start-Arc $arc $tgt
        $openMsgs = $script:OpenMsgs
        $loc = Get-Loc $id
        if (-not $loc.StartsWith($arc, [StringComparison]::OrdinalIgnoreCase)) {
            End-Row $name $id $null $before; $id = 0
            $ok = $observe -and ($openMsgs -ne 'no window')
            Row $name 'RUN' (V $ok) ('the archive did not open; panel at: ' + (Tail $loc 80) + '; at open: ' + (Tail $openMsgs 160))
            return
        }
        if ($openOnly) {
            End-Row $name $id $null $before; $id = 0
            Row $name 'RUN' 'PASS' ('the archive opened; at open: ' + (Tail $openMsgs 160))
            return
        }
        Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
        Post-Cmd (Get-Main $id) 727
        $r = Serve $id 40 @(1, 6)
        $msgs = Msgs $r
        End-Row $name $id $null $before; $id = 0
        $files = @(Tgt-Files $tgt)
        $facts = New-Object System.Collections.ArrayList
        if ($observe) { $ok = $true }
        else {
            $ok = ($files.Count -eq $want.Count)
            foreach ($k in $want.Keys) {
                if ($files -notcontains $k) { $ok = $false; [void]$facts.Add('missing ' + (Esc (Short $k))); continue }
                $c = Content $tgt $k
                if ($c -cne $want[$k]) { $ok = $false }
                [void]$facts.Add(('{0}: {1}' -f (Esc (Short $k)), $c))
            }
        }
        [void]$facts.Add('tgt: ' + $(if ($files.Count) { Esc-Names $files } else { 'empty' }))
        if ($wantDir) {
            $dOk = [IO.Directory]::Exists($LP + $tgt + '\' + $wantDir)
            if (-not $dOk -or $openMsgs -ne 'no window') { $ok = $false }
            [void]$facts.Add('folder ' + (Esc (Short $wantDir)) + ' extracted: ' + $dOk)
        }
        # a refused member: the system's "(206) file name too long" when the archive is opened, the
        # rest of the archive extracted
        if ($need206) { $m = $openMsgs -match '\(206\)'; if (-not $m) { $ok = $false }; [void]$facts.Add('message (206) at open: ' + $m) }
        Row $name 'RUN' (V $ok) (($facts -join '; ') + '; at open: ' + (Tail $openMsgs 160) + '; windows: ' + (Tail $msgs 220))
    }
    catch { Row $name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $name $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc307_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("tar307_probe (feature 307) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}; python {3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP(), ((& $Python --version 2>&1) -join ' '))
    Out ''
    foreach ($n in @('GNU-TOOLONG', 'GNU-DEEP', 'GNU-255', 'GNU-255DIR', 'GNU-LONG', 'ZIP-TOOLONG', '7Z-TOOLONG', 'GNU-DIR100')) { Run-Row $n }
    # the open-only rows run last with simple icons in archives (the registry is restored at the end)
    if ((Want 'CPIO-778') -or (Want 'CPIO-TOOLONG')) {
        & reg.exe add "$RegKey\0.1\Packers & Unpackers" /v 'Simple Icons In Archives' /t REG_DWORD /d 1 /f | Out-Null
        foreach ($n in @('CPIO-778', 'CPIO-TOOLONG')) { Run-Row $n }
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
