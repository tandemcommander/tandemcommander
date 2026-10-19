<#
.SYNOPSIS
    Feature 248 probe (GitHub issue #13): the column names of the Desktop view (Folders plug-in,
    fld:) in the panel's header line - the names the shell gives ("Typ polozky", "Datum zmeny"
    with their Czech accents on a Czech Windows) must be drawn right, not as UTF-8 bytes read as
    code page 1250 ("Typ polo..ky" with two wrong letters).

.DESCRIPTION
    The program is started in -Lang (default czech), the left panel is put into the Detailed view
    and changed to fld: (the Desktop). The header line above the panel's list (owner-drawn) is
    captured and read by the text recognition of Windows (specs\124-regedt-key-text\probe\
    shotocr_lib.ps1). The expected texts are the shell's own column names of the Desktop
    (Shell.Application, Namespace(0).GetDetailsOf(null, i)), so the source holds no accented
    literal and the probe follows the Windows language it runs on.

      NAME    column 0: the core's own Name column (a control - code page, right before and after)
      COL<i>  column i (1..3) of the shell whose name holds a letter outside ASCII: the header
              holds it exactly or with the diacritics folded (garbled text has a wrong LETTER for
              every accented one - "polo" + U+0139 U+013E + "ky" folds to POLOLKY, not POLOZKY)
      ASCII   a column name of pure ASCII is reported as INFO (it cannot show the defect)
      CELLS   the list holds the type text (shell column 2) of at least one
              Desktop item whose type has non-ASCII letters (cells are UTF-8 - right before and
              after; a regression control)
      END     the program ended by WM_CLOSE with exit code 0, no stray window, no new report

    The crop is saved to -ShotDir for a look. -Expect before only changes the header; verdicts
    are computed the same way (the COL rows must FAIL before the fix: the negative control).

    MUST run through tools\run_on_hidden_desktop.ps1. Refuses while any tandemcommander.exe runs
    (the probes share HKCU\Software\Tandem Commander). The whole key is exported before, restored
    and SHA-256-verified after (backup %TEMP%\tc248_backup.reg). Exit code = FAIL rows.

.PARAMETER Exe      tandemcommander.exe of the build under test
.PARAMETER Repo     the repository root (default: three folders above this script)
.PARAMETER Expect   fixed or before
.PARAMETER Lang     language folder name for the program (default czech)
.PARAMETER ShotDir  where the crops go (default: %TEMP%\tc248\shots)

.NOTES
    Windows PowerShell 5.1 compatible; pure ASCII.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Exe,
    [string]$Repo,
    [ValidateSet('fixed', 'before')][string]$Expect = 'fixed',
    [string]$OutFile,
    [string]$Lang = 'czech',
    [string]$ShotDir,
    [int]$ModeCmd = 2972
)
$ErrorActionPreference = 'Stop'
$Exe = (Resolve-Path -LiteralPath $Exe).Path
if (-not $Repo) { $Repo = Join-Path $PSScriptRoot '..\..\..' }
$RepoRoot = (Resolve-Path -LiteralPath $Repo).Path
$others = @(Get-Process tandemcommander -ErrorAction SilentlyContinue)
if ($others.Count) { Write-Output ('NOT RUN: tandemcommander.exe already runs: ' + (($others | ForEach-Object { '' + $_.Id + ' ' + $_.Path }) -join '; ')); exit 3 }

. (Join-Path $RepoRoot 'specs\098-long-path-overruns\probe\fix_probe_lib.ps1')
. (Join-Path $RepoRoot 'specs\124-regedt-key-text\probe\shotocr_lib.ps1')

$Root = $TempRoot + '\tc248'
$StartDir = $Root + '\start'
if (-not $ShotDir) { $ShotDir = $Root + '\shots' }

function Sync([int]$Id) { [void][Drv098f]::Send((Get-Main $Id), 0, 0, 0, 20000) }
function Set-Lang([string]$Slg) { & reg.exe add "$RegKey\0.1\Configuration" /v 'Language' /t REG_SZ /d $Slg /f | Out-Null }
function Has-NonAscii([string]$s) { foreach ($c in $s.ToCharArray()) { if ([int]$c -gt 127) { return $true } }; return $false }

# the shell's column names of the Desktop (index 0..3)
function Shell-Columns {
    $sh = New-Object -ComObject Shell.Application
    $f = $sh.Namespace(0)
    return @(0..3 | ForEach-Object { '' + $f.GetDetailsOf($null, $_) })
}
# the distinct type texts (column 2) of the Desktop's items
function Shell-Types {
    $sh = New-Object -ComObject Shell.Application
    $f = $sh.Namespace(0)
    return @($f.Items() | ForEach-Object { '' + $f.GetDetailsOf($_, 2) } | Where-Object { $_ } | Sort-Object -Unique)
}

