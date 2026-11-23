# Sends real keystrokes to the game through SendInput with scan codes.
# Unity's new Input System reads raw input, which WScript.Shell SendKeys does not produce,
# so driving the game for a test needs this.
#
#   .\tools\SendKeys.ps1 -Keys DOWN,DOWN,ENTER -DelayMs 700
#
# Two things bite here and are handled below:
#   - On x64 the INPUT struct is 40 bytes (its union is sized by MOUSEINPUT). Passing the
#     smaller size of a keyboard-only layout makes SendInput fail with error 87 and send nothing.
#   - Windows only lets the foreground process change the foreground, so the window is raised
#     with the input queues attached, and the result is checked before any key is sent.
param(
    [Parameter(Mandatory = $true)][string[]]$Keys,
    [int]$DelayMs = 500,
    [string]$ProcessName = "Necrodancer",
    [switch]$Ctrl,
    [switch]$Shift,
    [int]$HoldMs = 60
)

$ErrorActionPreference = "Stop"

if (-not ("Win32Input" -as [type])) {
    Add-Type @"
using System;
using System.Runtime.InteropServices;

public static class Win32Input
{
    [StructLayout(LayoutKind.Sequential)]
    public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }

    // Size 40 is sizeof(INPUT) on x64: 8 bytes of type plus padding, then the 32-byte union.
    [StructLayout(LayoutKind.Explicit, Size = 40)]
    public struct INPUT
    {
        [FieldOffset(0)] public uint type;
        [FieldOffset(8)] public KEYBDINPUT ki;
    }

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool BringWindowToTop(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, IntPtr lpdwProcessId);
    [DllImport("kernel32.dll")] public static extern uint GetCurrentThreadId();
    [DllImport("user32.dll")] public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);

    [DllImport("user32.dll")] public static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);

    public static bool ForceForeground(IntPtr hWnd)
    {
        // Windows only lets the foreground thread hand over the foreground: attach to it, and tap Alt
        // (a key event of our own lifts the foreground lock).
        uint fgThread = GetWindowThreadProcessId(GetForegroundWindow(), IntPtr.Zero);
        uint self = GetCurrentThreadId();
        keybd_event(0x12, 0, 0, UIntPtr.Zero);
        keybd_event(0x12, 0, 2, UIntPtr.Zero);
        AttachThreadInput(self, fgThread, true);
        ShowWindow(hWnd, 9);            // SW_RESTORE
        BringWindowToTop(hWnd);
        bool ok = SetForegroundWindow(hWnd);
        AttachThreadInput(self, fgThread, false);
        return ok && GetForegroundWindow() == hWnd;
    }

    [StructLayout(LayoutKind.Sequential)]
    public struct MOUSEINPUT { public int dx, dy; public uint mouseData, dwFlags, time; public IntPtr dwExtraInfo; }

    [StructLayout(LayoutKind.Explicit, Size = 40)]
    public struct MINPUT
    {
        [FieldOffset(0)] public uint type;
        [FieldOffset(8)] public MOUSEINPUT mi;
    }

    [DllImport("user32.dll", SetLastError = true)]
    public static extern uint SendInput(uint nInputs, MINPUT[] pInputs, int cbSize);

    /// <summary>
    /// A one-pixel mouse move. When the display has gone to sleep the game stops processing input
    /// entirely, and keystrokes are swallowed; a mouse event wakes it first.
    /// </summary>
    public static void WakeDisplay()
    {
        MINPUT[] m = new MINPUT[2];
        m[0].type = 0; m[0].mi = new MOUSEINPUT { dx = 1, dy = 0, dwFlags = 0x0001 };
        m[1].type = 0; m[1].mi = new MOUSEINPUT { dx = -1, dy = 0, dwFlags = 0x0001 };
        SendInput(2, m, Marshal.SizeOf(typeof(MINPUT)));
    }

    const uint INPUT_KEYBOARD = 1;
    const uint KEYEVENTF_KEYUP = 0x0002;
    const uint KEYEVENTF_SCANCODE = 0x0008;
    const uint KEYEVENTF_EXTENDEDKEY = 0x0001;

    public static uint Hold(ushort scan, bool extended, bool down)
    {
        uint flags = KEYEVENTF_SCANCODE | (extended ? KEYEVENTF_EXTENDEDKEY : 0) | (down ? 0 : KEYEVENTF_KEYUP);
        INPUT[] inputs = new INPUT[1];
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].ki = new KEYBDINPUT { wVk = 0, wScan = scan, dwFlags = flags, time = 0, dwExtraInfo = IntPtr.Zero };
        return SendInput(1, inputs, Marshal.SizeOf(typeof(INPUT)));
    }

    public static uint Tap(ushort scan, bool extended)
    {
        uint flags = KEYEVENTF_SCANCODE | (extended ? KEYEVENTF_EXTENDEDKEY : 0);
        INPUT[] inputs = new INPUT[2];
        inputs[0].type = INPUT_KEYBOARD;
        inputs[0].ki = new KEYBDINPUT { wVk = 0, wScan = scan, dwFlags = flags, time = 0, dwExtraInfo = IntPtr.Zero };
        inputs[1].type = INPUT_KEYBOARD;
        inputs[1].ki = new KEYBDINPUT { wVk = 0, wScan = scan, dwFlags = flags | KEYEVENTF_KEYUP, time = 0, dwExtraInfo = IntPtr.Zero };
        return SendInput(2, inputs, Marshal.SizeOf(typeof(INPUT)));
    }
}
"@
}

