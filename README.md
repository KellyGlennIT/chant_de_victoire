# Chants de Victoire
**A French-language hymnbook built for reading, singing, and remembering.**

Chants de Victoire brings the collection of Christian hymns into a mobile reading experience. Instead of relying on a connection to look up lyrics, the app carries its hymn texts with it. You can find a song by title, number, author, theme, or a line of lyrics, read it with historical context, keep favorites close, and follow the words hands-free in a full-screen worship view. It also gives you a place to write, edit, and share your own songs.

The project combines the familiar structure of a numbered hymnbook with practical tools for personal devotion and congregational singing. The app interface and hymn texts are in French.

---

## Table of contents
- [The experience](#the-experience)
- [Hymn data](#hymn-data)
- [How the project is put together](#how-the-project-is-put-together)
- [What works offline?](#what-works-offline)
- [Run the project](#run-the-project)
- [Platform notes](#platform-notes)
- [Project structure](#project-structure)
- [Known limitations and placeholders](#known-limitations-and-placeholders)
- [Sources and content considerations](#sources-and-content-considerations)

---

## The experience

### Explore the hymnbook
The **Chants** tab lists the bundled hymnbook: **457 entries** in total — **414 numbered hymns** (numbered `1`–`400`, including 28 lettered variants such as `25a`, `25b`, `31a`, `31b`) and **43 short chorals** labelled `Choral 1`–`Choral 43`.

Search is more than a title filter. Results are ranked by relevance across several fields:

| Match | Example |
| --- | --- |
| Exact number | `25a` |
| Number prefix | `25` |
| Exact or partial title | `victoire` |
| Whole word in title, then any substring | `grand` |
| Author | `empaytaz` |
| Theme | `adoration` |
| Lyrics (from 2 characters up) | `prosternés` |

Search is **accent-insensitive**: typing `benissons` finds `Grand Dieu, nous te bénissons`, and `oe`/`œ` are folded together. Lyrics are bundled with the app and read from an asset file, not fetched when you open a song.

Opening a hymn takes you to a reader with scrollable lyrics. The **À propos** button (info icon) in the reader's app bar opens a draggable bottom sheet with the supporting details when present: author, year, composer, translator, biblical reference, themes, source, history, and verification note. The sheet opens at 65% of the screen height and can be drag-resized between 30% and 95%, so the lyrics are never fully covered.

### Make the words easier to follow
The reader uses a dark theme with a configurable lyric font size, and lyrics are selectable and copyable (`SelectionArea`). Tap the floating full-screen button to enter **Worship mode**: a black, minimal-distraction view with large centered lyrics. You can start or stop automatic scrolling and change its speed from inside that view. The **Plus** (More) tab also sets a default reading font size (14–40) and scroll speed (5–50); both are saved between sessions.

### Keep and create songs
- **Favorites (Favoris):** Star any hymn from the list or its reader to add it to the **Favoris** tab; unstar to remove it. The list is saved on the device. A PDF export of the whole favorites list is available from the Favorites screen.
- **Write (Écrire):** Create a personal song with a title and lyrics, plus optional metadata (author, composer, translator, year, source, biblical reference, themes, history). The editor includes helper buttons for *Couplet*, *Refrain*, *Pont*, and *Séparer une strophe*, a live **Aperçu** (preview), and **Brouillon** (draft) auto-save — if you leave mid-edit, the app offers to restore your draft. Saved songs can be **edited** (Modifier), shared as text, exported to PDF, or deleted. **Mes chants** lists your saved songs and can be searched by title, lyrics, author, or theme.
- **Share:** From a hymn's reader or a saved song, send the title, lyrics, and metadata through the system share sheet, or generate and share a PDF. The PDF uses A4 pages and splits long lyrics into page-sized line groups.

Bulk export helpers exist for *all favorites* and *all custom songs* as PDFs.

### Learn and connect
The **Apprendre** (Learn) tab embeds an external hymn player at `https://cantiques.yapper.fr/player/?filter=CV` in a WebView. It is separate from the offline hymn collection and needs internet access. The **Plus** tab contains:

- **Taille du texte** and **Vitesse de défilement** sliders
- **À propos** — the developer screen
- **Sources** — references used for historical data
- **Plus d'applications** — a "coming soon" notice for *Artist Notebook*
- **Partager l'application** — shares a Google Play search link
- The assembly's location (opens Google Maps) and phone number (opens the dialer)

---

## Hymn data

The bundled catalogue lives in `assets/data/chants_de_victoire_hymns.json` (~1.5 MB) and is declared in `pubspec.yaml`. It is a JSON array of objects:

```json
{
  "number": "1",
  "title": "Grand Dieu, nous te bénissons",
  "lyrics": "1. Grand Dieu, nous te bénissons,\n...",
  "isCustom": false,
  "auteur": "Henri-Louis Empaytaz (1790–1853) ...",
  "annee": "Version française traditionnellement datée de 1817 ...",
  "histoire": "« Grand Dieu, nous te bénissons » appartient à la famille du Te Deum ...",
  "compositeur": "Mélodie « Grosser Gott / Holy God, We Praise Thy Name » ...",
  "traducteur": "Adaptation française attribuée à Henri-Louis Empaytaz.",
  "source": "Cantiquest, CV n°1 ... https://cantiques.yapper.fr/CV/CV_001.html ; ...",
  "referenceBiblique": "Te Deum ; résonances avec les Psaumes ...",
  "themes": "Louange, adoration, Trinité, liturgie",
  "metadataReviewNote": "Paroles comparées à la transcription CV_001 ...",
  "lyricsReviewStatus": "...",
  "statutHistorique": "..."
}
```

Notes on the schema:

- `number`, `title`, and `lyrics` are **required**; all other fields are optional strings.
- `number` is a string so lettered variants (`25a`) and chorals (`Choral 1`) can share the same model.
- The two additional fields in the asset (`lyricsReviewStatus`, `statutHistorique`) are **not** read by the app model — they are editorial metadata kept for provenance tracking.
- Every entry currently carries `auteur`, `annee`, `histoire`, `source`, and `metadataReviewNote`; `themes` is present on 306 of 457 entries.
- `metadataReviewNote` is shown in shared text but not in the reader card.

### Validation on load
The loader (`loadHymnsFromAssets()`) is strict. It throws a `FormatException` — surfacing an error screen with **Réessayer** — when the file:

- cannot be read from the bundle,
- is not valid JSON, or is not a top-level **list**,
- contains an entry that is not a JSON object,
- has a hymn with an empty/missing `number`, `title`, or `lyrics`,
- has a non-boolean `isCustom` value,
- has a **duplicate hymn number**.

Two checks that are easy to miss when adding content: the file must be a **list at the top level** (not `{"hymns": [...]}`), and no two entries may share a number.

---

## How the project is put together

This is a Flutter application targeting Android and iOS. The app logic is currently in a single file, `lib/main.dart` (~3,600 lines).

1. **Model (`Hymn`):** A single class for built-in and custom songs. `toJson()`/`fromJson()` round-trip the optional metadata through the same schema used by the asset file, so custom songs are stored in exactly the same shape.
2. **Data loading:** `allHymns` holds the in-memory catalogue, with a `_HymnSearchIndex` map built once after load. Search indexes are pre-folded (lowercase + accent-stripped) strings, so each keystroke only folds the query.
3. **Navigation and screens:** A splash screen loads the catalogue and preferences, then shows five tabs — **Chants, Favoris, Écrire, Apprendre, Plus**. Readers, worship mode, the developer page, and the sources page push on top of those tabs. The UI uses a dark palette with green (`#1B5E20`) and gold accents.
4. **Reader (`HymnReaderScreen`):** The screen opened for any hymn or saved song. It keeps the favorite state locally, surfaces the hymn's metadata on demand through the **À propos** bottom sheet (`InfoAuteurChant`), and hands the hymn to `WorshipModeScreen` for full-screen reading. Its app bar menu offers export as TXT (system share sheet) or PDF (`PdfGenerator`), and custom songs show no favorite star.
5. **Local preferences:** `shared_preferences` stores favorite numbers (`favorites`, a string list), custom songs (`customSongs`, JSON-encoded), font size (`fontSize`), scroll speed (`scrollSpeed`), and the write-tab draft (`chantWriterDraftV2`).
6. **Export:** `pdf` builds A4 documents, `path_provider` supplies the documents directory for the generated file, and `share_plus` opens the native share sheet.
7. **External content:** `webview_flutter` displays the Learn page; `url_launcher` opens links, the map, and the dialer; `font_awesome_flutter` supplies the social icons on the developer page.

---

## What works offline?

| Activity | Connection needed? |
| --- | --- |
| Browse and read bundled hymn lyrics | No |
| Search hymns, use worship mode, manage favorites | No |
| Write and edit songs, change reading preferences | No |
| Export and share a PDF | No (sharing depends on the destination app) |
| Open the Learn tab's external page | **Yes** |
| Open web links, map, or share through another app | Depends on the destination app and service |

Data stored in `shared_preferences` remains on that installation unless the device or app data is cleared. The project does **not** implement sign-in, synchronization, or a backup/restore workflow — uninstalling the app loses custom songs and favorites.

---

## Run the project

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) with Dart `>=3.0.0 <4.0.0`
- For iOS: **macOS**, Xcode 15 or newer, CocoaPods, and an iOS 15.0+ device or simulator
- For Android: the Android SDK and a device or emulator

The project was created with **Flutter 3.47.5 (stable)** and targets **iOS 15.0**.

### Commands
From the project root:

```sh
flutter pub get
flutter devices          # confirm a device or simulator is available
flutter run
```

### Build for Android

```sh
flutter build apk              # debug-friendly APK
flutter build appbundle        # Play Store AAB
```

### Build for iOS (requires macOS + Xcode)

```sh
flutter build ios --release --no-codesign   # compile check without signing
open ios/Runner.xcworkspace                 # archive for TestFlight/App Store
```

Or simply `flutter run` on a connected iPhone or simulator from a Mac.

> **Cannot build iOS from Windows.** The `ios/` folder can be edited on any OS, but Xcode and the iOS toolchain only run on macOS.

---

## Platform notes

### iOS
The `ios/` folder is a standard Flutter project using **Swift Package Manager** for plugins (there is intentionally **no `Podfile`** — the plugins are wired through `Flutter/ephemeral/Packages/FlutterGeneratedPluginSwiftPackage`, referenced by `project.pbxproj`).

Key settings:

| Setting | Value |
| --- | --- |
| Deployment target | iOS `15.0` |
| Bundle identifier | `com.example.chantDeVictoire` (**change before release**) |
| Display name | `Chant De Victoire` |
| Device family | iPhone + iPad |
| Flutter entry | `AppDelegate` (`FlutterImplicitEngineDelegate`) + `SceneDelegate` (`FlutterSceneDelegate`) |
| Registered plugins | `share_plus`, `shared_preferences_foundation`, `url_launcher_ios`, `webview_flutter_wkwebview` |

**Before publishing to the App Store:**

1. Change `PRODUCT_BUNDLE_IDENTIFIER` from `com.example.*` to your own reverse-DNS identifier in `ios/Runner.xcodeproj/project.pbxproj` (all three Runner configurations).
2. Set your **Team** in Xcode → *Runner* → *Signing & Capabilities* (Automatic signing).
3. Optionally add `ITSAppUsesNonExemptEncryption = <false/>` to `Info.plist` to skip the export-compliance question on each upload. The app uses only standard HTTPS via `web_view_flutter` and `url_launcher`, so `false` is normally correct — confirm with Apple's guidance for your case.
4. The Learn WebView loads an HTTPS page, so no `NSAppTransportSecurity` exception is needed. If you later load `http://` URLs, you will need one.

### Android
The Android project uses Kotlin DSL build files (`build.gradle.kts`), application ID `com.example.chant_de_victoire`, and a Kotlin `MainActivity`. Change the application ID and app label in `android/app/build.gradle.kts` and `AndroidManifest.xml` before publishing.

---

## Project structure

```
chant_de_victoire/
├── lib/
│   └── main.dart                               # entire app: model, loader, screens, PDF export
├── assets/
│   └── data/
│       └── chants_de_victoire_hymns.json       # 457 bundled hymns & chorals (~1.5 MB)
├── android/                                    # Kotlin DSL Gradle project
├── ios/
│   ├── Runner/
│   │   ├── AppDelegate.swift
│   │   ├── SceneDelegate.swift
│   │   ├── Info.plist
│   │   └── Base.lproj/                         # Main & LaunchScreen storyboards
│   ├── Runner.xcodeproj/
│   └── Runner.xcworkspace/
├── pubspec.yaml
└── README.md
```

---

## Known limitations and placeholders

These are visible in the code today and worth fixing before a public release:

- **Developer screen contact details are placeholders:** the email and phone show `XXX XXX XXX`.
- **Social links are partly generic:** the Instagram, YouTube, and LinkedIn icons open the sites' home pages rather than a profile. The WhatsApp, Facebook, and TikTok links point to specific accounts — verify them.
- **“Partager l'application”** shares a *Google Play search* URL, not an app listing. If the app is on the App Store, the link will send iOS users to Google Play.
- **“Plus d'applications”** is a "coming soon" placeholder (*Artist Notebook*).
- **Bundle identifiers are `com.example.*`** on both platforms.
- **No automated tests.** `test/` is empty, and `ios/RunnerTests/RunnerTests.swift` contains only the template test, which asserts nothing.
- **The asset does not include application launcher icons.** `flutter_launcher_icons` in `pubspec.yaml` points at `assets/icon/icon.png`, and that file is missing. Create `assets/icon/icon.png` and run `dart run flutter_launcher_icons` if you want generated icons; otherwise the existing default Flutter icons are used.
- **Encoding check needed on the hymn file.** Raw inspection of `assets/data/chants_de_victoire_hymns.json` (read with UTF-8) showed sequences such as `Ã©` and `â€™`. This usually means the file is Windows-1252 encoded while the app decodes it as UTF-8, which would render accents as mojibake (`bÃ©nissons` instead of `bénissons`). `flutter analyze` cannot detect this. Verify by opening the asset as UTF-8, or by reading hymn 1 on a device; if it is affected, re-save the file as UTF-8.
- **All app logic is in `lib/main.dart`.** It is 3,751 lines, but the file is longer than its content: whole class blocks (`Hymn`, `HymnReaderScreen`/`_HymnReaderScreenState`) appear twice, and the second copy shadows the first. A duplicate `HymnReaderScreen` makes the project **fail to compile** with `duplicate_definition`; it was removed so `flutter analyze` reports no issues, but the remaining duplicate `Hymn` block and commented-out screens should be cleaned up. Splitting the file into `models/`, `screens/`, `services/`, and `widgets/` would make the project much easier to maintain.
- **UI changes in the reader must be kept in one place.** Because `main.dart` has (and has had) duplicated reader code, edit the definition near the top of the file — the `// ======================== READER ========================` section — and verify with `flutter analyze --no-pub` that no duplicate class came back.

---

## Sources and content considerations

The hymn texts are drawn from the *Chants de Victoire* tradition; the 1915 edition referenced below is public domain in most jurisdictions, but modern French adaptations, translations, and editorial notes may still be protected. Confirm the status of the specific texts and translations you ship.

Historical notes are attached to each hymn record. The **Sources** screen (`Plus → Sources`) lists the references used to check that material:

- [Chants de Victoire — full text (1915)](https://archive.org/details/chantsdevictoire00unse/page/n5/mode/2up) on Internet Archive
- [Hymnary.org](https://hymnary.org) — hymnological database
- [Cantiquest](https://cantiquest.com)
- [JEMAF](https://jemaf.fr)
- [Chants et Hymnes Chrétiens](https://chantsethymneschretiens.blogspot.com)

This is a **list of reference sites**, not a per-hymn citation system with page-level provenance. Each record also has its own `source` field, which is where per-hymn references live.

Before distributing the app or its content, review:

- the rights to hymn texts and translations, and to any exported PDFs,
- whether the historical claims in `histoire` fields are accurate to the edition consulted,
- the licence for the app code (no `LICENSE` file is currently included).

The developer page credits **Br. Mbuna Kelly Glenn A.** as founder and developer and describes the aim as "preserving worship, strengthening spiritual discipline, and modernizing sacred hymn access for believers everywhere."

---

*Chants de Victoire — the words for worship, close at hand.*
