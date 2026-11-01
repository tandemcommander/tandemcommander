<#
.SYNOPSIS
    Feature 383 (backlog item copying-into-an-archive-folder-typed-in-another-case-packs): Copy (F5) / Move (F6) of a
    disk file into an archive whose target is TYPED in the Copy dialog as a folder inside the archive
    in another case than the archive spells it (<x.7z>\DOCS\ while the archive holds Docs) must pack
    into the existing folder Docs, not into a new folder DOCS beside it.

.DESCRIPTION
    Fixture per row (under the probe's %TEMP% folder): <row>\src holds n.txt ('N') - the left panel;
    <row>\a\<content> packed by C:\Program Files\7-Zip\7z.exe (-ssc) into <row>\x.7z or <row>\x.zip.
    The right panel shows the fixture's start folder. The left panel focuses n.txt (Home, End), Copy
    (727) or Move (728) opens, the target field (210) is set to <archive><typed>, OK; the dialogs that
    follow are answered OK / Yes. The archive is then listed by 7z.exe (l -ba -slt); paths compared
    with their case.
      TYPED    Docs\f.txt; typed \DOCS\           PASS = Docs\n.txt, no path DOCS...
      EXACT    Docs\f.txt; typed \Docs\ (control) PASS = Docs\n.txt
      DEEP     Docs\Sub\g.txt; typed \dOCS\sUB\  PASS = Docs\Sub\n.txt
      NEWTAIL  Docs\f.txt; typed \DOCS\New\       PASS = Docs\New\n.txt (the missing tail as typed)
      MOVE     Docs\f.txt; F6, typed \DOCS\       PASS = Docs\n.txt and src\n.txt gone
      TWINS    Docs\f.txt, X\a.txt, X\A.txt (a case-sensitive listing, 252/382); typed \DOCS\
                                                  PASS = Docs\n.txt
      TWINEX   Docs\f.txt, DOCS\g.txt; typed \DOCS\ (exact twin) PASS = DOCS\n.txt, no Docs\n.txt
      AMBIG    Docs\f.txt, DOCS\g.txt; typed \docs\ (two folders of that name ignoring case: no guess)
                                                  PASS = neither Docs\n.txt nor DOCS\n.txt
      PANEL    Docs\f.txt; the RIGHT panel shows the archive (its listing is reused); typed \DOCS\
                                                  PASS = Docs\n.txt, no path DOCS...
    Each row for 7Z and ZIP. MUST run through tools\run_on_hidden_desktop.ps1. Registry exported,
    restored and verified. Exit code = number of FAIL rows.

.NOTES
    Windows PowerShell 5.1; pure ASCII. Built on specs\382-arc-case-twins-path\probe\arctwins382_probe.ps1
    and specs\099-move-into-archive-links\probe\linkmove_probe.ps1.
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
$Root = $TempRoot + '\tc383'
$StartDir = $Root + '\start'
$SevenZip = 'C:\Program Files\7-Zip\7z.exe'

function Make-CsDir([string]$d) {
    NewDir $d
    $o = & fsutil.exe file setCaseSensitiveInfo $d enable 2>&1
    if ($LASTEXITCODE -ne 0) { throw ('no case-sensitive folder: ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
}
function Make-Archive([string]$Kind, [string]$Src, [string]$Dir) {
    $arc = $Dir + '\x.' + $(if ($Kind -eq '7Z') { '7z' } else { 'zip' })
    $t = $(if ($Kind -eq '7Z') { '-t7z' } else { '-tzip' })
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $o = & $SevenZip a $t -bd -y -ssc $arc ($Src + '\*') 2>&1
    $rc = $LASTEXITCODE; $ErrorActionPreference = $old
    if ($rc -ne 0 -or -not [IO.File]::Exists($arc)) { throw ('archive not made, exit ' + $rc + ': ' + (($o | ForEach-Object { "$_" }) -join ' ')) }
    return $arc
}
# the archive's item paths, case kept, '\'-separated, sorted
function Arc-Paths([string]$Arc) {
    if (-not [IO.File]::Exists($Arc)) { return @('(no archive)') }
    $old = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
    $l = & $SevenZip l -ba -slt $Arc 2>&1; $ErrorActionPreference = $old
    return @(@($l | ForEach-Object { "$_" } | Where-Object { $_ -match '^Path = ' } | ForEach-Object { ($_ -replace '^Path = ', '').Replace('/', '\') }) | Sort-Object)
}
function Has([string[]]$a, [string]$p) { return ($a -ccontains $p) }
function HasPrefix([string[]]$a, [string]$p) { return (@($a | Where-Object { $_.StartsWith($p, [StringComparison]::Ordinal) }).Count -gt 0) }

function Run-Case([string]$Kind, [string]$Case) {
    $name = $Kind + '-' + $Case
    if (-not (Want $name)) { return }
    if (-not (Test-Path -LiteralPath $SevenZip)) { Row $name 'RUN' 'NOT DRIVEN' 'no 7z.exe'; return }
    $d = $Root + '\' + $name
    $src = $d + '\src'; $a = $d + '\a'
    $cmd = 727
    try {
        NewDir $src; WriteFile ($src + '\n.txt') 'N'
        Make-CsDir $a
        switch ($Case) {
            'DEEP' { Make-CsDir ($a + '\Docs'); Make-CsDir ($a + '\Docs\Sub'); WriteFile ($a + '\Docs\Sub\g.txt') 'G' }
            'TWINS' {
                Make-CsDir ($a + '\Docs'); WriteFile ($a + '\Docs\f.txt') 'F'
                Make-CsDir ($a + '\X'); WriteFile ($a + '\X\a.txt') 'a'; WriteFile ($a + '\X\A.txt') 'A'
            }
            { $_ -eq 'TWINEX' -or $_ -eq 'AMBIG' } {
                Make-CsDir ($a + '\Docs'); WriteFile ($a + '\Docs\f.txt') 'F'
                Make-CsDir ($a + '\DOCS'); WriteFile ($a + '\DOCS\g.txt') 'G'
            }
            default { Make-CsDir ($a + '\Docs'); WriteFile ($a + '\Docs\f.txt') 'F' }
        }
        $arc = Make-Archive $Kind $a $d
    }
    catch { Row $name 'RUN' 'NOT DRIVEN' ('fixture: ' + $_.Exception.Message); return }
    switch ($Case) {
        'EXACT' { $typed = '\Docs\' }
        'DEEP' { $typed = '\dOCS\sUB\' }
        'NEWTAIL' { $typed = '\DOCS\New\' }
        'AMBIG' { $typed = '\docs\' }
        default { $typed = '\DOCS\' }
    }
    if ($Case -eq 'MOVE') { $cmd = 728 }
    $id = 0; $before = Reports; $fatal = $null
    try {
        $target = $arc + $typed
        if (-not $target.StartsWith($Root + '\')) { throw ('typed path outside the fixture: ' + $target) }
        $saveStart = $StartDir
        if ($Case -eq 'PANEL') { $script:StartDir = $arc }   # Start-Tc opens the right panel on $StartDir
        try { $id = Start-Tc $src } finally { $script:StartDir = $saveStart }
        Key $id 0x24; Key $id 0x23
        $dlg = Open-ByCmd $id $cmd
        if ($dlg -eq [IntPtr]::Zero) { throw ('command ' + $cmd + ' opened no window') }
        $fld = Find-Ctl $dlg 210
        if ($fld -eq [IntPtr]::Zero) { throw 'no target field 210' }
        [void][Drv098f]::SetText($fld, $target, 5000)
        $back = [Drv098f]::GetText($fld, 5000)
        Click-Ok $dlg
        Start-Sleep -Milliseconds 800
        $r = Serve $id 60
        $fatal = $r.Fatal; if (-not $fatal) { $fatal = Fatal-Win $id }
        $msgs = Msgs $r
        End-Row $name $id $fatal $before; $id = 0
        $p = Arc-Paths $arc
        $srcLeft = [IO.File]::Exists($LP + $src + '\n.txt')
        switch ($Case) {
            'EXACT' { $ok = (Has $p 'Docs\n.txt') }
            'DEEP' { $ok = (Has $p 'Docs\Sub\n.txt') -and -not (HasPrefix $p 'dOCS') -and -not (HasPrefix $p 'Docs\sUB') }
            'NEWTAIL' { $ok = (Has $p 'Docs\New\n.txt') -and -not (HasPrefix $p 'DOCS') }
            'MOVE' { $ok = (Has $p 'Docs\n.txt') -and -not (HasPrefix $p 'DOCS') -and -not $srcLeft }
            'TWINEX' { $ok = (Has $p 'DOCS\n.txt') -and -not (Has $p 'Docs\n.txt') }
            'AMBIG' { $ok = -not (Has $p 'Docs\n.txt') -and -not (Has $p 'DOCS\n.txt') }
            default { $ok = (Has $p 'Docs\n.txt') -and -not (HasPrefix $p 'DOCS') }
        }
        $ok = $ok -and (-not $fatal) -and ($back -ceq $target)
        Row $name 'RUN' (V $ok) ("typed: {0}; archive: [{1}]; src n.txt left: {2}; windows: {3}{4}" -f $typed, ($p -join ', '), $srcLeft, (Tail $msgs 160), $(if ($fatal) { '; FATAL ' + $fatal } else { '' }))
    }
    catch { Row $name 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally { if ($id) { End-Row $name $id $fatal $before } }
}

$backup = Join-Path $env:TEMP 'tc383_backup.reg'
$existed = Backup-Reg $backup
$restored = $false; $nf = 0
try {
    if ([IO.Directory]::Exists($LP + $Root)) { [IO.Directory]::Delete($LP + $Root, $true) }
    NewDir $StartDir
    Set-Config
    Out ("arctarget383_probe (feature 383) {0}" -f $Label)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; registry key existed {1}; ACP {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), $existed, [Drv098f]::GetACP())
    Out ''
    foreach ($k in @('7Z', 'ZIP')) {
        foreach ($c in @('TYPED', 'EXACT', 'DEEP', 'NEWTAIL', 'MOVE', 'TWINS', 'TWINEX', 'AMBIG', 'PANEL')) { Run-Case $k $c }
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
