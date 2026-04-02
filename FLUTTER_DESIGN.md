# Hush — Flutter Codebase Design Document

> **Purpose:** This document is a living reference that explains every file in the Flutter codebase —
> what it does, how it connects to other files, and why we made each technical choice.
> It is updated automatically every time code changes.
>
> **Who this is for:** You. If you've never touched Flutter before, start at Section 1 and read top-down.
> Return to the relevant section whenever you're working on a specific part of the app.

---

## How to Read This Document

Each section maps to a folder in `frontend/lib/`. For each file you'll find:
- **What it is** — plain English, no jargon
- **What it does** — the job this file has
- **How it connects** — which other files use it, or which files it depends on
- **Key concept** — the Flutter/Dart idea you need to understand to work on it

---

## Section 0 — Flutter Fundamentals (Read This First)

### What is Flutter?
Flutter is Google's UI framework. You write Dart code, and Flutter compiles it down to native
Android/iOS code — no JavaScript bridge, no web view. It's fast and looks native.

### Everything is a Widget
The single most important concept in Flutter: **everything on screen is a widget**.
A button is a widget. A text label is a widget. A screen is a widget. Even padding is a widget.
Widgets are composable — you build complex UIs by nesting simpler widgets inside each other.

### Stateless vs Stateful Widgets
- **StatelessWidget** — shows something that never changes. Like a label or an icon.
- **StatefulWidget** — has internal state that can change, triggering a screen rebuild. Like a counter or a form.
- **ConsumerWidget / ConsumerStatefulWidget** — Riverpod-aware widgets that can `ref.watch()` providers.

### How Flutter Renders
`main.dart` calls `runApp()` → Flutter takes the widget tree you give it → renders it to the screen.
When state changes (via `setState()` or Riverpod), Flutter re-renders only the parts that changed.

### Hot Reload vs Hot Restart
- **Hot reload (`r`)** — injects code changes into the running app. State is preserved. Use for UI tweaks.
- **Hot restart (`R`)** — fully restarts the app. State is lost. Use when you add new providers or change structure.

---

## Section 1 — Entry Point

### `lib/main.dart`
**What it is:** The front door of the entire app. The first Dart file that runs.

**What it does:**
1. Calls `DatabaseService.init()` to open/create the SQLite database
2. Calls `ReminderService.init()` to re-schedule any saved daily writing reminder
3. Wraps the app in `ProviderScope` (required for Riverpod state management to work)
4. Watches the active `HushTheme` from `themeProvider` and applies it to `MaterialApp`
5. Uses `go_router` via `routerProvider` for navigation

**How it connects:**
- `DatabaseService.init()` from `core/database/isar_service.dart`
- `ReminderService.init()` from `services/reminder_service.dart`
- `themeProvider` from `providers/theme_provider.dart`
- `routerProvider` from `router/app_router.dart`

**Key concept — ProviderScope:**
Think of `ProviderScope` as a global container that holds all your app's state (notes, themes, lock status).
Every widget inside it can read from or write to that state. It must wrap your entire app.

---

## Section 2 — Core Layer (`lib/core/`)

The `core/` folder contains foundational services that the rest of the app depends on.
These are not screens or UI — they are pure logic and infrastructure.

---

### `lib/core/constants/app_constants.dart`
**What it is:** A file of fixed values that don't change.

**What it does:** Stores things like: default folder name ("General"), autosave debounce time (1500ms),
search debounce time (300ms), app version string.

**How it connects:** Imported by services and widgets that need these values.

---

### `lib/core/constants/theme_constants.dart`
**What it is:** The definition of every visual theme in the app.

**What it does:** Defines the `HushTheme` class and a `kHushThemes` list of all 9 themes:
Classic, Midnight, Parchment, Sakura, Ocean, Forest, Slate, Rose Gold, Noir.

**`HushTheme` key fields:**
| Field | Type | Purpose |
|---|---|---|
| `id` | String | Unique identifier for persistence |
| `name` | String | Display name |
| `primary` | Color | Accent colour (buttons, highlights) |
| `surface` | Color | AppBar / card background |
| `pageBackground` | Color | BookPage background |
| `pageLines` | Color | Ruled-line / dot / grid colour |
| `pageStyle` | PageStyle | `blank`, `ruled`, `dotted`, or `grid` |
| `textPrimary` | Color | Main text colour |
| `textSecondary` | Color | Subdued text colour |

**How it connects:**
- `providers/theme_provider.dart` reads `kHushThemes` to know which themes exist
- `screens/settings/settings_screen.dart` displays theme swatches
- `screens/book/book_screen.dart` and `widgets/book/book_page.dart` use the active theme for page rendering

---

### `lib/core/crypto/encryption_service.dart`
**What it is:** The security heart of the app. Handles all encryption and decryption.

**What it does:**
- `encrypt(plaintext, key)` → AES-256-GCM → returns `EncryptedPayload(ciphertext, iv, authTag)`
- `decrypt(payload, key)` → returns the original plaintext string
- Uses `pointycastle` package (pure Dart crypto)

**Key concept — AES-256-GCM:**
AES-256 = the encryption algorithm (scrambles your text into unreadable bytes using a 256-bit key).
GCM = the mode (produces an `authTag` — if anyone tampers with the ciphertext, decryption fails).
IV = a 12-byte random value per encryption — ensures identical plaintexts produce different ciphertexts.

---

### `lib/core/crypto/key_derivation.dart`
Turns a human password/PIN into a 32-byte cryptographic key using PBKDF2-SHA256 (310,000 iterations).
`generateSalt()` returns 32 random bytes stored once per install in `flutter_secure_storage`.

