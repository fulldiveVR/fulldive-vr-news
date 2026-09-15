# Fulldive VR News

An Android news reader for VR/XR headlines, built with Flutter and styled after
the Fulldive VR shell app. It ships under the **same package name and signing
key as the legacy Unity app**, so installing it replaces that app rather than
sitting alongside it.

- **Feed** — paginated list of stories with cover image, headline, teaser,
  topic chip and source/date footer. Pull to refresh; the next page loads as
  you approach the end of the list.
- **Reader** — full story on its own screen, with the publisher's page opening
  in an in-app browser rather than handing the reader off to Chrome.
- **Backend** — Cloud Firestore, read anonymously. Stories are written by
  `tools/news_seeder` today and by a content service later.

## Identity inherited from the Unity app

Everything below is deliberately taken from `../fulldive-unity-plugins` so the
build is recognised as an update of the existing app:

| | Value | Source |
| --- | --- | --- |
| Package / applicationId | `in.fulldive.shell` | `buildSrc/.../values.kt` (Cardboard + Daydream production) |
| Signing key | `keys/keys.jks`, alias `FullDive` | copied from `fulldive-unity-plugins/keys/` |
| Certificate SHA-1 | `D2:5C:7E:06:…:55:D0` | matches `certificate_hash` in google-services.json |
| Firebase project | `full-dive-co` (`254410647594`) | `android/app/google-services.json` |
| Launcher icon | `ic_fixed_robot.png` | `main/src/main/res/mipmap-*` |
| Palette | navy `#212E47`, orange `#FA8A19` | `main/src/main/res/values/colors.xml` |
| Wordmark | `ic_logoassets_text_white.png` | `main/src/google/main/res/drawable-*` |

`versionCode` is `7000000` (`version: 7.0.0+7000000` in `pubspec.yaml`), above
the last Unity release's `6100211` — Play rejects anything lower as a
downgrade.

## Building

```bash
flutter pub get
flutter run                 # debug, on a connected device or emulator
tools/build_release.sh      # named release artifacts, signed with keys/keys.jks
```

`tools/build_release.sh` builds and names the artifacts after the app and its
version, so they are ready to upload as they are:

```
build/outputs/fulldive-vr-news-v7.0.0.aab
build/outputs/fulldive-vr-news-v7.0.0.apk
```

Pass `aab` or `apk` to build just one. Plain `flutter build apk --release`
still works and still signs correctly; it just leaves the artifact under its
default `app-release.apk` name.

Release signing reads the same environment variables the Unity project used:

```bash
export FULLDIVE_KEYSTORE_PASSWORD=…
export FULLDIVE_ALIAS=FullDive
export FULLDIVE_ALIAS_PASSWORD=…
```

Without them the release build falls back to the debug keys, so
`flutter run --release` still works locally.

`keys/keys.jks` is the production signing key, copied here so the build works
out of a fresh checkout — treat this repository as private accordingly.

> **Note:** `flutter test` builds native assets for the host, so on macOS it
> needs a working `xcrun`. If it fails with "Building native assets failed",
> accept the Xcode licence once: `sudo xcodebuild -license accept`.

## Firestore

The project has **no `(default)` database** — the only one is named `main`, so
both the app (`NewsRepository.databaseId`) and the seeder address it
explicitly.

Stories live in the `news` collection, ordered by `publishedAt` descending and
paged with `startAfterDocument`; the single-field index Firestore creates
automatically is all the query needs.

`firestore.rules` grants public read on `/news/**` and leaves everything else
denied, matching the ruleset that was already in place. Deploy it with:

```bash
GCLOUD_ACCOUNT=you@fulldive.com tools/deploy_firestore_rules.sh
```

Writes are closed to clients; the seeder and the future service write with
privileged credentials, which bypass rules.

## Filling the collection

See [`tools/news_seeder/README.md`](tools/news_seeder/README.md). In short:

```bash
node tools/news_seeder/seed.js --dry-run   # inspect
node tools/news_seeder/seed.js             # write ~60 stories
```

## Layout

```
lib/
  main.dart                          Firebase init and app entry point
  src/
    app.dart                         MaterialApp and routing
    theme/fulldive_theme.dart        Brand palette and ThemeData
    models/news_article.dart         Document model and text helpers
    data/news_repository.dart        Firestore paging queries
    data/news_feed_controller.dart   Feed state: first page, next page, refresh
    screens/news_feed_screen.dart    Home screen
    screens/news_article_screen.dart Reader screen
    screens/web_article_screen.dart  In-app browser for the original page
    widgets/                         Cards, brand marks, shared meta line
tools/
  news_seeder/                       Firestore bootstrap script
  build_release.sh                   Builds and names the aab/apk
  deploy_firestore_rules.sh          Publishes firestore.rules
```
