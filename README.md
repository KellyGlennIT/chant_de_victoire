# Chants de Victoire
**A French-language hymnbook built for reading, singing, and remembering.**

Chants de Victoire brings a collection of Christian hymns into a mobile reading experience. Instead of relying on a connection to look up lyrics, the app carries its hymn texts with it. You can find a song by title or number, read it with historical context when available, keep favorites close, and follow the words hands-free in a full-screen worship view. It also gives you a place to write and save your own songs.

The project combines the familiar structure of a numbered hymnbook with practical tools for personal devotion and congregational singing. The hymn texts are primarily in French; some navigation and settings labels are currently in English.

## The experience
### Explore the hymnbook
The **Home** tab displays the built-in hymns, numbered through **400**, alongside **43 short chorals**. Some hymns use lettered numbers such as `25a` and `25b`. Search matches a title or number, so you can go straight to a familiar hymn or browse the collection. The lyrics are bundled in the app rather than fetched when you open a song.

Opening a hymn takes you to a reader with scrollable lyrics. When a record includes supporting details, an expandable section shows the author, year, and background of the song. These notes are part of the hymn data, not a live lookup. The **More → Sources** screen lists references used for historical information.

### Make the words easier to follow
The reader uses a dark theme with a configurable lyric font size. Tap its full-screen button to enter **Worship mode**: a black, distraction-light view with large centered lyrics. Start or stop automatic scrolling and adjust its speed from within that view. The **More** tab also lets you set a default scroll speed and reading font size, which are retained between sessions.

### Keep and create songs
- **Favorites:** Star a built-in hymn from the list or its reader to add it to the Favorites tab. Unstar it to remove it. This list is saved on the device.
- **Write:** Enter a title and lyrics to save a personal song. Search saved songs by title or lyrics, open one in the same reader, share it, or delete it. The Write tab is a collection of individual songs, not a playlist editor; the current interface does not edit an existing song after it has been saved.
- **Share:** From a hymn's reader or a saved song, send its title and lyrics through the system share sheet, or generate and share a PDF. The option labeled “TXT” shares plain text; it does **not** create a `.txt` file.

### Learn and connect
The **Learn** tab embeds an external hymn resource at `https://cantiques.yapper.fr/player/?filter=CV` in a WebView. It is separate from the offline hymn collection and needs internet access. The **More** tab includes app information, a Sources screen, external links, and links to the assembly's map and phone dialer. Some promotional and social links in the code are placeholders; verify them before publishing or sharing the app broadly.

## How the project is put together
This is a Flutter application targeting the configured mobile platforms, Android and iOS. Its current app logic and bundled content live together in `lib/main.dart`:

1. **Hymn model and collection:** Each `Hymn` stores a number, title, lyrics, and optional author, year, and history; custom songs use the same model. The built-in list is compiled into the application.
2. **Navigation and screens:** A splash screen leads to five tabs—Home, Favorites, Write, Learn, and More. Readers and supporting pages open from those tabs. The UI uses a dark palette with green and gold accents and adjusts spacing for screen width.
3. **Local preferences:** `shared_preferences` stores favorite hymn numbers, custom songs encoded as JSON, font size, and scroll speed. These are local device preferences, not an account or cloud backup.
4. **Export:** `pdf` builds A4 pages for an individual hymn or custom song, `path_provider` supplies the application's documents directory, and `share_plus` opens the native share sheet. Longer lyrics are divided into page-sized line groups. The code also contains helpers to generate PDFs of all favorites or all custom songs, but those bulk exports are **not exposed in the current UI**.
5. **External content:** `webview_flutter` displays the Learn page; `url_launcher` opens outside links and phone/map actions. `font_awesome_flutter` supplies icons on the About page.

### What works offline?

| Activity | Connection needed? |
| --- | --- |
| Browse and read bundled hymn lyrics | No |
| Search hymns, use worship mode, manage favorites | No |
| Write songs and change reading preferences | No |
| Open the Learn tab's external page | Yes |
| Open web links or share through another app | Depends on the destination app and service |

Data stored with `shared_preferences` remains on that installation unless the device or app clears it. This project does not implement sign-in, synchronization, or a backup/restore workflow.

## Run the project
Install the [Flutter SDK]{https://docs.flutter.dev/get-started/install} and set up an Android or iOS development environment. `pubspec.yaml` specifies Dart `>=3.0.0 <4.0.0`; use a Flutter installation compatible with that range. From the project root, with a device or emulator available:

```sh
flutter pub get
flutter run
```

To build for Android using your configured Flutter toolchain:

```sh
flutter build apk
```

The project version in `pubspec.yaml` is `1.0.0+1`. Its dependencies include `shared_preferences`, `share_plus`, `pdf`, `path_provider`, `webview_flutter`, `url_launcher`, and `font_awesome_flutter`; `flutter_test`, `flutter_lints`, and `flutter_launcher_icons` are listed as development dependencies. No application tests are included in the current checkout.

> **Icon configuration:** The launcher-icons configuration points to the icon image under `assets/icon/` for Android and iOS. The `assets/` directory is absent from this checkout; add the image before generating launcher icons.

## Sources and content considerations
Historical notes appear only where included with a hymn. The in-app Sources screen links to a 1915 edition of *Chants de Victoire* on Internet Archive and other hymn-reference sites; it is a list of references, not a per-hymn citation system. Review individual historical claims and the rights to hymn texts, translations, and any exports before distributing the app or its content.

The About screen credits **Br. Mbuna Kelly Glenn A.** as founder and developer and describes the aim as preserving worship, strengthening spiritual discipline, and modernizing access to hymns.

---

*Chants de Victoire — the words for worship, close at hand.*
