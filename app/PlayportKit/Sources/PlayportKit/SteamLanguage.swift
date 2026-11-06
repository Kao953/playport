// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

/// The Steam API language codes a game can be told (ISteamApps::GetCurrentGameLanguage,
/// ISteamUtils::GetSteamUILanguage, gbe's `language=`), with their names: a game's page picks
/// one (LaunchSettings.gameLanguage, decision 0186); English when none is picked.
public enum SteamLanguage {
    public static let fallback = "english"

    public static let all: [(code: String, name: String)] = [
        ("english", "English"),
        ("tchinese", "繁體中文 (Traditional Chinese)"),
        ("schinese", "简体中文 (Simplified Chinese)"),
        ("japanese", "日本語 (Japanese)"),
        ("koreana", "한국어 (Korean)"),
        ("french", "Français"),
        ("german", "Deutsch"),
        ("spanish", "Español (Spain)"),
        ("latam", "Español (Latin America)"),
        ("italian", "Italiano"),
        ("portuguese", "Português (Portugal)"),
        ("brazilian", "Português (Brasil)"),
        ("russian", "Русский"),
        ("polish", "Polski"),
        ("turkish", "Türkçe"),
        ("thai", "ไทย"),
        ("vietnamese", "Tiếng Việt"),
        ("ukrainian", "Українська"),
    ]

    /// A code's name; the code itself for one not listed.
    public static func name(_ code: String) -> String {
        all.first { $0.code == code }?.name ?? code
    }
}