---

### `lib/core/crypto/key_store.dart`
Saves/loads the master key via `flutter_secure_storage` (Android Keystore-backed).
The key is only loaded after successful biometric auth — never accessible while locked.

---

### `lib/core/auth/biometric_auth.dart`
Wraps `local_auth` package. `authenticate(reason)` shows the system biometric prompt.
Returns `true` on success, `false` on failure. `biometricOnly: false` allows PIN fallback.

---

### `lib/core/auth/app_lock_notifier.dart`
Riverpod `StateNotifier` managing locked/unlocked state.
- `unlock()` → biometric auth → loads master key from `KeyStore` → emits unlocked state
- `lock()` → clears master key from memory → emits locked state
- `masterKeyProvider` → exposes the in-memory `Uint8List?` key (null when locked)

**Critical:** The router watches `appLockProvider`. If locked, ALL routes redirect to `/lock`.

---

### `lib/core/database/isar_service.dart`
**What it is:** The SQLite database singleton.
(File named `isar_service.dart` for historical reasons — internally uses **sqflite**.)

**Schema (v6):**

| Table | Key columns |
|---|---|
| `notes` | id, folder_id, title, encrypted_body, iv, auth_tag, is_pinned, is_archived, is_deleted, word_count, reading_time_sec, cover_color, font_family, page_number, sort_order, page_layout, layout_images, created_at, updated_at |
| `folders` | id, name, color, icon, is_locked, encrypted_folder_key, cover_image_path, sort_order, created_at, updated_at |
| `tags` | id, name, color, created_at |
| `note_tags` | note_id (FK→notes), tag_id (FK→tags) — many-to-many join table |

**Migration strategy:**
- `onCreate` = `_createTables` — defines full schema for fresh installs. Also inserts the default "General" folder (id=1).
- `onUpgrade` = `_onUpgrade` — consecutive `if (oldVersion < N)` blocks. Safe for multi-version jumps.
- v1→v2: added `tags` and `note_tags` tables.
- v3: added `sort_order` to `notes`.
- v4: added `idx_notes_title` and `idx_notes_updated` indexes.
- v5: added `cover_image_path` to `folders`.
- v6: added `page_layout` and `layout_images` to `notes`.
- `PRAGMA foreign_keys = ON` is executed after open so `ON DELETE CASCADE` on `note_tags` works.

**`DatabaseService.instance`** returns the open `Database` handle. All services use this.

---

### `lib/core/utils/text_utils.dart`
- `countWords(text)` — splits by whitespace and counts
- `formatReadingTime(seconds)` — "< 1 min read", "~2 min read"

---

## Section 3 — Data Models (`lib/models/`)

Plain Dart classes. Each model maps to a SQLite table.
`toMap()` converts to a `Map<String, dynamic>` for sqflite inserts.
`fromMap()` converts a sqflite row back to a Dart object.

---

### `lib/models/note.dart`
| Field | Type | SQLite column |
|---|---|---|
| `id` | int? | `id` (PK AUTOINCREMENT) |
| `folderId` | int | `folder_id` |
| `title` | String | `title` |
| `encryptedBody` | String | `encrypted_body` (base64 AES ciphertext) |
| `iv` | String | `iv` (base64, 12 bytes) |
| `authTag` | String | `auth_tag` (base64, 16 bytes GCM tag) |
| `isPinned` | bool | `is_pinned` (0/1) |
| `isArchived` | bool | `is_archived` (0/1) |
| `isDeleted` | bool | `is_deleted` (0/1) |
| `wordCount` | int | `word_count` |
| `readingTimeSec` | int | `reading_time_sec` |
| `coverColor` | String | `cover_color` (hex string) |
| `fontFamily` | String | `font_family` |
| `pageNumber` | int | `page_number` |
| `sortOrder` | int | `sort_order` |
| `pageLayout` | String | `page_layout` — `'text_only'` \| `'image_side'` \| `'collage'` |
| `layoutImages` | List\<String\> | `layout_images` (JSON-encoded array of absolute file paths) |
| `createdAt` | DateTime | `created_at` (ISO-8601 string) |
| `updatedAt` | DateTime | `updated_at` (ISO-8601 string) |

**The critical point about `encryptedBody`:**
The actual note content is NEVER stored as plain text. It's encrypted before being saved to SQLite,
and decrypted in memory when you open the note.

---

### `lib/models/folder.dart`
| Field | Purpose |
|---|---|
| `id` | Auto-increment PK |
| `name` | Display name |
| `color` | Hex colour for the card accent |
| `icon` | String key mapping to `IconData` in `FolderCard` |
| `isLocked` | If true, opening requires a PIN |
| `encryptedFolderKey` | Stores `pin:SHA256(salt+pin)` when locked |
| `coverImagePath` | Absolute file path to per-journal cover photo (nullable) |
| `sortOrder` | User-defined grid order |

`FolderCopyWith` extension (in `folder_service.dart`) provides `copyWith()` without touching this model.

---

### `lib/models/tag.dart`
| Field | Purpose |
|---|---|
| `id` | Auto-increment PK |
| `name` | Unique tag label |
| `color` | Hex colour for chip display |
| `createdAt` | Creation timestamp |

---

## Section 4 — Providers (`lib/providers/`)

We use **Riverpod v2**, manually written (no `@riverpod` code generation).

**Pattern used throughout:**
- `FutureProvider` / `FutureProvider.family` — for async read-only data (lists)
- `StateNotifierProvider` — for mutable state with write operations
- After any write, the notifier calls `_ref.invalidate(theProvider)` to trigger a re-fetch

