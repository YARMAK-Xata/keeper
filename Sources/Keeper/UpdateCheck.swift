import Foundation

/// A published release, reduced to the two things Keeper needs: which version it is, and the page
/// to send someone to.
struct Release: Equatable {
    /// The tag exactly as GitHub published it, "v1.9".
    let version: String
    let page: URL

    /// How the app says it out loud. Releases are tagged `v1.9` and the bundle calls itself
    /// `1.9`; "Keeper v1.9 is available" next to an About box reading 1.8 looks like two
    /// different numbering schemes, so the tag's v is dropped for display and kept for comparing.
    var displayVersion: String {
        version.lowercased().hasPrefix("v") ? String(version.dropFirst()) : version
    }
}

/// Reading and comparing releases. Pure, so it can be tested without going near the network —
/// which matters more here than usual, because the network part is the part people are trusting
/// us about and the logic part is the part that would quietly be wrong.
enum UpdateCheck {
    /// Releases are published from this repository and nowhere else. The check is not a lookup of
    /// "some update server" whose answer we act on: it asks GitHub about this one project, and a
    /// reply pointing anywhere else is discarded rather than opened. An app holding Accessibility
    /// access must not be talked into opening an arbitrary link by whatever answers an HTTP call.
    static let repository = "YARMAK-Xata/keeper"
    static let feed = URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!
    private static let trustedHost = "github.com"

    /// Whether `candidate` is a later version than `current`.
    ///
    /// Numeric, component by component, because as text "1.10" sorts before "1.9" and the tenth
    /// release would silently stop being offered. Anything that is not a plain dotted number —
    /// a hand-typed tag, a beta suffix, an empty string — is not an update: a checker that nags
    /// because someone mistyped a tag is worse than one that says nothing.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        guard let new = components(candidate), let old = components(current) else { return false }
        for index in 0..<max(new.count, old.count) {
            let a = index < new.count ? new[index] : 0
            let b = index < old.count ? old[index] : 0
            if a != b { return a > b }
        }
        return false
    }

    /// "v1.9" and "1.9" are the same version — the tag wears a v and the bundle does not.
    private static func components(_ version: String) -> [Int]? {
        var text = version.trimmingCharacters(in: .whitespaces)
        if text.lowercased().hasPrefix("v") { text.removeFirst() }
        guard !text.isEmpty else { return nil }
        let parts = text.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
        let numbers = parts.compactMap { Int($0) }
        return numbers.count == parts.count ? numbers : nil
    }

    /// Reads GitHub's answer, taking the two fields we need out of a much larger payload.
    ///
    /// Drafts and prereleases are not offered: they are published for the author, not for whoever
    /// is running the app. A release whose page is not on github.com is discarded.
    static func release(from data: Data) -> Release? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = object["tag_name"] as? String,
              let link = object["html_url"] as? String,
              let page = URL(string: link),
              page.scheme == "https", page.host == trustedHost,
              object["draft"] as? Bool != true,
              object["prerelease"] as? Bool != true
        else { return nil }
        return Release(version: tag, page: page)
    }
}
