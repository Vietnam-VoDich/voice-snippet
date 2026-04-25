import AppKit
import SwiftUI

extension Color {
    static let accent = Color(red: 0.20, green: 0.45, blue: 0.90)
}

// Transparent area that lets the user drag the window.
// Use as `.background(WindowDragHandle())` — buttons drawn on top still receive clicks.
struct WindowDragHandle: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { DragNSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class DragNSView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
        override func hitTest(_ point: NSPoint) -> NSView? {
            bounds.contains(point) ? self : nil
        }
    }
}

// MARK: - Components

struct LevelMeter: View {
    let level: Double
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 1.5) {
                ForEach(0..<16, id: \.self) { i in
                    let t = Double(i) / 16.0
                    RoundedRectangle(cornerRadius: 1)
                        .fill(level > t ? barColor(for: t) : Color.primary.opacity(0.06))
                        .frame(width: max(2, (geo.size.width - 1.5 * 15) / 16))
                }
            }
        }
        .frame(height: 6)
    }
    private func barColor(for t: Double) -> Color {
        if t > 0.85 { return .red.opacity(0.8) }
        if t > 0.65 { return .orange.opacity(0.7) }
        return .green.opacity(0.6)
    }
}

struct CopiedFlash: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 12, weight: .bold))
            Text("Copied")
                .font(.system(size: 12, weight: .medium))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Capsule().fill(.black.opacity(0.7)))
    }
}

// MARK: - Chrome wrapper

struct SnippetChrome<Content: View>: View {
    @ObservedObject var state: AppState
    var onClose: () -> Void
    @ViewBuilder var content: () -> Content
    @Environment(\.colorScheme) private var colorScheme
    private let radius: CGFloat = 22

    private var cardBackground: Color {
        colorScheme == .dark
            ? Color(red: 0.12, green: 0.13, blue: 0.16)
            : Color.white
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(cardBackground,
                            in: RoundedRectangle(cornerRadius: state.viewMode == .mini ? 18 : 22,
                                                  style: .continuous))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.16),
                        radius: 16, y: 6)

            if state.viewMode == .tabbed {
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(10)
                .keyboardShortcut(.cancelAction)
            }
        }
        .padding(state.viewMode == .mini ? 8 : 12)
    }
}

// MARK: - Root view

struct RootView: View {
    @ObservedObject var state: AppState
    var actions: AppActions

    var body: some View {
        switch state.viewMode {
        case .mini: MiniPill(state: state, actions: actions)
        case .tabbed: TabbedView(state: state, actions: actions)
        }
    }
}

struct AppActions {
    var toggleRecord: () -> Void
    var cancelRecord: () -> Void
    var format: (String, String?) -> Void
    var openFolder: () -> Void
    var useHistory: (HistoryItem) -> Void
}

// MARK: - Mini pill

struct MiniPill: View {
    @ObservedObject var state: AppState
    var actions: AppActions

    private var isRecording: Bool {
        if case .recording = state.phase { return true }; return false
    }

