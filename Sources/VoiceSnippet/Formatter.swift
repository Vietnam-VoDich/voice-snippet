import Foundation
import FoundationModels

enum Formatter {
    static let stylePrompts: [String: String] = [
        "clean": """
            Rewrite the user's dictated text. Remove filler words (um, uh, like, you know), \
            fix obvious speech-to-text errors, and add punctuation. Preserve the meaning and \
            tone exactly. Return only the rewritten text with no preamble.
            """,
        "bullets": """
            Convert the user's dictated text into a tight bulleted list. One idea per bullet, \
            no nesting unless strictly necessary. Return only the bullets.
            """,
        "email": """
            Rewrite the user's dictated text as the body of a friendly, professional email. \
            No subject line, no greeting, no signature — just the body. Return only the body.
            """,
        "formal": """
            Rewrite the user's dictated text in a polished, formal business register. \
            Keep the meaning intact. Return only the rewritten text.
            """,
        "notes": """
            Convert the user's dictated text into meeting-style notes with short headers \
            and bullets under each. Return only the notes.
            """,
        "tweet": """
            Rewrite the user's dictated text as a single punchy tweet under 280 characters. \
            No hashtags unless present in the original. Return only the tweet.
            """,
    ]

    static func format(text: String, style: String, instruction: String?) async throws -> String {
        guard let basePrompt = stylePrompts[style] else {
            throw FormatterError.unknownStyle(style)
        }

        switch SystemLanguageModel.default.availability {
        case .available:
            break
        case .unavailable(.appleIntelligenceNotEnabled):
            throw FormatterError.unavailable(
                "Apple Intelligence is off. Turn it on in System Settings → Apple Intelligence & Siri.")
        case .unavailable(.deviceNotEligible):
            throw FormatterError.unavailable(
                "This Mac doesn't support Apple Intelligence — Foundation Models can't run here.")
        case .unavailable(.modelNotReady):
            throw FormatterError.unavailable(
                "Apple Intelligence model is still downloading. Try again in a minute.")
        case .unavailable(let other):
            throw FormatterError.unavailable("Apple Intelligence unavailable: \(other).")
        }

        var instructions = basePrompt
        if let instruction, !instruction.isEmpty {
            instructions += "\n\nExtra instruction from the user: \(instruction)"
        }

        let session = LanguageModelSession(instructions: instructions)
        let options = GenerationOptions(temperature: 0.2)
        let response = try await session.respond(to: text, options: options)
        return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum FormatterError: LocalizedError {
    case unknownStyle(String)
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unknownStyle(let style): return "Unknown style: \(style)"
        case .unavailable(let reason): return reason
        }
    }
}
