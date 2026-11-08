// SPDX-License-Identifier: GPL-3.0-or-later
// A mod picked in Files, merged into an installed game's folder (decision 0200).
//
// - The plan reads the mod as an import does (GameImporter.plan: a folder or a .zip,
//   .DS_Store and __MACOSX left out, a zip's single top folder taken off), then finds
//   where its tree sits in the game: it tries the tree as it is, with each leading
//   folder all its files share taken off, and under the picked folder's own name (a
//   player who picks `nativePC` itself), and keeps the one whose folders the game
//   already has most of. A mod none of whose folders the game has is refused, unless
//   it is only files for the game's top folder (a loader DLL and its .ini).
// - The merge never deletes: a file of the mod replaces the game's file of the same
//   path (matched without regard to case, under the game's own spelling), and every
//   other file stays. An empty file of the mod is not written over a non-empty one
//   (what a copy that stopped half way leaves).
// - Before a game file is first replaced it is moved, not copied, to
//   `Games/.playport-mods/<folder>/backup/`; files and folders the mods added are
//   listed in `manifest.json` beside it. Remove mods puts the backups back and deletes
//   what was added, so the folder is as it was before the first mod.

import Foundation
import SteamClientKit
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

public struct ModPlan: Sendable {
    /// What the player picked, for messages and the manifest.
    public var name: String
    public var source: ImportSource
    /// `path`: under the game's folder; `from`: as GameImporter planned it.
    public var files: [ImportPlan.File]
    /// Empty files of the mod that would replace a non-empty game file.
    public var skippedEmpty: [String]
    public var skippedSymlinks: Int
    /// The leading folders taken off (or the name put in front, as `+name`), for the log.
    public var mapping: String
    public var totalBytes: UInt64 { files.reduce(0) { $0 + $1.size } }
}

public struct ModManifest: Codable, Sendable, Equatable {
    /// The mods merged, in order.
    public var mods: [String] = []
    /// Game files replaced, under the game's spelling; their originals are in backup/.
    public var originals: [String] = []
    /// Files the mods added, which the game did not have.
    public var added: [String] = []
    /// Folders the mods created.
    public var addedDirs: [String] = []
    public init() {}
}

public struct ModReport: Sendable, Equatable {
    public var written = 0
    public var replaced = 0
    public var added = 0
    public var skippedEmpty = 0
    public var bytes: UInt64 = 0
}

public struct ModInstaller: Sendable {
    public let game: URL
    public let store: URL
    public var reserveBytes: UInt64 = 256 << 20
    public var freeSpace: @Sendable (URL) throws -> UInt64 = { try InstallFS.availableCapacity($0) }

    public init(gamesRoot: URL, folder: String) {
        game = gamesRoot.appendingPathComponent(folder, isDirectory: true)
        store = gamesRoot.appendingPathComponent(".playport-mods", isDirectory: true).appendingPathComponent(folder, isDirectory: true)
    }

    var manifestURL: URL { store.appendingPathComponent("manifest.json") }
    var backup: URL { store.appendingPathComponent("backup", isDirectory: true) }

    public var manifest: ModManifest? {
        guard let d = try? Data(contentsOf: manifestURL) else { return nil }
        return try? JSONDecoder().decode(ModManifest.self, from: d)
    }

