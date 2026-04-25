import AppKit
import Carbon.HIToolbox
import Combine
import SwiftUI

// MARK: - Floating window

final class FloatingSnippetWindow: NSWindow {
    init(contentView: NSView) {
        super.init(contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
                   styleMask: [.borderless, .fullSizeContentView],
                   backing: .buffered, defer: false)
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false  // SwiftUI draws the shadow; the system shadow would show a hard edge around the rounded corners
        isMovableByWindowBackground = false  // dragging is handled explicitly via WindowDragHandle
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        collectionBehavior = [.canJoinAllSpaces, .transient, .fullScreenAuxiliary]
        isReleasedWhenClosed = false
        self.contentView = contentView
    }
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - App controller

final class AppController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var window: FloatingSnippetWindow?
    private let state = AppState()
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

        let actions = AppActions(
            toggleRecord: { [weak self] in self?.toggleRecording() },
            cancelRecord: { [weak self] in self?.cancelRecording() },
            format: { [weak self] style, instruction in self?.format(style: style, instruction: instruction) },
            openFolder: { NSWorkspace.shared.open(Config.notesDir) },
            useHistory: { [weak self] item in
                guard let self else { return }
                self.state.lastText = item.text
                self.state.currentText = item.text
                self.copyToPasteboard()
            }
        )

        let root = SnippetChrome(state: state, onClose: { [weak self] in self?.hideWindow() }) {
            RootView(state: self.state, actions: actions)
        }
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(x: 0, y: 0, width: 440, height: 560)
        window = FloatingSnippetWindow(contentView: hosting)

        state.$viewMode
            .dropFirst()
            .removeDuplicates()
            .receive(on: DispatchQueue.main)  // fire AFTER the @Published value is stored and SwiftUI has updated
            .sink { [weak self] newMode in self?.applySize(for: newMode) }
            .store(in: &cancellables)

        applySize(for: state.viewMode)
        showWindow()

        // ⌥Q — toggle show / hide window
        hotkey.onPress[1] = { [weak self] in self?.openAndToggle() }

