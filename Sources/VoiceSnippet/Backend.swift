import AVFoundation
import Carbon.HIToolbox
import Foundation

// MARK: - Config

enum Config {
    static let backendBase = URL(string: "http://127.0.0.1:8003")!
    static var transcribeURL: URL { backendBase.appendingPathComponent("transcribe") }
    static var formatURL: URL { backendBase.appendingPathComponent("voice-format") }
    // ~/.analystai/voice-notes — NOT in ~/Documents (which triggers TCC prompts)
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

// MARK: - Backend client

enum Backend {
    static func transcribe(fileURL: URL) async throws -> String {
        var request = URLRequest(url: Config.transcribeURL)
        request.httpMethod = "POST"
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")
        var body = Data()
        let audio = try Data(contentsOf: fileURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"audio.m4a\"\r\n"
            .data(using: .utf8)!)
        body.append("Content-Type: audio/mp4\r\n\r\n".data(using: .utf8)!)
        body.append(audio)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        let (data, response) = try await URLSession.shared.upload(for: request, from: body)
        try Self.check(response, body: data)
        struct R: Decodable { let text: String }
        return try JSONDecoder().decode(R.self, from: data).text
    }

    static func format(text: String, style: String, instruction: String?) async throws -> String {
        var request = URLRequest(url: Config.formatURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        var payload: [String: Any] = ["text": text, "style": style]
        if let instruction, !instruction.isEmpty { payload["instruction"] = instruction }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.check(response, body: data)
        struct R: Decodable { let text: String }
        return try JSONDecoder().decode(R.self, from: data).text
    }

    private static func check(_ response: URLResponse, body: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw NSError(domain: "Backend", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "No response from \(Config.backendBase)"])
        }
        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: body, encoding: .utf8)?.prefix(200) ?? ""
            throw NSError(domain: "Backend", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode) — \(snippet)"])
        }
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
                if body.isEmpty || body.hasPrefix("[backend unreachable") { continue }
                let date = fmt.date(from: "\(dateStr) \(header)")
                    ?? fmt.date(from: "\(dateStr) 00:00:00")
                    ?? Date()
                items.append(.init(timestamp: date, text: body))
            }
        }
        return items.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Global hotkey

final class Hotkey {
    typealias Handler = () -> Void
    var onPress: Handler?
    var onRelease: Handler?
    private var ref: EventHotKeyRef?

    func register() {
        let sig: FourCharCode = 0x56534E50
        let id = EventHotKeyID(signature: sig, id: 1)
        let keyCode = UInt32(kVK_Space)
        let mods = UInt32(controlKey | optionKey)

        var specs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased)),
        ]
        InstallEventHandler(GetApplicationEventTarget(), { _, event, ctx in
            guard let ctx = ctx, let event = event else { return noErr }
            let me = Unmanaged<Hotkey>.fromOpaque(ctx).takeUnretainedValue()
            let kind = GetEventKind(event)
            if kind == UInt32(kEventHotKeyPressed) { me.onPress?() }
            else if kind == UInt32(kEventHotKeyReleased) { me.onRelease?() }
            return noErr
        }, 2, &specs, Unmanaged.passUnretained(self).toOpaque(), nil)

        RegisterEventHotKey(keyCode, mods, id, GetApplicationEventTarget(), 0, &ref)
    }
}
