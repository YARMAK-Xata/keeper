import XCTest
@testable import Keeper

/// The other localization tests read the `.lproj` folders off disk, which proves they are written
/// correctly and proves nothing about whether they ship. This one goes through the built resource
/// bundle — the same one `L` reads at runtime — so a language SwiftPM failed to copy, or that
/// macOS would not resolve, fails here rather than in front of a friend in Warsaw.
final class LocalizedLookupTests: XCTestCase {
    /// The bundle for one language inside Keeper's resource bundle, which is what the system
    /// picks when the Mac is set to that language.
    private func bundle(_ language: String) throws -> Bundle {
        let path = try XCTUnwrap(L.bundle.path(forResource: language, ofType: "lproj"),
                                 "\(language).lproj did not make it into the resource bundle")
        return try XCTUnwrap(Bundle(path: path))
    }

    private func lookup(_ key: String, _ language: String) throws -> String {
        try bundle(language).localizedString(forKey: key, value: nil, table: nil)
    }

    /// Every language ships, and every one of its strings comes back translated rather than as the
    /// key itself — which is what a missing entry looks like on screen.
    func testEveryLanguageShipsAndResolvesEveryKey() throws {
        for language in LocalizationTests.languages {
            let bundle = try bundle(language)
            let english = try XCTUnwrap(PropertyListSerialization.propertyList(
                from: try Data(contentsOf: XCTUnwrap(L.bundle.url(forResource: "Localizable",
                                                                  withExtension: "strings",
                                                                  subdirectory: "en.lproj"))),
                options: [], format: nil) as? [String: Any])

            for key in english.keys {
                let value = bundle.localizedString(forKey: key, value: nil, table: nil)
                XCTAssertNotEqual(value, key, "\(language) has no text for \(key)")
                XCTAssertFalse(value.isEmpty, "\(language) has an empty string for \(key)")
            }
        }
    }

    /// A spot check per language, so a folder full of the wrong language's text cannot pass.
    func testEachLanguageSaysItsOwnWords() throws {
        let expected = [
            "en": "Start session", "uk": "Почати сесію", "ru": "Начать сессию",
            "de": "Sitzung starten", "fr": "Démarrer la session", "it": "Avvia sessione",
            "pl": "Rozpocznij sesję",
        ]
        for (language, text) in expected {
            XCTAssertEqual(try lookup("button.start", language), text)
        }
    }

    /// The knight's bubble takes the site's name. Formatting it is where a translation with the
    /// wrong specifier stops being a typo and starts being a crash.
    func testFormattedStringsSubstituteTheirArgument() throws {
        for language in LocalizationTests.languages {
            let format = try lookup("knight.bubble", language)
            let sentence = String(format: format, locale: Locale(identifier: language), "youtube.com")
            XCTAssertTrue(sentence.contains("youtube.com"), "\(language): the site's name vanished")
            XCTAssertFalse(sentence.contains("%"), "\(language): a specifier survived formatting")
        }
    }

    /// Two arguments, and languages that reorder them. A translation that dropped `%2$@` would
    /// read as a missing browser name; one that repeated it would read past the argument list.
    func testTwoArgumentEventsKeepBothArguments() throws {
        for language in LocalizationTests.languages {
            let format = try lookup("event.closed", language)
            let sentence = String(format: format, locale: Locale(identifier: language), "youtube.com", "Safari")
            XCTAssertTrue(sentence.contains("youtube.com"), "\(language): the site's name vanished")
            XCTAssertTrue(sentence.contains("Safari"), "\(language): the browser's name vanished")
            XCTAssertFalse(sentence.contains("%"), "\(language): a specifier survived formatting")
        }
    }

    /// The counting sentence, at the three counts that tell the Slavic forms apart: 1 site,
    /// 2 sites, 5 sites. Each has to come out as a different word, and never as the raw token.
    func testPluralsPickADifferentWordForOneTwoAndFive() throws {
        for language in ["uk", "ru", "pl"] {
            let format = try lookup("state.onDuty.subtitle", language)
            let sentences = [1, 2, 5].map {
                String(format: format, locale: Locale(identifier: language), $0)
            }
            for (count, sentence) in zip([1, 2, 5], sentences) {
                XCTAssertTrue(sentence.contains("\(count)"), "\(language): \(count) is not in \"\(sentence)\"")
                XCTAssertFalse(sentence.contains("%"), "\(language): \"\(sentence)\" kept a specifier")
            }
            XCTAssertEqual(Set(sentences).count, 3,
                           "\(language) does not decline: \(sentences)")
        }
    }

    /// Two-form languages need the singular and the plural to differ, and both to read cleanly.
    func testTwoFormLanguagesStillDecline() throws {
        for language in ["en", "de", "fr"] {
            let format = try lookup("state.onDuty.subtitle", language)
            let one = String(format: format, locale: Locale(identifier: language), 1)
            let many = String(format: format, locale: Locale(identifier: language), 7)
            XCTAssertNotEqual(one, many, "\(language) reads the same at 1 and 7")
            XCTAssertFalse(one.contains("%") || many.contains("%"), "\(language) kept a specifier")
        }
    }

    /// The sentence that declines twice — "guarding 2 sites and 3 apps" — with counts that take
    /// different plural forms on each side. This is the one a `.stringsdict` gets wrong quietly.
    func testTheTwoPluralSentenceDeclinesOnBothSides() throws {
        for language in LocalizationTests.languages {
            let format = try lookup("state.onDuty.subtitle.both", language)
            let sentence = String(format: format, locale: Locale(identifier: language), 1, 5)
            XCTAssertTrue(sentence.contains("1"), "\(language): the site count vanished from \"\(sentence)\"")
            XCTAssertTrue(sentence.contains("5"), "\(language): the app count vanished from \"\(sentence)\"")
            XCTAssertFalse(sentence.contains("%"), "\(language): \"\(sentence)\" kept a specifier")
            XCTAssertFalse(sentence.contains("@"), "\(language): \"\(sentence)\" kept a variable token")
        }
    }
}
