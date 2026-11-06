// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation
import XCTest
@testable import PlayportKit

/// A game's Steam language (decision 0186): saved per game, and named on its page.
final class GameLanguageTests: XCTestCase {
    func testAGamesLanguageRoundTripsAndCountsAsSet() throws {
        var s = LaunchSettings()
        XCTAssertTrue(s.isEmpty)
        s.gameLanguage = "tchinese"
        XCTAssertFalse(s.isEmpty)
        let back = try JSONDecoder().decode(LaunchSettings.self, from: JSONEncoder().encode(s))
        XCTAssertEqual(back.gameLanguage, "tchinese")
    }

    func testSettingsSavedBeforeTheLanguageDecodeWithNone() throws {
        let old = try JSONDecoder().decode(LaunchSettings.self, from: Data(#"{"arguments":"-dx11"}"#.utf8))
        XCTAssertNil(old.gameLanguage)
        XCTAssertEqual(old.arguments, "-dx11")
    }

    func testNamesAreShownAndUnknownCodesStayAsTheyAre() {
        XCTAssertTrue(SteamLanguage.name("tchinese").hasPrefix("繁體中文"))
        XCTAssertEqual(SteamLanguage.name("klingon"), "klingon")
        XCTAssertEqual(SteamLanguage.all.first?.code, SteamLanguage.fallback)
    }
}
