import AppKit
import AVFoundation
import Carbon.HIToolbox
import Combine
import SwiftUI

// MARK: - Config

enum Config {
    static let backendBase = URL(string: "http://127.0.0.1:8003")!
    static var transcribeURL: URL { backendBase.appendingPathComponent("transcribe") }
    static var formatURL: URL { backendBase.appendingPathComponent("voice-format") }
    static var notesDir: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/AnalystAI/voice-notes", isDirectory: true)
    }
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

    /// Returns normalized input level 0.0–1.0 (from dBFS, -50dB floor).
    func level() -> Double {
        guard let r = recorder, r.isRecording else { return 0 }
        r.updateMeters()
        let db = Double(r.averagePower(forChannel: 0)) // -160...0 dB
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
                          userInfo: [NSLocalizedDescriptionKey: "No HTTP response from \(Config.backendBase)"])
        }
        guard (200..<300).contains(http.statusCode) else {
            let snippet = String(data: body, encoding: .utf8)?.prefix(200) ?? ""
            throw NSError(domain: "Backend", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey:
                            "HTTP \(http.statusCode) from \(response.url?.absoluteString ?? "?") — \(snippet)"])
        }
    }
}

// MARK: - Notes persistence (fallback if backend unreachable)

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

    /// Load transcripts from the most recent daily files (up to `days` back).
    /// Returns newest first, parsed from the "## HH:MM:SS\n\ntext" format.
    static func loadRecent(days: Int = 3) -> [PopoverState.HistoryItem] {
        let fm = FileManager.default
        let dir = Config.notesDir
        guard let names = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
        let mdFiles = names.filter { $0.hasSuffix(".md") }.sorted(by: >)
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone.current
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"

        var items: [PopoverState.HistoryItem] = []
        for name in mdFiles.prefix(days) {
            let dateStr = String(name.dropLast(3)) // strip .md → YYYY-MM-DD
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
                if body.hasPrefix("[backend unreachable") { continue }
                // Parse timestamp; fall back to file date midnight if it fails
                let date = fmt.date(from: "\(dateStr) \(header)")
                    ?? fmt.date(from: "\(dateStr) 00:00:00")
                    ?? Date()
                items.append(.init(timestamp: date, text: body))
            }
        }
        return items.sorted { $0.timestamp > $1.timestamp }
    }
}

// MARK: - Global hotkey (⌃⌥Space)

final class Hotkey {
    typealias Handler = () -> Void
    var onPress: Handler?
    var onRelease: Handler?
    private var ref: EventHotKeyRef?

    func register() {
        let sig: FourCharCode = 0x56534E50 // 'VSNP'
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

// MARK: - State

final class PopoverState: ObservableObject {
    @Published var phase: Phase = .idle
    @Published var lastText: String = ""      // the raw transcript (what was spoken)
    @Published var currentText: String = ""   // what the user sees / will paste
    @Published var customInstruction: String = ""
    @Published var isFormatting: Bool = false
    @Published var showCustom: Bool = false
    enum ViewMode: Int { case mini = 0, compact = 1, full = 2 }
    @Published var viewMode: ViewMode = {
        ViewMode(rawValue: UserDefaults.standard.integer(forKey: "viewMode")) ?? .mini
    }() {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: "viewMode") }
    }
    var compact: Bool { viewMode == .compact }
    @Published var recordingSeconds: Int = 0
    @Published var inputLevel: Double = 0      // 0..1 live mic level
    @Published var history: [HistoryItem] = []
    @Published var autoPaste: Bool = UserDefaults.standard.object(forKey: "autoPaste") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoPaste, forKey: "autoPaste") }
    }
    @Published var pushToTalk: Bool = UserDefaults.standard.object(forKey: "pushToTalk") as? Bool ?? false {
        didSet { UserDefaults.standard.set(pushToTalk, forKey: "pushToTalk") }
    }

    struct HistoryItem: Identifiable, Codable {
        var id = UUID()
        let timestamp: Date
        let text: String
    }

    enum Phase { case idle, recording, processing, done, error(String) }

    init() {
        // Prefer disk (source of truth across days); fall back to UserDefaults if disk empty.
        let fromDisk = Notes.loadRecent(days: 3)
        if !fromDisk.isEmpty {
            history = Array(fromDisk.prefix(20))
        } else if let data = UserDefaults.standard.data(forKey: "history"),
                  let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            history = decoded
        }
    }

    func addToHistory(_ text: String) {
        history.insert(.init(timestamp: Date(), text: text), at: 0)
        if history.count > 20 { history.removeLast(history.count - 20) }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: "history")
        }
    }
}

