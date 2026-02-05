param(
    [Parameter(Mandatory = $true, HelpMessage = "Password for encryption")]
    [SecureString]$Password
)

$sourceFolders = @("capturas", "recortes")
$sourceFiles = Get-ChildItem "historial*.txt" -ErrorAction SilentlyContinue

$tempZip = "temp_backup.zip"
$encryptedBase = "data.enc"
$chunkSize = 90MB

# 1. Zip
Write-Host "Compressing files..." -ForegroundColor Cyan
if (Test-Path $tempZip) { Remove-Item $tempZip }
Compress-Archive -Path $sourceFolders, $sourceFiles -DestinationPath $tempZip -Force -ErrorAction SilentlyContinue

if (-not (Test-Path $tempZip)) {
    Write-Error "Could not create zip file. Check if folders 'capturas' or 'recortes' exist."
    exit
}

# 2. Encrypt
Write-Host "Encrypting..." -ForegroundColor Cyan
$salt = [System.Security.Cryptography.RandomNumberGenerator]::GetBytes(16)
$pdb = New-Object System.Security.Cryptography.Rfc2898DeriveBytes $Password, $salt, 10000

$aes = New-Object System.Security.Cryptography.AesManaged
$aes.Key = $pdb.GetBytes(32)
$aes.IV = $pdb.GetBytes(16)

$fsInput = New-Object IO.FileStream $tempZip, [IO.FileMode]::Open
$fsOutput = New-Object IO.FileStream "$encryptedBase.tmp", [IO.FileMode]::Create
$cs = New-Object System.Security.Cryptography.CryptoStream $fsOutput, $aes.CreateEncryptor(), [System.Security.Cryptography.CryptoStreamMode]::Write

$fsOutput.Write($salt, 0, $salt.Length) 

$fsInput.CopyTo($cs)
$cs.Close()
$fsInput.Close()
$fsOutput.Close()

# 3. Chunk
Write-Host "Chunking into 90MB parts..." -ForegroundColor Cyan
$inputFile = Get-Item "$encryptedBase.tmp"
$buffer = New-Object byte[] $chunkSize
$reader = [System.IO.File]::OpenRead($inputFile.FullName)
$count = 0

while (($read = $reader.Read($buffer, 0, $buffer.Length)) -gt 0) {
    $count++
    $partName = "{0}.{1:D3}" -f $encryptedBase, $count
    $writer = [System.IO.File]::Create($partName)
    $writer.Write($buffer, 0, $read)
    $writer.Close()
    Write-Host "Created part: $partName"
}
$reader.Close()

# Cleanup
Remove-Item $tempZip
Remove-Item "$encryptedBase.tmp"

Write-Host "Backup complete! Created $count encrypted parts ready for GitHub." -ForegroundColor Green
Write-Host "You can now run: git add data.enc.*; git commit -m 'Update encrypted backup'; git push" -ForegroundColor Yellow
