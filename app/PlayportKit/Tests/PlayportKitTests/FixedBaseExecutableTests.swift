// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import XCTest
@testable import PlayportKit

/// An x86-64 executable that must load in the executable window gets no pool over 768 MiB
/// (decision 0191).
final class FixedBaseExecutableTests: XCTestCase {
    /// A minimal PE32+ header: machine, characteristics, ImageBase, DllCharacteristics.
    private func header(machine: UInt16 = 0x8664, characteristics: UInt16, base: UInt64, dll: UInt16) -> Data {
        var d = [UInt8](repeating: 0, count: 512)
        func put(_ at: Int, _ v: UInt64, _ n: Int) { for i in 0..<n { d[at + i] = UInt8((v >> UInt64(8 * i)) & 0xff) } }
        put(0, 0x5A4D, 2); put(0x3C, 0x80, 4)
        put(0x80, 0x4550, 4); put(0x84, UInt64(machine), 2); put(0x80 + 22, UInt64(characteristics), 2)
        put(0x80 + 24, 0x20B, 2); put(0x80 + 24 + 24, base, 8); put(0x80 + 24 + 70, UInt64(dll), 2)
        return Data(d)
    }

    func testARelocsStrippedExecutableAtTheDefaultBaseNeedsTheWindow() {
        // Shining Resonance Refrain's game.exe: characteristics 0x23, ImageBase 0x140000000.
        XCTAssertEqual(FixedBaseExecutable.imageBase(header: header(characteristics: 0x23, base: 0x1_4000_0000, dll: 0x8160)),
                       0x1_4000_0000)
    }

    func testANonDynamicBaseExecutableNeedsTheWindowToo() {
        XCTAssertEqual(FixedBaseExecutable.imageBase(header: header(characteristics: 0x22, base: 0x1_4000_0000, dll: 0)),
                       0x1_4000_0000)
    }

    func testARelocatableOrOtherExecutableDoesNot() {
        XCTAssertNil(FixedBaseExecutable.imageBase(header: header(characteristics: 0x22, base: 0x1_4000_0000, dll: 0x8160)))
        XCTAssertNil(FixedBaseExecutable.imageBase(header: header(characteristics: 0x23, base: 0x1_0000_0000, dll: 0)))
        XCTAssertNil(FixedBaseExecutable.imageBase(header: header(machine: 0x14c, characteristics: 0x23, base: 0x1_4000_0000, dll: 0)))
        XCTAssertNil(FixedBaseExecutable.imageBase(header: Data("not a PE".utf8)))
    }

    func testAnUnrealBootstrapNeedsWhatItsShippingExecutableNeeds() throws {
        // FINAL FANTASY RESONANCE DEMO: a relocatable FFRS.exe starts the fixed-base shipping exe (decision 0202).
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("fixedbase-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let bin = dir.appendingPathComponent("FFRS/Binaries/Win64")
        try FileManager.default.createDirectory(at: bin, withIntermediateDirectories: true)
        try header(characteristics: 0x22, base: 0x1_4000_0000, dll: 0x8160).write(to: dir.appendingPathComponent("FFRS.exe"))
        XCTAssertNil(FixedBaseExecutable.imageBase(launching: dir.appendingPathComponent("FFRS.exe")))
        try header(characteristics: 0x23, base: 0x1_4000_0000, dll: 0x8160).write(to: bin.appendingPathComponent("FFRS-Win64-Shipping.exe"))
        XCTAssertEqual(FixedBaseExecutable.imageBase(launching: dir.appendingPathComponent("FFRS.exe")), 0x1_4000_0000)
    }

    func testThePoolIsCappedOnlyForSuchAnExecutable() {
        let capped = JitPool.forFixedBase(gameMB: 896, imageBase: 0x1_4000_0000)
        XCTAssertEqual(capped.mb, JitPool.windowKeepingMB)
        XCTAssertNotNil(capped.note)
        XCTAssertEqual(JitPool.forFixedBase(gameMB: 896, imageBase: nil).mb, 896)
        XCTAssertEqual(JitPool.forFixedBase(gameMB: 512, imageBase: 0x1_4000_0000).mb, 512)
        XCTAssertNil(JitPool.forFixedBase(gameMB: nil, imageBase: 0x1_4000_0000).mb)
    }
}