// MARK: - UI

struct LevelMeter: View {
    let level: Double  // 0..1
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(0..<20, id: \.self) { i in
                    let threshold = Double(i) / 20.0
                    let on = level > threshold
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(on ? barColor(for: threshold) : Color.secondary.opacity(0.15))
                        .frame(width: (geo.size.width - 2 * 19) / 20)
                }
            }
        }
        .frame(height: 10)
    }
    private func barColor(for t: Double) -> Color {
        if t > 0.85 { return .red }
        if t > 0.65 { return .orange }
        return .green
    }
}

struct SnippetView: View {
    @ObservedObject var state: PopoverState
    var onToggleRecord: () -> Void
    var onCancel: () -> Void
    var onFormat: (String) -> Void
    var onCustomFormat: () -> Void
    var onCopy: () -> Void
    var onPaste: () -> Void
    var onUseHistory: (PopoverState.HistoryItem) -> Void
    var onOpenFolder: () -> Void

    private let styles: [(id: String, label: String)] = [
        ("clean", "Clean"),
        ("bullets", "Bullets"),
        ("email", "Email"),
        ("formal", "Formal"),
        ("notes", "Notes"),
        ("tweet", "Tweet"),
    ]

    var body: some View {
        switch state.viewMode {
        case .mini: miniBody
        case .compact: compactBody
        case .full: fullBody
        }
    }

    // Just a mic button — the tiniest form factor
    private var miniBody: some View {
        HStack(spacing: 8) {
            Button(action: {
                state.viewMode = .compact
                onToggleRecord()
            }) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.accentColor)
                        .frame(width: 40, height: 40)
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.return)

