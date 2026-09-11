import Foundation

/// What Keeper is doing, in the words each surface puts at the top. The panel and the window
/// read the same three states from here so they can never disagree about which one is showing.
enum SurfaceState {
    case needsAccess
    case ready
    case onDuty

    static func current(trusted: Bool, running: Bool) -> SurfaceState {
        if running { return .onDuty }
        return trusted ? .ready : .needsAccess
    }

    func title(startedAt: Date?) -> String {
        switch self {
        case .needsAccess: return L.t("state.needsAccess.title")
        case .ready: return L.t("state.ready.title")
        case .onDuty: return L.t("state.onDuty.title", L.time(startedAt ?? Date()))
        }
    }

    /// On duty the line names what is actually being guarded, which is one count, the other, or
    /// both — three sentences rather than one with an awkward zero in it.
    func subtitle(siteCount: Int, appCount: Int) -> String {
        switch self {
        case .needsAccess: return L.t("state.needsAccess.subtitle")
        case .ready: return L.t("state.ready.subtitle")
        case .onDuty:
            if appCount == 0 { return L.plural("state.onDuty.subtitle", siteCount) }
            if siteCount == 0 { return L.plural("state.onDuty.subtitle.apps", appCount) }
            return L.plural("state.onDuty.subtitle.both", siteCount, appCount)
        }
    }
}
