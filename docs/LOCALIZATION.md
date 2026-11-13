# Localization — Level Up

## Decision: English only, for now

Level Up ships with a single locale: `en` (`supportedLocales = ['en']`). The language-selection plumbing remains in place but is inactive:

- `l10n.dart` documents that "Level Up ships in English only".
- `AppLocalizations.supportedLocales` returns only `Locale('en')`.
- `appLanguages` resolves to `['en']`, so the "Language" row in Settings is hidden unless `appLanguages.length > 1` (see `settings_screen.dart` `_categories()`).

The System layer's ~600 strings are still inline English copy (not yet in ARB). That is intentional for now: moving them into ARB is the prerequisite for adding a second locale, and this work is deferred until there is a real translation to ship.

## If/when a second locale is added

1. Add the new locale to `supportedLocales` in `app_localizations.dart` and to `app_XX.arb`.
2. Move System-layer copy (system_screen, system_widgets, system_sheets, hunter_*) into `app_localizations`/`app_XX.arb` so it can be translated.
3. Remove the `appLanguages.length > 1` guard so the Language row appears in Settings, wired to `setAppLanguage`.
4. Regenerate `app_localizations_en.dart` (and any new locale) via the l10n tooling.

## Why not remove the plumbing entirely

Keeping the (currently single-locale) l10n scaffolding costs nothing and avoids a future migration. The only user-visible language surface — the Settings "Language" row — is hidden until a second locale exists.
