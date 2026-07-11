# ============================================================
#  armar-galeria.ps1
#  Copia SOLO las fotos elegidas para el sitio, con nombres limpios.
#  El resto queda en "fotos" (que no se sube a GitHub).
#
#  USO:  powershell -ExecutionPolicy Bypass -File armar-galeria.ps1
# ============================================================

$fotos   = Join-Path $PSScriptRoot "fotos"
$galeria = Join-Path $PSScriptRoot "galeria"

New-Item -ItemType Directory -Force -Path $galeria | Out-Null

# Numero de foto original  ->  nombre en el sitio
$seleccion = @(
    # ---- MUEBLERIA (cocinas, closets, cubiertas) ----
    @{ n =   2; destino = "muebleria-01.jpg" },
    @{ n =   7; destino = "muebleria-02.jpg" },
    @{ n =  12; destino = "muebleria-03.jpg" },
    @{ n =  16; destino = "muebleria-04.jpg" },
    @{ n =  18; destino = "muebleria-05.jpg" },
    @{ n =  34; destino = "muebleria-06.jpg" },

    # ---- AMPLIACIONES (obra, estructura, techumbre, terminaciones) ----
    @{ n =  47; destino = "ampliaciones-01.jpg" },
    @{ n =  54; destino = "ampliaciones-02.jpg" },
    @{ n =  62; destino = "ampliaciones-03.jpg" },
    @{ n =  63; destino = "ampliaciones-04.jpg" },
    @{ n =  68; destino = "ampliaciones-05.jpg" },
    @{ n =  79; destino = "ampliaciones-06.jpg" },

    # ---- GASFITERIA (banos, artefactos) ----
    @{ n =  78; destino = "gasfiteria-01.jpg" },
    @{ n =  81; destino = "gasfiteria-02.jpg" },
    @{ n =  85; destino = "gasfiteria-03.jpg" },
    @{ n =  87; destino = "gasfiteria-04.jpg" }
)

$ok = 0
foreach ($s in $seleccion) {
    $origen = Join-Path $fotos ("foto-{0:d3}.jpg" -f $s.n)
    if (Test-Path $origen) {
        Copy-Item $origen (Join-Path $galeria $s.destino) -Force
        Write-Host ("  OK  foto-{0:d3}.jpg  ->  {1}" -f $s.n, $s.destino)
        $ok++
    } else {
        Write-Host ("  FALTA foto-{0:d3}.jpg" -f $s.n) -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "$ok fotos copiadas a la carpeta 'galeria'." -ForegroundColor Green
