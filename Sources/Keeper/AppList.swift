import Foundation

/// One application on the list, held by bundle identifier rather than by name or path.
///
/// The identifier is what survives the things that happen to apps: a rename, a beta build in a
/// different folder, a second copy on another volume. The name and the icon are looked up from it
/// when a row is drawn, so an app that moves keeps working and an app that is gone still shows a
/// row you can recognise and remove.
struct AppRule: Equatable, Hashable {
    let bundleID: String

    init(bundleID: String) {
        self.bundleID = bundleID
    }

    init?(line: String) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { return nil }
        self.init(bundleID: trimmed)
    }

    /// Two identifiers naming the same app, compared the way the system does: without case.
    var key: String { bundleID.lowercased() }

    /// What to call the app when it is not installed any more and the system has no name for it.
    /// "com.hnc.Discord" reads as "Discord", which is what the person put there.
    var fallbackName: String {
        bundleID.split(separator: ".").last.map(String.init) ?? bundleID
    }
}

/// The ordered list of applications for a session. Deliberately the same shape as `SiteList` —
/// same text storage, same add/remove/contains/count — so the two lists cannot drift apart.
struct AppList: Equatable {
    private(set) var entries: [AppRule]

    /// Why this app cannot be blocked, as a sentence for the person, or nil when it can.
    ///
    /// Closing a tab cannot lock anybody out of anything. Hiding an app can, so there has to be a
    /// floor: the place where Keeper's own permission is revoked, the thing that draws the
    /// desktop, and Keeper itself. This switch is both the list and the reasons — one source, and
    /// the keys are literals so the localization test can see them.
    static func refusal(for bundleID: String) -> String? {
        switch bundleID.lowercased() {
        case "com.apple.systempreferences": return L.t("list.apps.refused.settings")
        case "com.apple.finder": return L.t("list.apps.refused.finder")
        case "dev.keeper.keeper": return L.t("list.apps.refused.self")
        default: return nil
        }
    }

    private static func isRefused(_ rule: AppRule) -> Bool { refusal(for: rule.bundleID) != nil }

    init(text: String) {
        var seen = Set<String>()
        entries = text.split(whereSeparator: \.isNewline).compactMap { line in
            guard let rule = AppRule(line: String(line)), !Self.isRefused(rule) else { return nil }
            return seen.insert(rule.key).inserted ? rule : nil
        }
    }

    var text: String { entries.map(\.bundleID).joined(separator: "\n") }
    var isEmpty: Bool { entries.isEmpty }
    var count: Int { entries.count }

    func contains(_ bundleID: String) -> Bool {
        entries.contains { $0.key == bundleID.lowercased() }
    }

    /// Adds an app. Returns false when the identifier is empty, already listed, or refused.
    @discardableResult
    mutating func add(_ bundleID: String) -> Bool {
        guard let rule = AppRule(line: bundleID), !Self.isRefused(rule),
              !entries.contains(where: { $0.key == rule.key }) else { return false }
        entries.append(rule)
        return true
    }

    mutating func remove(_ bundleID: String) {
        entries.removeAll { $0.key == bundleID.lowercased() }
    }
}
