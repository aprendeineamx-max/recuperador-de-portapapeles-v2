<#
.SYNOPSIS
    Monitorea y registra eventos del mouse (clics y scroll) en un archivo de texto.
    Versión Reparada: Elimina dependencias complejas y usa bloqueo simple para escritura segura.
#>

$source = @"
using System;
using System.Diagnostics;
using System.Windows.Forms;
using System.Runtime.InteropServices;
using System.IO;
using System.Collections.Generic;
using System.Threading;

public class MouseLogger
{
    private const int WH_MOUSE_LL = 14;
    private const int WM_LBUTTONDOWN = 0x0201;
    private const int WM_RBUTTONDOWN = 0x0204;
    private const int WM_MBUTTONDOWN = 0x0207;
    private const int WM_MOUSEWHEEL = 0x020A;

    private static LowLevelMouseProc _proc = HookCallback;
    private static IntPtr _hookID = IntPtr.Zero;
    private static string _logFile;
    private static List<string> _buffer = new List<string>();
    private static object _lock = new object();
    private static bool _running = true;

    public static void Start(string logPath)
    {
        _logFile = logPath;
        
        Thread writer = new Thread(WriteLoop);
        writer.IsBackground = true;
        writer.Start();

        _hookID = SetHook(_proc);
        Application.Run();
        UnhookWindowsHookEx(_hookID);
        _running = false;
    }

    private static void WriteLoop()
    {
        while (_running)
        {
            string[] toWrite = null;
            lock (_lock)
            {
                if (_buffer.Count > 0)
                {
                    toWrite = _buffer.ToArray();
                    _buffer.Clear();
                }
            }

            if (toWrite != null)
            {
                try
                {
                    File.AppendAllText(_logFile, string.Join(Environment.NewLine, toWrite) + Environment.NewLine);
                }
                catch { }
            }
            Thread.Sleep(100);
        }
    }

    private static IntPtr SetHook(LowLevelMouseProc proc)
    {
        using (Process curProcess = Process.GetCurrentProcess())
        using (ProcessModule curModule = curProcess.MainModule)
        {
            return SetWindowsHookEx(WH_MOUSE_LL, proc,
                GetModuleHandle(curModule.ModuleName), 0);
        }
    }

    private delegate IntPtr LowLevelMouseProc(int nCode, IntPtr wParam, IntPtr lParam);

    private static IntPtr HookCallback(int nCode, IntPtr wParam, IntPtr lParam)
    {
        if (nCode >= 0)
        {
            MSLLHOOKSTRUCT hookStruct = (MSLLHOOKSTRUCT)Marshal.PtrToStructure(lParam, typeof(MSLLHOOKSTRUCT));
            string action = null;

            if (wParam == (IntPtr)WM_LBUTTONDOWN) action = "Clic Izquierdo";
            else if (wParam == (IntPtr)WM_RBUTTONDOWN) action = "Clic Derecho";
            else if (wParam == (IntPtr)WM_MBUTTONDOWN) action = "Clic Medio";
            else if (wParam == (IntPtr)WM_MOUSEWHEEL)
            {
                short delta = (short)((hookStruct.mouseData >> 16) & 0xffff);
                action = (delta > 0) ? "Scroll Arriba" : "Scroll Abajo";
            }

            if (action != null)
            {
                string logEntry = string.Format("[{0:yyyy-MM-dd HH:mm:ss}] {1} - Posición: X={2}, Y={3}", DateTime.Now, action, hookStruct.pt.x, hookStruct.pt.y);
                lock (_lock)
                {
                    _buffer.Add(logEntry);
                }
            }
        }
        return CallNextHookEx(_hookID, nCode, wParam, lParam);
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT { public int x; public int y; }

    [StructLayout(LayoutKind.Sequential)]
    private struct MSLLHOOKSTRUCT
    {
        public POINT pt;
        public uint mouseData;
        public uint flags;
        public uint time;
        public IntPtr dwExtraInfo;
    }

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr SetWindowsHookEx(int idHook, LowLevelMouseProc lpfn, IntPtr hMod, uint dwThreadId);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool UnhookWindowsHookEx(IntPtr hhk);

    [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr CallNextHookEx(IntPtr hhk, int nCode, IntPtr wParam, IntPtr lParam);

    [DllImport("kernel32.dll", CharSet = CharSet.Auto, SetLastError = true)]
    private static extern IntPtr GetModuleHandle(string lpModuleName);
}
"@

Add-Type -TypeDefinition $source -ReferencedAssemblies System.Windows.Forms, System.Drawing

$logPath = Join-Path $PSScriptRoot "historial_clicks.txt"
Write-Host "Iniciando monitor de mouse (Optimizado v2)..." -ForegroundColor Cyan
[MouseLogger]::Start($logPath)