            Button { state.viewMode = .compact } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Expand (⌃⌥Space)")
        }
        .padding(8)
    }

    // Tiny single-row layout: status + record + expand
    private var compactBody: some View {
        HStack(spacing: 10) {
            Circle().fill(dotColor).frame(width: 8, height: 8)
            Text(statusText).font(.system(size: 12, weight: .medium))
            if isRecording {
                Text(formatTime(state.recordingSeconds))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                LevelMeter(level: state.inputLevel).frame(width: 80)
            } else if !state.lastText.isEmpty {
                Text(state.currentText)
                    .font(.system(size: 11))
                    .lineLimit(1)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
            }

            Button(action: onToggleRecord) {
                Image(systemName: recordIconName).font(.system(size: 14, weight: .medium))
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .keyboardShortcut(.return)
            .tint(isRecording ? .red : .accentColor)

            Button { state.viewMode = .mini } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Collapse to mic button")

            Button { state.viewMode = .full } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("Expand full")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(minWidth: 360, maxWidth: .infinity)
    }

    private var fullBody: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Status row
            HStack(spacing: 8) {
                Circle().fill(dotColor).frame(width: 10, height: 10)
                Text(statusText).font(.system(size: 13, weight: .medium))
                if case .recording = state.phase {
                    Text(formatTime(state.recordingSeconds))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button { state.viewMode = .compact } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Collapse to compact")
                Text("⌃⌥Space").font(.system(size: 11)).foregroundColor(.secondary)
            }

            // Live audio meter while recording
            if case .recording = state.phase {
                LevelMeter(level: state.inputLevel)
            }

            // Transcript display — always visible once we have text.
            // Shows Original and Formatted side-by-side when they differ.
            if !state.lastText.isEmpty {
                let formatted = state.currentText != state.lastText && !state.currentText.isEmpty
                HStack(alignment: .top, spacing: 10) {
                    transcriptPanel(
                        title: "Original",
                        text: state.lastText,
                        accent: false,
                        copyText: state.lastText
                    )
                    if formatted {
                        transcriptPanel(
                            title: "Formatted",
                            text: state.currentText,
                            accent: true,
                            copyText: state.currentText
                        )
                    }
                }
            }

            // Action toolbar — single row with the only things that matter
            HStack(spacing: 8) {
                Button(action: onToggleRecord) {
                    Label(state.lastText.isEmpty ? "Record" : "New recording",
                          systemImage: recordIconName)
                        .font(.system(size: 13, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.return)
                .tint(isRecording ? .red : .accentColor)

                if isRecording {
                    Button("Cancel", role: .cancel, action: onCancel)
                        .controlSize(.large)
                        .keyboardShortcut(.cancelAction)
                }

                if !state.lastText.isEmpty {
                    Menu {
                        ForEach(Array(styles.enumerated()), id: \.element.id) { idx, s in
                            Button(s.label) { onFormat(s.id) }
                                .keyboardShortcut(KeyEquivalent(Character("\(idx + 1)")),
                                                  modifiers: .command)
                        }
                        Divider()
                        Button("Custom prompt…") { state.showCustom.toggle() }
                            .keyboardShortcut("k", modifiers: .command)
                        if state.currentText != state.lastText {
                            Divider()
                            Button("Revert to original") {
                                state.currentText = state.lastText
                            }
                        }
                    } label: {
                        Label(state.isFormatting ? "Formatting…" : "Format",
                              systemImage: "wand.and.stars")
                            .font(.system(size: 13))
                    }
                    .menuStyle(.borderlessButton)
                    .frame(width: 130)
                    .controlSize(.large)
                    .disabled(state.isFormatting)
                }
            }

            // Custom prompt — only visible when toggled from the Format menu
            if state.showCustom && !state.lastText.isEmpty {
                HStack(spacing: 6) {
                    TextField("e.g. make it formal like an email",
                              text: $state.customInstruction)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onSubmit { onCustomFormat() }
                    Button("Apply", action: onCustomFormat)
                        .controlSize(.small)
                        .disabled(state.isFormatting || state.customInstruction.isEmpty)
                    Button {
                        state.showCustom = false
                        state.customInstruction = ""
                    } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                }
            }

            if state.isFormatting {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.5)
                    Text("Rewriting with gemma3:4b…")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            // History (loaded from disk; up to 20 most recent across last 3 days)
            Divider()
            HStack {
                Text("Recent").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                Spacer()
                Button {
                    onOpenFolder()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "folder")
                        Text("Open all transcripts")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
            }
            if state.history.isEmpty {
                Text("No transcripts yet — record one above.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(state.history) { item in
                            Button { onUseHistory(item) } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(timeStamp(item.timestamp))
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                    Text(item.text)
                                        .font(.system(size: 11))
                                        .lineLimit(4)
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .textSelection(.enabled)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 6)
                                    .fill(Color.secondary.opacity(0.08)))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 180)
            }
        }
        .padding(12)
        .frame(minWidth: 520, maxWidth: .infinity)
    }

    @ViewBuilder
    private func transcriptPanel(title: String, text: String, accent: Bool, copyText: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accent ? .accentColor : .secondary)
                Spacer()
                Button {
                    let pb = NSPasteboard.general
                    pb.clearContents()
                    pb.setString(copyText, forType: .string)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }.font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(accent ? .accentColor : .secondary)
            }
            ScrollView {
                Text(text)
                    .font(.system(size: 12))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(minHeight: 80, maxHeight: 160)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(accent ? Color.accentColor.opacity(0.10)
                                  : Color.secondary.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(accent ? Color.accentColor.opacity(0.30) : Color.clear, lineWidth: 1)
            )
        }
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
    private func timeStamp(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "HH:mm:ss"; return f.string(from: d)
    }

    private var dotColor: Color {
        switch state.phase {
        case .idle: return .gray
        case .recording: return .red
        case .processing: return .orange
        case .done: return .green
        case .error: return .pink
        }
    }
    private var statusText: String {
        switch state.phase {
        case .idle: return "Ready"
        case .recording: return "Recording…"
        case .processing: return "Transcribing…"
        case .done: return "Saved"
        case .error(let m): return "Error: \(m)"
        }
    }
    private var recordButtonTitle: String {
        switch state.phase {
        case .recording: return "Stop"
        default: return "Record"
        }
    }
    private var isRecording: Bool {
        if case .recording = state.phase { return true }
        return false
    }
    private var recordIconName: String {
        switch state.phase {
        case .recording: return "stop.fill"
        case .processing: return "waveform"
        default: return "mic.fill"
        }
    }
}

// MARK: - Floating snippet window (ChatGPT-style centered panel)

final class FloatingSnippetWindow: NSWindow {
    init(contentView: NSView) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 680, height: 700),
                   styleMask: [.borderless, .fullSizeContentView],
                   backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovableByWindowBackground = true
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        self.contentView = contentView
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Container view that wraps the SnippetView with rounded corners and vibrant material.
struct SnippetChrome<Content: View>: View {
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content
    var body: some View {
        ZStack(alignment: .topTrailing) {
            content()
                .padding(16)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.35), radius: 24, y: 10)

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(10)
            .keyboardShortcut(.cancelAction)
        }
        .padding(8) // breathing room for the shadow
    }
}

// MARK: - App controller