---

### `lib/providers/notes_provider.dart`
- `notesProvider` — `FutureProvider.family<List<Note>, int?>` — loads notes by folderId (null = all)
- `NotesNotifier` — handles `createNote`, `updateNote`, `deleteNote`, `pinNote`, `archiveNote`, `moveToFolder`
- After any write: invalidates both `notesProvider` AND `foldersProvider` (so folder entry counts refresh)

---

### `lib/providers/folder_provider.dart`
- `foldersProvider` — `FutureProvider<List<Folder>>` — loads all folders ordered by `sort_order`
- `FoldersNotifier` — handles `createFolder`, `updateFolder`, `deleteFolder`
- After any write: invalidates `foldersProvider`

---

### `lib/providers/tag_provider.dart`
- `tagsProvider` — `FutureProvider<List<Tag>>` — all tags
- `noteTagsProvider` — `FutureProvider.family<List<Tag>, int>` — tags for a specific note id
- `TagsNotifier` — handles `createTag`, `deleteTag`

---

### `lib/providers/theme_provider.dart`
- `themeProvider` — `StateNotifierProvider<ThemeNotifier, HushTheme>`
- Persists selected theme id to `SharedPreferences` — survives app restarts
- `main.dart` watches this and rebuilds `MaterialApp` when theme changes

---

### `lib/providers/background_provider.dart`
- `backgroundProvider` — `StateNotifierProvider<BackgroundNotifier, AppBackground>`
- `AppBackground` = union of three types: `color(Color)`, `gradient(List<Color>)`, `image(String path)`
- `kBackgroundPresets` — 12 built-in presets (6 solid colours + 6 gradients)
- `BackgroundNotifier` exposes `setColor`, `setGradient`, `setImage`, `setPreset`
- Persists to `SharedPreferences` (`bg_type`, `bg_color`, `bg_grad0/1`, `bg_image` keys)

---

### `lib/providers/typography_provider.dart`
- `typographyProvider` — `StateNotifierProvider<TypographyNotifier, AppTypography>`
- `AppTypography` = { fontFamily, fontScale (0.85–1.3), textColor, useCustomColor }
- `kAppFonts` — 7 Google Font families selectable as app-wide body text
- `kFontScales` — Small / Default / Large / XL size multipliers
- `kTextColorPresets` — 8 preset text colour swatches
- Persists to `SharedPreferences`

---

## Section 5 — Services (`lib/services/`)

Services contain business logic. They're pure Dart — no Flutter widgets, no providers.

---

### `lib/services/note_service.dart`
**Core operations:**

| Method | What it does |
|---|---|
| `getNotes({folderId})` | SELECT with optional folder filter, excludes soft-deleted |
| `getNoteById(id)` | Fetch a single note |
| `createNote({title, deltaJson, masterKey, folderId})` | Encrypts delta JSON → inserts row |
| `updateNote({note, deltaJson, masterKey, title})` | Re-encrypts → updates row |
| `softDelete(note)` | Sets `is_deleted=1` — note stays in DB but hidden |
| `decryptBody(note, masterKey)` | Decrypts `encrypted_body`+`iv`+`auth_tag` → Quill Delta JSON string |
| `pinNote(note, {pinned})` | Flips `is_pinned` |
| `archiveNote(note, {archived})` | Flips `is_archived` |
| `moveToFolder(note, folderId)` | Updates `folder_id` |
| `getNotesPerDay()` | `SELECT DATE(created_at), COUNT(*)` → `Map<DateTime, int>` for heatmap |

**Encrypt-then-save pipeline (every auto-save):**
```
Quill Delta JSON string
    ↓  EncryptionService.encrypt(deltaJson, masterKey)
EncryptedPayload(ciphertext, iv, authTag)
    ↓  db.insert('notes', note.toMap())
Stored as base64 strings in SQLite
```

---

### `lib/services/folder_service.dart`
| Method | What it does |
|---|---|
| `getFolders()` | SELECT all folders ORDER BY sort_order |
| `getFolderById(id)` | Fetch a single folder by id |
| `createFolder({name, color, icon})` | Inserts with next sort_order |
| `updateFolder(folder)` | UPDATE row |
| `deleteFolder(id)` | Moves notes to General (folder_id=1), then deletes folder |
| `noteCount(folderId)` | `SELECT COUNT(*) WHERE folder_id=? AND is_deleted=0` |
| `noteCountsAll()` | Single GROUP BY query — returns `Map<int,int>` for all folders |
| `setCoverImage(folderId, path)` | Stores absolute image path (null clears it) |
| `setPin(folderId, pin)` | Stores SHA-256(salt+pin) in `encrypted_folder_key` |
| `removePin(folderId)` | Clears `is_locked=0` and `encrypted_folder_key=null` |
| `verifyPin(folderId, pin)` | Compares hash — returns bool |

**Important:** General folder always has `id=1` (first row inserted by `_createTables`). The FAB in
HomeScreen routes new notes to `folderId=1` to ensure they appear in the General journal.

---

### `lib/services/tag_service.dart`
| Method | What it does |
|---|---|
| `getAllTags()` | SELECT all tags |
| `createTag({name, color})` | INSERT with UNIQUE constraint on name |
| `deleteTag(id)` | DELETE — CASCADE removes `note_tags` rows |
| `getTagsForNote(noteId)` | JOIN `note_tags` → `tags` |
| `setTagsForNote(noteId, tagIds)` | Transaction: DELETE existing, INSERT new |

---

