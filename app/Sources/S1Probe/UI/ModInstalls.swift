// SPDX-License-Identifier: GPL-3.0-or-later
// Game page › Install a mod (decision 0200): the shell opens the Files picker (touch,
// as Add a game's), the picked folders and zips are merged into the game's folder one
// after another by PlayportKit's ModInstaller, and Remove mods puts the game back.

import Combine
import Foundation
import PlayportKit
import SteamClientKit
import UniformTypeIdentifiers

@MainActor
final class ModInstalls: ObservableObject {
    static let shared = ModInstalls()
    /// Install a mod: the shell opens the Files picker (AppShell).
    static let requests = PassthroughSubject<Void, Never>()
    static let contentTypes: [UTType] = [.folder, .zip]

    /// The game folder being changed, and how far it is.
    @Published private(set) var busy: String?
    @Published private(set) var status = ""
    /// Bumped after a change, so the page reads the manifest again.
    @Published private(set) var generation = 0
    private var target: (folder: String, name: String)?

    func installer(_ folder: String) -> ModInstaller { ModInstaller(gamesRoot: LibraryModel.paths.games, folder: folder) }

    func manifest(_ folder: String) -> ModManifest? {
        _ = generation
        return installer(folder).manifest
    }

    func request(folder: String, name: String) {
        guard busy == nil else { return }
        target = (folder, name)
        Self.requests.send(())
    }

    /// What the picker returned: each item planned and merged in the order picked.
    func picked(_ urls: [URL]) {
        guard let target, busy == nil, !urls.isEmpty else { return }
        self.target = nil
        busy = target.folder
        status = "Reading \(urls.count == 1 ? urls[0].lastPathComponent : "\(urls.count) mods")…"
        let installer = installer(target.folder), game = installer.game
        Task {
            var lines: [String] = [], failed = false
            for (n, url) in urls.enumerated() {
                let label = urls.count == 1 ? url.lastPathComponent : "\(url.lastPathComponent) (\(n + 1) of \(urls.count))"
                let result = await Task.detached(priority: .userInitiated) { () -> Result<(ModPlan, ModReport), Error> in
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    return Result {
                        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? url.hasDirectoryPath
                        guard isDir || url.pathExtension.lowercased() == "zip" else {
                            throw ImportError.refused("pick a mod's folder or a .zip of it")
                        }
                        let plan = try ModInstaller.plan(isDir ? .folder(url) : .zip(url), game: game, name: url.lastPathComponent)
                        let report = try installer.install(plan) { p in
                            Task { @MainActor in
                                ModInstalls.shared.status = "\(label): \(p.filesDone) of \(p.filesTotal) files"
                            }
                        }
                        return (plan, report)
                    }
                }.value
                switch result {
                case let .success((plan, r)):
                    SteamUILog.logger.info("mods", "\(target.folder): \(plan.name) merged (\(plan.mapping)): \(r.written) files, "
                                           + "\(r.replaced) replaced, \(r.added) added, \(r.skippedEmpty) empty skipped, \(r.bytes) bytes")
                    var line = "\(url.lastPathComponent): \(r.written) files (\(r.replaced) replaced, \(r.added) new)"
                    if r.skippedEmpty > 0 { line += ", \(r.skippedEmpty) empty files skipped" }
                    lines.append(line)
                case let .failure(e):
                    SteamUILog.logger.warn("mods", "\(target.folder): \(url.lastPathComponent) stopped: \(e)")
                    lines.append("\(url.lastPathComponent): \((e as? ImportError)?.description ?? "\(e)")")
                    failed = true
                }
            }
            busy = nil
            status = ""
            generation += 1
            PadModal.shared.picker(title: failed ? "Some mods were not installed" : "Mods installed", context: target.name,
                                   note: lines.joined(separator: "\n"),
                                   options: [PadOption(id: "ok", label: "OK")], selected: "ok") { _ in }
        }
    }

    func remove(folder: String, name: String) {
        guard busy == nil else { return }
        busy = folder
        status = "Putting the game's files back…"
        let installer = installer(folder)
        Task {
            let result = await Task.detached(priority: .userInitiated) { Result { try installer.remove() } }.value
            busy = nil
            status = ""
            generation += 1
            let note: String
            switch result {
            case let .success(r):
                SteamUILog.logger.info("mods", "\(folder): removed: \(r.restored) restored, \(r.deleted) deleted, \(r.missing) backups missing")
                note = "\(r.restored) game files put back, \(r.deleted) mod files deleted."
                    + (r.missing > 0 ? " \(r.missing) backups were missing: Check game files will find those." : "")
            case let .failure(e):
                SteamUILog.logger.warn("mods", "\(folder): remove stopped: \(e)")
                note = "Removing stopped: \(e)"
            }
            PadModal.shared.picker(title: "Remove mods", context: name, note: note,
                                   options: [PadOption(id: "ok", label: "OK")], selected: "ok") { _ in }
        }
    }
}
