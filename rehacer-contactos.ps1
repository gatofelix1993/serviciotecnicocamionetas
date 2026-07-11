# ============================================================
#  rehacer-contactos.ps1
#  Rehace las hojas de contacto mas livianas (menos de 1 MB),
#  usando las fotos ya optimizadas de la carpeta "fotos".
#
#  USO:  powershell -ExecutionPolicy Bypass -File rehacer-contactos.ps1
# ============================================================

Add-Type -AssemblyName System.Drawing

$destino   = Join-Path $PSScriptRoot "fotos"
$contactos = Join-Path $PSScriptRoot "contactos"

# Laminas mas chicas y comprimidas para no pasar 1 MB
$cols    = 5
$filas   = 6
$celda   = 230
$calidad = 55
$porHoja = $cols * $filas

if (-not (Test-Path $destino)) {
    Write-Host "No existe la carpeta 'fotos'. Corre primero optimizar-fotos.ps1" -ForegroundColor Red
    exit
}

# Borra las laminas viejas
if (Test-Path $contactos) { Remove-Item (Join-Path $contactos "*.jpg") -Force -ErrorAction SilentlyContinue }
New-Item -ItemType Directory -Force -Path $contactos | Out-Null

$codec  = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$params = New-Object System.Drawing.Imaging.EncoderParameters(1)
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [int]$calidad)

$fotos = Get-ChildItem -Path $destino -Filter "foto-*.jpg" -File | Sort-Object Name
Write-Host "$($fotos.Count) fotos encontradas." -ForegroundColor Cyan

$fuente    = New-Object System.Drawing.Font("Arial", 18, [System.Drawing.FontStyle]::Bold)
$fondoNum  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(235, 200, 30, 30))
$textoNum  = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
$fondoHoja = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 30, 30, 30))

$hoja = 0
for ($i = 0; $i -lt $fotos.Count; $i += $porHoja) {
    $hoja++
    $fin = [Math]::Min($i + $porHoja - 1, $fotos.Count - 1)
    $lote = $fotos[$i..$fin]

    $lienzo = New-Object System.Drawing.Bitmap(($cols * $celda), ($filas * $celda))
    $gh = [System.Drawing.Graphics]::FromImage($lienzo)
    $gh.FillRectangle($fondoHoja, 0, 0, $lienzo.Width, $lienzo.Height)
    $gh.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    $k = 0
    foreach ($f in $lote) {
        $cx = ($k % $cols) * $celda
        $cy = [Math]::Floor($k / $cols) * $celda

        $mini = [System.Drawing.Image]::FromFile($f.FullName)
        $escala = [Math]::Min(($celda - 4) / $mini.Width, ($celda - 4) / $mini.Height)
        $mw = [int]($mini.Width * $escala)
        $mh = [int]($mini.Height * $escala)
        $mx = $cx + [int](($celda - $mw) / 2)
        $my = $cy + [int](($celda - $mh) / 2)

        $gh.DrawImage($mini, $mx, $my, $mw, $mh)
        $mini.Dispose()

        # numero de la foto (sale del nombre foto-XXX.jpg)
        $num = [int]($f.BaseName -replace 'foto-', '')
        $gh.FillRectangle($fondoNum, ($cx + 3), ($cy + 3), 48, 28)
        $gh.DrawString("$num", $fuente, $textoNum, ($cx + 6), ($cy + 4))

        $k++
    }

    $rutaHoja = Join-Path $contactos ("hoja-{0:d2}.jpg" -f $hoja)
    $lienzo.Save($rutaHoja, $codec, $params)
    $gh.Dispose(); $lienzo.Dispose()

    $peso = [Math]::Round((Get-Item $rutaHoja).Length / 1KB)
    Write-Host ("  hoja-{0:d2}.jpg  ({1} KB)" -f $hoja, $peso)
}

Write-Host ""
Write-Host "$hoja hojas listas. Avisale a Claude." -ForegroundColor Green
