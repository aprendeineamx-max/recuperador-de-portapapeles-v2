<#
.SYNOPSIS
    Monitorea el portapapeles y guarda las imágenes copiadas en una carpeta.
    Usa el número de secuencia del portapapeles para detectar cambios eficientemente.
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$saveDir = Join-Path $PSScriptRoot "capturas"
if (-not (Test-Path $saveDir)) {
    New-Item -ItemType Directory -Path $saveDir | Out-Null
}

$code = @"
using System;
using System.Runtime.InteropServices;

public class ClipboardWatcher
{
    [DllImport("user32.dll")]
    public static extern uint GetClipboardSequenceNumber();
}
"@

Add-Type -TypeDefinition $code

$lastSequence = 0

Write-Host "Iniciando monitor de capturas..." -ForegroundColor Cyan
Write-Host "Guardando en: $saveDir" -ForegroundColor Gray

while ($true) {
    try {
        $currentSequence = [ClipboardWatcher]::GetClipboardSequenceNumber()
        
        if ($currentSequence -ne $lastSequence) {
            if ([System.Windows.Forms.Clipboard]::ContainsImage()) {
                # Verificar si es un recorte propio para ignorarlo
                $data = [System.Windows.Forms.Clipboard]::GetDataObject()
                if ($data.GetDataPresent("RecorteMarker")) {
                    Write-Host "Detectado recorte interno: Ignorando guardado en capturas." -ForegroundColor Yellow
                }
                else {
                    $img = [System.Windows.Forms.Clipboard]::GetImage()
                    if ($img -ne $null) {
                        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss_fff"
                        $filename = "captura_$timestamp.png"
                        $fullPath = Join-Path $saveDir $filename
                        
                        $img.Save($fullPath, [System.Drawing.Imaging.ImageFormat]::Png)
                        $img.Dispose()
                        
                        Write-Host "[$timestamp] Imagen guardada: $filename" -ForegroundColor Green
                    }
                }
            }
            $lastSequence = $currentSequence
        }
    }
    catch {
        # Ignorar errores transitorios
    }
    Start-Sleep -Milliseconds 500
}
