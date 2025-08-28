# -------------------------------
# Hedef klasör
# -------------------------------
$folder = "$env:USERPROFILE\Desktop\EDR"

# -------------------------------
# Dosyalar
# -------------------------------
$files = @(
    "scan.exe",
    "1.ps1",
    "2.ps1",
    "3.ps1"
)

# -------------------------------
# Dosyaları sırayla çalıştır
# -------------------------------
foreach ($file in $files) {
    $fullPath = Join-Path $folder $file
    
    if (Test-Path $fullPath) {
        Write-Output "Çalıştırılıyor: $fullPath"
        
        if ($file -like "*.exe") {
            # EXE çalıştır
            Start-Process -FilePath $fullPath
        } elseif ($file -like "*.ps1") {
            # PS1 script çalıştır
            PowerShell -ExecutionPolicy Bypass -File $fullPath
        }
        
        Write-Output "$file çalıştırıldı, 5 saniye bekleniyor..."
        Start-Sleep -Seconds 5
    } else {
        Write-Output "Dosya bulunamadı: $fullPath"
    }
}

Write-Output "Tüm dosyalar çalıştırıldı."
