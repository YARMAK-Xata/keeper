import Foundation

/// One line of the blacklist. `host` is lowercased with no "www."; a bare word (no dot)
/// matches any dot-separated label of a host. `pathPrefix` is "" or "/a/b" with no trailing slash.
struct BlacklistRule: Equatable {
    let host: String
    let pathPrefix: String

    init(host: String, pathPrefix: String) {
        self.host = host
        self.pathPrefix = pathPrefix
    }

    init?(line: String) {
        var s = line.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty, !s.hasPrefix("#") else { return nil }
        if let r = s.range(of: "://") { s = String(s[r.upperBound...]) }
        if let i = s.firstIndex(where: { $0 == "?" || $0 == "#" }) { s = String(s[..<i]) }
        var host = s
        var path = ""
        if let slash = s.firstIndex(of: "/") {
            host = String(s[..<slash])
            path = String(s[slash...])
        }
        if let colon = host.firstIndex(of: ":") { host = String(host[..<colon]) }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        while path.hasSuffix("/") { path.removeLast() }
        guard !host.isEmpty else { return nil }
        self.init(host: host, pathPrefix: path)
    }

    /// The rule written back out in one comparable form: "youtube.com", "reddit.com/r/funny".
    var canonical: String { host + pathPrefix }

    func matches(host rawHost: String, path rawPath: String) -> Bool {
        var h = rawHost.lowercased()
        if h.hasPrefix("www.") { h.removeFirst(4) }
        let hostMatches: Bool
        if host.contains(".") {
            hostMatches = h == host || h.hasSuffix("." + host)
        } else {
            hostMatches = h.split(separator: ".").contains { $0 == host }
        }
        guard hostMatches else { return false }
        if pathPrefix.isEmpty { return true }
        let p = rawPath.lowercased()
        return p == pathPrefix || p.hasPrefix(pathPrefix + "/")
    }
}

struct Blacklist: Equatable {
    let rules: [BlacklistRule]

    init(text: String) {
        rules = text.split(whereSeparator: \.isNewline).compactMap { BlacklistRule(line: String($0)) }
    }

    var isEmpty: Bool { rules.isEmpty }

    func matches(_ url: URL) -> BlacklistRule? {
        guard let host = url.host(percentEncoded: false), !host.isEmpty else { return nil }
        return rules.first { $0.matches(host: host, path: url.path(percentEncoded: false)) }
    }
}