    var body: some View {
        HStack(spacing: 10) {
            // Expand button
            Button { state.viewMode = .tabbed } label: {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.accent)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.accent.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .help("Expand to full view")

            // Status / last transcript preview — drag area
            ZStack(alignment: .leading) {
                WindowDragHandle()
                VStack(alignment: .leading, spacing: 2) {
                    if isRecording {
                        HStack(spacing: 6) {
                            Circle().fill(.red).frame(width: 6, height: 6)
                            Text("Recording… \(formatTime(state.recordingSeconds))")
                                .font(.system(size: 12, weight: .medium))
                            LevelMeter(level: state.inputLevel).frame(width: 60)
                        }
                    } else if !state.lastText.isEmpty {
                        Text(state.currentText)
                            .font(.system(size: 12))
                            .lineLimit(1)
                            .foregroundColor(.primary)
                    } else {
                        Text("Voice Snippet")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Mic button
            Button(action: actions.toggleRecord) {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red.gradient : Color.accent.gradient)
                        .frame(width: 36, height: 36)
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private func formatTime(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Tabbed view (bottom tab bar)

struct TabbedView: View {
    @ObservedObject var state: AppState
    var actions: AppActions

    var body: some View {
        VStack(spacing: 0) {
            // Persistent top header — always-visible mode controls
            HStack(spacing: 8) {
                Button { state.viewMode = .mini } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 10, weight: .semibold))
                        Text("Mini")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.accent)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 6)
                        .fill(Color.accent.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .help("Fold to mini widget")

                Spacer()

                Text(state.selectedTab.label)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .padding(.trailing, 28)  // clear the close X in the top-right corner
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .background(WindowDragHandle())

            Divider().opacity(0.3)

            // Tab content
            Group {
                switch state.selectedTab {
                case .record:     RecordTab(state: state, actions: actions)
                case .history:    HistoryTab(state: state, actions: actions)
                case .dictionary: DictionaryTab(store: state.dictionary)
                case .settings:   SettingsTab(state: state, actions: actions)
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom tab bar
            Divider().opacity(0.3)
            HStack(spacing: 0) {
                ForEach(AppTab.allCases, id: \.self) { tab in
                    Button {
                        state.selectedTab = tab
                    } label: {
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 16))
                            Text(tab.label)
                                .font(.system(size: 10))
                        }
                        .foregroundColor(state.selectedTab == tab ? .accent : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Record tab

struct RecordTab: View {
    @ObservedObject var state: AppState
    var actions: AppActions

    private let styles: [(id: String, label: String)] = [
        ("clean", "Clean"), ("bullets", "Bullets"), ("email", "Email"),
        ("formal", "Formal"), ("notes", "Notes"), ("tweet", "Tweet"),
    ]

    private var isRecording: Bool {
        if case .recording = state.phase { return true }; return false
    }

    var body: some View {
        ZStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    Spacer().frame(height: 4)
                    // Status
                    HStack(spacing: 6) {
                        Circle().fill(dotColor).frame(width: 8, height: 8)
                        Text(statusText).font(.system(size: 12, weight: .medium))
                        if isRecording {
                            Text(formatTime(state.recordingSeconds))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    // Audio meter
                    if isRecording {
                        LevelMeter(level: state.inputLevel)
                    }

                    // Transcript
                    if !state.lastText.isEmpty {
                        let hasFormatted = state.currentText != state.lastText && !state.currentText.isEmpty
                        VStack(alignment: .leading, spacing: 8) {
                            transcriptCard(label: "Original", text: $state.lastText, accent: false)
                            if hasFormatted {
                                transcriptCard(label: "Formatted", text: $state.currentText, accent: true)
                            }
                        }
                    }

                    // Record button — centered circle
                    HStack {
                        Spacer()
                        VStack(spacing: 6) {
                            Button(action: actions.toggleRecord) {
                                ZStack {
                                    Circle()
                                        .fill(isRecording ? Color.red.gradient : Color.accent.gradient)
                                        .frame(width: 56, height: 56)
                                        .shadow(color: (isRecording ? Color.red : .accent).opacity(0.3),
                                                radius: 8, y: 3)
                                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                                        .font(.system(size: 22, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                            Text(isRecording ? "Tap to stop" : (state.lastText.isEmpty ? "Tap to record" : "New recording"))
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }

                    // Cancel + Format row
                    if isRecording || (!state.lastText.isEmpty && !isRecording) {
                        HStack(spacing: 10) {
                            if isRecording {
                                Button("Cancel", role: .cancel, action: actions.cancelRecord)
                                    .controlSize(.small)
                            }
                            Spacer()
                            if !state.lastText.isEmpty && !isRecording {
                                Menu {
                                    ForEach(Array(styles.enumerated()), id: \.element.id) { idx, s in
                                        Button(s.label) { actions.format(s.id, nil) }
                                            .keyboardShortcut(KeyEquivalent(Character("\(idx + 1)")),
                                                              modifiers: .command)
                                    }
                                    Divider()
                                    Button("Custom prompt…") { state.showCustom.toggle() }
                                    if state.currentText != state.lastText {
                                        Divider()
                                        Button("Revert to original") {
                                            state.currentText = state.lastText
                                        }
                                    }
                                } label: {
                                    Label("Format", systemImage: "wand.and.stars")
                                        .font(.system(size: 12))
                                }
                                .menuStyle(.borderlessButton)
                                .controlSize(.regular)
                                .disabled(state.isFormatting)
                            }
                        }
                    }

                    // Custom prompt
                    if state.showCustom && !state.lastText.isEmpty {
                        HStack(spacing: 6) {
                            TextField("e.g. make it formal like an email",
                                      text: $state.customInstruction)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                                .onSubmit { actions.format("clean", state.customInstruction) }
                            Button("Apply") { actions.format("clean", state.customInstruction) }
                                .controlSize(.small)
                                .disabled(state.isFormatting || state.customInstruction.isEmpty)
                            Button { state.showCustom = false } label: {
                                Image(systemName: "xmark").font(.system(size: 10))
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondary)
                        }
                    }

                    if state.isFormatting {
                        HStack(spacing: 6) {
                            ProgressView().scaleEffect(0.5)
                            Text("Rewriting…").font(.system(size: 11)).foregroundColor(.secondary)
                        }
                    }
                }
                .padding(.bottom, 12)
            }

            // Copied flash overlay
            if state.showCopiedFlash {
                VStack {
                    Spacer()
                    CopiedFlash()
                    Spacer().frame(height: 60)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                .animation(.easeOut(duration: 0.25), value: state.showCopiedFlash)
            }
        }
    }

    @ViewBuilder
    private func transcriptCard(label: String, text: Binding<String>, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accent ? .accent : .secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text.wrappedValue, forType: .string)
                    state.flashCopied()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }.font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(accent ? .accent : .secondary)
            }
            TextField("", text: text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent ? Color.accent.opacity(0.06) : Color.primary.opacity(0.04))
                )
        }
    }

    private var dotColor: Color {
        switch state.phase {
        case .idle: return .gray; case .recording: return .red
        case .processing: return .orange; case .done: return .green
        case .error: return .pink
        }
    }
    private var statusText: String {
        switch state.phase {
        case .idle: return "Ready"; case .recording: return "Recording…"
        case .processing: return "Transcribing…"; case .done: return "Saved"
        case .error(let m): return "Error: \(m)"
        }
    }
    private func formatTime(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - History tab

struct HistoryTab: View {
    @ObservedObject var state: AppState
    var actions: AppActions

    private var filtered: [HistoryItem] {
        if state.historySearch.isEmpty { return state.history }
        let q = state.historySearch.lowercased()
        return state.history.filter { $0.text.lowercased().contains(q) }
    }

    private var grouped: [(String, [HistoryItem])] {
        let df = DateFormatter()
        df.dateFormat = "EEEE, MMM d"
        var groups: [(String, [HistoryItem])] = []
        var currentKey = ""
        var currentItems: [HistoryItem] = []
        for item in filtered {
            let key = df.string(from: item.timestamp)
            if key != currentKey {
                if !currentItems.isEmpty { groups.append((currentKey, currentItems)) }
                currentKey = key
                currentItems = []
            }
            currentItems.append(item)
        }
        if !currentItems.isEmpty { groups.append((currentKey, currentItems)) }
        return groups
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                    .font(.system(size: 12))
                TextField("Search transcripts", text: $state.historySearch)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                if !state.historySearch.isEmpty {
                    Button { state.historySearch = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.04)))

            if filtered.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "clock").font(.system(size: 24)).foregroundStyle(.tertiary)
                    Text(state.history.isEmpty ? "No transcripts yet" : "No results")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(grouped, id: \.0) { dateLabel, items in
                            Text(dateLabel)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.secondary)
                            ForEach(items) { item in
                                HistoryRow(item: item) {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(item.text, forType: .string)
                                    state.flashCopied()
                                } onReformat: {
                                    actions.useHistory(item)
                                    state.selectedTab = .record
                                }
                            }
                        }
                    }
                }
            }

            HStack {
                Spacer()
                Button { actions.openFolder() } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "folder")
                        Text("Open folder")
                    }
                    .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accent)
            }
        }
    }
}

struct HistoryRow: View {
    let item: HistoryItem
    var onCopy: () -> Void
    var onReformat: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.timestamp, format: .dateTime.hour().minute().second())
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)
                Spacer()
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc").font(.system(size: 10))
                }
                .buttonStyle(.plain).foregroundColor(.secondary)
                Button(action: onReformat) {
                    Image(systemName: "wand.and.stars").font(.system(size: 10))
                }
                .buttonStyle(.plain).foregroundColor(.secondary)
            }
            Text(item.text)
                .font(.system(size: 11))
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.primary.opacity(0.03)))
    }
}