    func save(_ m: ModManifest) throws {
        try FileManager.default.createDirectory(at: store, withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(m).write(to: manifestURL, options: .atomic)
    }

    // MARK: the game's tree, without regard to case

    /// The game's entries by lowercased name, per folder (relative path, game's spelling).
    final class Listing {
        let root: URL
        var dirs: [String: [String: (name: String, isDir: Bool)]] = [:]
        init(_ root: URL) { self.root = root }

        func entries(_ rel: String) -> [String: (name: String, isDir: Bool)] {
            if let e = dirs[rel] { return e }
            var out: [String: (name: String, isDir: Bool)] = [:]
            let url = rel.isEmpty ? root : root.appendingPathComponent(rel)
            for n in (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? [] {
                var st = stat()
                guard lstat(url.appendingPathComponent(n).path, &st) == 0 else { continue }
                let kind = st.st_mode & S_IFMT
                if kind == S_IFLNK { continue }
                out[n.lowercased()] = (n, kind == S_IFDIR)
            }
            dirs[rel] = out
            return out
        }

        func forget(_ rel: String) { dirs[rel] = nil }

        /// How many leading parts exist as folders, and those parts under the game's spelling.
        func resolve(_ parts: [String]) -> (existing: Int, path: [String], fileExists: Bool) {
            var cur: [String] = []
            for (i, p) in parts.enumerated() {
                let e = entries(cur.joined(separator: "/"))
                let last = i == parts.count - 1
                if let hit = e[p.lowercased()], hit.isDir != last {
                    cur.append(hit.name)
                    continue
                }
                return (i, cur + parts[i...], false)
            }
            return (parts.count - 1, cur, true)
        }
    }

    // MARK: the plan

    public static func plan(_ source: ImportSource, game: URL, name: String? = nil) throws -> ModPlan {
        let base = try GameImporter.plan(source)
        let listing = Listing(game)
        let split = base.files.map { ($0, $0.path.split(separator: "/").map(String.init)) }
        // Leading folders every file shares.
        var common = 0
        if let first = split.first?.1 {
            outer: while common < first.count - 1 {
                for (_, p) in split where p.count - 1 <= common || p[common].lowercased() != first[common].lowercased() { break outer }
                common += 1
            }
        }
        struct Candidate { var strip: Int; var prefix: [String]; var score: Int }
        var candidates: [Candidate] = (0...common).map { Candidate(strip: $0, prefix: [], score: 0) }
        candidates.append(Candidate(strip: 0, prefix: [base.name], score: 0))
        for i in candidates.indices {
            var s = 0
            for (_, p) in split {
                let parts = candidates[i].prefix + p.dropFirst(candidates[i].strip)
                let r = listing.resolve(parts)
                if r.fileExists { s += 2 } else if parts.count > 1, r.existing == parts.count - 1 { s += 1 }
            }
            candidates[i].score = s
        }
        // The best score; on a tie, the tree as picked, then the fewest folders taken off.
        var best = candidates[0]
        for c in candidates.dropFirst() where c.score > best.score { best = c }
        if best.score == 0 {
            guard split.allSatisfy({ $0.1.count == 1 }) else {
                throw ImportError.refused("none of its folders are in the game's folder. Pick the folder that holds the game's own folders (for example nativePC), or the folder above it.")
            }
        }
        var files: [ImportPlan.File] = [], empty: [String] = []
        var seen = Set<String>()
        // A folder the game lacks gets the spelling of the first file that names it.
        var spelled: [String: String] = [:]
        for (f, p) in split {
            let parts = best.prefix + p.dropFirst(best.strip)
            let r = listing.resolve(parts)
            var out = Array(r.path.prefix(r.existing))
            for part in r.path.dropFirst(r.existing).dropLast() {
                let k = (out + [part]).joined(separator: "/").lowercased()
                out.append(spelled[k] ?? part)
                spelled[k] = spelled[k] ?? part
            }
            if !r.fileExists { out.append(r.path.last ?? "") } else { out = r.path }
            let path = out.joined(separator: "/")
            guard seen.insert(path.lowercased()).inserted else { continue }
            if f.size == 0, r.fileExists, (InstallFS.fileSize(game.appendingPathComponent(path)) ?? 0) > 0 {
                empty.append(path)
                continue
            }
            files.append(.init(path: path, size: f.size, from: f.from))
        }
        guard !files.isEmpty else { throw ImportError.empty }
        let mapping = best.prefix.isEmpty ? (best.strip == 0 ? "as is" : "-\(best.strip) folder(s)") : "+\(best.prefix.joined(separator: "/"))"
        return ModPlan(name: name ?? source.url.lastPathComponent, source: source, files: files, skippedEmpty: empty,
                       skippedSymlinks: base.skippedSymlinks, mapping: mapping)
    }

    // MARK: the merge

    public func install(_ plan: ModPlan, progress: @escaping @Sendable (GameImporter.Progress) -> Void = { _ in }) throws -> ModReport {
        let fm = FileManager.default
        guard fm.fileExists(atPath: game.path) else { throw ImportError.refused("the game's folder is missing") }
        let free = try freeSpace(game)
        let needed = plan.totalBytes + reserveBytes
        guard free >= needed else { throw ImportError.insufficientSpace(needed: needed, available: free) }
        var m = manifest ?? ModManifest()
        var originals = Set(m.originals.map { $0.lowercased() }), added = Set(m.added.map { $0.lowercased() })
        var addedDirs = Set(m.addedDirs.map { $0.lowercased() })
        var report = ModReport(skippedEmpty: plan.skippedEmpty.count)
        defer {
            if !m.mods.contains(plan.name) { m.mods.append(plan.name) }
            try? save(m)
        }
        var zip: ZipArchive?
        if case let .zip(u) = plan.source { zip = try ZipArchive(url: u) }
        let byPath = Dictionary((zip?.entries ?? []).map { ($0.path, $0) }, uniquingKeysWith: { a, _ in a })
        let total = plan.totalBytes, count = plan.files.count
        var done: UInt64 = 0
        var last = Date()
        progress(.init(bytesDone: 0, bytesTotal: total, filesDone: 0, filesTotal: count))
        for (i, f) in plan.files.enumerated() {
            let parts = f.path.split(separator: "/").map(String.init)
            // Folders the game lacks.
            var dir = game
            for (j, p) in parts.dropLast().enumerated() {
                dir.appendPathComponent(p, isDirectory: true)
                if !fm.fileExists(atPath: dir.path) {
                    try fm.createDirectory(at: dir, withIntermediateDirectories: false)
                    let rel = parts[0...j].joined(separator: "/")
                    if addedDirs.insert(rel.lowercased()).inserted { m.addedDirs.append(rel) }
                }
            }
            let dst = game.appendingPathComponent(f.path)
            let key = f.path.lowercased()
            if fm.fileExists(atPath: dst.path) {
                if !originals.contains(key), !added.contains(key) {
                    let keep = backup.appendingPathComponent(f.path)
                    try fm.createDirectory(at: keep.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try? fm.removeItem(at: keep)
                    guard rename(dst.path, keep.path) == 0 else { throw ClientError.transport("back up \(f.path) errno \(errno)") }
                    originals.insert(key)
                    m.originals.append(f.path)
                    report.replaced += 1
                }
            } else if !originals.contains(key), added.insert(key).inserted {
                m.added.append(f.path)
                report.added += 1
            }
            let part = dst.deletingLastPathComponent().appendingPathComponent(".\(dst.lastPathComponent).part")
            try? fm.removeItem(at: part)
            let tick: (UInt64) throws -> Void = { n in
                done += n
                if Date().timeIntervalSince(last) >= 0.5 {
                    last = Date()
                    progress(.init(bytesDone: done, bytesTotal: total, filesDone: i, filesTotal: count))
                }
            }
            switch plan.source {
            case let .folder(root): try GameImporter.copy(root.appendingPathComponent(f.from), part, tick)
            case .zip:
                guard let zip, let e = byPath[f.from] else { throw ImportError.refused("\(f.from) is no longer in the archive") }
                try GameImporter.write(part) { sink in try zip.extract(e) { buf in try sink(buf); try tick(UInt64(buf.count)) } }
            }
            guard InstallFS.fileSize(part) == f.size else {
                try? fm.removeItem(at: part)
                throw ClientError.verificationFailed("\(f.path) copied as \(InstallFS.fileSize(part) ?? 0) bytes, not \(f.size)")
            }
            guard rename(part.path, dst.path) == 0 else { throw ClientError.transport("rename \(f.path) errno \(errno)") }
            report.written += 1
            report.bytes += f.size
        }
        progress(.init(bytesDone: total, bytesTotal: total, filesDone: count, filesTotal: count))
        return report
    }

    // MARK: removing

    public struct Removal: Sendable, Equatable {
        public var restored = 0
        public var deleted = 0
        public var missing = 0
    }

    /// Puts every backed-up game file back, deletes what the mods added, then the store.
    public func remove() throws -> Removal {
        let fm = FileManager.default
        guard let m = manifest else { return Removal() }
        var r = Removal()
        for p in m.added {
            let u = game.appendingPathComponent(p)
            if (try? fm.removeItem(at: u)) != nil { r.deleted += 1 }
        }
        for p in m.originals {
            let keep = backup.appendingPathComponent(p), dst = game.appendingPathComponent(p)
            guard fm.fileExists(atPath: keep.path) else { r.missing += 1; continue }
            try fm.createDirectory(at: dst.deletingLastPathComponent(), withIntermediateDirectories: true)
            guard rename(keep.path, dst.path) == 0 else { throw ClientError.transport("restore \(p) errno \(errno)") }
            r.restored += 1
        }
        // Folders the mods made, deepest first, when nothing else is in them.
        for d in m.addedDirs.sorted(by: { $0.count > $1.count }) {
            let u = game.appendingPathComponent(d)
            if let c = try? fm.contentsOfDirectory(atPath: u.path), c.allSatisfy({ $0 == ".DS_Store" }) { try? fm.removeItem(at: u) }
        }
        try fm.removeItem(at: store)
        return r
    }
}
