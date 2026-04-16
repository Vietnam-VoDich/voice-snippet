import Foundation

// MARK: - History item (shared across Notes + State)

struct HistoryItem: Identifiable, Codable {
    var id = UUID()
    let timestamp: Date
    let text: String
}

// MARK: - Dictionary (custom vocabulary + context)

struct DictionaryEntry: Identifiable, Codable {
    var id = UUID()
    var term: String
    var correctedTerm: String
    var context: String
}

final class DictionaryStore: ObservableObject {
    @Published var entries: [DictionaryEntry] = []

    init() { load() }

    var correctionMap: [String: String] {
        Dictionary(entries.map { ($0.term.lowercased(), $0.correctedTerm) },
                   uniquingKeysWith: { _, last in last })
    }

    var contextBlock: String {
        entries.compactMap { e in
            e.context.isEmpty ? nil : "- \(e.correctedTerm): \(e.context)"
        }.joined(separator: "\n")
    }

    func applyCorrections(to text: String) -> String {
        var result = text
        for entry in entries where !entry.term.isEmpty && !entry.correctedTerm.isEmpty {
            result = result.replacingOccurrences(
                of: entry.term, with: entry.correctedTerm,
                options: .caseInsensitive
            )
        }
        return result
    }

    func add(_ entry: DictionaryEntry) {
        entries.append(entry)
        save()
    }

    func update(_ entry: DictionaryEntry) {
        if let i = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[i] = entry
            save()
        }
    }

    func delete(_ entry: DictionaryEntry) {
        entries.removeAll { $0.id == entry.id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: Config.dictionaryURL),
              let decoded = try? JSONDecoder().decode([DictionaryEntry].self, from: data)
        else { return }
        entries = decoded
    }

    private func save() {
        try? FileManager.default.createDirectory(at: Config.notesDir, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: Config.dictionaryURL)
        }
    }
}

// MARK: - App state

enum AppTab: Int, CaseIterable {
    case record, history, dictionary, settings
    var label: String {
        switch self {
        case .record: return "Record"
        case .history: return "History"
        case .dictionary: return "Dictionary"
        case .settings: return "Settings"
        }
    }
    var icon: String {
        switch self {
        case .record: return "mic.fill"
        case .history: return "clock"
        case .dictionary: return "book"
        case .settings: return "gearshape"
        }
    }
}

enum ViewMode: Int { case mini = 0, tabbed = 1 }
enum Phase { case idle, recording, processing, done, error(String) }

final class AppState: ObservableObject {
    @Published var phase: Phase = .idle
    @Published var lastText: String = ""
    @Published var currentText: String = ""
    @Published var customInstruction: String = ""
    @Published var isFormatting: Bool = false
    @Published var showCustom: Bool = false
    @Published var showCopiedFlash: Bool = false

    @Published var viewMode: ViewMode = {
        ViewMode(rawValue: UserDefaults.standard.integer(forKey: "viewMode")) ?? .mini
    }() {
        didSet { UserDefaults.standard.set(viewMode.rawValue, forKey: "viewMode") }
    }

    @Published var selectedTab: AppTab = .record
    @Published var recordingSeconds: Int = 0
    @Published var inputLevel: Double = 0
    @Published var history: [HistoryItem] = []
    @Published var historySearch: String = ""

    @Published var autoPaste: Bool = UserDefaults.standard.object(forKey: "autoPaste") as? Bool ?? true {
        didSet { UserDefaults.standard.set(autoPaste, forKey: "autoPaste") }
    }
    @Published var pushToTalk: Bool = UserDefaults.standard.object(forKey: "pushToTalk") as? Bool ?? false {
        didSet { UserDefaults.standard.set(pushToTalk, forKey: "pushToTalk") }
    }

    let dictionary = DictionaryStore()

    init() {
        let fromDisk = Notes.loadAll()
        if !fromDisk.isEmpty {
            history = fromDisk
        } else if let data = UserDefaults.standard.data(forKey: "history"),
                  let decoded = try? JSONDecoder().decode([HistoryItem].self, from: data) {
            history = decoded
        }
    }

    func addToHistory(_ text: String) {
        history.insert(.init(timestamp: Date(), text: text), at: 0)
        if let data = try? JSONEncoder().encode(Array(history.prefix(100))) {
            UserDefaults.standard.set(data, forKey: "history")
        }
    }

    func flashCopied() {
        showCopiedFlash = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.showCopiedFlash = false
        }
    }
}
