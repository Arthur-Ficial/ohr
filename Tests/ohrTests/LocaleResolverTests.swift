// LocaleResolverTests — pure-logic tests for speech locale matching
// Regression: https://github.com/Arthur-Ficial/ohr/issues/1

import Foundation
import OhrCore

func runLocaleResolverTests() {
    // --- canonicalLanguageRegion ---

    test("canonicalLanguageRegion honours -u-rg- regional override") {
        // `-u-rg-atzzzz` is the regional override that Locale.current carries
        // for a user living in Austria with English as their language. The
        // canonical form reflects the user's effective region (en-AT), which
        // is why Speech has no matching model and we must fall back.
        let loc = Locale(identifier: "en-US-u-rg-atzzzz")
        try assertEqual(canonicalLanguageRegion(loc), "en-AT")
    }
    test("canonicalLanguageRegion for bare language+region") {
        try assertEqual(canonicalLanguageRegion(Locale(identifier: "de-DE")), "de-DE")
    }
    test("canonicalLanguageRegion with underscore identifier") {
        try assertEqual(canonicalLanguageRegion(Locale(identifier: "de_AT")), "de-AT")
    }
    test("canonicalLanguageRegion for language-only locale returns language") {
        try assertEqual(canonicalLanguageRegion(Locale(identifier: "fr")), "fr")
    }

    // --- resolveSupportedLocale ---

    let supported = [
        Locale(identifier: "en-US"),
        Locale(identifier: "en-GB"),
        Locale(identifier: "en-CA"),
        Locale(identifier: "de-DE"),
        Locale(identifier: "de-AT"),
        Locale(identifier: "fr-FR"),
    ]

    test("resolves exact match when available") {
        let resolved = resolveSupportedLocale(requested: Locale(identifier: "de-DE"), supported: supported)
        try assertNotNil(resolved)
        try assertEqual(canonicalLanguageRegion(resolved!), "de-DE")
    }
    test("strips Unicode extension before matching (the issue #1 case)") {
        let resolved = resolveSupportedLocale(
            requested: Locale(identifier: "en-US-u-rg-atzzzz"),
            supported: supported
        )
        try assertNotNil(resolved)
        try assertEqual(canonicalLanguageRegion(resolved!), "en-US")
    }
    test("falls back to same-language different region (en-AT -> en-US)") {
        let resolved = resolveSupportedLocale(
            requested: Locale(identifier: "en-AT"),
            supported: supported
        )
        try assertNotNil(resolved)
        try assertEqual(resolved?.language.languageCode?.identifier, "en")
    }
    test("supported de-AT is picked for de-AT request (no fallback needed)") {
        let resolved = resolveSupportedLocale(
            requested: Locale(identifier: "de-AT"),
            supported: supported
        )
        try assertEqual(canonicalLanguageRegion(resolved!), "de-AT")
    }
    test("returns nil when language unsupported (ja with only en/de/fr)") {
        let resolved = resolveSupportedLocale(
            requested: Locale(identifier: "ja-JP"),
            supported: supported
        )
        try assertNil(resolved)
    }
    test("empty supported list always returns nil") {
        let resolved = resolveSupportedLocale(
            requested: Locale(identifier: "en-US"),
            supported: []
        )
        try assertNil(resolved)
    }
}
