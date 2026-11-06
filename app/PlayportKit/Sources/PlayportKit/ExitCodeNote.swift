// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// What a game's exit code means, in words a player can act on or pass on in a
/// report: the Windows status codes and Win32 errors a game most often ends
/// with under Playport. A code not listed is the game's own.
public enum ExitCodeNote {
    /// The code's name and meaning; nil for 0.
    public static func explain(_ code: UInt32) -> String? {
        if code == 0 { return nil }
        if let known = table[code] { return known }
        switch code {
        case 0xC000_0000...0xCFFF_FFFF:
            return "a Windows error status (NTSTATUS 0x\(hex(code))): the game or the runtime failed"
        case 0x8000_0000...0x8FFF_FFFF:
            return "a Windows error result (HRESULT 0x\(hex(code))) the game returned"
        case 1...255:
            return "the game's own error code \(code): it stopped by itself and chose this code"
        default:
            return "a code the game chose (0x\(hex(code))); its own log may say why"
        }
    }

    /// `0xC0000005 (access violation: …)` for a log or a failure screen.
    public static func line(_ code: UInt32) -> String {
        "0x\(hex(code))" + (explain(code).map { " (\($0))" } ?? "")
    }

    static func hex(_ code: UInt32) -> String { String(format: "%08X", code) }

    static let table: [UInt32: String] = [
        // Crashes.
        0xC000_0005: "access violation: the game crashed reading or writing memory it does not have",
        0xC000_001D: "illegal instruction: a CPU instruction the x86 emulator does not handle",
        0xC000_0096: "privileged instruction: the game ran an instruction only a driver may run (often anti-cheat or DRM)",
        0xC000_00FD: "stack overflow: the game recursed until its stack ran out",
        0xC000_0374: "heap corruption: the game damaged its own memory",
        0xC000_0409: "fail-fast: the game stopped itself on a fatal error it detected (stack buffer overrun or __fastfail)",
        0xC000_0602: "fail-fast exception: the game stopped itself on a fatal error",
        0xC000_0417: "invalid parameter: the C runtime stopped the game on a bad argument",
        0x8000_0003: "breakpoint: the game hit a debug break or a failed assertion",
        0xE06D_7363: "unhandled C++ exception: the game threw an error nothing caught",
        0xE043_4352: "unhandled .NET exception: the game's .NET code threw an error nothing caught",
        0xE043_4F4D: "unhandled .NET exception (older runtime)",
        0x0000_0003: "abort(): the game's C runtime aborted it",
        // Missing pieces.
        0xC000_0135: "DLL not found: the game needs a DLL that is neither in its folder nor in the runtime",
        0xC000_0139: "entry point not found: a DLL lacks a function the game needs",
        0xC000_0142: "DLL initialization failed: a DLL the game loads refused to start",
        0xC000_007B: "invalid image format: a DLL or EXE of the wrong architecture, or damaged",
        0xC06D_007E: "delay-loaded DLL not found",
        0xC06D_007F: "delay-loaded function not found",
        0xC000_0034: "object name not found: a file or registry key the game needs is missing",
        0xC000_003A: "path not found: a folder the game needs is missing",
        0xC000_0022: "access denied",
        // Memory.
        0xC000_0017: "out of memory",
        0xC000_012D: "commitment limit reached: out of virtual memory",
        0x8007_000E: "out of memory (E_OUTOFMEMORY)",
        // Graphics.
        0x887A_0005: "GPU device removed (DXGI_ERROR_DEVICE_REMOVED): the graphics backend failed",
        0x887A_0006: "GPU device hung (DXGI_ERROR_DEVICE_HUNG)",
        0x887A_0004: "graphics feature unsupported (DXGI_ERROR_UNSUPPORTED): the game asked for a Direct3D level the backend lacks",
        0x887A_0007: "GPU device reset (DXGI_ERROR_DEVICE_RESET)",
        0x8876_086C: "Direct3D 9 invalid call (D3DERR_INVALIDCALL)",
        0x8007_0057: "invalid argument (E_INVALIDARG)",
        0x8000_4005: "unspecified failure (E_FAIL)",
        // Ended from outside.
        0x0000_042B: "process aborted (ERROR_PROCESS_ABORTED): the game was ended from outside. After Playport's Quit game this is "
            + "expected (the game did not close itself within 10 s); otherwise the runtime ended it",
        0xC000_013A: "ended by Ctrl+C or a close request (STATUS_CONTROL_C_EXIT)",
        0x4001_0004: "terminated by a debugger (DBG_TERMINATE_PROCESS)",
        0xFFFF_FFFF: "-1: the game's generic failure code",
    ]
}

/// The files and folders a game asked for and did not get, from the runtime's
/// `[file-fail]` lines in the log: a missing DLL, data file or save shows here.
public enum FileFailNote {
    /// Distinct paths with their status, last first, at most `limit`; the runtime's own
    /// lookups (FEX configuration, the session folder, the unix side) left out.
    public static func summary(_ log: String, limit: Int = 12) -> [String] {
        var seen = Set<String>(), out: [String] = []
        for line in log.split(separator: "\n").reversed() where line.hasPrefix("[file-fail]") {
            guard let n = line.range(of: " name=") else { continue }
            var name = String(line[n.upperBound...])
            if name.hasPrefix("\\??\\") { name.removeFirst(4) }
            let lower = name.lowercased()
            if noise.contains(where: { lower.contains($0) }) { continue }
            let status = line.range(of: "status=").map { String(line[$0.upperBound...].prefix { !$0.isWhitespace }) } ?? "?"
            guard seen.insert(lower).inserted else { continue }
            out.append("\(name) (\(statusText[status.lowercased()] ?? status))")
            if out.count == limit { break }
        }
        return out
    }

    static let noise = ["fex-emu", "\\unix\\", "z:\\usr\\", "z:\\var\\", "z:\\private\\", "\\appdata\\local\\playport\\session"]

    static let statusText = [
        "0xc0000034": "not found",
        "0xc000003a": "folder not found",
        "0xc0000022": "access denied",
        "0xc0000035": "already exists",
        "0xc0000043": "in use",
        "0xc00000ba": "is a folder",
    ]
}
