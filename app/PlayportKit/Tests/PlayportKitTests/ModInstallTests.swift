// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import XCTest
@testable import PlayportKit
import SteamClientKit

final class ModInstallTests: XCTestCase {
    var root: URL!
    var games: URL { root.appendingPathComponent("Games") }
    var game: URL { games.appendingPathComponent("RE") }

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("mod-\(UUID().uuidString)")
        try file("RE/bhd.exe", "MZ", in: games)
        try file("RE/nativePC/arcPC/id/e_rom/common.arc", "original common", in: games)
        try file("RE/nativePC/arcPC/jp/room.arc", "original room", in: games)
        try file("RE/nativePC/sound/a.sngw", "original sound", in: games)
    }

    override func tearDownWithError() throws { try? FileManager.default.removeItem(at: root) }

    private func file(_ rel: String, _ text: String = "x", in base: URL) throws {
        let url = base.appendingPathComponent(rel)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
    }

    private func text(_ rel: String) -> String? {
        (try? Data(contentsOf: game.appendingPathComponent(rel))).map { String(decoding: $0, as: UTF8.self) }
    }

    private func installer() -> ModInstaller {
        var i = ModInstaller(gamesRoot: games, folder: "RE")
        i.freeSpace = { _ in 1 << 40 }
        i.reserveBytes = 0
        return i
    }

    func testAModWrappedInItsOwnFoldersMergesWithoutDeletingAnything() throws {
        let mod = root.appendingPathComponent("Mods/HD Textures")
        try file("Mod files/nativePC/arcPC/jp/room.arc", "modded room", in: mod)
        try file("Mod files/nativePC/arcPC/jp/new.arc", "new", in: mod)
        try file("Mod files/.DS_Store", "junk", in: mod)
        let plan = try ModInstaller.plan(.folder(mod), game: game)
        XCTAssertEqual(plan.files.map(\.path), ["nativePC/arcPC/jp/new.arc", "nativePC/arcPC/jp/room.arc"])
        let r = try installer().install(plan)
        XCTAssertEqual(r.replaced, 1)
        XCTAssertEqual(r.added, 1)
        XCTAssertEqual(text("nativePC/arcPC/jp/room.arc"), "modded room")
        XCTAssertEqual(text("nativePC/arcPC/id/e_rom/common.arc"), "original common")
        XCTAssertEqual(text("nativePC/sound/a.sngw"), "original sound")
    }

    func testPickingTheGameFolderItselfPutsItUnderItsName() throws {
        let mod = root.appendingPathComponent("Mods/nativePC")
        try file("arcPC/id/e_rom/common.arc", "modded common", in: mod)
        let plan = try ModInstaller.plan(.folder(mod), game: game)
        XCTAssertEqual(plan.files.map(\.path), ["nativePC/arcPC/id/e_rom/common.arc"])
    }

    func testCaseFollowsTheGame() throws {
        let mod = root.appendingPathComponent("Mods/m")
        try file("NATIVEPC/ARCPC/JP/ROOM.ARC", "modded", in: mod)
        try file("NATIVEPC/Extra/a.txt", "a", in: mod)
        try file("NATIVEPC/Extra/b.txt", "b", in: mod)
        let plan = try ModInstaller.plan(.folder(mod), game: game)
        XCTAssertEqual(Set(plan.files.map(\.path)), ["nativePC/arcPC/jp/room.arc", "nativePC/Extra/a.txt", "nativePC/Extra/b.txt"])
    }

    func testAnEmptyFileDoesNotReplaceAGameFile() throws {
        let mod = root.appendingPathComponent("Mods/m")
        try file("nativePC/sound/a.sngw", "", in: mod)
        try file("nativePC/arcPC/jp/room.arc", "modded", in: mod)
        let plan = try ModInstaller.plan(.folder(mod), game: game)
        XCTAssertEqual(plan.skippedEmpty, ["nativePC/sound/a.sngw"])
        _ = try installer().install(plan)
        XCTAssertEqual(text("nativePC/sound/a.sngw"), "original sound")
    }

    func testAModWithNoMatchingFoldersIsRefusedButTopLevelFilesAreNot() throws {
        let odd = root.appendingPathComponent("Mods/odd")
        try file("textures/x.dds", "x", in: odd)
        XCTAssertThrowsError(try ModInstaller.plan(.folder(odd), game: game))
        let loader = root.appendingPathComponent("Mods/loader")
        try file("dinput8.dll", "MZ", in: loader)
        XCTAssertEqual(try ModInstaller.plan(.folder(loader), game: game).files.map(\.path), ["dinput8.dll"])
    }

    func testRemovingModsRestoresTheGameAsItWas() throws {
        let a = root.appendingPathComponent("Mods/a"), b = root.appendingPathComponent("Mods/b")
        try file("nativePC/arcPC/jp/room.arc", "mod a", in: a)
        try file("nativePC/arcPC/new/n.arc", "new", in: a)
        try file("nativePC/arcPC/jp/room.arc", "mod b", in: b)
        let i = installer()
        _ = try i.install(try ModInstaller.plan(.folder(a), game: game))
        let r = try i.install(try ModInstaller.plan(.folder(b), game: game))
        XCTAssertEqual(r.replaced, 0, "the original was backed up once, by the first mod")
        XCTAssertEqual(text("nativePC/arcPC/jp/room.arc"), "mod b")
        XCTAssertEqual(i.manifest?.mods, ["a", "b"])
        let removal = try i.remove()
        XCTAssertEqual(removal, .init(restored: 1, deleted: 1, missing: 0))
        XCTAssertEqual(text("nativePC/arcPC/jp/room.arc"), "original room")
        XCTAssertFalse(FileManager.default.fileExists(atPath: game.appendingPathComponent("nativePC/arcPC/new").path))
        XCTAssertNil(i.manifest)
    }
}
