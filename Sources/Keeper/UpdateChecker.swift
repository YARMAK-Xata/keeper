import AppKit
import SwiftUI

/// The one part of Keeper that talks to the network.
///
/// It is deliberately the whole of it. `SECURITY.md` used to promise Keeper *could not* reach the
/// network — no `URLSession` anywhere, and a grep the reader could run to prove it. That promise
/// is worth more than a feature, so what replaced it is a narrower one that is still checkable:
/// one file, one URL, one GET, no body, nothing about you in the request, and nothing happens at
/// all until you switch it on. If this file grows a second request, that promise is broken again.
///
/// It never downloads or installs anything. It compares a version and offers a link; whoever is
/// running Keeper decides what to do about it.
@MainActor
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    enum Status: Equatable { case idle, checking, upToDate, failed }

    /// A newer release than this build, once one has been found.
    @Published private(set) var available: Release?
    /// Only so Settings can say something back when the button is pressed by hand.
    @Published private(set) var status: Status = .idle

    /// On unless switched off.
    ///
    /// This was the other way round at first, and off-by-default is the safer claim to make — but
    /// it makes the feature pointless, because almost nobody opens Settings, and an update notice
    /// nobody ever sees is not an update notice. So the cost is paid in the open instead: every
    /// document that describes Keeper says it contacts GitHub daily and says where the switch is,
    /// rather than the app being quiet about it and technically defensible.
    static let enabledKey = "checkForUpdates"
    private static let lastCheckedKey = "lastUpdateCheck"
    private static let interval: TimeInterval = 24 * 60 * 60

    /// `bool(forKey:)` cannot express this: it reads an absent key as false, which is the
    /// opposite of what a fresh install should do. Reading the object and defaulting it keeps
    /// "never set" and "set to off" apart.
    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Self.enabledKey) as? Bool ?? true
    }

    /// What this build calls itself. Absent when running the bare SwiftPM binary, which has no
    /// Info.plist — and with nothing to compare against, nothing is ever offered.
    var currentVersion: String? {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    private init() {}

    /// Called when a surface appears. Does nothing unless switched on, and at most once a day —
    /// opening the panel twenty times in an afternoon is not twenty requests.
    func checkIfDue() {
        guard isEnabled, available == nil else { return }
        let last = UserDefaults.standard.object(forKey: Self.lastCheckedKey) as? Date ?? .distantPast
        guard Date().timeIntervalSince(last) > Self.interval else { return }
        Task { await check() }
    }

    /// The Settings button. Asks now whether or not a day has passed, because a person pressing a
    /// button is entitled to an answer — but still only when the switch is on.
    func checkNow() {
        guard isEnabled else { return }
        Task { await check() }
    }

    private func check() async {
        guard let current = currentVersion else { return }
        status = .checking
        UserDefaults.standard.set(Date(), forKey: Self.lastCheckedKey)

        // Ephemeral: no cookie jar, no cache, nothing about the request kept on disk afterwards.
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        let session = URLSession(configuration: configuration)

        var request = URLRequest(url: UpdateCheck.feed)
        request.httpMethod = "GET"
        // GitHub refuses a request with no User-Agent. It says which build is asking and nothing
        // else — no identifier, no machine, nothing that distinguishes one copy from another.
        request.setValue("Keeper/\(current)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let release = UpdateCheck.release(from: data) else {
                status = .failed
                return
            }
            if UpdateCheck.isNewer(release.version, than: current) {
                available = release
                status = .idle
            } else {
                available = nil
                status = .upToDate
            }
        } catch {
            // Offline, rate-limited, GitHub having a bad day. None of it is the user's problem,
            // and none of it should interrupt what they opened Keeper to do.
            status = .failed
        }
    }

    /// Opens the release page. Keeper does not download or replace itself — there is no code here
    /// that could, which is the point.
    func openReleasePage() {
        guard let page = available?.page else { return }
        NSWorkspace.shared.open(page)
    }
}