### `lib/services/reminder_service.dart`
Daily writing reminder using `flutter_local_notifications v21`.

| Method | What it does |
|---|---|
| `init()` | Initializes plugin + timezone DB, re-schedules if previously enabled |
| `scheduleDaily(TimeOfDay)` | Cancels old, schedules new via `zonedSchedule()` |
| `cancelAll()` | Cancels notification, clears prefs |
| `isEnabled()` | Reads from SharedPreferences |
| `getSavedTime()` | Returns saved hour/minute (default 20:00) |

**Android requirements:**
- `POST_NOTIFICATIONS` permission (Android 13+)
- `RECEIVE_BOOT_COMPLETED` permission + boot receiver in AndroidManifest
- `isCoreLibraryDesugaringEnabled = true` in `build.gradle.kts` + `desugar_jdk_libs:2.1.4` dependency
  (required because flutter_local_notifications v21 uses `java.time` APIs not in older Android runtimes)

---

## Section 6 — Screens (`lib/screens/`)

---

### `lib/screens/lock/lock_screen.dart`
First screen on every launch. Tap "Unlock with Biometric" → triggers `appLockProvider.notifier.unlock()`.
On success, router redirects to `/home`. Has "Dev: Skip Auth" button in debug builds only.

---

### `lib/screens/home/home_screen.dart`
**The dashboard.** Two-tab layout:

**Journals tab:**
- `SliverGrid` of `FolderCard` widgets (2-column) + a "New journal" placeholder card at the end
- Tap folder → opens `BookScreen` for that folder (`/book?folderId=N`)
- Long-press folder → bottom sheet with delete option
- Tap "New journal" → `_CreateFolderSheet` bottom sheet (name + 8 colour swatches + 8 icon options)

**All Entries tab:**
- `ListView` of `NoteCard` widgets — all non-archived notes across all folders

**FAB:** Creates a new note in the General folder (`/editor?folderId=1`).

---

### `lib/screens/book/book_screen.dart`
**Kindle-style reading view.** Opens from a folder tap in HomeScreen.

**Page order:** `[Cover] [ChapterHeader₁] [Content₁] [ChapterHeader₂] [Content₂] …`

1. In `initState`, fetches folder info via `FolderService.getFolderById` + notes via `NoteService.getNotes`
2. Decrypts each note body once — stores `List<_PageDescriptor>` tagged with `_PageKind` (cover / chapter / content)
3. Renders a `PageFlipWidget` — each descriptor maps to `BookCoverPage`, `BookChapterPage`, or `BookPage`
4. AppBar title shows journal name on cover, entry title on content pages
5. Edit button only shown when on a chapter or content page (not on cover)

**Navigation edge case:** If `folderId` is null, no cover page. If folder is empty, shows an
empty state with a "Write first entry" button.

---

### `lib/screens/editor/note_editor_screen.dart`
**Rich-text editor.** Parameters: `noteId` (optional — null = new note) + `folderId`.

**Key behaviours:**
- `QuillController.basic()` for new notes; loads decrypted `Document` for existing notes
- Auto-save: Quill change → 1500ms debounce → `_autoSave()` → `NoteService.createNote/updateNote`
- After every save: `ref.invalidate(notesProvider)` + `ref.invalidate(foldersProvider)` — both lists refresh
- "Done" button → cancels debounce → saves immediately → `context.pop()`
- Emoji button → `EmojiPicker` bottom sheet → inserts emoji at cursor
- Draw button → pushes `DrawingCanvasScreen` → receives file path → inserts `BlockEmbed.image(filePath)`
- **Layout selector** (overflow menu): `_PageLayout` enum (`textOnly` / `imageSide` / `collage`)
  - `imageSide` — one header image (180px tall) above the Quill editor
  - `collage` — 2×2 grid of up to 4 images (160px tall) above the Quill editor
  - Images picked via `image_picker`; paths stored as JSON in `note.layoutImages`
  - `_LayoutImageStrip` widget renders the image area; tapping reopens the picker
- Basic / Advanced toolbar toggle (overflow menu)

---

### `lib/screens/editor/drawing_canvas_screen.dart`
Freehand drawing canvas. User draws, taps "Done" → saves as PNG to app documents directory →
returns file path to the caller (`NoteEditorScreen`). The path is embedded as `BlockEmbed.image`.

### `lib/screens/editor/image_embed_builder.dart`
Custom `EmbedBuilder` for `BlockEmbed.imageType`. Renders local PNG files using `Image.file()`.
Shows a placeholder if the file is missing. Registered via `embedBuilders: [LocalImageEmbedBuilder()]`
in `QuillEditorConfig`.

---

### `lib/screens/search/search_screen.dart`
**In-memory full-text search.** Opens from the search icon in HomeScreen AppBar.

1. `initState` → `_buildCorpus()`: fetches all notes, decrypts each body, extracts plain text via regex
2. Stores `List<({Note note, String plainText})>` in `_corpus` — built once, never re-fetched
3. Quill Delta plain-text extraction: regex `"insert"\s*:\s*"([^"]*)"` pulls all text insertions
4. Search field with 300ms debounce → `_runSearch()` → filters `_corpus` by `contains(query)`
5. Shows hit count when empty, "No results" when no matches, `ListView` of `NoteCard` when matched

---

### `lib/screens/settings/settings_screen.dart`
**Configuration hub.** Sections in order:

**App Theme:** `_ThemePicker` — 72×72 `AnimatedContainer` swatches from `kHushThemes`.

**Background:** `_BackgroundPresetGrid` — 12 preset swatches (solid + gradient).
"Custom image from gallery" tile → `image_picker` → stores path via `backgroundProvider`.

