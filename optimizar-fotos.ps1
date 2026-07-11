# ============================================================
#  optimizar-fotos.ps1
#
#  1. Toma las fotos sueltas de "fotos-originales" (los .zip se ignoran).
#  2. Las reduce a 1600px, calidad 80, corrige la rotacion del celular.
#  3. Las numera: fotos\foto-001.jpg, foto-002.jpg, ...
#  4. Arma hojas de contacto (30 fotos numeradas por lamina) en "contactos\".
#
#  USO (terminal de VS Code, dentro de la carpeta del proyecto):
#      powershell -ExecutionPolicy Bypass -File optimizar-fotos.ps1
# ============================================================

Add-Type -AssemblyName System.Drawing

$origen    = Join-Path $PSScriptRoot "fotos-originales"
$destino   = Join-Path $PSScriptRoot "fotos"
$contactos = Join-Path $PSScriptRoot "contactos"
$anchoMax  = 1600
$calidad   = 80

# Hoja de contacto: 5 columnas x 6 filas = 30 fotos por lamina
$cols    = 5
$filas   = 6
$celda   = 320
$porHoja = $cols * $filas

if (-not (Test-Path $origen)) {
    Write-Host "No existe la carpeta 'fotos-originales'." -ForegroundColor Red
    exit
}

New-Item -ItemType Directory -Force -Path $destino   | Out-Null
New-Item -ItemType Directory -Force -Path $contactos | Out-Null

# ---------- Los .zip se ignoran a proposito ----------

$codec  = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$params = New-Object System.Drawing.Imaging.EncoderParameters(1)
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [int]$calidad)

function Corregir-Rotacion($img) {
    if ($img.PropertyIdList -contains 274) {
        $o = $img.GetPropertyItem(274).Value[0]
        switch ($o) {
            3 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
            6 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone)  }
            8 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
        }
    }
}

# ---------- PASO 1: optimizar y numerar ----------
Write-Host "Optimizando fotos..." -ForegroundColor Cyan

$archivos = Get-ChildItem -Path $origen -Recurse -File |
            Where-Object { $_.Extension -match '(?i)^\.(jpg|jpeg|png)$' } |
            Sort-Object FullName

Write-Host "  $($archivos.Count) imagenes encontradas."

$n = 0
$listos = @()

foreach ($f in $archivos) {
    try {
        $img = [System.Drawing.Image]::FromFile($f.FullName)
        Corregir-Rotacion $img

        $ancho = $img.Width
        $alto  = $img.Height
        if ($ancho -gt $anchoMax) {
            $alto  = [int]($alto * ($anchoMax / $ancho))
            $ancho = $anchoMax
        }

        $n++
        $nueva = New-Object System.Drawing.Bitmap($ancho, $alto)
        $g = [System.Drawing.Graphics]::FromImage($nueva)
        $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $g.DrawImage($img, 0, 0, $ancho, $alto)

        $nombre = "foto-{0:d3}.jpg" -f $n
        $ruta = Join-Path $destino $nombre
        $nueva.Save($ruta, $codec, $params)

        $listos += [pscustomobject]@{ Num = $n; Ruta = $ruta }

        $g.Dispose(); $nueva.Dispose(); $img.Dispose()

        if ($n % 25 -eq 0) { Write-Host "  ... $n" }
    }
    catch {
        Write-Host "  ERROR con $($f.Name)" -ForegroundColor Yellow
    }
}

Write-Host "  $n fotos optimizadas." -ForegroundColor Green

# ---------- PASO 2: hojas de contacto ----------
Write-Host "Armando hojas de contacto..." -ForegroundColor Cyan

$fuente    = New-Object System.Drawing.Font("Arial", 24, [System.Drawing.FontStyle]::Bold)
$fondoNum  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 200, 40, 40))
$textoNum  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$fondoHoja = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 25, 25, 25))

$hoja = 0
for ($i = 0; $i -lt $listos.Count; $i += $porHoja) {
    $hoja++
    $fin = [Math]::Min($i + $porHoja - 1, $listos.Count - 1)
    $lote = $listos[$i..$fin]

    $lienzo = New-Object System.Drawing.Bitmap(($cols * $celda), ($filas * $celda))
    $gh = [System.Drawing.Graphics]::FromImage($lienzo)
    $gh.FillRectangle($fondoHoja, 0, 0, $lienzo.Width, $lienzo.Height)
    $gh.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    $k = 0
    foreach ($item in $lote) {
        $cx = ($k % $cols) * $celda
        $cy = [Math]::Floor($k / $cols) * $celda

        $mini = [System.Drawing.Image]::FromFile($item.Ruta)
        $escala = [Math]::Min(($celda - 6) / $mini.Width, ($celda - 6) / $mini.Height)
        $mw = [int]($mini.Width * $escala)
        $mh = [int]($mini.Height * $escala)
        $mx = $cx + [int](($celda - $mw) / 2)
        $my = $cy + [int](($celda - $mh) / 2)

        $gh.DrawImage($mini, $mx, $my, $mw, $mh)
        $mini.Dispose()

        $etq = "$($item.Num)"
        $gh.FillRectangle($fondoNum, ($cx + 4), ($cy + 4), 66, 38)
        $gh.DrawString($etq, $fuente, $textoNum, ($cx + 10), ($cy + 6))

        $k++
    }

    $rutaHoja = Join-Path $contactos ("hoja-{0:d2}.jpg" -f $hoja)
    $lienzo.Save($rutaHoja, $codec, $params)
    $gh.Dispose(); $lienzo.Dispose()
    Write-Host ("  hoja-{0:d2}.jpg" -f $hoja)
}

Write-Host ""
Write-Host "LISTO." -ForegroundColor Green
Write-Host "  $n fotos optimizadas en la carpeta 'fotos'"
Write-Host "  $hoja hojas de contacto en la carpeta 'contactos'"
Write-Host "Ahora avisale a Claude." -ForegroundColor Cyan
