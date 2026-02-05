param(
    [Parameter(Mandatory = $true, HelpMessage = "Password for decryption")]
    [SecureString]$Password
)

$encryptedBase = "data.enc"
$outputZip = "restored_backup.zip"

# 1. Combine
Write-Host "Combining chunks..." -ForegroundColor Cyan
$parts = Get-ChildItem "${encryptedBase}.*" | Sort-Object Name
if ($parts.Count -eq 0) {
    Write-Error "No backup parts (data.enc.*) found."
    exit
}

if (Test-Path "${encryptedBase}.tmp") { Remove-Item "${encryptedBase}.tmp" }
$fsCombined = [System.IO.File]::Create("${encryptedBase}.tmp")
foreach ($part in $parts) {
    Write-Host "Reading $($part.Name)..."
    $bytes = [System.IO.File]::ReadAllBytes($part.FullName)
    $fsCombined.Write($bytes, 0, $bytes.Length)
}
$fsCombined.Close()

# 2. Decrypt
Write-Host "Decrypting..." -ForegroundColor Cyan
try {
    $fsInput = New-Object IO.FileStream "${encryptedBase}.tmp", [IO.FileMode]::Open
    $salt = New-Object byte[] 16
    $fsInput.Read($salt, 0, 16)

    $pdb = New-Object System.Security.Cryptography.Rfc2898DeriveBytes $Password, $salt, 10000
    $aes = New-Object System.Security.Cryptography.AesManaged
    $aes.Key = $pdb.GetBytes(32)
    $aes.IV = $pdb.GetBytes(16)

    $fsOutput = New-Object IO.FileStream $outputZip, [IO.FileMode]::Create
    $cs = New-Object System.Security.Cryptography.CryptoStream $fsOutput, $aes.CreateDecryptor(), [System.Security.Cryptography.CryptoStreamMode]::Write

    $fsInput.CopyTo($cs)
    $cs.Close()
    $fsInput.Close()
    $fsOutput.Close()
}
catch {
    Write-Error "Decryption failed. Wrong password or corrupted data."
    if ($fsInput) { $fsInput.Close() }
    if ($fsOutput) { $fsOutput.Close() }
    exit
}

# 3. Unzip
Write-Host "Unzipping..." -ForegroundColor Cyan
Expand-Archive -Path $outputZip -DestinationPath . -Force

# Cleanup
Remove-Item "${encryptedBase}.tmp"
Remove-Item $outputZip

Write-Host "Restore complete! Your data folders are back." -ForegroundColor Green
