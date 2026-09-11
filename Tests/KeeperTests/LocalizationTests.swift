import XCTest
@testable import Keeper

/// Guards the thing that breaks silently: a string added to the code, or to English, and
/// forgotten everywhere else. A missing key shows the key itself in the window.
final class LocalizationTests: XCTestCase {
    private static let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

    /// Every language Keeper speaks. English is the base every other one is measured against.
    static let languages = ["en", "uk", "ru", "de", "fr", "it", "pl"]

    /// The ones whose numbers decline into more than a singular and a plural. Russian, Ukrainian
    /// and Polish all split the plural three ways — 1 сайт, 2 сайти, 5 сайтів — and a missing
    /// form does not fail loudly, it just prints the wrong word.
    private static let manyFormLanguages = ["uk", "ru", "pl"]

    private func table(_ language: String, _ file: String) throws -> [String: Any] {
        let url = Self.root.appending(path: "Sources/Keeper/Resources/\(language).lproj/\(file)")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(plist as? [String: Any])
    }

    /// Every `L.t("…")` and `L.plural("…")` in the source has an English entry.
    func testEveryKeyUsedInCodeExists() throws {
        let strings = Set(try table("en", "Localizable.strings").keys)
        let plurals = Set(try table("en", "Localizable.stringsdict").keys)
        let sources = try FileManager.default
            .contentsOfDirectory(at: Self.root.appending(path: "Sources/Keeper"), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }

        var missing: [String] = []
        for file in sources {
            let text = try String(contentsOf: file, encoding: .utf8)
            for (pattern, available) in [(#"L\.t\("([^"]+)""#, strings), (#"L\.plural\("([^"]+)""#, plurals)] {
                let regex = try NSRegularExpression(pattern: pattern)
                for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)) {
                    let key = String(text[Range(match.range(at: 1), in: text)!])
                    if !available.contains(key) { missing.append("\(file.lastPathComponent): \(key)") }
                }
            }
        }
        XCTAssertEqual(missing, [], "keys used in code but absent from the English tables")
    }

    /// Every language carries exactly the same keys, so no window falls back to English mid-sentence.
    func testTranslationsCoverTheSameKeys() throws {
        for file in ["Localizable.strings", "Localizable.stringsdict"] {
            let base = Set(try table("en", file).keys)
            for language in Self.languages.dropFirst() {
                let other = Set(try table(language, file).keys)
                XCTAssertEqual(base.subtracting(other), [], "\(language)/\(file) is missing keys")
                XCTAssertEqual(other.subtracting(base), [], "\(language)/\(file) has keys English does not")
            }
        }
    }

    /// Nothing was left in English by accident. Every translation differs from the English text,
    /// apart from the handful of entries that are genuinely the same word in both.
    func testNothingWasLeftUntranslated() throws {
        // Proper nouns, a licence line, and words Italian and German spell the English way.
        let sameInSomeLanguages: Set<String> = [
            "about.credit", "menu.open", "menu.quit", "menu.about", "checkbox.dock",
            "list.apps.choose", "permission.continue", "state.ready.title",
        ]
        let english = try table("en", "Localizable.strings")
        for language in Self.languages.dropFirst() {
            let other = try table(language, "Localizable.strings")
            for (key, value) in english where !sameInSomeLanguages.contains(key) {
                let mine = try XCTUnwrap(other[key] as? String)
                XCTAssertNotEqual(mine, value as? String, "\(language) \(key) is still the English text")
            }
        }
    }

    /// Every language that needs one/few/many carries all of them, in every plural variable —
    /// "guarding 2 sites and 3 apps" declines twice.
    func testPluralsCarryEveryFormTheLanguageNeeds() throws {
        for language in Self.manyFormLanguages {
            let dict = try table(language, "Localizable.stringsdict")
            for (key, value) in dict {
                let entry = try XCTUnwrap(value as? [String: Any])
                let variables = entry.values.compactMap { $0 as? [String: Any] }
                XCTAssertFalse(variables.isEmpty, "\(language) \(key) has no plural variable at all")
                for variable in variables {
                    for form in ["one", "few", "many", "other"] {
                        XCTAssertNotNil(variable[form], "\(language) \(key) has no \(form) form")
                    }
                }
            }
        }
    }

    /// Two-plural languages still need `other`; without it the entry silently returns nothing.
    func testEveryPluralHasAnOtherForm() throws {
        for language in Self.languages {
            let dict = try table(language, "Localizable.stringsdict")
            for (key, value) in dict {
                let entry = try XCTUnwrap(value as? [String: Any])
                for variable in entry.values.compactMap({ $0 as? [String: Any] }) {
                    XCTAssertNotNil(variable["other"], "\(language) \(key) has no other form")
                }
            }
        }
    }

    /// A plural entry's format key has to name the variables the entry actually defines, or the
    /// sentence comes out with a raw `%#@…@` token in it.
    func testPluralFormatKeysNameTheirVariables() throws {
        for language in Self.languages {
            for (key, value) in try table(language, "Localizable.stringsdict") {
                let entry = try XCTUnwrap(value as? [String: Any])
                let format = try XCTUnwrap(entry["NSStringLocalizedFormatKey"] as? String)
                let variables = entry.keys.filter { $0 != "NSStringLocalizedFormatKey" }
                XCTAssertFalse(variables.isEmpty, "\(language) \(key) defines no variables")
                for name in variables {
                    XCTAssertTrue(format.contains("@\(name)@"), "\(language) \(key): format does not use \(name)")
                }
            }
        }
    }

    /// Positional specifiers matter once a language reorders the sentence.
    func testTwoArgumentStringsUsePositionalSpecifiers() throws {
        for language in Self.languages {
            for (key, value) in try table(language, "Localizable.strings") {
                let text = try XCTUnwrap(value as? String)
                let plain = text.components(separatedBy: "%@").count - 1
                if plain > 1 {
                    XCTFail("\(language) \(key) uses %@ twice; use %1$@ and %2$@")
                }
            }
        }
    }

    /// A translation may reorder the arguments but it may not lose one, and it may not invent a
    /// third. `String(format:)` reads past the end of the argument list and crashes if it does.
    func testTranslationsTakeTheSameArgumentsAsEnglish() throws {
        func placeholders(_ text: String) -> Set<String> {
            let pattern = try! NSRegularExpression(pattern: #"%(?:\d+\$)?[@a-z]+"#)
            let matches = pattern.matches(in: text, range: NSRange(text.startIndex..., in: text))
            return Set(matches.map { match in
                let token = String(text[Range(match.range, in: text)!])
                // "%1$@" and "%@" are the same argument; only the count and kinds matter here.
                return token.replacingOccurrences(of: #"^%\d+\$"#, with: "%", options: .regularExpression)
            })
        }
        let english = try table("en", "Localizable.strings")
        for language in Self.languages.dropFirst() {
            let other = try table(language, "Localizable.strings")
            for (key, value) in english {
                let base = placeholders(try XCTUnwrap(value as? String))
                let mine = placeholders(try XCTUnwrap(other[key] as? String))
                XCTAssertEqual(mine, base, "\(language) \(key) does not take the same arguments as English")
            }
        }
    }

    /// The note inside the disk image is the first thing anyone who is sent Keeper reads, and it
    /// carries the one instruction they cannot work out for themselves — the Gatekeeper dance an
    /// app signed outside the App Store needs before it will open at all. An app that speaks
    /// seven languages behind install instructions in two is a friend in Warsaw stuck on step one.
    func testTheDiskImageNoteSpeaksEveryLanguageTheAppDoes() throws {
        // Each language's own heading in the note. A new language with no entry here fails, which
        // is the point: the note has to be written before the release is built.
        let headings = [
            "en": "KEEPER\n======", "uk": "KEEPER (українською)", "ru": "KEEPER (Русский)",
            "de": "KEEPER (Deutsch)", "fr": "KEEPER (Français)", "it": "KEEPER (Italiano)",
            "pl": "KEEPER (Polski)",
        ]
        let note = try String(contentsOf: Self.root.appending(path: "docs/Open-me-first.txt"),
                              encoding: .utf8)
        for language in Self.languages {
            let heading = try XCTUnwrap(headings[language],
                                        "\(language) is translated but has no section in the note")
            XCTAssertTrue(note.contains(heading), "the note has no \(language) section")
        }
    }

    /// A language only reaches the user if the app bundle says the app speaks it: macOS picks the
    /// best match from `CFBundleLocalizations` against the user's language order, and a folder the
    /// list does not mention is never chosen. The two have to be kept in step by hand, so this
    /// reads the build script rather than trusting that they were.
    func testTheBundleDeclaresEveryLanguageOnDisk() throws {
        let script = try String(contentsOf: Self.root.appending(path: "scripts/build-app.sh"), encoding: .utf8)
        let declared = Set(try NSRegularExpression(pattern: #"<string>([a-z]{2})</string>"#)
            .matches(in: script, range: NSRange(script.startIndex..., in: script))
            .map { String(script[Range($0.range(at: 1), in: script)!]) })

        let folders = Set(try FileManager.default
            .contentsOfDirectory(atPath: Self.root.appending(path: "Sources/Keeper/Resources").path)
            .filter { $0.hasSuffix(".lproj") }
            .map { String($0.dropLast(".lproj".count)) })

        XCTAssertEqual(folders, Set(Self.languages), "a .lproj folder this test does not know about")
        XCTAssertEqual(folders.subtracting(declared), [],
                       "translated, but CFBundleLocalizations in scripts/build-app.sh does not list it, "
                       + "so macOS will never choose it")
    }
}
