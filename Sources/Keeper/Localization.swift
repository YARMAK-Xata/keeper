import Foundation

/// Every visible string in Keeper goes through here, so no view holds a literal and
/// adding a language means adding a `.lproj` folder rather than touching code.
/// Lookups follow the Mac's language preference the same way the system apps do.
enum L {
    /// The bundle SwiftPM builds for this target's resources.
    static let bundle = Bundle.module

    static func t(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: nil)
    }

    static func t(_ key: String, _ args: CVarArg...) -> String {
        String(format: bundle.localizedString(forKey: key, value: key, table: nil),
               locale: .current, arguments: args)
    }

    /// Resolves a `.stringsdict` entry. The locale must be passed or the plural rule never runs.
    static func plural(_ key: String, _ count: Int) -> String {
        String(format: bundle.localizedString(forKey: key, value: key, table: nil),
               locale: .current, count)
    }

    /// A sentence that declines twice — "guarding 2 sites and 3 apps" — which needs one
    /// `.stringsdict` entry carrying two plural variables.
    static func plural(_ key: String, _ first: Int, _ second: Int) -> String {
        String(format: bundle.localizedString(forKey: key, value: key, table: nil),
               locale: .current, first, second)
    }

    /// "12:04", in the viewer's clock format.
    static func time(_ date: Date) -> String {
        date.formatted(.dateTime.hour().minute())
    }

    private static let relative: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.dateTimeStyle = .named          // "just now" rather than "0 seconds ago"
        f.unitsStyle = .abbreviated
        return f
    }()

    /// "just now", "2 min ago" — localized by the system, not by a second set of strings.
    static func ago(_ date: Date, from now: Date = Date()) -> String {
        relative.localizedString(for: date, relativeTo: now)
    }
}
