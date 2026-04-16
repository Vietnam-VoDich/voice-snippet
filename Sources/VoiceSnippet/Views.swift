import AppKit
import SwiftUI

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
    private let radius: CGFloat = 22

    var body: some View {
        if state.viewMode == .mini {
            content()
                .background(Capsule(style: .continuous).fill(.regularMaterial))
                .clipShape(Capsule(style: .continuous))
                .shadow(color: .black.opacity(0.20), radius: 16, y: 6)
                .padding(8)
        } else {
            ZStack(alignment: .topTrailing) {
                content()
                    .background(.regularMaterial,
                                in: RoundedRectangle(cornerRadius: radius, style: .continuous))
                    .shadow(color: .black.opacity(0.22), radius: 20, y: 8)
                    .shadow(color: .black.opacity(0.08), radius: 3, y: 1)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .padding(10)
                .keyboardShortcut(.cancelAction)
            }
            .padding(12)
        }
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
        HStack(spacing: 6) {
            Button {
                state.viewMode = .tabbed
                state.selectedTab = .record
                actions.toggleRecord()
            } label: {
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red.gradient : Color.accentColor.gradient)
                        .frame(width: 36, height: 36)
                        .shadow(color: (isRecording ? Color.red : .accentColor).opacity(0.35), radius: 6, y: 2)
                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(.plain)

            Button { state.viewMode = .tabbed } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }
}

// MARK: - Tabbed view (bottom tab bar)

struct TabbedView: View {
    @ObservedObject var state: AppState
    var actions: AppActions

    var body: some View {
        VStack(spacing: 0) {
            // Tab content
            Group {
                switch state.selectedTab {
                case .record:     RecordTab(state: state, actions: actions)
                case .history:    HistoryTab(state: state, actions: actions)
                case .dictionary: DictionaryTab(store: state.dictionary)
                case .settings:   SettingsTab(state: state, actions: actions)
                }
            }
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
                        .foregroundColor(state.selectedTab == tab ? .accentColor : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 4)
        }
        .padding(.top, 12)
        .padding(.horizontal, 16)
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
                        Button { state.viewMode = .mini } label: {
                            Image(systemName: "minus")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                        .buttonStyle(.plain)
                        .help("Minimize")
                    }

                    // Audio meter
                    if isRecording {
                        LevelMeter(level: state.inputLevel)
                    }

                    // Transcript
                    if !state.lastText.isEmpty {
                        let hasFormatted = state.currentText != state.lastText && !state.currentText.isEmpty
                        VStack(alignment: .leading, spacing: 8) {
                            transcriptCard(label: "Original", text: state.lastText, accent: false)
                            if hasFormatted {
                                transcriptCard(label: "Formatted", text: state.currentText, accent: true)
                            }
                        }
                    }

                    // Record button
                    HStack(spacing: 8) {
                        Button(action: actions.toggleRecord) {
                            Label(isRecording ? "Stop" : (state.lastText.isEmpty ? "Record" : "New recording"),
                                  systemImage: isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 13, weight: .medium))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 2)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .tint(isRecording ? .red : .accentColor)

                        if isRecording {
                            Button("Cancel", role: .cancel, action: actions.cancelRecord)
                                .controlSize(.large)
                        }

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
                                    .font(.system(size: 13))
                            }
                            .menuStyle(.borderlessButton)
                            .frame(width: 120)
                            .controlSize(.large)
                            .disabled(state.isFormatting)
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
    private func transcriptCard(label: String, text: String, accent: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.system(size: 10, weight: .semibold))
                    .foregroundColor(accent ? .accentColor : .secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    state.flashCopied()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy")
                    }.font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .foregroundColor(accent ? .accentColor : .secondary)
            }
            Text(text)
                .font(.system(size: 12))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(accent ? Color.accentColor.opacity(0.06) : Color.primary.opacity(0.04))
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
                .foregroundColor(.accentColor)
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
            // Hotkey
            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard shortcut").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                HStack(spacing: 8) {
                    Text("⌃⌥Space")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.05)))
                    Text("Control + Option + Space")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                Text("Hidden → Record → Stop → Hide")
                    .font(.system(size: 10)).foregroundStyle(.tertiary)
            }

            Divider().opacity(0.3)

            // Toggles
            Toggle("Auto-paste into frontmost app", isOn: $state.autoPaste)
                .font(.system(size: 12))
            Toggle("Push-to-talk (hold ⌃⌥Space)", isOn: $state.pushToTalk)
                .font(.system(size: 12))

            Divider().opacity(0.3)

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text("Backend").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                HStack {
                    Text(Config.backendBase.absoluteString)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                }
                Text("STT: distil-whisper-large-v3 (mlx-whisper)")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                Text("Format: gemma3:4b via Ollama")
                    .font(.system(size: 11)).foregroundColor(.secondary)
            }

            Divider().opacity(0.3)

            HStack {
                Button { actions.openFolder() } label: {
                    Label("Open voice-notes folder", systemImage: "folder")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain).foregroundColor(.accentColor)
                Spacer()
            }

            Spacer()

            Text("Hamilton Voice · v0.2.0")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }
}
