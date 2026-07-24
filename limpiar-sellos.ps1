# ============================================================
#  limpiar-sellos.ps1
#  Deja los sellos con fondo transparente y recortados al borde.
#
#  1. Borra solo el blanco que rodea al sello (entra desde los
#     bordes hacia adentro), asi el blanco INTERIOR del sello
#     se conserva.
#  2. Recorta el sobrante y lo deja cuadrado y centrado.
#
#  No modifica los originales: crea archivos nuevos "-limpio".
#
#  Uso en la terminal, dentro de la carpeta del proyecto:
#      powershell -ExecutionPolicy Bypass -File .\limpiar-sellos.ps1
# ============================================================

Add-Type -AssemblyName System.Drawing

$carpeta = Split-Path -Parent $MyInvocation.MyCommand.Path

# Que tan claro cuenta como fondo (0-255), por archivo.
# Baja el numero si queda halo; subelo si se come parte del sello.
$umbralSEC  = 200
$umbralCSWA = 238

function Limpiar-Sello {
  param([string]$Entrada, [string]$Salida, [int]$Umbral = 238)

  if (-not (Test-Path $Entrada)) {
    Write-Host "  No encuentro: $Entrada" -ForegroundColor Red
    return
  }

  Write-Host "  Procesando $(Split-Path $Entrada -Leaf) (umbral $Umbral) ..."

  $orig = [System.Drawing.Bitmap]::FromFile($Entrada)
  $bmp = New-Object System.Drawing.Bitmap $orig.Width, $orig.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.DrawImage($orig, 0, 0, $orig.Width, $orig.Height)
  $g.Dispose()
  $orig.Dispose()

  $w = $bmp.Width
  $h = $bmp.Height

  $rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
  $data = $bmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadWrite, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $stride = $data.Stride
  $bytes = New-Object byte[] ($stride * $h)
  [System.Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)

  # --- Relleno por inundacion desde los bordes ---
  $visitado = New-Object bool[] ($w * $h)
  $pila = New-Object System.Collections.Generic.Stack[int]

  for ($x = 0; $x -lt $w; $x++) {
    $pila.Push($x)
    $pila.Push((($h - 1) * $w) + $x)
  }
  for ($y = 0; $y -lt $h; $y++) {
    $pila.Push($y * $w)
    $pila.Push(($y * $w) + ($w - 1))
  }

  while ($pila.Count -gt 0) {
    $i = $pila.Pop()
    if ($visitado[$i]) { continue }
    $visitado[$i] = $true

    $x = $i % $w
    $y = [int](($i - $x) / $w)
    $off = ($y * $stride) + ($x * 4)

    $b = $bytes[$off]
    $vr = $bytes[$off + 1]
    $r = $bytes[$off + 2]
    $a = $bytes[$off + 3]

    $esFondo = ($a -lt 10) -or ($r -ge $Umbral -and $vr -ge $Umbral -and $b -ge $Umbral)
    if (-not $esFondo) { continue }

    $bytes[$off + 3] = 0

    if ($x -gt 0)          { $j = $i - 1;  if (-not $visitado[$j]) { $pila.Push($j) } }
    if ($x -lt ($w - 1))   { $j = $i + 1;  if (-not $visitado[$j]) { $pila.Push($j) } }
    if ($y -gt 0)          { $j = $i - $w; if (-not $visitado[$j]) { $pila.Push($j) } }
    if ($y -lt ($h - 1))   { $j = $i + $w; if (-not $visitado[$j]) { $pila.Push($j) } }
  }

  [System.Runtime.InteropServices.Marshal]::Copy($bytes, 0, $data.Scan0, $bytes.Length)
  $bmp.UnlockBits($data)

  # --- Recorte al contenido visible ---
  $minX = $w; $minY = $h; $maxX = -1; $maxY = -1

  for ($y = 0; $y -lt $h; $y++) {
    $fila = $y * $stride
    for ($x = 0; $x -lt $w; $x++) {
      if ($bytes[$fila + ($x * 4) + 3] -gt 10) {
        if ($x -lt $minX) { $minX = $x }
        if ($y -lt $minY) { $minY = $y }
        if ($x -gt $maxX) { $maxX = $x }
        if ($y -gt $maxY) { $maxY = $y }
      }
    }
  }

  if ($maxX -lt 0) {
    Write-Host "  Quedo todo transparente. Baja el umbral." -ForegroundColor Red
    $bmp.Dispose()
    return
  }

  $ancho = $maxX - $minX + 1
  $alto = $maxY - $minY + 1
  $lado = [Math]::Max($ancho, $alto)
  $origenX = $minX + [int]($ancho / 2) - [int]($lado / 2)
  $origenY = $minY + [int]($alto / 2) - [int]($lado / 2)

  # Recorte al contenido
  $recorte = New-Object System.Drawing.Bitmap $lado, $lado, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g2 = [System.Drawing.Graphics]::FromImage($recorte)
  $g2.DrawImage($bmp, -$origenX, -$origenY)
  $g2.Dispose()

  # Reduccion con remuestreo de calidad: el navegador achica muy mal
  # imagenes gigantes, asi que se las entregamos ya al tamano util.
  $meta = 600
  if ($lado -gt $meta) {
    $final = New-Object System.Drawing.Bitmap $meta, $meta, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g3 = [System.Drawing.Graphics]::FromImage($final)
    $g3.InterpolationMode   = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g3.PixelOffsetMode     = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g3.SmoothingMode       = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g3.CompositingQuality  = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g3.DrawImage($recorte, 0, 0, $meta, $meta)
    $g3.Dispose()
    $recorte.Dispose()
    $recorte = $final
    $lado = $meta
  }

  $recorte.Save($Salida, [System.Drawing.Imaging.ImageFormat]::Png)
  Write-Host "  Listo: $(Split-Path $Salida -Leaf)  ($lado x $lado)" -ForegroundColor Green

  $recorte.Dispose()
  $bmp.Dispose()
}

Write-Host ""
Write-Host "Limpiando sellos..." -ForegroundColor Cyan
Write-Host ""

Limpiar-Sello -Entrada (Join-Path $carpeta 'galeria\selloSEC.png')  -Salida (Join-Path $carpeta 'galeria\selloSEC-limpio.png')  -Umbral $umbralSEC
Limpiar-Sello -Entrada (Join-Path $carpeta 'galeria\selloSCWA.png') -Salida (Join-Path $carpeta 'galeria\selloSCWA-limpio.png') -Umbral $umbralCSWA

Write-Host ""
Write-Host "Terminado. Recarga el sitio con Ctrl+F5." -ForegroundColor Cyan
Write-Host ""
Read-Host "Enter para cerrar"