# Scan codes (set 1). The extended flag matters for the arrow and navigation block.
$scan = @{
    'ESC' = @(0x01, $false); 'ENTER' = @(0x1C, $false); 'SPACE' = @(0x39, $false)
    'BACKSPACE' = @(0x0E, $false); 'LCTRL' = @(0x1D, $false); 'LSHIFT' = @(0x2A, $false); 'RSHIFT' = @(0x36, $false); 'LALT' = @(0x38, $false); 'COMMA' = @(0x33, $false); 'PERIOD' = @(0x34, $false); 'SLASH' = @(0x35, $false); 'SEMICOLON' = @(0x27, $false); 'LBRACKET' = @(0x1A, $false); 'RBRACKET' = @(0x1B, $false); 'MINUS' = @(0x0C, $false); 'EQUALS' = @(0x0D, $false); 'GRAVE' = @(0x29, $false); 'APOSTROPHE' = @(0x28, $false); 'BACKSLASH' = @(0x2B, $false); 'TAB' = @(0x0F, $false); 'DELETE' = @(0x53, $true)
    'UP' = @(0x48, $true); 'DOWN' = @(0x50, $true); 'LEFT' = @(0x4B, $true); 'RIGHT' = @(0x4D, $true)
    'HOME' = @(0x47, $true); 'END' = @(0x4F, $true); 'PAGEUP' = @(0x49, $true); 'PAGEDOWN' = @(0x51, $true)
    'F1' = @(0x3B, $false); 'F2' = @(0x3C, $false); 'F3' = @(0x3D, $false); 'F4' = @(0x3E, $false)
    'F5' = @(0x3F, $false); 'F6' = @(0x40, $false); 'F7' = @(0x41, $false); 'F8' = @(0x42, $false)
    'A' = @(0x1E, $false); 'B' = @(0x30, $false); 'C' = @(0x2E, $false); 'D' = @(0x20, $false)
    'E' = @(0x12, $false); 'G' = @(0x22, $false); 'H' = @(0x23, $false); 'I' = @(0x17, $false)
    'M' = @(0x32, $false); 'N' = @(0x31, $false); 'Q' = @(0x10, $false); 'R' = @(0x13, $false)
    'S' = @(0x1F, $false); 'T' = @(0x14, $false); 'W' = @(0x11, $false)
    'F' = @(0x21, $false); 'J' = @(0x24, $false); 'K' = @(0x25, $false); 'L' = @(0x26, $false); 'O' = @(0x18, $false); 'P' = @(0x19, $false); 'U' = @(0x16, $false); 'V' = @(0x2F, $false); 'X' = @(0x2D, $false); 'Y' = @(0x15, $false); 'Z' = @(0x2C, $false)
    'F9' = @(0x43, $false); 'F10' = @(0x44, $false); 'F11' = @(0x57, $false); 'F12' = @(0x58, $false)
    '1' = @(0x02, $false); '2' = @(0x03, $false); '3' = @(0x04, $false); '4' = @(0x05, $false); '5' = @(0x06, $false); '6' = @(0x07, $false); '7' = @(0x08, $false); '8' = @(0x09, $false); '9' = @(0x0A, $false); '0' = @(0x0B, $false)
}

$proc = Get-Process $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $proc) { throw "$ProcessName is not running" }
[Win32Input]::WakeDisplay()
Start-Sleep -Milliseconds 400
$fg = $false
for ($try = 0; $try -lt 6 -and -not $fg; $try++) {
    $fg = [Win32Input]::ForceForeground($proc.MainWindowHandle)
    if (-not $fg) { Start-Sleep -Milliseconds 300 }
}
if (-not $fg) {
    throw "Could not bring $ProcessName to the foreground; no keys were sent."
}
Start-Sleep -Milliseconds 700

$LCTRL = 0x1D
$LSHIFT = 0x2A
if ($Ctrl) { $null = [Win32Input]::Hold([ushort]$LCTRL, $false, $true) }
if ($Shift) { $null = [Win32Input]::Hold([ushort]$LSHIFT, $false, $true) }
try {
    $Keys = @($Keys | ForEach-Object { $_ -split "," } | Where-Object { $_ })
    foreach ($key in $Keys) {
        $k = $key.ToUpperInvariant()
        if (-not $scan.ContainsKey($k)) { throw "Unknown key: $key" }
        if ($HoldMs -gt 0) {
            $null = [Win32Input]::Hold([ushort]$scan[$k][0], [bool]$scan[$k][1], $true)
            Start-Sleep -Milliseconds $HoldMs
            $null = [Win32Input]::Hold([ushort]$scan[$k][0], [bool]$scan[$k][1], $false)
            $sent = 2
        } else {
            $sent = [Win32Input]::Tap([ushort]$scan[$k][0], [bool]$scan[$k][1])
        }
        if ($sent -ne 2) { throw "SendInput refused $key (sent=$sent, error=$([Runtime.InteropServices.Marshal]::GetLastWin32Error()))" }
        Start-Sleep -Milliseconds $DelayMs
    }
}
finally {
    if ($Shift) { $null = [Win32Input]::Hold([ushort]$LSHIFT, $false, $false) }
    if ($Ctrl) { $null = [Win32Input]::Hold([ushort]$LCTRL, $false, $false) }
}
$mods = @(); if ($Ctrl) { $mods += 'Ctrl' }; if ($Shift) { $mods += 'Shift' }
Write-Output ("sent: " + (($mods + ($Keys -join ',')) -join '+'))