**Typography:** Font family chip row (7 Google Fonts) + 4-button text size selector + 8 text colour swatches.
State lives in `typographyProvider` / `TypographyNotifier` → persisted via `SharedPreferences`.

**Default Entry Font:** Per-note font default. Stored in `fontProvider`.

**Export:** PDF export (all entries) + encrypted ZIP backup.

**Import:** Pick `.md` / `.txt` → `ImportService.importFile` → new entry in General folder.

**Writing Streak:** `HeatMapCalendar` fed from `NoteService.getNotesPerDay()`.

**Daily Writing Reminder:** `SwitchListTile` + time picker → `ReminderService.scheduleDaily(picked)`.

**Security:** Toggle `FLAG_SECURE` via `SecurityService` (MethodChannel → Android `window.addFlags`).

**About:** Static info tiles.

---

### `lib/screens/tags/tag_management_screen.dart`
Accessible from Settings. Lists all tags. Create: name field + 8 colour circles + "Add" button.
Delete: trash icon on each `_TagTile`. Uses `tagsProvider` (watch) + `tagsNotifierProvider` (mutate).

---

## Section 7 — Widgets (`lib/widgets/`)

---

### `lib/widgets/book/book_page.dart`
A single content page in the book view. `StatefulWidget` — creates and disposes a `QuillController` per page.

- `QuillController(document: widget.doc, readOnly: true)` — read-only mode is set on the **controller**, not in `QuillEditorConfig`
- Background: `widget.theme.pageBackground` (a `Color`, not a hex string)
- `_PageTexturePainter` (`CustomPainter`): draws ruled lines, dot grid, or square grid depending on `theme.pageStyle`

---

### `lib/widgets/book/book_cover_page.dart`
First page of a journal in book view. Displays:
- Cover photo (if `folder.coverImagePath` set) as full-bleed background with a dark gradient overlay
- Journal name (large bold) + entry count + decorative rule at bottom
- Falls back to page-texture background + folder accent colour when no cover image

---

### `lib/widgets/book/book_chapter_page.dart`
Chapter-header page shown before each entry's content. Displays entry title, date, word count, and a
decorative rule — no Quill editor. Full-page layout lets the user orient themselves before reading.

---

### `lib/widgets/folders/folder_card.dart`
Grid card for a folder. Shows: coloured circle with icon, folder name, entry count, optional lock badge.

- When `folder.coverImagePath` is set and the file exists: renders the image as a cover with a dark gradient overlay; icon and text switch to white for contrast.
- Maps icon string keys (42 options: `'book'`, `'star'`, `'heart'`, …) → `IconData`.
- `onLongPress` triggers the folder options menu in `HomeScreen`.

---

### `lib/widgets/common/app_background.dart`
`AppBackgroundWrapper` — `ConsumerWidget` that wraps a child with the app-wide background.
- Reads `backgroundProvider` → switches on `AppBackgroundType`
- `image`: `Stack(Image.file + semi-transparent overlay + child)`
- `gradient`: `Container(BoxDecoration(gradient: LinearGradient(...)))`
- `color`: `Container(color: ...)`
Used in `HomeScreen`, `NoteViewerScreen`. **Not** used in `BookScreen` (manages its own background) or `LockScreen`.

---

### `lib/widgets/notes/note_card.dart`
Card for a single note. Shows: coloured avatar, title, date, word count, reading time, pin icon.
`onTap` → `/editor?noteId=N&folderId=N`.
`onLongPress` → `_NoteContextMenu` bottom sheet with:
- Pin / Unpin
- Archive / Unarchive
- Move to folder (sub-sheet with folder picker)
- Delete (soft-delete)

---

### `lib/widgets/notes/tag_chip.dart`
Small `Chip` widget showing a tag's name in its own colour. Used in note detail views.

---

## Section 8 — Router (`lib/router/app_router.dart`)

**Actual routes:**

| Path | Screen | Parameters |
|---|---|---|
| `/lock` | `LockScreen` | none |
| `/home` | `HomeScreen` | none |
| `/editor` | `NoteEditorScreen` | `?noteId=N` (optional) + `?folderId=N` (required) |
| `/book` | `BookScreen` | `?folderId=N` (optional — null = all notes) |
| `/search` | `SearchScreen` | none |
| `/settings` | `SettingsScreen` | none |
| `/settings/tags` | `TagManagementScreen` | none |

**The redirect guard:** Every navigation attempt reads `appLockProvider.isLocked`.
If `true` → redirects to `/lock`. This means even deep-links hit the lock screen first.

---

## Section 9 — Android Native

### `android/app/src/main/kotlin/com/hush/frontend/MainActivity.kt`
Extends `FlutterFragmentActivity` (NOT `FlutterActivity`).
**Why:** `local_auth` uses `BiometricPrompt` which is a `DialogFragment`. It requires a `FragmentManager`,
which is only available from a `FragmentActivity`. Using `FlutterActivity` causes silent biometric failures.

### `android/app/src/main/AndroidManifest.xml`
Required permissions:
- `POST_NOTIFICATIONS` — for writing reminder (Android 13+)
- `RECEIVE_BOOT_COMPLETED` — to re-schedule reminder after reboot
- `VIBRATE` — for notification vibration

Required receivers (inside `<application>`):
- `ScheduledNotificationReceiver`
- `ScheduledNotificationBootReceiver`