        // ⌥W — record now (show if hidden, start/stop recording). Also handles push-to-talk.
        hotkey.onPress[2] = { [weak self] in
            guard let self else { return }
            if self.state.pushToTalk {
                if case .recording = self.state.phase { return }
                self.showWindow()
                self.toggleRecording()
            } else {
                if let w = self.window, !w.isVisible { self.showWindow() }
                self.toggleRecording()
            }
        }
        hotkey.onRelease[2] = { [weak self] in
            guard let self else { return }
            if self.state.pushToTalk, case .recording = self.state.phase {
                self.toggleRecording()
            }
        }
        hotkey.register()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showWindow()
        return true
    }

    // MARK: - Menubar icon

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
        let elapsed = Int(Date().timeIntervalSince(recordStart ?? Date()))
        btn.title = String(format: " %d:%02d", elapsed / 60, elapsed % 60)
        btn.imagePosition = .imageLeft
    }

    // MARK: - Window management

    @objc private func handleStatusClick() {
        if NSApp.currentEvent?.type == .rightMouseUp { showMenu() }
        else { toggleWindow() }
    }

    private func applySize(for mode: ViewMode) {
        guard let window else { return }
        let sz: NSSize = mode == .mini
            ? NSSize(width: 420, height: 72)
            : NSSize(width: 440, height: 500)
        var frame = window.frame
        let topY = frame.maxY
        frame.size = sz
        frame.origin.y = topY - sz.height
        if let screen = NSScreen.main {
            let vf = screen.visibleFrame
            frame.origin.x = max(vf.minX + 8, min(frame.origin.x, vf.maxX - sz.width - 8))
        }
        window.setFrame(frame, display: true, animate: false)
    }

    private func showWindow() {
        guard let window else { return }
        if !window.isVisible {
            if let screen = NSScreen.main ?? NSScreen.screens.first {
                let vf = screen.visibleFrame
                let w = window.frame.width, h = window.frame.height
                window.setFrame(NSRect(x: vf.midX - w/2, y: vf.maxY - h - 120, width: w, height: h),
                                display: true)
            }
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func hideWindow() { window?.orderOut(nil) }

    private func toggleWindow() {
        guard let window else { return }
        if window.isVisible { hideWindow() } else { showWindow() }
    }

    private func openAndToggle() {
        guard let window else { return }
        if !window.isVisible {
            showWindow()
        } else {
            hideWindow()
        }
    }

    // MARK: - Right-click menu

    private func showMenu() {
        let menu = NSMenu()
        let paste = NSMenuItem(title: "Auto-paste after transcribe",
                               action: #selector(toggleAutoPaste), keyEquivalent: "")
        paste.target = self; paste.state = state.autoPaste ? .on : .off
        menu.addItem(paste)
        let ptt = NSMenuItem(title: "Push-to-talk (hold ⌥W)",
                             action: #selector(togglePushToTalk), keyEquivalent: "")
        ptt.target = self; ptt.state = state.pushToTalk ? .on : .off
        menu.addItem(ptt)
        menu.addItem(.separator())
        let open = NSMenuItem(title: "Open voice-notes folder",
                              action: #selector(openNotesFolder), keyEquivalent: "")
        open.target = self; menu.addItem(open)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Voice Snippet",
                                action: #selector(NSApp.terminate(_:)), keyEquivalent: "q"))
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleAutoPaste() { state.autoPaste.toggle() }
    @objc private func togglePushToTalk() { state.pushToTalk.toggle() }
    @objc private func openNotesFolder() { NSWorkspace.shared.open(Config.notesDir) }

    // MARK: - Recording

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
            if elapsed != self.state.recordingSeconds { self.state.recordingSeconds = elapsed }
            self.state.inputLevel = self.recorder.level()
        }
    }

    private func stopRecordTimer() {
        recordTimer?.invalidate(); recordTimer = nil; recordStart = nil
    }

    @MainActor
    private func process(_ url: URL) async {
        state.phase = .processing
        setMenubarIcon(.processing)
        do {
            var text = try await Transcriber.shared.transcribe(fileURL: url)
            text = state.dictionary.applyCorrections(to: text)
            state.lastText = text
            state.currentText = text
            state.phase = .done
            state.addToHistory(text)
            Notes.append(text)
            setMenubarIcon(.idle)
            copyToPasteboard()
            state.flashCopied()
            if state.autoPaste { paste() }
        } catch {
            state.phase = .error(error.localizedDescription)
            setMenubarIcon(.idle)
            Notes.append("[transcription failed; audio at \(url.path)]")
        }
    }

    // MARK: - Format

    @MainActor
    private func format(style: String, instruction: String?) {
        guard !state.lastText.isEmpty else { return }
        state.isFormatting = true
        Task {
            defer { self.state.isFormatting = false }
            do {
                var fullInstruction = instruction ?? ""
                let ctx = state.dictionary.contextBlock
                if !ctx.isEmpty {
                    fullInstruction = "Context:\n\(ctx)\n\n\(fullInstruction)"
                }
                let formatted = try await Formatter.format(
                    text: state.lastText, style: style,
                    instruction: fullInstruction.isEmpty ? nil : fullInstruction
                )
                state.currentText = formatted
                copyToPasteboard()
                state.flashCopied()
            } catch {
                state.phase = .error(error.localizedDescription)
            }
        }
    }

    // MARK: - Clipboard

    private func copyToPasteboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(state.currentText, forType: .string)
    }

    private func paste() {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: CGKeyCode(kVK_ANSI_V), keyDown: false)
        down?.flags = .maskCommand; up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap); up?.post(tap: .cghidEventTap)
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let controller = AppController()
app.delegate = controller
app.run()