// MARK: - Dictionary tab

struct DictionaryTab: View {
    @ObservedObject var store: DictionaryStore
    @State private var newTerm = ""
    @State private var newCorrected = ""
    @State private var newContext = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Custom vocabulary and context for better transcription and formatting.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            // Add form
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    TextField("Heard (e.g. deep world)", text: $newTerm)
                        .textFieldStyle(.roundedBorder).font(.system(size: 12))
                    Image(systemName: "arrow.right").foregroundStyle(.tertiary)
                    TextField("Correct (e.g. DP World)", text: $newCorrected)
                        .textFieldStyle(.roundedBorder).font(.system(size: 12))
                }
                HStack(spacing: 6) {
                    TextField("Context (optional): e.g. DP World is a port operator in Dubai",
                              text: $newContext)
                        .textFieldStyle(.roundedBorder).font(.system(size: 11))
                    Button("Add") {
                        guard !newTerm.isEmpty, !newCorrected.isEmpty else { return }
                        store.add(.init(term: newTerm, correctedTerm: newCorrected, context: newContext))
                        newTerm = ""; newCorrected = ""; newContext = ""
                    }
                    .controlSize(.small)
                    .disabled(newTerm.isEmpty || newCorrected.isEmpty)
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.03)))

            Divider().opacity(0.3)

            if store.entries.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "book").font(.system(size: 24)).foregroundStyle(.tertiary)
                    Text("No entries yet. Add terms that Whisper gets wrong.")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.entries) { entry in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: 4) {
                                        Text(entry.term)
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                            .strikethrough()
                                        Image(systemName: "arrow.right")
                                            .font(.system(size: 9))
                                            .foregroundStyle(.tertiary)
                                        Text(entry.correctedTerm)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    if !entry.context.isEmpty {
                                        Text(entry.context)
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                            .lineLimit(2)
                                    }
                                }
                                Spacer()
                                Button { store.delete(entry) } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(8)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.03)))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Settings tab

struct SettingsTab: View {
    @ObservedObject var state: AppState
    var actions: AppActions

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hotkeys
            VStack(alignment: .leading, spacing: 6) {
                Text("Keyboard shortcuts").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    Text("⌥Q")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                    Text("Show / hide window")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                HStack(spacing: 8) {
                    Text("⌥W")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                    Text("Record now — start / stop")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }

            Divider().opacity(0.3)

            // Toggles
            Toggle("Auto-paste into frontmost app", isOn: $state.autoPaste)
                .font(.system(size: 12))
            Toggle("Push-to-talk (hold ⌥W)", isOn: $state.pushToTalk)
                .font(.system(size: 12))

            Divider().opacity(0.3)

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text("Engine").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                Text("Speech: distil-whisper-large-v3 (WhisperKit, on-device)")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                Text("Format: Apple Foundation Models (on-device)")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }

            Divider().opacity(0.3)

            HStack {
                Button { actions.openFolder() } label: {
                    Label("Open voice-notes folder", systemImage: "folder")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain).foregroundColor(.accent)
                Spacer()
            }

            Spacer()

            Text("Voice Snippet · v0.4.0")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
