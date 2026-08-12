//
//  StepOneContent.swift
//  StepOne
//
//  Trip copy, milestones and UI strings, loaded from StepOneContent.json.
//  The JSON is generated from the StepOne design source and holds all eight
//  languages, so nothing here is hand-transcribed.
//

import Foundation

// MARK: - Model

struct TripSpec: Codable, Hashable, Identifiable {
    let title: String
    let desc: String
    let photo: String
    let emoji: String
    let hue: Double
    let meters: Int

    var id: String { title }
}

struct Milestone: Codable, Hashable {
    let km: Double
    let dist: String
    let name: String
    let desc: String

    var meters: Double { km * 1000 }
}

struct LanguageSpec: Codable, Hashable {
    let id: String
    let native: String
}

struct OnboardingCard: Codable, Hashable, Identifiable {
    let id: String
    let title: String
    let desc: String
    let emoji: String
    let m: Int
}

struct StepOneContent: Codable {
    let version: String
    let journeyBase: Int
    let slot: Double
    let languages: [LanguageSpec]
    let categories: [String]
    let milestones: [Milestone]
    let onboardingCards: [OnboardingCard]
    let strings: [String: [String: String]]
    let trips: [String: [String: [TripSpec]]]

    static let shared: StepOneContent = load()

    private static func load() -> StepOneContent {
        guard let url = Bundle.main.url(forResource: "StepOneContent", withExtension: "json") else {
            fatalError("StepOneContent.json is missing from the app bundle")
        }
        do {
            return try JSONDecoder().decode(StepOneContent.self, from: Data(contentsOf: url))
        } catch {
            fatalError("StepOneContent.json could not be decoded: \(error)")
        }
    }

    func trips(lang: String, category: String) -> [TripSpec] {
        trips[lang]?[category] ?? trips["en"]?[category] ?? []
    }

    /// Milestone phases. The design groups the 51 milestones into four named
    /// arcs by index range.
    /// Names are string keys; the Journey screen resolves them.
    static let phases: [(key: String, range: Range<Int>)] = [
        ("phaseLocal", 0..<10),
        ("phaseCity", 10..<22),
        ("phaseWonders", 22..<35),
        ("phaseEpic", 35..<51),
    ]
}

// MARK: - Strings

/// Looks up a UI string for the active language, falling back to English.
struct Strings {
    let lang: String
    private let table: [String: String]
    private let fallback: [String: String]

    init(lang: String, content: StepOneContent = .shared) {
        self.lang = lang
        self.table = content.strings[lang] ?? [:]
        self.fallback = content.strings["en"] ?? [:]
    }

    subscript(key: String) -> String {
        table[key] ?? fallback[key] ?? key
    }

    /// `S("traveled", "d", "120 m")` fills the design's `{d}`-style slots.
    func callAsFunction(_ key: String, _ slot: String, _ value: String) -> String {
        self[key].replacingOccurrences(of: "{\(slot)}", with: value)
    }

    func greeting(part: DayPart, name: String) -> String {
        let word = self[part.stringKey]
        return self[key: "greet"]
            .replacingOccurrences(of: "{g}", with: word)
            .replacingOccurrences(of: "{n}", with: name)
    }

    private subscript(key key: String) -> String { self[key] }

    func categoryName(_ category: String) -> String {
        switch category {
        case "creativity": return self["tabC"]
        case "physical": return self["tabP"]
        case "housework": return self["tabH"]
        case "hygiene": return self["tabHy"]
        case "study": return self["tabSt"]
        case "hobby": return self["tabHb"]
        case "social": return self["tabSo"]
        default: return category
        }
    }
}

enum DayPart {
    case morning, afternoon, evening

    static func current(now: Date = Date(), calendar: Calendar = .current) -> DayPart {
        let hour = calendar.component(.hour, from: now)
        if hour < 12 { return .morning }
        if hour < 18 { return .afternoon }
        return .evening
    }

    var stringKey: String {
        switch self {
        case .morning: return "m"
        case .afternoon: return "a"
        case .evening: return "e"
        }
    }

    /// The onboarding greeting is English-only in the design.
    var englishWord: String {
        switch self {
        case .morning: return "morning"
        case .afternoon: return "afternoon"
        case .evening: return "evening"
        }
    }
}

// MARK: - Units

enum DistanceUnit: String {
    case meters = "m"
    case feet = "ft"

    /// Mirrors the design's `fmt(m)`.
    func format(_ meters: Int) -> String {
        switch self {
        case .meters: return "\(meters) m"
        case .feet: return "\(Int((Double(meters) * 3.28084).rounded())) ft"
        }
    }

    func formatTotal(_ meters: Int) -> String {
        let value: Int = self == .meters ? meters : Int((Double(meters) * 3.28084).rounded())
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = ","
        formatter.locale = Locale(identifier: "en_US")
        let text = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        return "\(text) \(rawValue)"
    }
}
