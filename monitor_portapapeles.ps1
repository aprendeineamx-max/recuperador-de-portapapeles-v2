<#
.SYNOPSIS
    Monitorea el portapapeles y guarda los cambios en un archivo de texto.
#>

$historyFile = Join-Path $PSScriptRoot "historial_portapapeles.txt"
$lastClip = ""

Write-Host "Iniciando monitor de portapapeles..." -ForegroundColor Cyan
Write-Host "Historial guardado en: $historyFile" -ForegroundColor Gray
Write-Host "Presiona Ctrl+C para detener." -ForegroundColor Yellow

Add-Type -AssemblyName System.Windows.Forms

while ($true) {
    if ([System.Windows.Forms.Clipboard]::ContainsText()) {
        $currentClip = [System.Windows.Forms.Clipboard]::GetText()
        
        if ($currentClip -ne $lastClip -and -not [string]::IsNullOrWhiteSpace($currentClip)) {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $entry = "[$timestamp]`r`n$currentClip`r`n----------------------------------------`r`n"
            
            # Guardar en archivo (append)
            $entry | Out-File -FilePath $historyFile -Append -Encoding UTF8
            
            Write-Host "[$timestamp] Nuevo elemento guardado." -ForegroundColor Green
            $lastClip = $currentClip
        }
    }
    Start-Sleep -Milliseconds 500
}
