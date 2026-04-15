// ============================================================================
// LocaleResolver.swift — pure locale matching for speech support
// Part of OhrCore — the pure-logic layer
// ============================================================================

import Foundation

/// Reduce a Locale to its language-region pair (e.g. `en-US`), discarding
/// Unicode extensions such as `-u-rg-atzzzz` that `Locale.current` often
/// carries. Used to compare a user's requested locale against Speech
/// framework's supportedLocales list.
public func canonicalLanguageRegion(_ locale: Locale) -> String {
    let lang = locale.language.languageCode?.identifier ?? "en"
    if let region = locale.region?.identifier {
        return "\(lang)-\(region)"
    }
    return lang
}

/// Pick a supported `Locale` for the requested one.
///
/// Preference order:
///   1. Exact language+region match (e.g. `de-DE` requested, `de-DE` supported).
///   2. Same language, any supported region (e.g. `en-AT` → `en-US`).
///   3. `nil` if the language itself is unsupported.
///
/// This is the fallback rule that prevents a SIGTRAP in the Speech framework
/// when `Locale.current` has a region that has no installed speech model
/// (macOS Tahoe ships e.g. `de-AT` but NOT `en-AT`).
public func resolveSupportedLocale(requested: Locale, supported: [Locale]) -> Locale? {
    let wanted = canonicalLanguageRegion(requested)
    if let exact = supported.first(where: { canonicalLanguageRegion($0) == wanted }) {
        return exact
    }
    let lang = requested.language.languageCode?.identifier
    return supported.first { $0.language.languageCode?.identifier == lang }
}
