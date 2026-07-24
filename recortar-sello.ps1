# ============================================================
#  recortar-sello.ps1
#  Recorta el margen blanco de un PNG dejando solo el sello.
#  No borra el original: genera un archivo nuevo.
#
#  Uso:  clic derecho > Ejecutar con PowerShell
#        o en la terminal:  .\recortar-sello.ps1
# ============================================================

Add-Type -AssemblyName System.Drawing

$carpeta = Split-Path -Parent $MyInvocation.MyCommand.Path
$entrada = Join-Path $carpeta 'galeria\selloSEC.png'
$salida  = Join-Path $carpeta 'galeria\selloSEC-recortado.png'

# Que tan claro cuenta como "fondo blanco" (0-255).
# Si queda un borde blanco, baja a 235. Si se come el sello, sube a 250.
$umbral = 243

if (-not (Test-Path $entrada)) {
  Write-Host "No encuentro el archivo: $entrada" -ForegroundColor Red
  Read-Host "Enter para cerrar"
  exit
}

Write-Host "Leyendo $entrada ..."
$src = [System.Drawing.Bitmap]::FromFile($entrada)

$minX = $src.Width
$minY = $src.Height
$maxX = -1
$maxY = -1

for ($y = 0; $y -lt $src.Height; $y++) {
  for ($x = 0; $x -lt $src.Width; $x++) {
    $p = $src.GetPixel($x, $y)

    # Pixel de contenido: no es blanco y no es transparente
    $esFondo = ($p.A -lt 10) -or ($p.R -ge $umbral -and $p.G -ge $umbral -and $p.B -ge $umbral)

    if (-not $esFondo) {
      if ($x -lt $minX) { $minX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -gt $maxY) { $maxY = $y }
    }
  }
}

if ($maxX -lt 0) {
  Write-Host "La imagen se ve completamente blanca. Prueba bajando el umbral." -ForegroundColor Red
  $src.Dispose()
  Read-Host "Enter para cerrar"
  exit
}

$ancho = $maxX - $minX + 1
$alto  = $maxY - $minY + 1

# Lo dejamos cuadrado y centrado, para que el recorte circular del sitio calce
$lado    = [Math]::Max($ancho, $alto)
$centroX = $minX + [int]($ancho / 2)
$centroY = $minY + [int]($alto  / 2)
$origenX = $centroX - [int]($lado / 2)
$origenY = $centroY - [int]($lado / 2)

$destino = New-Object System.Drawing.Bitmap $lado, $lado, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($destino)
$g.Clear([System.Drawing.Color]::White)
$g.DrawImage($src, -$origenX, -$origenY)
$g.Dispose()

$destino.Save($salida, [System.Drawing.Imaging.ImageFormat]::Png)

Write-Host ""
Write-Host "Original : $($src.Width) x $($src.Height)"
Write-Host "Recortado: $lado x $lado"
Write-Host "Guardado en: $salida" -ForegroundColor Green
Write-Host ""

$src.Dispose()
$destino.Dispose()

Read-Host "Enter para cerrar"
