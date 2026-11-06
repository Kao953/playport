// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// An x86-64 executable that must load at its ImageBase inside the executable window
/// (0x140000000-0x15c000000, ARCHITECTURE.md): its relocations are stripped, or it is not
/// DYNAMIC_BASE. The runtime holds that window only above a JIT pool of up to
/// `JitPool.windowKeepingMB`, so such a game's Play gets no larger pool (decision 0191).
public enum FixedBaseExecutable {
    public static let window: ClosedRange<UInt64> = 0x1_4000_0000...0x1_5BFF_FFFF

    /// The ImageBase the executable needs, from its first bytes (4 KiB is enough); nil for an
    /// executable that relocates, is not x86-64, or needs no address in the window.
    public static func imageBase(header data: Data) -> UInt64? {
        let d = [UInt8](data.prefix(4096))
        func u(_ at: Int, _ n: Int) -> UInt64? {
            guard at >= 0, at + n <= d.count else { return nil }
            return (0..<n).reduce(UInt64(0)) { $0 | UInt64(d[at + $1]) << UInt64($1 * 8) }
        }
        guard u(0, 2) == 0x5A4D, let pe = u(0x3C, 4).map(Int.init), u(pe, 4) == 0x4550,
              u(pe + 4, 2) == 0x8664, let characteristics = u(pe + 22, 2),
              u(pe + 24, 2) == 0x20B, let base = u(pe + 24 + 24, 8),
              let dll = u(pe + 24 + 70, 2) else { return nil }
        let relocsStripped = characteristics & 0x0001 != 0
        let dynamicBase = dll & 0x0040 != 0
        guard relocsStripped || !dynamicBase, window.contains(base) else { return nil }
        return base
    }

    /// The executable's ImageBase as `imageBase(header:)` reads it from the file.
    public static func imageBase(file: URL) -> UInt64? {
        guard let h = try? FileHandle(forReadingFrom: file) else { return nil }
        defer { try? h.close() }
        return (try? h.read(upToCount: 4096)).flatMap { imageBase(header: $0) }
    }
}
