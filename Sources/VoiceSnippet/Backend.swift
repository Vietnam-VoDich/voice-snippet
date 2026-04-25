import AVFoundation
import Carbon.HIToolbox
import Foundation

// MARK: - Config

enum Config {
    // Notes live outside ~/Documents so we don't trigger the macOS Documents-folder TCC prompt.
    static var notesDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".analystai/voice-notes", isDirectory: true)
    }
    static var dictionaryURL: URL { notesDir.appendingPathComponent("dictionary.json") }
}

// MARK: - Recorder

final class Recorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private(set) var currentFile: URL?

    func start() throws {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice-snippet-\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
        ]
        let r = try AVAudioRecorder(url: tmp, settings: settings)
        r.delegate = self
        r.isMeteringEnabled = true
        r.record()
        recorder = r
        currentFile = tmp
    }

    func level() -> Double {
        guard let r = recorder, r.isRecording else { return 0 }
        r.updateMeters()
        let db = Double(r.averagePower(forChannel: 0))
        let floor = -50.0
        if db < floor { return 0 }
        return min(1.0, (db - floor) / -floor)
    }

    func stop() -> URL? {
        recorder?.stop()
        let url = currentFile
        recorder = nil
        return url
    }

    func cancel() {
        recorder?.stop()
        if let url = currentFile { try? FileManager.default.removeItem(at: url) }
        recorder = nil
        currentFile = nil
    }
}

// MARK: - Notes persistence

enum Notes {
    static func append(_ text: String) {
        let fm = FileManager.default
        try? fm.createDirectory(at: Config.notesDir, withIntermediateDirectories: true)
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let tf = DateFormatter(); tf.dateFormat = "HH:mm:ss"
        let file = Config.notesDir.appendingPathComponent("\(df.string(from: Date())).md")
        let entry = "\n## \(tf.string(from: Date()))\n\n\(text)\n"
        if let fh = try? FileHandle(forWritingTo: file) {
            fh.seekToEndOfFile()
            fh.write(entry.data(using: .utf8)!)
            try? fh.close()
        } else {
            try? entry.data(using: .utf8)?.write(to: file)
        }
    }

    static func loadAll() -> [HistoryItem] {
        let fm = FileManager.default
        let dir = Config.notesDir
        guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
        let mdFiles = names.filter { $0.hasSuffix(".md") }.sorted(by: >)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var items: [HistoryItem] = []
        for name in mdFiles {
            let dateStr = String(name.dropLast(3))
            let url = dir.appendingPathComponent(name)
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else { continue }
            for block in raw.components(separatedBy: "\n## ") {
                let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty { continue }
                let lines = trimmed.components(separatedBy: "\n")
                let header = lines.first?.replacingOccurrences(of: "## ", with: "") ?? ""
                let body = lines.dropFirst().joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if body.isEmpty { continue }
                let date = fmt.date(from: "\(dateStr) \(header)")
                    ?? fmt.date(from: "\(dateStr) 00:00:00")
                    ?? Date()
                items.append(.init(timestamp: date, text: body))
            }
        }
        return items.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Global hotkeys

final class Hotkey {
    typealias Handler = () -> Void
    // Keyed by hotkey id (1 = show/hide toggle, 2 = record-now toggle)
    var onPress: [UInt32: Handler] = [:]
    var onRelease: [UInt32: Handler] = [:]
    private var refs: [EventHotKeyRef?] = []

    func register() {
        let sig: FourCharCode = 0x56534E50

        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, ctx in
            guard let ctx = ctx, let event = event else { return noErr }
            let me = Unmanaged<Hotkey>.fromOpaque(ctx).takeUnretainedValue()
            var hkID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hkID)
            let kind = GetEventKind(event)
            if kind == UInt32(kEventHotKeyPressed) { me.onPress[hkID.id]?() }
            else if kind == UInt32(kEventHotKeyReleased) { me.onRelease[hkID.id]?() }
            return noErr
        }, 2, &specs, Unmanaged.passUnretained(self).toOpaque(), nil)

        // ⌥Q — show / hide window
        var ref1: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_ANSI_Q), UInt32(optionKey),
                            EventHotKeyID(signature: sig, id: 1),
                            GetApplicationEventTarget(), 0, &ref1)
        refs.append(ref1)

        // ⌥W — start / stop recording (show window if hidden)
        var ref2: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_ANSI_W), UInt32(optionKey),
                            EventHotKeyID(signature: sig, id: 2),
                            GetApplicationEventTarget(), 0, &ref2)
        refs.append(ref2)
    }
}
