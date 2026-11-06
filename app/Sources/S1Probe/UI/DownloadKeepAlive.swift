// SPDX-License-Identifier: GPL-3.0-or-later
// Downloads in the background (decision 0181). iOS suspends an app soon after it
// leaves the screen, and a suspended download stops. While a job runs and Playport
// is in the background, a silent sound plays on a loop, mixed with other apps' audio
// (Info.plist's audio background mode, which the pairing code's window already
// needs): iOS keeps an app that plays audio running, so the download goes on. It
// stops when Playport is in front again, when no job runs, or when iOS interrupts
// the audio (a call): the job then pauses as before, and resumes once Playport is
// back in front.

import AVFoundation
import UIKit

@MainActor
final class DownloadKeepAlive {
    static let shared = DownloadKeepAlive()

    private var player: AVAudioPlayer?
    private var downloading = false
    private var inBackground = false
    private var observers: [NSObjectProtocol] = []

    private init() {
        let c = NotificationCenter.default
        observers.append(c.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { DownloadKeepAlive.shared.sceneChanged(background: true) }
        })
        observers.append(c.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { DownloadKeepAlive.shared.sceneChanged(background: false) }
        })
    }

    /// Downloads calls this whenever a job starts or stops.
    func update(downloading: Bool) {
        self.downloading = downloading
        apply()
    }

    private func sceneChanged(background: Bool) {
        inBackground = background
        apply()
    }

    private func apply() {
        let want = downloading && inBackground
        if want, player == nil { start() } else if !want, player != nil { stop() }
    }

    private func start() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, options: [.mixWithOthers])
            try session.setActive(true)
            let p = try AVAudioPlayer(data: Self.silence)
            p.numberOfLoops = -1
            p.volume = 0
            guard p.play() else { throw CocoaError(.featureUnsupported) }
            player = p
            LibraryModel.log("downloads: Playport is in the background; a silent sound keeps the download going")
        } catch {
            LibraryModel.log("downloads: could not keep the download going in the background: \(error)")
        }
    }

    private func stop() {
        player?.stop()
        player = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        LibraryModel.log("downloads: the background sound stopped (\(inBackground ? "no download runs" : "Playport is in front"))")
    }

    /// One second of silence: 8 kHz, mono, 16-bit PCM, as a WAV file.
    private static let silence: Data = {
        let rate: UInt32 = 8000, samples = rate, bytes = samples * 2
        var d = Data()
        func put<T: FixedWidthInteger>(_ v: T) { withUnsafeBytes(of: v.littleEndian) { d.append(contentsOf: $0) } }
        d.append(contentsOf: Array("RIFF".utf8)); put(UInt32(36 + bytes)); d.append(contentsOf: Array("WAVE".utf8))
        d.append(contentsOf: Array("fmt ".utf8)); put(UInt32(16)); put(UInt16(1)); put(UInt16(1))
        put(rate); put(rate * 2); put(UInt16(2)); put(UInt16(16))
        d.append(contentsOf: Array("data".utf8)); put(bytes)
        d.append(Data(count: Int(bytes)))
        return d
    }()
}
