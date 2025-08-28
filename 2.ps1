$logs = @("Application", "System", "Security")

# Source kontrolü
if (-not [System.Diagnostics.EventLog]::SourceExists("FakeSource")) {
    [System.Diagnostics.EventLog]::CreateEventSource("FakeSource", "Application")
}

foreach ($log in $logs) {
    try {
        Clear-EventLog -LogName $log
        Write-Output "$log temizlendi."
    } catch {
        Write-Output "$log temizlenemedi: $_"
    }
}

foreach ($log in $logs) {
    for ($i=0; $i -lt 300; $i++) {
        try {
            Write-EventLog -LogName $log -Source "FakeSource" -EntryType Information -EventId 1000 -Message "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
        } catch {
            Write-Output "$log üzerine yazma başarısız: $_"
        }
    }
    Write-Output "$log üzerine 300 adet 'A' yazıldı."
}

