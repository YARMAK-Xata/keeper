import XCTest
@testable import Keeper

/// `SECURITY.md` makes a promise about what Keeper can reach, and a promise nobody checks decays.
/// This is that check, run on every build.
///
/// The document used to say Keeper *could not* talk to the network — no `URLSession` anywhere,
/// and a grep the reader could run to prove it. Adding the update check spent that promise, so
/// what replaced it is narrower and still verifiable: the network lives in exactly one file, and
/// it makes exactly one request to exactly one host. These tests fail the moment that stops being
/// true, which is the only thing that makes the sentence in SECURITY.md worth reading.
final class NetworkSurfaceTests: XCTestCase {
    private static let sources = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appending(path: "Sources/Keeper")

    /// The one file allowed to reach the network.
    private static let networkFile = "UpdateChecker.swift"

    private func swiftFiles() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: Self.sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
    }

    /// Strips comments, so the prose explaining why a thing is absent does not read as the thing.
    private func code(_ url: URL) throws -> String {
        try String(contentsOf: url, encoding: .utf8)
            .components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
    }

    /// Matched as whole symbols rather than substrings. `Font.system(size:)` is not `system()`,
    /// and a test that cannot tell them apart gets switched off the first time it cries wolf.
    private func uses(_ pattern: String, _ text: String) -> Bool {
        let regex = try? NSRegularExpression(pattern: pattern)
        return regex?.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) != nil
    }

    func testOnlyOneFileCanReachTheNetwork() throws {
        let networking = [#"\bURLSession\b"#, #"\bNWConnection\b"#, #"\bNWBrowser\b"#,
                          #"\bCFSocket\b"#, #"(?<![.\w])socket\s*\("#]
        var offenders: [String] = []
        for file in try swiftFiles() where file.lastPathComponent != Self.networkFile {
            let text = try code(file)
            for api in networking where uses(api, text) {
                offenders.append("\(file.lastPathComponent) matches \(api)")
            }
        }
        XCTAssertEqual(offenders, [], "SECURITY.md says the network lives in \(Self.networkFile) alone")
    }

    /// One request, to one address, built into the binary — not a base URL assembled at runtime
    /// from something that could be pointed elsewhere.
    func testThereIsExactlyOneAddress() throws {
        let text = try code(Self.sources.appending(path: Self.networkFile))
        let urls = try NSRegularExpression(pattern: #"https?://[^\s"')]+"#)
            .matches(in: text, range: NSRange(text.startIndex..., in: text))
            .map { String(text[Range($0.range, in: text)!]) }
        XCTAssertEqual(urls, [], "\(Self.networkFile) should take its address from UpdateCheck.feed")
        XCTAssertEqual(UpdateCheck.feed.host, "api.github.com")
        XCTAssertEqual(UpdateCheck.feed.scheme, "https")
        XCTAssertEqual(UpdateCheck.feed.path, "/repos/\(UpdateCheck.repository)/releases/latest")
    }

    /// The other half of the old promise, which has not changed: Keeper starts no other program.
    func testKeeperStartsNothing() throws {
        let spawning = [#"\bProcess\s*\("#, #"\bNSTask\b"#, #"\bposix_spawn\b"#,
                        #"(?<![.\w])system\s*\("#, #"(?<![.\w])popen\s*\("#,
                        #"\bNSAppleScript\b"#]
        var offenders: [String] = []
        for file in try swiftFiles() {
            let text = try code(file)
            for api in spawning where uses(api, text) {
                offenders.append("\(file.lastPathComponent) matches \(api)")
            }
        }
        XCTAssertEqual(offenders, [], "SECURITY.md says Keeper cannot start another program")
    }

    /// The check is on unless switched off, and — this is the part worth a test — switching it
    /// off has to actually stick. `bool(forKey:)` reads an absent key as false, so the naive
    /// reading would have made a fresh install look like someone had already opted out.
    @MainActor
    func testTheCheckIsOnUnlessTurnedOff() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: UpdateChecker.enabledKey)
        defer {
            if let saved { defaults.set(saved, forKey: UpdateChecker.enabledKey) }
            else { defaults.removeObject(forKey: UpdateChecker.enabledKey) }
        }

        defaults.removeObject(forKey: UpdateChecker.enabledKey)
        XCTAssertTrue(UpdateChecker.shared.isEnabled, "a fresh install checks for updates")

        defaults.set(false, forKey: UpdateChecker.enabledKey)
        XCTAssertFalse(UpdateChecker.shared.isEnabled, "switching it off must stick")

        defaults.set(true, forKey: UpdateChecker.enabledKey)
        XCTAssertTrue(UpdateChecker.shared.isEnabled)
    }
}

/// Opening at login is on from the first run, and stays off once it has been turned off. The
/// second half is the one worth a test: a check that ran on every launch would quietly re-enable
/// a login item the user had just removed, which is the behaviour people rightly hate.
final class LoginItemTests: XCTestCase {
    private let key = "loginItemDecided"

    func testTheDecisionIsRecordedSoItIsOnlyMadeOnce() {
        let defaults = UserDefaults.standard
        let saved = defaults.object(forKey: key)
        defer {
            if let saved { defaults.set(saved, forKey: key) } else { defaults.removeObject(forKey: key) }
        }

        defaults.removeObject(forKey: key)
        XCTAssertFalse(defaults.bool(forKey: key), "a fresh install has not decided yet")

        LoginItem.enableOnFirstRun()
        XCTAssertTrue(defaults.bool(forKey: key),
                      "after the first run the decision is recorded, so later launches leave it alone")
    }
}
