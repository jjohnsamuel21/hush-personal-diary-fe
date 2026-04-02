import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

// Singleton that holds the open SQLite database.
// Renamed kept as isar_service.dart for minimal churn — internally uses sqflite.
// Call DatabaseService.init() once in main() before runApp().
class DatabaseService {
  DatabaseService._();
  static late Database _db;

  static Future<void> init() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'hush.db');

    _db = await openDatabase(
      path,
      version: 10,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );

    // SQLite doesn't enforce foreign keys by default — enable it so
    // ON DELETE CASCADE on note_tags actually works.
    await _db.execute('PRAGMA foreign_keys = ON;');
  }

  static Database get instance => _db;

  // Incremental migration — runs for users upgrading from an older version.
  // Each "if (oldVersion < N)" block is idempotent and runs in order,
  // so a user jumping from v1 directly to v3 would apply both v2 and v3 changes.
  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS tags (
          id         INTEGER PRIMARY KEY AUTOINCREMENT,
          name       TEXT NOT NULL UNIQUE,
          color      TEXT NOT NULL DEFAULT '#5C6BC0',
          created_at TEXT NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS note_tags (
          note_id INTEGER NOT NULL,
          tag_id  INTEGER NOT NULL,
          PRIMARY KEY (note_id, tag_id),
          FOREIGN KEY (note_id) REFERENCES notes(id)  ON DELETE CASCADE,
          FOREIGN KEY (tag_id)  REFERENCES tags(id)   ON DELETE CASCADE
        )
      ''');
    }
    if (oldVersion < 3) {
      // Add manual sort order for drag-to-reorder support.
      // Default 0 means "use date-based ordering" for existing notes.
      await db.execute(
        'ALTER TABLE notes ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      // Index on title speeds up DB-level prefix searches (future feature)
      // and on updated_at for sorting.
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_notes_title ON notes(title)',
      );
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_notes_updated ON notes(updated_at DESC)',
      );
    }
    if (oldVersion < 5) {
      // Per-journal cover image — absolute file path stored as TEXT.
      await db.execute(
        'ALTER TABLE folders ADD COLUMN cover_image_path TEXT',
      );
    }
    if (oldVersion < 6) {
      // Page layout mode and associated image paths (JSON array).
      await db.execute(
        "ALTER TABLE notes ADD COLUMN page_layout TEXT NOT NULL DEFAULT 'text_only'",
      );
      await db.execute(
        'ALTER TABLE notes ADD COLUMN layout_images TEXT',
      );
    }
    if (oldVersion < 7) {
      // Per-journal reading background.
      // reading_bg_preset_id: a preset id from kBackgroundPresets (nullable = use global)
      // reading_bg_image_path: absolute path for a custom image background (nullable)
      await db.execute(
        'ALTER TABLE folders ADD COLUMN reading_bg_preset_id TEXT',
      );
      await db.execute(
        'ALTER TABLE folders ADD COLUMN reading_bg_image_path TEXT',
      );
    }
    if (oldVersion < 9) {
      // Per-entry background override.
      // note_bg_preset_id: a preset id from kBackgroundPresets (null = no override)
      // note_bg_image_path: absolute path for a custom image (null = no override)
      await db.execute(
        'ALTER TABLE notes ADD COLUMN note_bg_preset_id TEXT',
      );
      await db.execute(
        'ALTER TABLE notes ADD COLUMN note_bg_image_path TEXT',
      );
    }
    if (oldVersion < 8) {
      // Local cache for shared notes pulled from the backend.
      // These are intentionally NOT encrypted — shared notes are plaintext on the server.
      await db.execute('''
        CREATE TABLE IF NOT EXISTS shared_notes (
          id                   TEXT PRIMARY KEY,
          owner_email          TEXT NOT NULL,
          owner_display_name   TEXT,
          owner_avatar_url     TEXT,
          title                TEXT NOT NULL,
          body                 TEXT NOT NULL,
          font_family          TEXT NOT NULL DEFAULT 'Merriweather',
          cover_color          TEXT NOT NULL DEFAULT '#5C6BC0',
          is_archived          INTEGER NOT NULL DEFAULT 0,
          my_permission        TEXT NOT NULL DEFAULT 'owner',
          collaborators_json   TEXT,
          server_updated_at    TEXT NOT NULL,
          synced_at            TEXT NOT NULL
        )
      ''');
    }
    if (oldVersion < 10) {
      // Activity log for both local and shared note sessions.
      // Local logs can be deleted by the user; shared logs are per-user (deleting
      // your log does not affect other collaborators' logs).
      await db.execute('''
        CREATE TABLE IF NOT EXISTS activity_logs (
          id           INTEGER PRIMARY KEY AUTOINCREMENT,
          session_type TEXT NOT NULL DEFAULT 'local',
          note_id      TEXT,
          action       TEXT NOT NULL,
          note_title   TEXT,
          detail       TEXT,
          created_at   TEXT NOT NULL
        )
      ''');
    }
  }

  // Called once when the database file is first created.
  // Defines the schema — all tables and their columns.
  static Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id               INTEGER PRIMARY KEY AUTOINCREMENT,
        folder_id        INTEGER NOT NULL DEFAULT 0,
        title            TEXT NOT NULL,
        encrypted_body   TEXT NOT NULL,
        iv               TEXT NOT NULL,
        auth_tag         TEXT NOT NULL,
        is_pinned        INTEGER NOT NULL DEFAULT 0,
        is_archived      INTEGER NOT NULL DEFAULT 0,
        is_deleted       INTEGER NOT NULL DEFAULT 0,
        word_count       INTEGER NOT NULL DEFAULT 0,
        reading_time_sec INTEGER NOT NULL DEFAULT 0,
        cover_color      TEXT NOT NULL DEFAULT '#5C6BC0',
        font_family      TEXT NOT NULL DEFAULT 'Merriweather',
        page_number      INTEGER NOT NULL DEFAULT 0,
        sort_order       INTEGER NOT NULL DEFAULT 0,
        page_layout          TEXT NOT NULL DEFAULT 'text_only',
        layout_images        TEXT,
        note_bg_preset_id    TEXT,
        note_bg_image_path   TEXT,
        created_at           TEXT NOT NULL,
        updated_at           TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE folders (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        name                  TEXT NOT NULL,
        color                 TEXT NOT NULL DEFAULT '#5C6BC0',
        icon                  TEXT NOT NULL DEFAULT 'book',
        is_locked             INTEGER NOT NULL DEFAULT 0,
        encrypted_folder_key  TEXT,
        cover_image_path      TEXT,
        reading_bg_preset_id  TEXT,
        reading_bg_image_path TEXT,
        sort_order            INTEGER NOT NULL DEFAULT 0,
        created_at            TEXT NOT NULL,
        updated_at            TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE tags (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL UNIQUE,
        color      TEXT NOT NULL DEFAULT '#5C6BC0',
        created_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE note_tags (
        note_id INTEGER NOT NULL,
        tag_id  INTEGER NOT NULL,
        PRIMARY KEY (note_id, tag_id),
        FOREIGN KEY (note_id) REFERENCES notes(id)  ON DELETE CASCADE,
        FOREIGN KEY (tag_id)  REFERENCES tags(id)   ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE shared_notes (
        id                   TEXT PRIMARY KEY,
        owner_email          TEXT NOT NULL,
        owner_display_name   TEXT,
        owner_avatar_url     TEXT,
        title                TEXT NOT NULL,
        body                 TEXT NOT NULL,
        font_family          TEXT NOT NULL DEFAULT 'Merriweather',
        cover_color          TEXT NOT NULL DEFAULT '#5C6BC0',
        is_archived          INTEGER NOT NULL DEFAULT 0,
        my_permission        TEXT NOT NULL DEFAULT 'owner',
        collaborators_json   TEXT,
        server_updated_at    TEXT NOT NULL,
        synced_at            TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE activity_logs (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        session_type TEXT NOT NULL DEFAULT 'local',
        note_id      TEXT,
        action       TEXT NOT NULL,
        note_title   TEXT,
        detail       TEXT,
        created_at   TEXT NOT NULL
      )
    ''');
    // No default folders — users create journals explicitly.
  }
}

// Keep the old name working so isar_service.dart imports don't need changing
// in files we've already written
typedef IsarService = DatabaseService;
