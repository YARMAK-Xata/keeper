import Foundation

/// One of the sites offered as a single click. The label is a brand name, never translated.
struct SitePreset: Equatable {
    let label: String
    let rule: String

    static let all: [SitePreset] = [
        SitePreset(label: "YouTube", rule: "youtube.com"),
        SitePreset(label: "Reddit", rule: "reddit.com"),
        SitePreset(label: "X", rule: "x.com"),
        SitePreset(label: "TikTok", rule: "tiktok.com"),
        SitePreset(label: "Instagram", rule: "instagram.com"),
        SitePreset(label: "Netflix", rule: "netflix.com"),
        SitePreset(label: "Twitch", rule: "twitch.tv"),
    ]
}

/// The ordered list of sites for a session.
///
/// Entries are canonical rule strings ("youtube.com", "reddit.com/r/funny"), so anything a
/// person types — a full URL, a bare word, a path — normalises to one comparable form and
/// duplicates collapse. Stored as newline-separated text, which is what earlier versions
/// wrote, so an existing list survives the upgrade untouched.
struct SiteList: Equatable {
    private(set) var entries: [String]

    init(text: String) {
        var seen = Set<String>()
        entries = text.split(whereSeparator: \.isNewline).compactMap { line in
            guard let rule = BlacklistRule(line: String(line)) else { return nil }
            return seen.insert(rule.canonical).inserted ? rule.canonical : nil
        }
    }

    var text: String { entries.joined(separator: "\n") }
    var isEmpty: Bool { entries.isEmpty }
    var count: Int { entries.count }
    var blacklist: Blacklist { Blacklist(text: text) }

    func contains(_ raw: String) -> Bool {
        guard let rule = BlacklistRule(line: raw) else { return false }
        return entries.contains(rule.canonical)
    }

    /// Adds a site. Returns false when the text names no host, or the site is already listed.
    ///
    /// Pasting the address of the page you are trying to escape is the likeliest way to add a
    /// site, so a full URL is read as "this whole site" and its path is dropped: pasting a video
    /// address blocks youtube.com, not youtube.com/watch. Text typed without a scheme is taken
    /// literally, so "reddit.com/r/funny" still means that one corner of Reddit.
    @discardableResult
    mutating func add(_ raw: String) -> Bool {
        guard var rule = BlacklistRule(line: raw) else { return false }
        if raw.contains("://") {
            rule = BlacklistRule(host: rule.host, pathPrefix: "")
        }
        guard !entries.contains(rule.canonical) else { return false }
        entries.append(rule.canonical)
        return true
    }

    mutating func remove(_ entry: String) {
        entries.removeAll { $0 == entry }
    }

    /// The presets not already on the list, so a chip disappears once it has been used.
    var unusedPresets: [SitePreset] {
        SitePreset.all.filter { !entries.contains($0.rule) }
    }
}