function Run-Case {
    $before = Reports; $id = 0
    try {
        Set-Lang ($Lang + '.slg')
        $id = Start-Tc $StartDir
        $main = Get-Main $id
        Post-Cmd $main $ModeCmd; Sync $id; Start-Sleep -Milliseconds 800   # the Detailed view
        $held = Do-ChangeDir $id 'fld:'
        Sync $id; Start-Sleep -Milliseconds 2500
        $boxes = @(Get-Tops $id | Where-Object { [Drv098f]::Cls($_) -ne $MainClass })
        if ($boxes.Count) { Row $Lang 'PATH' 'FAIL' ('a window after the path change: ' + (($boxes | ForEach-Object { WinDesc $_ }) -join ' || ')); return }
        $loc = Get-Loc $id
        Row $Lang 'PATH' (V ($loc -like 'fld:*')) ("Change Directory field held 'fld:': {0}; panel location '{1}'" -f $held, (Esc $loc))

        $list = Get-LeftList $id
        $rc = [Shot124]::RelRect($main, $list); $rc[3] = 22                    # the header line: the top of the list window
        $hdr = Shot-Read $main $list (Join-Path $ShotDir ("{0}_{1}_header.png" -f $Expect, $Lang)) 3 $rc
        $rec = Esc ($hdr.Lines -join ' | ')
        $cols = Shell-Columns
        $h0 = Ocr-Has $hdr.Lines $cols[0]
        Row $Lang 'NAME' (V ($h0 -ne 'no')) ("core column '{0}': {1}; recognized: {2}" -f (Esc $cols[0]), $h0, $rec)
        for ($i = 1; $i -le 3; $i++) {
            $n = $cols[$i]
            if (-not $n) { Row $Lang ('COL' + $i) 'INFO' 'the shell gives no name'; continue }
            $h = Ocr-Has $hdr.Lines $n
            if (-not (Has-NonAscii $n)) { Row $Lang ('COL' + $i) 'INFO' ("ASCII name '{0}' (cannot show the defect): {1}" -f (Esc $n), $h); continue }
            Row $Lang ('COL' + $i) (V ($h -ne 'no')) ("shell column '{0}': {1}; recognized: {2}" -f (Esc $n), $h, $rec)
        }

        # the cells (UTF-8, interface 104) were right before and must stay right: the list holds the type text of at least one Desktop item whose type has non-ASCII letters
        $types = @(Shell-Types | Where-Object { Has-NonAscii $_ })
        if (-not $types.Count) { Row $Lang 'CELLS' 'INFO' 'no Desktop item has a type text with non-ASCII letters' }
        else {
            $rc2 = [Shot124]::RelRect($main, $list)                                    # the whole list (the first rows are
            # virtual folders with an empty type cell; the files below them have one)
            $cl = Shot-Read $main $list (Join-Path $ShotDir ("{0}_{1}_cells.png" -f $Expect, $Lang)) 3 $rc2
            $hit = @($types | Where-Object { (Ocr-Has $cl.Lines $_) -ne 'no' })
            # only the type texts are reported - the recognized list holds the user's own file names
            Row $Lang 'CELLS' (V ($hit.Count -gt 0)) ("{0} non-ASCII type texts on the Desktop, found in the list: {1}" -f $types.Count, (($hit | ForEach-Object { "'" + (Esc $_) + "'" }) -join ', '))
        }
    }
    catch { Row $Lang 'ERROR' 'FAIL' ($_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
    finally {
        if ($id) {
            $fatal = Fatal-Win $id
            Stop-Tc $id
            $ec = ExitCodeOf $id
            $rep = @(Take-Reports $before)
            Row $Lang 'END' (V ((-not $fatal) -and $ec -eq '0x00000000' -and $rep.Count -eq 0)) ("exit {0}; new reports {1}{2}" -f $ec, $rep.Count, $(if ($fatal) { '; FATAL: ' + $fatal } else { '' }))
        }
    }
}

# ---- main ---------------------------------------------------------------------------------
$backup = Join-Path $env:TEMP 'tc248_backup.reg'
$existed = Backup-Reg $backup
$regHash = $(if ($existed) { (Get-FileHash -LiteralPath $backup).Hash } else { '(no key)' })
$restored = $false; $nf = 0
try {
    NewDir $StartDir
    [void][IO.Directory]::CreateDirectory($ShotDir)
    Set-Config
    Out ("folders248_probe (feature 248, issue #13), expect: {0}" -f $Expect)
    Out ("Program : {0}" -f $Exe)
    Out ("Date    : {0}; desktop '{1}'; ACP {2}; UI culture {3}; recognizer languages: {4}; registry key existed {5}; export SHA-256 {6}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm'), [DeskLib098]::Name(), [Drv098f]::GetACP(), (Get-UICulture).Name, ((Ocr-Languages) -join ','), $existed, $regHash)
    Out ("Shell   : Desktop columns 0-3: {0}; crops: {1}" -f ((Shell-Columns | ForEach-Object { "'" + (Esc $_) + "'" }) -join ', '), $ShotDir)
    Out ''
    Run-Case
}
catch { Out ('PROBE ERROR: ' + $_.Exception.Message + ' @ ' + $_.ScriptStackTrace) }
finally {
    foreach ($p in @($Started)) { if (Test-Alive $p) { Stop-Process -Id $p -Force } }
    Start-Sleep -Milliseconds 600
    $restored = Restore-Reg $backup $existed
    if ($restored -and (Test-Path -LiteralPath $backup)) { Remove-Item -LiteralPath $backup -Force }
    try { if ([IO.Directory]::Exists($LP + $StartDir)) { [IO.Directory]::Delete($LP + $StartDir, $true) } } catch { }
    $leftover = @($Started | Where-Object { Test-Alive $_ })
    $np = @($script:Rows | Where-Object { $_.Verdict -eq 'PASS' }).Count
    $nf = @($script:Rows | Where-Object { $_.Verdict -eq 'FAIL' }).Count
    $ni = @($script:Rows | Where-Object { $_.Verdict -eq 'INFO' }).Count
    Out ''
    Out ("Rows: PASS {0}, FAIL {1}, INFO {2}. Left running: {3}; registry restored+identical: {4}" -f $np, $nf, $ni, $leftover.Count, $restored)
    if ($OutFile) { [IO.File]::WriteAllLines($OutFile, [string[]]$script:Lines, (New-Object Text.ASCIIEncoding)) }
}
exit $nf
