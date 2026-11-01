<#
.SYNOPSIS
    Feature 382 (backlog item a-path-typed-in-another-case-into-an-archive-with-case-twins): a folder inside a TAR /
    7z archive whose listing is case-sensitive (case twins in ANOTHER folder, feature 252) opened by a
    path typed in another case (<archive>\DOCS for Docs) opens that folder when its name is
    unambiguous; Select All + Copy (F5) then extracts only its files.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\src - a case-sensitive folder
    (fsutil file setCaseSensitiveInfo) with the archive's content; <row>\t.tar (Windows tar.exe) or
    <row>\t.7z (C:\Program Files\7-Zip\7z.exe, -ssc) made from it; <row>\tgt - an empty
    case-sensitive folder. The left panel is opened at the typed path, the right panel shows tgt;
    the panel path is read (Change Directory field), Select All (842), Copy (727, dialogs OK).
      TAR-MIXED / 7Z-MIXED      Docs\f.txt, X\a.txt, X\A.txt; opened at <archive>\DOCS.
                                PASS = panel at \Docs and tgt holds only f.txt = 'F'
      TAR-MIXDEEP / 7Z-MIXDEEP  Docs\Sub\g.txt, X\a.txt, X\A.txt; opened at <archive>\dOCS\SUB.
                                PASS = panel at \Docs\Sub and tgt holds only g.txt = 'G'
      TAR-MIXMISS / 7Z-MIXMISS  Docs\f.txt, X\a.txt, X\A.txt; opened at <archive>\DOCS\nothing
                                (the missing tail is shortened as before).
                                PASS = panel at \Docs and tgt holds only f.txt = 'F'
      TAR-EXACT / 7Z-EXACT      Docs\f.txt, DOCS\g.txt, X\a.txt; opened at <archive>\DOCS (exact).
                                PASS = panel at \DOCS and tgt holds only g.txt = 'G'
      TAR-AMBIG / 7Z-AMBIG      Docs\f.txt, DOCS\g.txt; opened at <archive>\docs (two folders of
                                that name ignoring case - no guess).
                                PASS = the panel is in neither \Docs nor \DOCS
    MUST run through tools\run_on_hidden_desktop.ps1. Registry exported, restored and verified.
    Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\273-tar-case-root\probe\arccase273_probe.ps1.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Label,
    [string]$OutFile,
    [string[]]$Only,
    [string]$Lib
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if ($Only) { $Only = @($Only | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ }) }
function Want([string]$n) { return (-not $Only) -or (@($Only | Where-Object { $n -like ($_ + '*') }).Count -gt 0) }
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output 'REFUSED: tandemcommander.exe already runs'; exit 99 }

if (-not $Lib) { $Lib = Join-Path $PSScriptRoot '..\..\098-long-path-overruns\probe\fix_probe_lib.ps1' }
. $Lib
$Root = $TempRoot + '\tc382'
$StartDir = $Root + '\start'
$TarExe = Join-Path $env:SystemRoot 'System32\tar.exe'
$SevenZip = 'C:\Program Files\7-Zip\7z.exe'