final class AppController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var window: FloatingSnippetWindow?
    private let state = PopoverState()
    private let recorder = Recorder()
    private let hotkey = Hotkey()
    private var pulseTimer: Timer?
    private var recordTimer: Timer?
    private var pulseOn = false
    private var recordStart: Date?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ n: Notification) {
        NSApp.setActivationPolicy(.regular)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setMenubarIcon(.idle)
        if let btn = statusItem.button {
            btn.action = #selector(handleStatusClick)
            btn.target = self
            btn.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let root = SnippetChrome(onClose: { [weak self] in self?.hideWindow() }) {
            SnippetView(
                state: self.state,
                onToggleRecord: { [weak self] in self?.toggleRecording() },
                onCancel: { [weak self] in self?.cancelRecording() },
                onFormat: { [weak self] style in self?.format(style: style, instruction: nil) },
                onCustomFormat: { [weak self] in
                    guard let self else { return }
                    self.format(style: "clean", instruction: self.state.customInstruction)
                },
                onCopy: { [weak self] in self?.copyToPasteboard() },
                onPaste: { [weak self] in self?.paste() },
                onUseHistory: { [weak self] item in
                    guard let self else { return }
                    self.state.lastText = item.text
                    self.state.currentText = item.text
                    self.copyToPasteboard()
                },
                onOpenFolder: { NSWorkspace.shared.open(Config.notesDir) }
            )
        }
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 680, height: 700)
        window = FloatingSnippetWindow(contentView: hosting)

        // Resize window when compact state changes
        state.$viewMode
            .removeDuplicates()
            .sink { [weak self] _ in self?.applyCompactSize() }
            .store(in: &cancellables)

        // Show the window immediately on launch so Dock/Finder launch has a visible result.
        applyCompactSize()
        showWindow()

        hotkey.onPress = { [weak self] in
            guard let self else { return }
            if self.state.pushToTalk {
                if case .recording = self.state.phase { return }
                self.showWindow()
                self.toggleRecording() // starts (we guarded against re-entry above)
            } else {
                self.openAndToggle()
            }
        }
        hotkey.onRelease = { [weak self] in
            guard let self else { return }
            if self.state.pushToTalk, case .recording = self.state.phase {
                self.toggleRecording() // stops + transcribes
            }
        }
        hotkey.register()
    }

    // Show the window when user clicks the Dock icon or relaunches from Finder.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    // MARK: menubar icon (SF Symbols, adapts to light/dark)

    private enum IconState { case idle, recording, processing }
    private func setMenubarIcon(_ s: IconState) {
        guard let btn = statusItem.button else { return }
        pulseTimer?.invalidate(); pulseTimer = nil
        btn.title = ""
        switch s {
        case .idle:
            let img = NSImage(systemSymbolName: "mic", accessibilityDescription: "Voice Snippet")
            img?.isTemplate = true
            btn.image = img
            btn.contentTintColor = nil
        case .recording:
            pulseOn = true
            applyRecordingIcon(filled: true)
            pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.55, repeats: true) { [weak self] _ in
                guard let self else { return }
                self.pulseOn.toggle()
                self.applyRecordingIcon(filled: self.pulseOn)
            }
        case .processing:
            let img = NSImage(systemSymbolName: "waveform", accessibilityDescription: nil)
            img?.isTemplate = false
            btn.image = img
            btn.contentTintColor = .systemOrange
        }
    }
    private func applyRecordingIcon(filled: Bool) {
        guard let btn = statusItem.button else { return }
        let name = filled ? "record.circle.fill" : "record.circle"
        let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)
        img?.isTemplate = false
        btn.image = img
        btn.contentTintColor = .systemRed
        // Show live timer next to the dot so the menubar shows "●  0:12"
        let elapsed = Int(Date().timeIntervalSince(recordStart ?? Date()))
        btn.title = String(format: " %d:%02d", elapsed / 60, elapsed % 60)
        btn.imagePosition = .imageLeft
    }

    // MARK: menu (right-click)

    @objc private func handleStatusClick() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showMenu()
        } else {
            toggleWindow()
        }
    }

    private func applyCompactSize() {
        guard let window else { return }
        let newSize: NSSize
        switch state.viewMode {
        case .mini:    newSize = NSSize(width: 100, height: 60)
        case .compact: newSize = NSSize(width: 480, height: 88)
        case .full:    newSize = NSSize(width: 680, height: 700)
        }
        var frame = window.frame
        // Keep the top-left of the window stable so the panel "grows downward"
        let topY = frame.maxY
        frame.size = newSize
        frame.origin.y = topY - newSize.height
        // Keep horizontally on screen
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            frame.origin.x = max(vf.minX + 8, min(frame.origin.x, vf.maxX - newSize.width - 8))
        }
        window.setFrame(frame, display: true, animate: true)
    }

    private func showWindow() {
        guard let window else { return }
        if !window.isVisible {
            // Center horizontally, ~120px from the top of the active screen
            if let screen = NSScreen.main ?? NSScreen.screens.first {
                let vf = screen.visibleFrame
                let w = window.frame.width
                let h = window.frame.height
                let x = vf.midX - w / 2
                let y = vf.maxY - h - 120
                window.setFrame(NSRect(x: x, y: y, width: w, height: h), display: true)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func hideWindow() {
        window?.orderOut(nil)
    }

    private func toggleWindow() {
        guard let window else { return }
        if window.isVisible { hideWindow() } else { showWindow() }
    }

    private func showMenu() {
        let menu = NSMenu()
        let pasteItem = NSMenuItem(title: "Auto-paste after transcribe",
                                   action: #selector(toggleAutoPaste), keyEquivalent: "")
        pasteItem.target = self
        pasteItem.state = state.autoPaste ? .on : .off
        menu.addItem(pasteItem)

        let pttItem = NSMenuItem(title: "Push-to-talk (hold ⌃⌥Space)",
                                 action: #selector(togglePushToTalk), keyEquivalent: "")
        pttItem.target = self
        pttItem.state = state.pushToTalk ? .on : .off
        menu.addItem(pttItem)
        menu.addItem(.separator())
        let openItem = NSMenuItem(title: "Open voice-notes folder",
                                  action: #selector(openNotesFolder), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit Voice Snippet",
                              action: #selector(NSApp.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil // so next left-click shows popover again
    }

    @objc private func toggleAutoPaste() { state.autoPaste.toggle() }
    @objc private func togglePushToTalk() { state.pushToTalk.toggle() }
    @objc private func openNotesFolder() { NSWorkspace.shared.open(Config.notesDir) }

    // MARK: popover

    private func openAndToggle() {
        showWindow()
        if state.viewMode == .mini { state.viewMode = .compact }
        toggleRecording()
    }

    // MARK: recording flow

    private func toggleRecording() {
        switch state.phase {
        case .recording:
            stopRecordTimer()
            if let url = recorder.stop() { Task { await process(url) } }
        default:
            do {
                try recorder.start()
                state.phase = .recording
                state.recordingSeconds = 0
                state.inputLevel = 0
                recordStart = Date()
                startRecordTimer()
                setMenubarIcon(.recording)
            } catch {
                state.phase = .error(error.localizedDescription)
                setMenubarIcon(.idle)
            }
        }
    }

    private func cancelRecording() {
        stopRecordTimer()
        recorder.cancel()
        state.phase = .idle
        state.recordingSeconds = 0
        state.inputLevel = 0
        setMenubarIcon(.idle)
    }

    private func startRecordTimer() {
        recordTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordStart else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            if elapsed != self.state.recordingSeconds {
                self.state.recordingSeconds = elapsed
            }
            self.state.inputLevel = self.recorder.level()
        }
    }

    private func stopRecordTimer() {
        recordTimer?.invalidate()
        recordTimer = nil
        recordStart = nil
    }

    @MainActor
    private func process(_ url: URL) async {
        state.phase = .processing
        setMenubarIcon(.processing)
        do {
            let text = try await Backend.transcribe(fileURL: url)
            state.lastText = text
            state.currentText = text
            state.phase = .done
            state.addToHistory(text)
            setMenubarIcon(.idle)
            copyToPasteboard()
            if state.autoPaste { paste() }
        } catch {
            state.phase = .error(error.localizedDescription)
            setMenubarIcon(.idle)
            Notes.append("[backend unreachable; audio at \(url.path)]")
        }
    }

    // MARK: format

    @MainActor
    private func format(style: String, instruction: String?) {
        guard !state.lastText.isEmpty else { return }
        state.isFormatting = true
        Task {
            defer { self.state.isFormatting = false }
            do {
                let formatted = try await Backend.format(
                    text: state.lastText, style: style, instruction: instruction
                )
                state.currentText = formatted
                copyToPasteboard()
            } catch {
                state.phase = .error(error.localizedDescription)
            }
        }
    }

    // MARK: clipboard / paste

    private func copyToPasteboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(state.currentText, forType: .string)
    }

    private func paste() {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        down?.flags = .maskCommand; up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
    }
}

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.run()
