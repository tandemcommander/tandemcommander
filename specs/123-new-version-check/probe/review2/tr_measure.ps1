# Review 2 (feature 123): do the translated texts fit their controls? GDI measurement with the dialog
# font (MS Shell Dlg 2 = Tahoma 8 pt at 96 dpi: dialog base units 6 x 13, so 1 DLU = 1.5 px wide, 1.625 px high).
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$root = Resolve-Path (Join-Path $PSScriptRoot '..\..\..\..')
$font = New-Object System.Drawing.Font('Tahoma', 11, [System.Drawing.FontStyle]::Regular, [System.Drawing.GraphicsUnit]::Pixel)
$bold14 = New-Object System.Drawing.Font('Tahoma', 15, [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
$flagsLine = [System.Windows.Forms.TextFormatFlags]::NoPadding -bor [System.Windows.Forms.TextFormatFlags]::SingleLine
$flagsWrap = [System.Windows.Forms.TextFormatFlags]::NoPadding -bor [System.Windows.Forms.TextFormatFlags]::WordBreak
function W($t, $f) { ([System.Windows.Forms.TextRenderer]::MeasureText($t.Replace('&', ''), $f, (New-Object System.Drawing.Size(10000, 100)), $flagsLine)).Width }
function WrapH($t, $f, $w) { ([System.Windows.Forms.TextRenderer]::MeasureText($t, $f, (New-Object System.Drawing.Size($w, 10000)), $flagsWrap)).Height }
$langs = 'english', 'czech', 'german', 'french', 'dutch', 'hungarian', 'romanian', 'slovak', 'spanish'
foreach ($lang in $langs) {
    if ($lang -eq 'english') { continue }
    $lines = [System.IO.File]::ReadAllLines((Join-Path $root "translations\$lang\salamand.slt"), [System.Text.Encoding]::UTF8)
    $dlg = 0
    "== $lang"
    foreach ($line in $lines) {
        if ($line -match '^\[DIALOG (\d+)\]') { $dlg = [int]$Matches[1]; continue }
        if ($line -match '^\[') { $dlg = 0; continue }
        if ($dlg -in 6236, 6251, 300 -and $line -match '^(\d+),(-?\d+),(-?\d+),(-?\d+),(-?\d+),\d+,"(.*)"$') {
            $id = [int]$Matches[1]; $cx = [int]$Matches[4]; $cy = [int]$Matches[5]; $t = $Matches[6]
            if ($t -eq '') { continue }
            if ($dlg -eq 300 -and $id -ne 6255) { continue }
            $pxW = [math]::Floor($cx * 6 / 4); $pxH = [math]::Floor($cy * 13 / 8)
            $verdict = ''
            if ($id -eq 6248) {
                $h = WrapH $t $font $pxW
                $verdict = "wrapped height $h px in $pxH px" + $(if ($h -gt $pxH) { '   <<< CLIPPED' } else { '' })
            }
            elseif ($id -eq 6238) {
                $w = W $t $bold14
                $verdict = "bold 1.4x width $w px in $pxW px" + $(if ($w -gt $pxW) { '   <<< CLIPPED' } else { '' })
            }
            else {
                $w = W $t $font
                $need = $w
                if ($id -in 6249, 6255) { $need = $w + 18 }       # check box glyph and gap
                if ($id -in 1, 2, 6250) { $need = $w + 12 }       # button borders and margins
                $verdict = "needs $need px of $pxW px" + $(if ($need -gt $pxW) { '   <<< CLIPPED' } else { '' })
            }
            "  [$dlg] $id  $verdict  | $t"
        }
        if ($dlg -eq 0 -and $line -match '^(14109|14110|14111|14149|14144|14145),\d+,"(.*)"$') {
            $t = $Matches[2].Replace('%s', $(if ($Matches[1] -eq '14109') { '99999.99999.99999' } else { '14. September 2026' }))
            "  string $($Matches[1]) width $(W $t $font) px | $t"
        }
    }
}
"About dialog client width: " + [math]::Floor(299 * 6 / 4) + " px; the line starts at 15 px"