function Make-CsDir([string]$d) {
    NewDir $d
    $o = & fsutil.exe file setCaseSensitiveInfo $d enable 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('no case-sensitive folder: ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
}
# a case-sensitive sub-folder (case-sensitivity is inherited by new folders, set it anyway)
function Make-Sub([string]$d) { Make-CsDir $d }
# the archive of the folder's content (items at the archive's root); returns its path
function Make-Archive([string]$Kind, [string]$Src, [string]$Dir) {
    $items = @([IO.Directory]::GetFileSystemEntries($LP + $Src) | ForEach-Object { [IO.Path]::GetFileName($_) })
    if ($Kind -eq 'TAR') {
        $arc = $Dir + '\t.tar'
        $o = & $TarExe -cf $arc -C $Src @items 2>&1
    }
    else {
        $arc = $Dir + '\t.7z'
        $o = & $SevenZip a -t7z -bd -y -ssc $arc ($Src + '\*') 2>&1   # -ssc: twins are two names
    }
    if ($LASTEXITCODE -ne 0 -or -not [IO.File]::Exists($arc)) { throw ('archive not made, exit ' + $LASTEXITCODE + ': ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
    return $arc
}
function Start-Arc([string]$Left, [string]$Right) {
    $p = Start-Process -FilePath $Exe -ArgumentList @('-t', 'TWINS', '-l', ('"{0}"' -f $Left), '-r', ('"{0}"' -f $Right), '-p', '1') -PassThru
    [void]$Started.Add($p.Id); [void]$p.Handle; $script:Procs[$p.Id] = $p
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt 60 -and (Test-Alive $p.Id) -and (Get-Main $p.Id) -eq [IntPtr]::Zero) { Start-Sleep -Milliseconds 100 }
    if ((Get-Main $p.Id) -eq [IntPtr]::Zero) { throw 'the program did not show its main window' }
    try { [void]$p.WaitForInputIdle(30000) } catch { }
    Start-Sleep -Milliseconds 2000
    [void](Serve $p.Id 10)
    return $p.Id
}
# the files under tgt, relative, '/'-separated, case kept
function Tgt-Files([string]$Tgt) {
    $base = ($LP + $Tgt + '\')
    return @([IO.Directory]::GetFiles($LP + $Tgt, '*', [IO.SearchOption]::AllDirectories) | ForEach-Object { $_.Substring($base.Length).Replace('\', '/') } | Sort-Object)
}
function Loc-Ends([string]$loc, [string]$want) {
    return $loc.EndsWith($want, [StringComparison]::Ordinal) -or $loc.EndsWith($want + '\', [StringComparison]::Ordinal)
}

function Run-Case([string]$Kind, [string]$Case) {
    $name = $Kind + '-' + $Case
    if (-not (Want $name)) { return }
    if ($Kind -eq 'TAR' -and -not (Test-Path -LiteralPath $TarExe)) { Row $name 'RUN' 'NOT DRIVEN' 'no tar.exe'; return }
    if ($Kind -eq '7Z' -and -not (Test-Path -LiteralPath $SevenZip)) { Row $name 'RUN' 'NOT DRIVEN' 'no 7z.exe'; return }
    $d = $Root + '\' + $name
    $src = $d + '\src'; $tgt = $d + '\tgt'
    $ambig = $false
    try {
        Make-CsDir $src; Make-CsDir $tgt
        if ($Case -eq 'MIXED' -or $Case -eq 'MIXMISS') {
            Make-Sub ($src + '\Docs'); WriteFile ($src + '\Docs\f.txt') 'F'
            Make-Sub ($src + '\X'); WriteFile ($src + '\X\a.txt') 'a'; WriteFile ($src + '\X\A.txt') 'A'
            $typed = $(if ($Case -eq 'MIXED') { '\DOCS' } else { '\DOCS\nothing' })
            $wantLoc = '\Docs'; $wantFile = 'f.txt'; $wantText = 'F'
        }
        elseif ($Case -eq 'MIXDEEP') {
            Make-Sub ($src + '\Docs'); Make-Sub ($src + '\Docs\Sub'); WriteFile ($src + '\Docs\Sub\g.txt') 'G'
            Make-Sub ($src + '\X'); WriteFile ($src + '\X\a.txt') 'a'; WriteFile ($src + '\X\A.txt') 'A'
            $typed = '\dOCS\SUB'; $wantLoc = '\Docs\Sub'; $wantFile = 'g.txt'; $wantText = 'G'
        }
        elseif ($Case -eq 'EXACT') {
            Make-Sub ($src + '\Docs'); Make-Sub ($src + '\DOCS'); Make-Sub ($src + '\X')
            WriteFile ($src + '\Docs\f.txt') 'F'; WriteFile ($src + '\DOCS\g.txt') 'G'; WriteFile ($src + '\X\a.txt') 'a'
            $typed = '\DOCS'; $wantLoc = '\DOCS'; $wantFile = 'g.txt'; $wantText = 'G'
        }
        else {
            Make-Sub ($src + '\Docs'); Make-Sub ($src + '\DOCS')
            WriteFile ($src + '\Docs\f.txt') 'F'; WriteFile ($src + '\DOCS\g.txt') 'G'
            $typed = '\docs'; $ambig = $true
        }
        $arc = Make-Archive $Kind $src $d
    }
    catch { Row $name 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    $id = 0; $before = Reports
    try {
        $left = $arc + $typed
        if (-not $left.StartsWith($Root + '\')) { throw ('typed path outside the fixture: ' + $left) }
        $id = Start-Arc $left $tgt
        $loc = Get-Loc $id
        $msgs = '-'
        if (-not $ambig) {
            Post-Cmd (Get-Main $id) 842; Start-Sleep -Milliseconds 800
            Post-Cmd (Get-Main $id) 727
            $r = Serve $id 40 @(1, 6)
            $msgs = Msgs $r
        }
        End-Row $name $id $null $before; $id = 0
        $files = @(Tgt-Files $tgt)
        $text = '-'
        if ($ambig) {
            $ok = -not (Loc-Ends $loc '\Docs') -and -not (Loc-Ends $loc '\DOCS')
        }
        else {
            if ($files -ccontains $wantFile) { $text = [IO.File]::ReadAllText($LP + $tgt + '\' + $wantFile) }
            $ok = (Loc-Ends $loc $wantLoc) -and ($files.Count -eq 1) -and ($files -ccontains $wantFile) -and ($text -ceq $wantText)
        }
        Row $name 'RUN' (V $ok) ("typed: {0}; panel at: {1}; tgt: {2}; content: {3}; windows: {4}" -f $typed, (Tail $loc 40), $(if ($files.Count) { $files -join ',' } else { 'empty' }), $text, (Tail $msgs 160))
    }
    catch { Row $name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $name $id $null $before } }
}

$backup = Join-Path $env:TEMP 'tc382_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("arctwins382_probe (feature 382) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    foreach ($k in @('TAR', '7Z')) {
        Run-Case $k 'MIXED'
        Run-Case $k 'MIXDEEP'
        Run-Case $k 'MIXMISS'
        Run-Case $k 'EXACT'
        Run-Case $k 'AMBIG'
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