### `android/app/build.gradle.kts`
```kotlin
compileOptions {
    isCoreLibraryDesugaringEnabled = true   // required for flutter_local_notifications v21
    sourceCompatibility = JavaVersion.VERSION_17
    targetCompatibility = JavaVersion.VERSION_17
}
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

---

## Section 10 — Key Commands

```bash
# Run on emulator (with hot reload)
fvm flutter run -d emulator-5554

# Build debug APK and install
fvm flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Static analysis (zero errors expected)
fvm flutter analyze

# Build release APK
fvm flutter build apk --release
```

---

## Phase 1 Decisions Log

| Decision | Reason |
|---|---|
| sqflite instead of Isar | Isar v3 incompatible with AGP 8.11.1 (namespace requirement). sqflite is stable, no code-gen needed. |
| No riverpod_generator | Conflicted with isar_generator on source_gen version. Manual providers are simpler and more readable. |
| flutter_quill 11.x | v9 had stale `intl ^0.19.0` constraint incompatible with Flutter SDK's pinned intl 0.20.2. |
| Manual providers | Plain `StateNotifierProvider` + `FutureProvider.family`. Easier to understand without annotations. |
| `CardTheme` → `CardThemeData` | Flutter 3.41 renamed the class. |

---

## Phase 2 Decisions Log

| Decision | Reason |
|---|---|
| `FlutterFragmentActivity` in MainActivity | `FlutterActivity` lacks `FragmentManager` needed by BiometricPrompt DialogFragment — silent auth failures on physical devices. |
| Pre-decrypt all notes in `BookScreen.initState` | Decrypting inside `BookPage.build()` would block the render thread on every page curl. One-time decrypt + store `Document` objects eliminates per-frame latency. |
| `readOnly` on `QuillController`, not `QuillEditorConfig` | In flutter_quill v11, `QuillEditorConfig` has no `readOnly` parameter — it lives on the controller. |
| `HushTheme` fields are `Color` objects | Theme constants use Flutter `Color` directly — no hex string parsing needed at render time. |
| `page_flip` children must be mutable list | The `page_flip` package internally calls `.add()` on the children list (to add lastPage). Passing a const list crashes. Always pass `.toList()` (a mutable copy). |
| `folderId=1` for FAB | General folder is always id=1 (first auto-increment insert). FAB must route to `folderId=1` so new notes appear in General, not orphaned at id=0. |
| `_save()` invalidates both `notesProvider` and `foldersProvider` | Without invalidating `foldersProvider`, folder entry counts shown on `FolderCard` would never update after creating a note. |
| `deleteNote` + `moveToFolder` also invalidate `foldersProvider` | Same reason — deleting or moving a note changes a folder's entry count. |
| In-memory search corpus | Decrypt all notes once in `initState`, filter in memory on keystroke. Avoids per-keystroke DB + decrypt overhead. |
| `desugar_jdk_libs:2.1.4` (not 2.1.3) | `flutter_local_notifications` v21 requires ≥ 2.1.4 at compile time. |
| `flutter_local_notifications` v21 named params | v21 changed `initialize()`, `cancel()`, and `zonedSchedule()` to all-named parameters. Positional calls fail. |

---

## Phase 3 Decisions Log

| Decision | Reason |
|---|---|
| `onboardingCompleteProvider` overridden from `SharedPreferences` in `main()` | Router needs the flag synchronously at startup. Reading prefs before `runApp()` and injecting via `ProviderScope.overrides` is the only safe pattern — no async gap between router creation and first render. |
| `QuillController` built ONCE in `_initEditor()`, never swapped | Flutter's element reconciliation throws `_elements.contains(element)` if you swap a `QuillController` after `QuillEditor` is already in the tree. The `_editorReady` bool pattern (show spinner → build editor once) prevents this. |
| `DefaultTextStyle.merge` (not `DefaultTextStyle`) for font override | `google_fonts` returns `TextStyle(color: null)`. `DefaultTextStyle(style:)` replaces the full inherited style, nulling out the color. Quill internals call `color!` and crash. `.merge` additively overlays only the non-null fields. |
| Explicit `QuillEditor` with lifecycle-managed `ScrollController` + `FocusNode` | `QuillEditor.basic` creates a new throw-away `FocusNode`/`ScrollController` on every call. Swapping these on rebuild causes element tree instability. Lifecycle-managed resources initialized in `initState`, disposed in `dispose`. |
| `_EditorAction` enum + `PopupMenuButton` for editor overflow | 6 icon buttons + Done exceeded the AppBar width on phones. Consolidating to emoji + font + PopupMenu + Done fits cleanly. |
| `fontFamily` param on both `createNote` and `updateNote` | Per-note font must be persisted so re-opening a note uses the same font the user chose, independent of the global default. |
| `ImportService.importFile(folderId: 1)` hard-codes General folder | General is always `id=1` (first auto-increment). Import always targets General — consistent with the FAB behavior. |

---

## Phase 4 Decisions Log

| Decision | Reason |
|---|---|
| FLAG_SECURE via native `MethodChannel` in `MainActivity.kt` | `flutter_windowmanager` v0.2.0 doesn't set an Android namespace, which newer AGP versions require. Native MethodChannel is more stable and has zero dependencies. |
| `.env` via `flutter_dotenv`, not `--dart-define` | `--dart-define` requires every developer and CI run to pass the key on the CLI. `flutter_dotenv` loads from a gitignored `.env` asset — simpler for a solo developer and avoids accidental key exposure in build scripts. |
| Fade transitions (180 ms) in go_router `pageBuilder` | Default Material slide transitions feel sluggish at lower frame rates. Fade is lighter on the GPU and reads as instantaneous at 180 ms. |
| `folderNoteCountsProvider` — one batch query vs N per card | Eliminated N `FutureBuilder` DB round-trips (one per folder card) with a single `GROUP BY folder_id` query. |
| `AutomaticKeepAliveClientMixin` on All Entries tab | Without keepAlive, switching between "Journals" and "All Entries" tabs re-runs the full `notesProvider` future (DB + widget rebuild). keepAlive preserves the built tree across tab switches. |
| `NoteViewerScreen` (read-only) as default entry tap | Users should read entries without accidentally triggering editing. Edit mode is reached intentionally via the AppBar button. QuillController is created with `readOnly: true`. |
| Per-journal PIN stored as `pin:SHA256(folderId_salt+pin)` in `encrypted_folder_key` | Re-uses the existing nullable column rather than adding a new column. The `pin:` prefix distinguishes it from future folder-key usage. SHA-256 with a folder-specific salt prevents rainbow table attacks and cross-folder PIN reuse attacks. |
| `sort_order` DB column (v3 migration) + `reorderNotes` batch update | Drag-to-reorder requires a persistent integer rank. `ALTER TABLE ... ADD COLUMN` is safe and idempotent for existing DBs (SQLite allows it without recreating the table). |
| DB indexes on `title` and `updated_at` (v4 migration) | Index on `updated_at DESC` speeds up the default note list query (ORDER BY updated_at DESC). Index on `title` prepares for future DB-level prefix search. |
| Search corpus built with `Future.microtask` yields every 10 notes | AES-GCM decryption is CPU-bound. Without yields, decrypting 100+ notes blocks the UI isolate for hundreds of ms (visible lag when opening search). Microtask yields let the framework process pending frames between chunks. |
| `autoTitle` uses `firstWhere((l) => l.isNotEmpty)` | Previous `split('\n').first` returned an empty string if the text started with a blank line, producing an "Entry — date" fallback even when content existed below. The `firstWhere` finds the first non-blank line regardless of position. |
| JSON-decode captured groups in `_extractPlainText` | Quill Delta encodes newlines as `\n` in JSON strings. The regex captures the raw JSON-escaped text, so without decoding, `autoTitle` received literal backslash-n as the title character sequence. `jsonDecode('"$raw"')` interprets all JSON escape sequences correctly. |

---

## Phase 5 Decisions Log

| Decision | Reason |
|---|---|
| Background and Typography split from single HushTheme | HushTheme controlled the whole visual identity. Splitting lets users independently choose a book-style app theme, a diary background (photo/gradient), and a reading font/size/colour without any of them conflicting. |
| Background stored in `SharedPreferences`, not per-note | Background is an app-wide aesthetic preference. Storing it globally avoids per-note overhead and matches user expectations (one background for the whole app). |
| `AppBackgroundWrapper` wraps body, not `MaterialApp` | Wrapping `MaterialApp` would paint behind system chrome (navigation bar, status bar). Wrapping `Scaffold.body` gives the background only where content lives. |
| Per-journal cover image stored as absolute file path in `folders.cover_image_path` | Keeps the data model simple — no blob storage in SQLite. `image_picker` already saves to device storage; we just reference the path. `File(path).existsSync()` guards against deleted files. |
| `FolderCard` dark gradient overlay on cover image | Pure image without overlay makes white text unreadable on light photos. A top-to-bottom gradient (`0.15 → 0.55` alpha) ensures legibility across all image types without completely hiding the photo. |
| Book experience: Cover → Chapter header → Content (3 page types) | Flat `[ChapterHeader, Content] × N` provides a clear "chapter opening" moment before each entry. The cover acts as a title page for the entire journal. `_PageDescriptor` + `_PageKind` enum map page indices to types without duplicating data. |
| `BookCoverPage` as a stateless widget (no QuillController) | Cover has no Quill content. Creating a QuillController for it would waste memory and cause lifecycle issues with `page_flip`. Stateless CustomPaint covers the page-texture background. |
| `BookChapterPage` shows entry metadata (not content) | A chapter page that repeated the first line of content would feel redundant. Showing just the title, date, and word count creates breathing room and builds anticipation before the reader flips to the content page. |
| Layout images stored as JSON array of paths in `notes.layout_images` | A single TEXT column avoids schema proliferation (no `layout_image_1`, `layout_image_2` columns). The array is always small (≤ 4 paths). JSON-decode on read is negligible cost. |
| `_LayoutImageStrip` is a separate widget above the QuillEditor | Keeps `NoteEditorScreen.build()` clean. The strip has its own rendering logic (single image vs 2×2 grid) that would clutter the editor build method. |
| Layout picker shows 3 options as equal-width `_LayoutOption` tiles | Visual parity makes the choice clear at a glance. ChoiceChip row would be too small to convey the spatial meaning of each layout. |
| `pickMultiImage(limit: maxCount)` for collage, `pickImage` for single | `pickMultiImage` opens the system multi-select picker in one tap. `limit:` caps selection without extra validation. For single-image layouts, `pickImage` is simpler and more direct. |

*Last updated: Phase 5 — Theming, backgrounds, typography, per-journal cover images, book experience, and page layouts complete.*

---

## Phase 7: Audio Recording, Activity Logs, Share Fixes, Theme–Background Unification

### Feature 1: Voice Notes (Audio Recording)

**Packages added:**
- `record: ^6.2.0` — cross-platform microphone recording, AAC (.m4a) output
- `just_audio: ^0.9.38` — audio playback for the inline player widget

**Permissions added (AndroidManifest.xml):**
- `android.permission.RECORD_AUDIO`

**New files:**
- `lib/services/audio_recording_service.dart` — static wrapper around `AudioRecorder`. Saves files to `{appDocuments}/audio/hush_audio_{timestamp}.m4a`. Fully offline.
- `lib/screens/editor/audio_embed_builder.dart` — two exports:
  - `AudioEmbedBuilder` — Quill `EmbedBuilder` for key `'audio'`. Renders an inline player (play/pause, progress slider, timestamp, delete button).
  - `AudioRecorderSheet` — bottom sheet with a large record/stop button, elapsed timer, and pulse animation. Designed for one-hand / driving use (single tap to start, single tap to stop).

**Changes to existing files:**
- `note_editor_screen.dart`:
  - Imports `audio_embed_builder.dart` and `activity_log_service.dart`
  - Adds `AudioEmbedBuilder()` to `QuillEditorConfig.embedBuilders`
  - Adds prominent `mic_rounded` IconButton in AppBar (not hidden in overflow menu — easy one-tap access)
  - `_openAudioRecorder()` — shows `AudioRecorderSheet`; on completion inserts `BlockEmbed(kAudioEmbedKey, path)` at cursor and auto-saves
  - Logs `'created'` / `'edited'` actions via `ActivityLogService`
- `shared_note_editor_screen.dart` — same audio additions; also logs shared activity

**Audio embed storage:**
Audio embeds are stored as `{'insert': {'audio': '/absolute/path/to/hush_audio_xxx.m4a'}}` in the Quill Delta JSON. The path is device-local — audio is not uploaded to the server for shared notes (future enhancement).

**Deletion:**
Long-tap the ×  icon on the player widget. A confirmation dialog appears before removing the embed from the document AND deleting the file from disk.

---

### Feature 2: Share Invite Fix

**Problem:** "Could not send invite. Try again" appeared even for valid emails because `SharedNoteService.shareNote()` returns `[]` on any network/server failure, and the UI showed a generic error.

**Fix in `manage_collaborators_screen.dart`:**
- Gate check before sending: if `noteId.startsWith('local_')` → show "Sync note first" message
- On `result.isEmpty` → show "Could not reach server. Check your connection…" (accurate, not misleading)

---

### Feature 3: Activity Logs

**DB migration:** v10 — new `activity_logs` table:
```sql
CREATE TABLE activity_logs (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  session_type TEXT NOT NULL DEFAULT 'local',  -- 'local' | 'shared'
  note_id      TEXT,
  action       TEXT NOT NULL,                  -- 'created' | 'edited' | 'deleted' | 'shared' | 'audio_added' | 'invite_accepted'
  note_title   TEXT,
  detail       TEXT,
  created_at   TEXT NOT NULL
)
```

**New files:**
- `lib/models/activity_log.dart` — `ActivityLog` model with `fromMap()`, `toMap()`, `actionLabel` getter
- `lib/services/activity_log_service.dart` — `log()`, `getLogs()`, `getLogsByType()`, `deleteLog()`, `clearLogsByType()`, `clearAllLogs()`
- `lib/screens/activity/activity_logs_screen.dart` — tabbed screen (All / Local / Shared), swipe-to-delete individual entries, overflow menu to clear by type or all

**Route:** `/settings/activity` (nested under `/settings`)

**Access:** Settings → Writing → Activity Log → "View activity log"

**Privacy:** Logs are always local-only; never uploaded to the server. Each user's shared logs are independent (deleting your log doesn't affect collaborators).

---

### Feature 4: Theme–Background Unification

**Problem:** Theme and Background were separate, so changing a theme didn't update the background — leading to mismatched visuals (e.g., Midnight theme with a light parchment background).

**Fix:**
- Added `defaultBackgroundPresetId` field to `HushTheme`:
  - Hush → `'parchment'`
  - Midnight → `'midnight'`
  - Forest → `'forest'`
  - Ocean → `'ocean'`
- `_ThemePicker.onTap` now also calls `backgroundProvider.notifier.setPreset(...)` with the theme's default preset, **unless** the user has a custom photo active (custom photos are always preserved)
- Added "Remove custom photo" ×  button next to the custom photo picker in `_BackgroundPresetGrid`

**No coupling between providers:** The theme auto-apply happens in the settings UI, not inside `ThemeNotifier` or `BackgroundNotifier` — avoids circular dependencies.

---

## Phase 7 Decisions Log

| Decision | Reason |
|---|---|
| `record: ^6.2.0` (not 5.x) | record 5.2.x has a broken sub-dependency graph (`record_linux 0.7.x` incompatible with `record_platform_interface 1.5.0`). 6.x uses `record_linux ^1.0.0` which is compatible. |
| `kAudioEmbedKey = 'audio'` as a top-level constant | Shared between `AudioEmbedBuilder` and any code that inserts audio embeds (both editors). Prevents typo-driven mismatch between the embed type string and the builder key. |
| Audio player in Quill embed rather than above/below editor | Inline placement means audio is part of the note's narrative flow — it can appear mid-paragraph or at the end, exactly where the user placed it. Separate strip-player can't represent multiple recordings at different positions. |
| `isDismissible: false, enableDrag: false` on recorder sheet | Accidental swipe-to-dismiss during recording would lose the recording. The user must explicitly press Stop or Cancel. |
| Activity logs never synced to server | Logs are personal usage metadata. Uploading them would require additional API endpoints, storage, and raises privacy questions. Local-only is consistent with the app's encrypted-private-diary philosophy. |
| Theme auto-applies background only when no custom photo | A user's intentional photo choice should not be overridden silently. Preset presets (color/gradient) are considered "theme-managed" and safe to replace. |
