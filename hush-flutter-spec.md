# Hush — Personal Diary App
## Complete Flutter Development Specification

> **Document Purpose:** This is a fully self-contained specification for building the Hush personal diary app using Flutter. The original React Native + Expo spec has been fully rewritten for Flutter + Dart. Every section — environment setup, phased build plan, folder structure, data models, and feature specs — is written so each phase ends with a testable, runnable Android simulator build. Follow sections sequentially.

> **Key Decisions:**
> - Framework: Flutter (Dart) — migrated from React Native + Expo
> - Architecture: Local-first, offline-first. Cloud sync is a future phase.
> - UX: Kindle-style page-curl navigation (retained from original vision)
> - AI: Mood/sentiment tracking over time (cloud-based, Phase 4)
> - Security: Biometric lock + AES-256-GCM encryption from Phase 1
> - Platform: Android first (simulator testable at every phase), iOS in Phase 3

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Technology Stack](#2-technology-stack)
3. [Prerequisites & Environment Setup](#3-prerequisites--environment-setup)
4. [Project Scaffold & Folder Structure](#4-project-scaffold--folder-structure)
5. [Database Schema & Data Models](#5-database-schema--data-models)
6. [Security Architecture](#6-security-architecture)
7. [Phased Build Plan](#7-phased-build-plan)
8. [Feature Specifications](#8-feature-specifications)
9. [Package-to-Feature Mapping](#9-package-to-feature-mapping)
10. [Navigation Architecture](#10-navigation-architecture)
11. [State Management Architecture](#11-state-management-architecture)
12. [Theming System](#12-theming-system)
13. [Screen-by-Screen Implementation Guide](#13-screen-by-screen-implementation-guide)
14. [Testing Strategy](#14-testing-strategy)
15. [Performance Optimizations](#15-performance-optimizations)
16. [Build & Release Pipeline](#16-build--release-pipeline)
17. [Future Roadmap (Phase 3+)](#17-future-roadmap-phase-3)

---

## 1. Project Overview

### 1.1 App Identity

| Field | Value |
|---|---|
| App Name | **Hush** (Personal Diary) |
| Package ID | `com.hush.diary` |
| Version | `1.0.0` |
| Platform Target | Android (Phase 1 & 2), iOS (Phase 3) |
| Architecture | Offline-first, local-only storage with cloud sync in Phase 4 |
| Primary Language | Dart |
| Framework | Flutter (stable channel) |

### 1.2 Core Philosophy

- **Privacy-first:** All data lives on-device in Phase 1 & 2. Cloud sync, if added, is end-to-end encrypted.
- **Offline-first:** The app works with zero internet. All core features function without network.
- **Security by default:** Every note and folder is AES-256-GCM encrypted at rest before database storage.
- **Kindle-like UX:** The primary reading/writing metaphor is a physical book — page turns, scrollable pages, a sense of tactile depth.
- **Expressiveness:** The editor feels as rich as a modern note-taking tool.

### 1.3 Feature Summary

| # | Feature | Priority | Phase |
|---|---|---|---|
| 1 | Biometric + PIN app lock | P0 | 1 |
| 2 | Local AES-256-GCM encrypted storage | P0 | 1 |
| 3 | Kindle-style page-turn book navigation | P0 | 2 |
| 4 | Pinch-to-zoom-out horizontal scroll between notes | P0 | 2 |
| 5 | Rich text editor (headings, bullets, bold, italic) | P0 | 1 |
| 6 | Folder system with per-folder lock | P1 | 2 |
| 7 | Tag-based notes with dynamic grouped views | P1 | 2 |
| 8 | Auto-generated or custom note titles | P1 | 1 |
| 9 | Light and dark mode | P0 | 1 |
| 10 | Multiple visual themes | P1 | 2 |
| 11 | Full-text search (in-memory, decrypted) | P1 | 2 |
| 12 | Journaling streak heatmap | P2 | 2 |
| 13 | Writing reminders (local notifications) | P2 | 2 |
| 14 | Export to PDF or encrypted ZIP | P2 | 3 |
| 15 | Word count & reading time | P1 | 1 |
| 16 | Pin, archive, soft-delete notes | P1 | 2 |
| 17 | Undo/redo in editor | P1 | 2 |
| 18 | Mood/sentiment AI insights | P2 | 4 |
| 19 | Font customization per note/global | P2 | 3 |
| 20 | Import from plain text / Markdown | P2 | 3 |
| 21 | Emoji & sticker insertion | P1 | 2 |
| 22 | GIF insertion (GIPHY) | P2 | 3 |

---

## 2. Technology Stack

### 2.1 Flutter Package List (`pubspec.yaml`)

```yaml
name: hush
description: A personal diary app — private, expressive, offline-first.
version: 1.0.0+1

environment:
  sdk: ">=3.2.0 <4.0.0"
  flutter: ">=3.16.0"

dependencies:
  flutter:
    sdk: flutter

  # --- Local Database ---
  isar: ^3.1.0                        # Embedded NoSQL DB (replaces WatermelonDB)
  isar_flutter_libs: ^3.1.0           # Platform binaries for Isar
  path_provider: ^2.1.2               # DB file path resolution

  # --- Encryption ---
  pointycastle: ^3.7.4                # AES-256-GCM encryption (pure Dart)
  flutter_secure_storage: ^9.0.0      # Android Keystore-backed key storage

  # --- Auth / Biometrics ---
  local_auth: ^2.2.0                  # Fingerprint / Face / PIN

  # --- Rich Text Editor ---
  flutter_quill: ^9.4.4               # Quill-based rich text editor for Flutter

  # --- Page Curl / Animation ---
  page_flip: ^0.1.5                   # Kindle-style page curl animation
  flutter_animate: ^4.5.0             # Micro-animations and transitions

  # --- State Management ---
  riverpod: ^2.5.1                    # Reactive state management
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5

  # --- Navigation ---
  go_router: ^13.2.0                  # Declarative routing

  # --- UI Components ---
  google_fonts: ^6.2.1                # Merriweather, Lato, JetBrains Mono
  flutter_emoji_picker: ^2.4.0        # Emoji picker widget
  cached_network_image: ^3.3.1        # Async image loading for GIFs

  # --- Local Notifications ---
  flutter_local_notifications: ^17.2.1 # Writing reminders

  # --- Calendar Heatmap ---
  flutter_heatmap_calendar: ^1.0.5    # Streak visualization

  # --- Export ---
  pdf: ^3.11.0                        # PDF generation (pure Dart)
  printing: ^5.13.2                   # PDF print/share
  archive: ^3.6.1                     # ZIP for encrypted export
  share_plus: ^9.0.0                  # Share sheet

  # --- File System ---
  file_picker: ^8.0.6                 # Import .txt / .md files
  path: ^1.9.0

  # --- Utilities ---
  intl: ^0.19.0                       # Date formatting
  uuid: ^4.4.0                        # Unique ID generation
  collection: ^1.18.0                 # Dart collection utilities
  freezed_annotation: ^2.4.1          # Immutable data classes
  json_annotation: ^4.9.0

  # --- Settings KV ---
  shared_preferences: ^2.2.3          # Theme/settings persistence

dev_dependencies:
  flutter_test:
    sdk: flutter
  riverpod_generator: ^2.4.3
  build_runner: ^2.4.9
  freezed: ^2.5.2
  json_serializable: ^6.8.0
  isar_generator: ^3.1.0
  flutter_lints: ^3.0.2
  mockito: ^5.4.4
```

### 2.2 Stack Rationale

| Layer | Choice | Why |
|---|---|---|
| Framework | Flutter + Dart | Zero JS bridge; compiles to native ARM; no RN toolchain pain; single codebase for Android + iOS |
| Database | Isar | Fastest embedded NoSQL for Flutter; reactive streams; no native setup ceremony unlike WatermelonDB |
| Encryption | pointycastle | Pure Dart AES-256-GCM; no native bindings needed; battle-tested crypto library |
| Key Storage | flutter_secure_storage | Uses Android Keystore on Android; hardware-backed on modern devices |
| Biometrics | local_auth | Flutter-official; fingerprint, face, PIN fallback via system biometric APIs |
| Rich Text | flutter_quill | Most mature rich text editor in Flutter ecosystem; Quill Delta format |
| Page Curl | page_flip | Bezier curve page curl; Kindle-style UX |
| Animations | flutter_animate | Chainable, declarative micro-animations; integrates cleanly with Flutter's widget tree |
| State | Riverpod v2 | Compile-safe, testable reactive state; best-in-class for Flutter 3.x |
| Navigation | go_router | Official Flutter team recommended router; deep linking ready |
| Build | flutter build apk | Local APK build; no cloud build service needed for development |

---

## 3. Prerequisites & Environment Setup

### 3.1 System Requirements

| Requirement | Minimum | Recommended |
|---|---|---|
| OS | Windows 10 64-bit | Windows 11 or macOS 14+ |
| RAM | 8 GB | 16 GB |
| Storage | 15 GB free | 25 GB free |
| Android Studio | Hedgehog (2023.1) | Latest stable |
| Java | JDK 17 | JDK 17 (required for Android tooling) |
| Flutter | 3.16 stable | Latest stable |

### 3.2 Step-by-Step Installation

#### Step 1 — Install Flutter (via FVM — Flutter Version Manager)

Using FVM avoids the version conflict chaos that breaks RN/Expo setups.

```bash
# Install FVM (macOS/Linux)
curl -fsSL https://fvm.app/install.sh | bash

# Windows (PowerShell as Admin)
winget install leoafarias.fvm

# Install Flutter stable via FVM
fvm install stable
fvm global stable

# Verify
fvm flutter --version
# Should print Flutter 3.x.x
```

#### Step 2 — Install Android Studio

1. Download from https://developer.android.com/studio
2. During setup, check: **Android SDK**, **Android SDK Platform**, **Android Virtual Device**
3. After install → SDK Manager → Install **Android 14 (API 34)**

#### Step 3 — Set Environment Variables

```bash
# macOS ~/.zshrc
export ANDROID_HOME=$HOME/Library/Android/sdk
export PATH=$PATH:$ANDROID_HOME/emulator
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Windows — System Environment Variables
# ANDROID_HOME = C:\Users\<YourName>\AppData\Local\Android\Sdk
# Add to PATH: %ANDROID_HOME%\platform-tools and %ANDROID_HOME%\emulator
```

#### Step 4 — Create Android Virtual Device (AVD)

1. Open Android Studio → More Actions → **Virtual Device Manager**
2. **Create Device** → Pixel 7 → **API 34 (Android 14)**
3. Allocate 4096 MB RAM to AVD
4. Start the AVD → confirm it boots to the Android home screen

#### Step 5 — Run Flutter Doctor

```bash
fvm flutter doctor
```

All items should be green except "Xcode" (not needed for Android-only Phase 1). Fix any red items before proceeding.

#### Step 6 — VS Code Extensions

```
Dart (Dart-Code.dart-code)
Flutter (Dart-Code.flutter)
Awesome Flutter Snippets
Flutter Riverpod Snippets
Error Lens
```

---

## 4. Project Scaffold & Folder Structure

### 4.1 Initialize Project

```bash
fvm flutter create hush --org com.hush --platforms android,ios
cd hush
```

### 4.2 Complete Folder Structure

```
hush/
├── pubspec.yaml
├── analysis_options.yaml          # Flutter linting config
├── .fvmrc                         # FVM version pin
│
├── android/
│   └── app/
│       └── src/main/
│           └── AndroidManifest.xml
│
├── assets/
│   ├── fonts/
│   │   ├── Merriweather-Regular.ttf   # Serif reading font
│   │   ├── Lato-Regular.ttf           # Sans UI font
│   │   └── Caveat-Regular.ttf         # Handwritten accent font
│   ├── stickers/                      # Bundled sticker PNGs
│   │   ├── emotions/
│   │   └── minimal/
│   └── themes/                        # Theme preview images
│
├── lib/
│   ├── main.dart                      # App entry point
│   │
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_constants.dart     # App-wide constants
│   │   │   ├── theme_constants.dart   # All theme definitions
│   │   │   ├── font_constants.dart    # Font family constants
│   │   │   └── writing_prompts.dart   # Random prompt strings
│   │   │
│   │   ├── crypto/
│   │   │   ├── encryption_service.dart  # AES-256-GCM encrypt/decrypt
│   │   │   ├── key_derivation.dart      # PBKDF2 key derivation
│   │   │   └── key_store.dart           # flutter_secure_storage wrapper
│   │   │
│   │   ├── auth/
│   │   │   ├── biometric_auth.dart      # local_auth wrapper
│   │   │   └── app_lock_notifier.dart   # Lock state (Riverpod)
│   │   │
│   │   ├── database/
│   │   │   ├── isar_service.dart        # Isar instance singleton
│   │   │   └── migrations.dart          # Schema version handling
│   │   │
│   │   └── utils/
│   │       ├── date_utils.dart
│   │       ├── text_utils.dart          # Word count, reading time
│   │       └── markdown_parser.dart     # .md → Quill Delta
│   │
│   ├── models/                          # Isar annotated models
│   │   ├── note.dart
│   │   ├── folder.dart
│   │   ├── tag.dart
│   │   ├── note_tag.dart                # Junction
│   │   └── group.dart
│   │
│   ├── providers/                       # Riverpod providers
│   │   ├── app_lock_provider.dart
│   │   ├── notes_provider.dart
│   │   ├── folders_provider.dart
│   │   ├── tags_provider.dart
│   │   ├── search_provider.dart
│   │   ├── theme_provider.dart
│   │   └── editor_provider.dart
│   │
│   ├── services/
│   │   ├── note_service.dart            # CRUD + encrypt/decrypt pipeline
│   │   ├── folder_service.dart
│   │   ├── tag_service.dart
│   │   ├── search_service.dart          # In-memory full-text search
│   │   ├── export_service.dart          # PDF + ZIP export
│   │   └── notification_service.dart    # Local notifications
│   │
│   ├── screens/
│   │   ├── lock/
│   │   │   └── lock_screen.dart         # Biometric / PIN entry
│   │   ├── home/
│   │   │   └── home_screen.dart         # Folder grid overview
│   │   ├── book/
│   │   │   └── book_screen.dart         # Kindle-style book view
│   │   ├── editor/
│   │   │   └── note_editor_screen.dart  # Full rich-text editor
│   │   ├── search/
│   │   │   └── search_screen.dart
│   │   ├── tags/
│   │   │   └── tags_screen.dart
│   │   └── settings/
│   │       ├── settings_screen.dart
│   │       ├── theme_picker_screen.dart
│   │       ├── password_settings_screen.dart
│   │       └── export_screen.dart
│   │
│   ├── widgets/
│   │   ├── common/
│   │   │   ├── hush_button.dart
│   │   │   ├── hush_modal.dart
│   │   │   ├── search_bar_widget.dart
│   │   │   ├── empty_state.dart
│   │   │   └── loading_overlay.dart
│   │   │
│   │   ├── editor/
│   │   │   ├── rich_text_editor.dart    # flutter_quill wrapper
│   │   │   ├── editor_toolbar.dart      # Custom Quill toolbar
│   │   │   ├── emoji_picker_widget.dart
│   │   │   └── word_count_bar.dart
│   │   │
│   │   ├── book/
│   │   │   ├── book_page.dart           # Single page widget
│   │   │   ├── book_cover.dart
│   │   │   ├── page_curl_wrapper.dart   # page_flip package wrapper
│   │   │   └── mini_page_strip.dart     # Zoom-out thumbnail strip
│   │   │
│   │   ├── notes/
│   │   │   ├── note_card.dart
│   │   │   ├── note_list_item.dart
│   │   │   └── tag_chip.dart
│   │   │
│   │   ├── folders/
│   │   │   ├── folder_card.dart
│   │   │   └── create_folder_modal.dart
│   │   │
│   │   └── stats/
│   │       ├── streak_heatmap.dart
│   │       └── writing_stats.dart
│   │
│   └── router/
│       └── app_router.dart              # go_router configuration
│
└── test/
    ├── crypto/
    ├── services/
    ├── widgets/
    └── screens/
```

---

## 5. Database Schema & Data Models

All models use Isar's code-generation annotations. After editing any model, run:

```bash
fvm flutter pub run build_runner build --delete-conflicting-outputs
```

### 5.1 Note Model

```dart
// lib/models/note.dart
import 'package:isar/isar.dart';

part 'note.g.dart';

@collection
class Note {
  Id id = Isar.autoIncrement;

  @Index()
  late int folderId;

  late String title;

  // AES-256-GCM encrypted Quill Delta JSON (base64)
  late String encryptedBody;
  late String iv;        // base64 — 12 bytes for GCM
  late String authTag;   // base64 — 16 bytes

  late bool isPrivate;
  late bool hasOwnPassword;
  String? encryptedNoteKey;       // Set only if per-note password

  late bool isPinned;
  late bool isArchived;
  late bool isDeleted;

  late int wordCount;
  late int readingTimeSec;

  late String coverColor;
  late String fontFamily;
  late int pageNumber;            // Position in the "book"

  @Index()
  late DateTime createdAt;
  late DateTime updatedAt;

  // Isar links
  final tags = IsarLinks<Tag>();
}
```

### 5.2 Folder Model

```dart
// lib/models/folder.dart
import 'package:isar/isar.dart';

part 'folder.g.dart';

@collection
class Folder {
  Id id = Isar.autoIncrement;

  late String name;
  late String color;
  late String icon;

  late bool isLocked;
  String? encryptedFolderKey;     // Folder-level key encrypted with master key

  late int sortOrder;

  late DateTime createdAt;
  late DateTime updatedAt;

  @Backlink(to: 'folder')
  final notes = IsarLinks<Note>();
}
```

### 5.3 Tag & Group Models

```dart
// lib/models/tag.dart
@collection
class Tag {
  Id id = Isar.autoIncrement;
  late String name;
  late String color;
  late DateTime createdAt;

  @Backlink(to: 'tags')
  final notes = IsarLinks<Note>();
}

// lib/models/group.dart
@collection
class Group {
  Id id = Isar.autoIncrement;
  late String name;
  late List<int> tagIds;          // List of Tag IDs
  late DateTime createdAt;
}
```

---

## 6. Security Architecture

### 6.1 Key Hierarchy

```
User Password / Biometric
        │
        ▼
PBKDF2-SHA256 (310,000 iterations)
        │
        ▼
Master AES-256 Key ──────────────────────────────────────────────────────────┐
        │                                                                     │
        ├── Encrypts all notes in "General" folder (default)                  │
        │                                                                     │
        └── Encrypts per-folder keys (stored in folder.encryptedFolderKey)   │
              │                                                               │
              └── Each folder key encrypts notes in that folder               │
                        │                                                     │
                        └── Optional: Per-note key (for private notes) ◄──────┘
```

### 6.2 Encryption Service

```dart
// lib/core/crypto/encryption_service.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class EncryptionService {
  /// Encrypts [plaintext] with AES-256-GCM.
  /// Returns base64-encoded ciphertext, iv, and authTag.
  static EncryptedPayload encrypt(String plaintext, Uint8List key) {
    final iv = _secureRandom(12);
    final cipher = GCMBlockCipher(AESEngine())
      ..init(true, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));

    final input = Uint8List.fromList(utf8.encode(plaintext));
    final output = cipher.process(input);

    // GCM appends 16-byte auth tag to ciphertext
    final ciphertext = output.sublist(0, output.length - 16);
    final authTag = output.sublist(output.length - 16);

    return EncryptedPayload(
      ciphertext: base64.encode(ciphertext),
      iv: base64.encode(iv),
      authTag: base64.encode(authTag),
    );
  }

  /// Decrypts an [EncryptedPayload] with AES-256-GCM.
  static String decrypt(EncryptedPayload payload, Uint8List key) {
    final iv = base64.decode(payload.iv);
    final authTag = base64.decode(payload.authTag);
    final ciphertext = base64.decode(payload.ciphertext);

    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));

    final combined = Uint8List.fromList([...ciphertext, ...authTag]);
    final output = cipher.process(combined);
    return utf8.decode(output);
  }

  static Uint8List _secureRandom(int length) {
    final rng = FortunaRandom();
    rng.seed(KeyParameter(Uint8List.fromList(
      List.generate(32, (_) => DateTime.now().microsecondsSinceEpoch % 256)
    )));
    return rng.nextBytes(length);
  }
}

class EncryptedPayload {
  final String ciphertext;
  final String iv;
  final String authTag;
  const EncryptedPayload({
    required this.ciphertext,
    required this.iv,
    required this.authTag,
  });
}
```

### 6.3 Key Derivation

```dart
// lib/core/crypto/key_derivation.dart
import 'dart:typed_data';
import 'package:pointycastle/export.dart';

class KeyDerivation {
  /// PBKDF2-SHA256 with 310,000 iterations (OWASP 2023 recommended).
  static Uint8List deriveKey(String password, Uint8List salt) {
    final pbkdf2 = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, 310000, 32));
    return pbkdf2.process(Uint8List.fromList(password.codeUnits));
  }

  static Uint8List generateSalt() {
    // 32 bytes of secure random data
    final rng = FortunaRandom();
    return rng.nextBytes(32);
  }
}
```

### 6.4 Biometric Authentication

```dart
// lib/core/auth/biometric_auth.dart
import 'package:local_auth/local_auth.dart';

class BiometricAuth {
  static final _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    final canCheck = await _auth.canCheckBiometrics;
    final isDeviceSupported = await _auth.isDeviceSupported();
    return canCheck && isDeviceSupported;
  }

  static Future<bool> authenticate({String reason = 'Unlock Hush'}) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,    // Allow device PIN as fallback
          stickyAuth: true,        // Don't cancel on app switch
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
```

---

## 7. Phased Build Plan

Each phase ends with a **runnable Android simulator build** you can test before moving on. The milestone at the end of each phase is the acceptance criterion — don't proceed until it passes.

---

### Phase 1 — Core Foundation (Weeks 1–3)
**Goal:** A working, secure diary app. Create encrypted notes, view them in a list, biometric lock works.

#### What gets built
- Flutter project scaffold (full folder structure above)
- Isar database integration (Note model only)
- AES-256-GCM encryption service + key derivation
- flutter_secure_storage key store
- Biometric + PIN lock screen
- Home screen: flat list of note cards (no folders yet)
- Note editor: flutter_quill rich text (bold, italic, headings, bullet lists)
- Auto-save with 1.5-second debounce
- Word count bar
- Light / dark mode (system-adaptive)
- Basic navigation: Home → Editor → back

#### Packages used in Phase 1
- `isar`, `isar_flutter_libs`, `path_provider`
- `pointycastle`, `flutter_secure_storage`
- `local_auth`
- `flutter_quill`
- `riverpod`, `flutter_riverpod`
- `go_router`
- `google_fonts`
- `shared_preferences`

#### Setup commands (run in order)
```bash
# 1. Create project
fvm flutter create hush --org com.hush --platforms android,ios
cd hush

# 2. Add all pubspec.yaml dependencies (copy the full pubspec from Section 2.1)
fvm flutter pub get

# 3. Generate Isar models
fvm flutter pub run build_runner build --delete-conflicting-outputs

# 4. Verify Android emulator is running
adb devices   # Should list your AVD

# 5. Run on emulator
fvm flutter run
```

#### AndroidManifest.xml additions for Phase 1
```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
```

#### Phase 1 Simulator Test Milestone ✓
Open the emulator. Confirm all of the following work:
- [ ] App launches to the Lock screen
- [ ] Biometric prompt appears (or PIN fallback if AVD has no fingerprint)
- [ ] After unlock, Home screen shows "No notes yet" empty state
- [ ] Tapping "New note" opens the Quill editor
- [ ] Can type, bold text, add a heading, create a bullet list
- [ ] Word count updates in real time
- [ ] Back button saves the note
- [ ] Home screen shows the saved note card
- [ ] Dark mode toggle (Settings) switches theme instantly
- [ ] Killing and relaunching the app requires biometric again

---

### Phase 2 — Full UX: Book Navigation + Folders + Search (Weeks 4–6)
**Goal:** The full Hush diary experience. Kindle-style book, folders, tags, search, streak heatmap, notifications.

#### What gets built on top of Phase 1
- Folder model + Folder service + per-folder encryption
- Folder grid on Home screen (FolderCard widgets)
- **Kindle-style BookScreen:** page_flip package integration, swipe to curl pages
- **Pinch-to-zoom-out MiniPageStrip:** PinchGestureDetector triggers thumbnail strip
- Tag model + Tag service + TagChip widget
- Tag assignment in editor
- SearchScreen: in-memory decrypted full-text search
- Pin / Archive / Soft-delete notes (long-press context menu)
- Note context menu (long-press): pin, archive, delete, move to folder
- Streak heatmap (flutter_heatmap_calendar)
- Writing reminders via flutter_local_notifications
- Multiple themes: Classic, Midnight, Parchment, Sakura, Ocean, Forest, Slate
- ThemePickerScreen in Settings
- Emoji picker (flutter_emoji_picker)
- Undo/redo in editor (Quill built-in)
- Per-folder lock (FolderLock prompt on folder open)

#### Additional AndroidManifest.xml entries
```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>

<!-- Required for scheduled notifications after device reboot -->
<receiver android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver"
  android:exported="true">
  <intent-filter>
    <action android:name="android.intent.action.BOOT_COMPLETED"/>
  </intent-filter>
</receiver>
```

#### Phase 2 Simulator Test Milestone ✓
- [ ] Home screen shows folder grid + "All Notes" view toggle
- [ ] Create a folder, assign a color and icon
- [ ] Notes inside a folder are displayed in BookScreen (page-curl on swipe)
- [ ] Pinch-out gesture transitions to MiniPageStrip thumbnail view
- [ ] Tapping a thumbnail snaps back to full-page view at that note
- [ ] Tags can be created and assigned to notes; TagChips appear on NoteCard
- [ ] Search bar finds matching notes by decrypting content in-memory
- [ ] Long-press on a note shows context menu (pin / archive / delete)
- [ ] Pinned notes appear at top of list
- [ ] Heatmap in Settings shows green squares on days with notes
- [ ] Theme picker changes app colors and page background instantly
- [ ] Setting a daily writing reminder triggers a notification at the scheduled time
- [ ] Per-folder lock prompts for folder password on open

---

### Phase 3 — Polish, Export & iOS (Weeks 7–9)
**Goal:** Production-ready. Export works, iOS builds, font customization, Markdown import.

#### What gets built on top of Phase 2
- PDF export (per note or entire journal)
- Encrypted ZIP export of full journal
- Markdown import via file_picker
- Font customization per note and globally (Merriweather, Lato, Caveat)
- GIF picker (GIPHY API — only network feature)
- Sticker insertion from bundled asset packs
- iOS build configuration and TestFlight distribution
- Onboarding screen (first-launch only)
- App icon + splash screen finalization

#### Phase 3 Simulator Test Milestone ✓
- [ ] Export → single note → PDF → share sheet opens with valid PDF
- [ ] Export → full journal → encrypted ZIP downloaded to Downloads folder
- [ ] Import → pick a .md or .txt file → contents appear in a new note in the editor
- [ ] Font picker in note settings changes the note's display font
- [ ] GIF search returns results from GIPHY; tapping inserts GIF into editor
- [ ] Sticker panel shows bundled sticker packs; tapping inserts sticker
- [ ] First-launch onboarding completes and doesn't show again
- [ ] (iOS) `fvm flutter build ipa` produces a valid .ipa — no build errors

---

### Phase 4 — AI Mood Insights (Weeks 10–12)
**Goal:** Mood/sentiment tracking over time using a backend AI service.

#### Architecture Decision
AI analysis runs server-side (FastAPI + Claude/GPT-4o) to avoid bloating the app with large on-device models. Entries are sent encrypted; the server decrypts, analyzes, and returns sentiment scores only — never stores content.

#### What gets built on top of Phase 3
- FastAPI backend (Python) with a `/analyze/mood` endpoint
- Client sends: decrypted note text + date (text never persisted server-side)
- Server returns: `{ mood: 'positive' | 'neutral' | 'negative', score: 0.0–1.0, keywords: [...] }`
- MoodInsightsScreen: line chart of mood scores over time
- Mood badge on NoteCard (color-coded: green/yellow/red)
- Weekly mood summary card on Home screen
- Opt-in consent flow (first time AI is used)
- Offline fallback: if no network, mood analysis is skipped gracefully

#### Backend Stack (Python)
```
FastAPI
├── POST /analyze/mood    → accepts note text, returns mood score
├── No database           → stateless, no content stored
└── Auth: HMAC request signing (shared secret between app and server)

Dependencies:
- anthropic (Claude API) or openai
- uvicorn, fastapi, pydantic
```

#### Phase 4 Simulator Test Milestone ✓
- [ ] Opt-in consent screen appears on first AI use
- [ ] Writing a new note and saving triggers background mood analysis
- [ ] NoteCard displays a mood color badge after analysis completes
- [ ] MoodInsightsScreen shows a line chart of mood scores over time
- [ ] With network off, the app works normally and mood badge shows "Pending"
- [ ] Weekly summary shows average mood for the current week

---

## 8. Feature Specifications

### 8.1 Kindle-Style Book Navigation

**Concept:** The diary is a physical book. Each note is one page. The user swipes to curl pages, pinches to zoom out to a thumbnail strip.

**Implementation:**

```
BookScreen
  └── PageFlipWidget (page_flip package)
        └── BookPage (scrollable content)
              └── QuillEditor (read-only)

Pinch-out gesture:
  GestureDetector(onScaleUpdate)
    scale < 0.7 → AnimatedSwitcher to MiniPageStrip
    MiniPageStrip: horizontal ListView.builder of NoteCard thumbnails
    Tap thumbnail → _pageController.animateToPage(index)
```

**Key implementation notes:**
- `PageFlipWidget` from `page_flip` handles Bezier page curl automatically
- Use `QuillController` in read-only mode inside `BookPage`
- `GestureDetector` wraps the entire BookScreen to catch pinch scale
- Animate opacity of `MiniPageStrip` with `flutter_animate`

### 8.2 Rich Text Editor

```dart
// lib/widgets/editor/rich_text_editor.dart
import 'package:flutter_quill/flutter_quill.dart';

class RichTextEditor extends ConsumerStatefulWidget {
  final String? initialDeltaJson;   // Decrypted Quill Delta JSON
  final Function(String deltaJson) onChanged;

  @override
  ConsumerState<RichTextEditor> createState() => _RichTextEditorState();
}

class _RichTextEditorState extends ConsumerState<RichTextEditor> {
  late QuillController _controller;
  final _debounce = Debouncer(milliseconds: 1500);

  @override
  void initState() {
    super.initState();
    final doc = widget.initialDeltaJson != null
        ? Document.fromJson(jsonDecode(widget.initialDeltaJson!))
        : Document();
    _controller = QuillController(
      document: doc,
      selection: const TextSelection.collapsed(offset: 0),
    );
    _controller.addListener(_onDocumentChanged);
  }

  void _onDocumentChanged() {
    _debounce.run(() {
      final json = jsonEncode(_controller.document.toDelta().toJson());
      widget.onChanged(json);
    });
  }
}
```

**Toolbar layout:**
- Row 1 (always visible): Bold, Italic, Underline, H1, H2, H3
- Row 2 (expandable): Bullet list, Numbered list, Blockquote, Align (L/C/R)
- FAB row: 😀 Emoji | Sticker | 📷 Image | Highlight color | Undo | Redo

### 8.3 Full-Text Search

Because content is encrypted at rest, search decrypts in-memory only — plaintext is never written anywhere.

```dart
// lib/services/search_service.dart
class SearchService {
  static Future<List<SearchResult>> search({
    required String query,
    required Uint8List masterKey,
    int? folderId,
  }) async {
    final isar = IsarService.instance;
    var notesQuery = isar.notes.filter().isArchivedEqualTo(false);
    if (folderId != null) {
      notesQuery = notesQuery.folderIdEqualTo(folderId);
    }
    final notes = await notesQuery.findAll();

    final results = <SearchResult>[];
    for (final note in notes) {
      final folderKey = await _getFolderKey(note.folderId, masterKey);
      final plaintext = EncryptionService.decrypt(
        EncryptedPayload(
          ciphertext: note.encryptedBody,
          iv: note.iv,
          authTag: note.authTag,
        ),
        folderKey,
      );

      final lower = query.toLowerCase();
      if (note.title.toLowerCase().contains(lower) ||
          plaintext.toLowerCase().contains(lower)) {
        final idx = plaintext.toLowerCase().indexOf(lower);
        final snippet = plaintext.substring(
          (idx - 40).clamp(0, plaintext.length),
          (idx + 80).clamp(0, plaintext.length),
        );
        results.add(SearchResult(note: note, snippet: snippet));
      }
    }
    return results;
  }
}
```

**UX:** Show a `CircularProgressIndicator` during search. Run decryption in a `compute()` isolate to avoid blocking the UI thread.

### 8.4 Themes System

```dart
// lib/core/constants/theme_constants.dart
class HushTheme {
  final String id;
  final String name;
  final Color background;
  final Color surface;
  final Color primary;
  final Color accent;
  final Color text;
  final Color textSecondary;
  final Color pageBackground;
  final Color pageLines;
  final String bodyFont;
  final String headingFont;
  final PageStyle pageStyle;

  const HushTheme({required this.id, required this.name, ...});
}

enum PageStyle { blank, ruled, dotted, grid }

const themes = [
  HushTheme(id: 'classic-light',  name: 'Classic',    ...),
  HushTheme(id: 'midnight',       name: 'Midnight',   ...),
  HushTheme(id: 'parchment',      name: 'Parchment',  ...),
  HushTheme(id: 'sakura',         name: 'Sakura',     ...),
  HushTheme(id: 'ocean',          name: 'Ocean',      ...),
  HushTheme(id: 'forest',         name: 'Forest',     ...),
  HushTheme(id: 'slate',          name: 'Slate',      ...),
  HushTheme(id: 'rose-gold',      name: 'Rose Gold',  ...),
  HushTheme(id: 'noir',           name: 'Noir',       ...),
];
```

---

## 9. Package-to-Feature Mapping

| Feature | Primary Package | Supporting |
|---|---|---|
| App biometric lock | `local_auth` | `flutter_secure_storage` |
| AES-256-GCM encryption | `pointycastle` | — |
| Secure key storage | `flutter_secure_storage` | — |
| Embedded database | `isar` | `isar_flutter_libs` |
| Fast KV settings | `shared_preferences` | — |
| Page flip / curl | `page_flip` | `flutter_animate` |
| Pinch-to-zoom-out | Flutter `GestureDetector` | `flutter_animate` |
| Rich text editor | `flutter_quill` | — |
| Emoji picker | `flutter_emoji_picker` | — |
| GIF search | GIPHY REST API (http) | `cached_network_image` |
| Themes + dark mode | Flutter `ThemeData` + Riverpod | `shared_preferences` |
| Navigation | `go_router` | — |
| State management | `riverpod`, `flutter_riverpod` | `riverpod_annotation` |
| Streak heatmap | `flutter_heatmap_calendar` | `intl` |
| Local notifications | `flutter_local_notifications` | — |
| PDF export | `pdf` (dart package) | `printing`, `share_plus` |
| Encrypted ZIP export | `archive` | `pointycastle` |
| Full-text search | Native Dart (in-memory) | `pointycastle` (decryption) |
| File import | `file_picker` | — |
| Font loading | `google_fonts` | — |
| Unique IDs | `uuid` | — |
| Data models | `isar` code-gen | `build_runner` |
| Immutable state | `freezed` | `json_serializable` |

---

## 10. Navigation Architecture

### 10.1 Router Configuration

```dart
// lib/router/app_router.dart
import 'package:go_router/go_router.dart';

final appRouter = GoRouter(
  initialLocation: '/lock',
  redirect: (context, state) {
    final isLocked = ref.read(appLockProvider).isLocked;
    if (isLocked && state.location != '/lock') return '/lock';
    return null;
  },
  routes: [
    GoRoute(path: '/lock',     builder: (c, s) => const LockScreen()),
    GoRoute(path: '/home',     builder: (c, s) => const HomeScreen()),
    GoRoute(
      path: '/book/:folderId',
      builder: (c, s) => BookScreen(
        folderId: int.parse(s.pathParameters['folderId']!),
        startPage: int.tryParse(s.uri.queryParameters['page'] ?? '0') ?? 0,
      ),
    ),
    GoRoute(
      path: '/editor',
      builder: (c, s) => NoteEditorScreen(
        noteId: int.tryParse(s.uri.queryParameters['noteId'] ?? ''),
        folderId: int.parse(s.uri.queryParameters['folderId'] ?? '0'),
      ),
    ),
    GoRoute(path: '/search',   builder: (c, s) => const SearchScreen()),
    GoRoute(path: '/tags',     builder: (c, s) => const TagsScreen()),
    GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
    GoRoute(path: '/settings/themes',   builder: (c, s) => const ThemePickerScreen()),
    GoRoute(path: '/settings/security', builder: (c, s) => const PasswordSettingsScreen()),
    GoRoute(path: '/settings/export',   builder: (c, s) => const ExportScreen()),
  ],
);
```

### 10.2 Navigation Flow

```
/lock
  └── (unlock) ──────────────────────────► /home
                                              │
                          ┌───────────────────┼─────────────────┐
                          ▼                   ▼                  ▼
                    /book/:folderId       /search           /settings
                          │                                      │
                          ▼                          ┌───────────┼──────────┐
                      /editor                    /themes    /security  /export
```

---

## 11. State Management Architecture

### 11.1 App Lock Provider

```dart
// lib/providers/app_lock_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../core/auth/biometric_auth.dart';

part 'app_lock_provider.g.dart';

@riverpod
class AppLock extends _$AppLock {
  @override
  bool build() => true;   // Start locked

  Future<bool> unlock() async {
    final success = await BiometricAuth.authenticate();
    if (success) state = false;
    return success;
  }

  void lock() => state = true;
}
```

### 11.2 Notes Provider

```dart
// lib/providers/notes_provider.dart
@riverpod
class NotesNotifier extends _$NotesNotifier {
  @override
  Future<List<Note>> build({int? folderId}) async {
    return NoteService.getNotes(folderId: folderId);
  }

  Future<void> createNote({required String title, required String deltaJson}) async {
    final masterKey = ref.read(masterKeyProvider)!;
    await NoteService.createNote(
      title: title,
      deltaJson: deltaJson,
      masterKey: masterKey,
    );
    ref.invalidateSelf();
  }

  Future<void> updateNote(Note note, String deltaJson) async {
    final masterKey = ref.read(masterKeyProvider)!;
    await NoteService.updateNote(note: note, deltaJson: deltaJson, masterKey: masterKey);
    ref.invalidateSelf();
  }

  Future<void> deleteNote(Note note) async {
    await NoteService.deleteNote(note);
    ref.invalidateSelf();
  }
}
```

### 11.3 Theme Provider

```dart
// lib/providers/theme_provider.dart
@riverpod
class ThemeNotifier extends _$ThemeNotifier {
  @override
  HushTheme build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final id = prefs.getString('activeThemeId') ?? 'classic-light';
    return themes.firstWhere((t) => t.id == id, orElse: () => themes.first);
  }

  Future<void> setTheme(HushTheme theme) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('activeThemeId', theme.id);
    state = theme;
  }
}
```

---

## 12. Theming System

Flutter's `ThemeData` is the single source of truth. Riverpod's `ThemeNotifier` holds the active `HushTheme`, and `main.dart` rebuilds `MaterialApp` whenever the theme changes.

```dart
// lib/main.dart
@override
Widget build(BuildContext context, WidgetRef ref) {
  final hushTheme = ref.watch(themeNotifierProvider);

  return MaterialApp.router(
    routerConfig: appRouter,
    theme: _buildThemeData(hushTheme, Brightness.light),
    darkTheme: _buildThemeData(hushTheme, Brightness.dark),
    themeMode: ThemeMode.system,
  );
}

ThemeData _buildThemeData(HushTheme ft, Brightness brightness) {
  return ThemeData(
    brightness: brightness,
    scaffoldBackgroundColor: ft.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: ft.primary,
      brightness: brightness,
    ),
    fontFamily: ft.bodyFont,
    textTheme: GoogleFonts.getTextTheme(ft.bodyFont),
    appBarTheme: AppBarTheme(backgroundColor: ft.surface),
    cardTheme: CardTheme(color: ft.surface),
  );
}
```

---

## 13. Screen-by-Screen Implementation Guide

### Screen 1 — LockScreen

**Purpose:** App entry gate. Shows biometric prompt. Falls back to PIN.

**Widgets:**
- `Scaffold` with centered `Column`
- App logo (Hush wordmark)
- `ElevatedButton('Unlock with Biometric')` → calls `ref.read(appLockProvider.notifier).unlock()`
- On unlock success → `context.go('/home')`
- PIN fallback link: `TextButton('Use PIN')` → opens PIN entry bottom sheet

**Riverpod:** Watches `appLockProvider`. Redirects to `/home` if already unlocked.

---

### Screen 2 — HomeScreen

**Purpose:** Dashboard. Shows folder grid + "All Notes" floating action.

**Widgets:**
- `AppBar` with search icon (→ `/search`) and settings icon (→ `/settings`)
- `GridView.builder` of `FolderCard` widgets
- `FolderCard` shows: icon, name, note count, color accent
- Long-press `FolderCard` → rename / delete / lock folder context menu
- `FloatingActionButton` → Quick new note (in default folder) → `/editor`
- Bottom `NavigationBar`: Home | Book | Search | Tags | Settings

**Riverpod:** Watches `foldersProvider`. Watches `notesProvider(folderId: null)` for "All Notes" count.

---

### Screen 3 — BookScreen

**Purpose:** The Kindle-style book reading experience.

**Widgets:**
- `GestureDetector` wrapping entire screen (pinch scale detection)
- `PageFlipWidget` from `page_flip` package:
  ```dart
  PageFlipWidget(
    children: notes.map((n) => BookPage(note: n)).toList(),
    initialIndex: widget.startPage,
    backgroundColor: theme.pageBackground,
    showDragCutoff: false,
  )
  ```
- `BookPage`: vertically scrollable `QuillEditor` in read-only mode
- When `scale < 0.7`: `AnimatedSwitcher` fades in `MiniPageStrip`
- `MiniPageStrip`: horizontal `ListView` of `NoteCard` thumbnails with `snapToInterval`
- `FloatingActionButton` (bottom right): `+` → new note in this folder

**Page curl direction:** Right-to-left swipe turns to next page (like reading a book).

---

### Screen 4 — NoteEditorScreen

**Purpose:** Full rich-text editor.

**Widgets:**
- `RichTextEditor` widget (QuillEditor + custom toolbar)
- `EditorToolbar` (Row of format buttons)
- `WordCountBar` at the bottom (updates every 500ms)
- `AppBar` actions: Done (saves + closes), More (note settings: tag, font, color)
- Auto-save triggers on Quill document change (debounced 1.5s)

**Save flow:**
```
onChanged (Quill Delta) →
  debounce 1.5s →
  deltaJson = jsonEncode(delta) →
  EncryptionService.encrypt(deltaJson, folderKey) →
  NoteService.updateNote(note, encryptedPayload)
```

---

### Screen 5 — SearchScreen

**Purpose:** Full-text search across all non-archived notes.

**Widgets:**
- `SearchBar` (auto-focused on screen open)
- `FutureBuilder` or `AsyncValue` watching `searchProvider(query)`
- `ListView` of `NoteListItem` with highlighted match snippet
- Debounce: 400ms after typing stops before triggering search

---

### Screen 6 — SettingsScreen

**Purpose:** App configuration hub.

**Sections:**
- Appearance: Theme picker link, dark mode toggle, font size
- Security: Change PIN, change biometric preference
- Notifications: Daily writing reminder toggle + time picker
- Data: Export journal (PDF / ZIP), import from file
- Stats: Streak heatmap, total entries, total words
- About: Version, privacy policy link

---

## 14. Testing Strategy

### 14.1 Unit Tests

```dart
// test/crypto/encryption_test.dart
void main() {
  group('EncryptionService', () {
    test('round-trip encrypt/decrypt returns original plaintext', () {
      const plaintext = 'Hello, Hush!';
      final key = Uint8List(32); // 256-bit key of zeros for testing
      final payload = EncryptionService.encrypt(plaintext, key);
      final decrypted = EncryptionService.decrypt(payload, key);
      expect(decrypted, equals(plaintext));
    });

    test('different plaintext produces different ciphertext', () {
      final key = Uint8List(32);
      final p1 = EncryptionService.encrypt('Hello', key);
      final p2 = EncryptionService.encrypt('Hello', key);
      // IV is random so ciphertext should differ even for same input
      expect(p1.ciphertext, isNot(equals(p2.ciphertext)));
    });

    test('tampered ciphertext throws on decrypt', () {
      final key = Uint8List(32);
      final payload = EncryptionService.encrypt('test', key);
      final tampered = EncryptedPayload(
        ciphertext: 'AAAA${payload.ciphertext.substring(4)}',
        iv: payload.iv,
        authTag: payload.authTag,
      );
      expect(() => EncryptionService.decrypt(tampered, key), throwsException);
    });
  });
}
```

### 14.2 Widget Tests

```dart
// test/widgets/lock_screen_test.dart
void main() {
  testWidgets('LockScreen shows unlock button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp(home: LockScreen())),
    );
    expect(find.text('Unlock with Biometric'), findsOneWidget);
  });
}
```

### 14.3 Run All Tests

```bash
fvm flutter test
```

---

## 15. Performance Optimizations

| Concern | Problem | Solution |
|---|---|---|
| Search on large journals | Decrypting 1000+ notes on main thread freezes UI | Run `SearchService.search()` in `compute()` isolate |
| Page flip with many notes | `PageFlipWidget` building all pages at once | Use lazy builders; only render ±2 pages around current |
| Image loading | GIFs in notes causing jank | `cached_network_image` with `CacheManager` |
| Isar queries | Fetching all notes for search | Add Isar indices on `createdAt` and `folderId` |
| Encryption on save | Blocking UI during heavy encryption | Use `Future` + `async/await`; never on main isolate |
| Cold start | Isar initialization delays | Initialize Isar in `main()` before `runApp()` |
| Flutter Quill | Large documents slow | Use `QuillController.dispose()` when leaving editor |

---

## 16. Build & Release Pipeline

### 16.1 Run on Android Emulator (Development)

```bash
# Ensure emulator is running
fvm flutter devices   # Confirm emulator appears

# Debug build (fast, with hot reload)
fvm flutter run

# Hot reload: press 'r' in terminal
# Hot restart: press 'R' in terminal
```

### 16.2 Build a Release APK (for testing on physical device)

```bash
# Build release APK (no cloud service needed)
fvm flutter build apk --release

# APK location:
# build/app/outputs/flutter-apk/app-release.apk

# Install on connected device via ADB
adb install build/app/outputs/flutter-apk/app-release.apk
```

### 16.3 Build an App Bundle (for Google Play)

```bash
fvm flutter build appbundle --release
# Output: build/app/outputs/bundle/release/app-release.aab
```

### 16.4 Sign the APK for Release

```bash
# Step 1: Generate a keystore (one-time)
keytool -genkey -v -keystore hush-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias hush

# Step 2: Add to android/key.properties
storePassword=<your-store-password>
keyPassword=<your-key-password>
keyAlias=hush
storeFile=../hush-release.jks

# Step 3: Reference in android/app/build.gradle
# (Add signingConfigs block — standard Flutter release signing)
```

### 16.5 iOS Build (Phase 3)

```bash
# Requires macOS + Xcode 15+
fvm flutter build ipa
# Distribute via TestFlight
```

### 16.6 AndroidManifest.xml — Full Permission List

```xml
<uses-permission android:name="android.permission.USE_BIOMETRIC"/>
<uses-permission android:name="android.permission.USE_FINGERPRINT"/>
<uses-permission android:name="android.permission.INTERNET"/>       <!-- Phase 3: GIPHY only -->
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED"/>
<uses-permission android:name="android.permission.VIBRATE"/>
<uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>  <!-- Phase 3: import -->
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/> <!-- Phase 3: export -->
```

### 16.7 App Store Optimization Checklist (before Play Store submission)

- [ ] App icon: 512×512 PNG, no alpha channel
- [ ] Feature graphic: 1024×500 PNG
- [ ] Screenshots: minimum 2, recommended 8 (phone + 10" tablet)
- [ ] Short description: ≤80 characters
- [ ] Full description: ≤4000 characters, include privacy statement
- [ ] Privacy policy URL: static page stating all data is on-device
- [ ] Content rating: complete IARC questionnaire (expected: Everyone)
- [ ] Target API level: API 34 (Android 14)
- [ ] `android:allowBackup="false"` in AndroidManifest.xml
- [ ] ProGuard/R8: enabled in release build.gradle
- [ ] No debug flags in release build

---

## 17. Future Roadmap (Phase 3+)

### Phase 3 — iOS & Polish (covered above)

Expo's single codebase is replaced here by Flutter's single codebase — iOS support is a natural extension:
- `fvm flutter build ipa`
- Requires Apple Developer Account ($99/year) for TestFlight / App Store
- `local_auth` works identically for Face ID on iOS
- `flutter_secure_storage` uses iOS Keychain on iOS

### Phase 4 — AI Mood Insights (covered above)

- FastAPI (Python) backend — stateless `/analyze/mood` endpoint
- Client sends note text; server returns mood score and keywords only
- Content is never stored server-side

### Phase 5 — End-to-End Encrypted Cloud Sync (Optional)

If users request cross-device sync:
- Zero-knowledge backend: Supabase or Cloudflare R2
- Only AES-256-GCM ciphertext ever leaves the device
- Server never sees plaintext — encryption/decryption is client-only
- Differential sync: only changed notes are transmitted
- This is a significant undertaking — scope separately from Phase 4

### Phase 6 — Widget & Wearable

- Android home screen widget (quick-add note): `home_widget` Flutter package
- Wear OS companion: quick streak view and last entry snippet

---

## Appendix A — `.fvmrc`

```json
{
  "flutter": "stable",
  "flavors": {}
}
```

## Appendix B — `analysis_options.yaml`

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    prefer_const_constructors: true
    prefer_const_literals_to_create_immutables: true
    avoid_print: true
    prefer_single_quotes: true
    always_declare_return_types: true
```

## Appendix C — Git Setup & Commit Convention

```bash
git init
git add .
git commit -m "chore: initial Flutter project scaffold"

# Commit format: conventional commits
# feat: add page flip animation
# fix: encryption key not persisting after app restart
# chore: update flutter to latest stable via fvm
# docs: update README with simulator setup instructions
```

## Appendix D — LLM Implementation Prompting Guide

When using this document with an LLM (Claude, etc.) to generate code, use this sequencing:

1. **"Implement the Isar schema and models from Section 5. Use Dart null safety and run build_runner."**
2. **"Implement the full EncryptionService and KeyDerivation from Section 6. Write round-trip tests."**
3. **"Implement the NoteService class using Isar + EncryptionService. Cover create, read, update, delete."**
4. **"Scaffold the go_router navigation from Section 10 and wire it to main.dart."**
5. **"Implement LockScreen from Section 13, Screen 1. Use local_auth and AppLock Riverpod provider."**
6. **"Implement BookScreen from Section 13, Screen 3. Use page_flip for the curl and GestureDetector for pinch-zoom."**
7. **"Implement NoteEditorScreen using flutter_quill. Include the custom toolbar and debounced auto-save."**
8. **"Implement all Riverpod providers from Section 11 and wire them to the screens."**
9. **"Implement the theming system from Section 12 with all 9 themes and system dark mode support."**
10. **"Set up the Android release signing from Section 16 and produce a testable release APK."**

---

*Document version: 2.0 | Migrated from React Native + Expo to Flutter + Dart | March 2026*
*Original spec authored for Hush v1.0 | Rewritten for Flutter stable channel, Dart 3.x, Isar 3.x, Riverpod 2.x*
