import 'package:flutter/material.dart';

/// Full user guide — accessible from Settings › Help & Guide.
/// Each feature is a collapsible section the user can expand individually.
class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Help & Guide'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Quick welcome card
          Card(
            color: colors.primaryContainer,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.auto_stories_rounded,
                      size: 36, color: colors.onPrimaryContainer),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Welcome to Hush',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: colors.onPrimaryContainer)),
                        const SizedBox(height: 4),
                        Text(
                          'Your private, encrypted diary. '
                          'Tap any section below to learn how it works.',
                          style: TextStyle(
                              fontSize: 13,
                              color:
                                  colors.onPrimaryContainer.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          _GuideSection(
            icon: Icons.lock_outline,
            title: 'Unlocking the app',
            color: colors.primary,
            steps: const [
              _Step(
                icon: Icons.fingerprint,
                title: 'Biometric unlock',
                body:
                    'Tap "Unlock with Biometric" on the lock screen. The app uses your phone\'s fingerprint or face recognition — no password is stored.',
              ),
              _Step(
                icon: Icons.no_encryption_outlined,
                title: 'No security set up?',
                body:
                    'If your phone has no lock screen PIN or biometrics, the app opens automatically with a single tap. Set up a screen lock in Android Settings to enable biometric protection.',
              ),
            ],
          ),

          _GuideSection(
            icon: Icons.edit_note_rounded,
            title: 'Writing an entry',
            color: colors.secondary,
            steps: const [
              _Step(
                icon: Icons.add_circle_outline,
                title: 'Create a new entry',
                body:
                    'Tap the ✏️ floating button on the All Entries screen. A blank editor opens immediately with the keyboard ready.',
              ),
              _Step(
                icon: Icons.title,
                title: 'Title field',
                body:
                    'Tap the title area at the top to give your entry a name. Leave it blank and Hush will auto-generate one from your first line.',
              ),
              _Step(
                icon: Icons.format_bold,
                title: 'Formatting toolbar',
                body:
                    'The toolbar below the title bar shows B (Bold), I (Italic), U (Underline), and H (Heading). Tap the ∨ chevron on the right of the toolbar to reveal more options: text colour, bullet lists, numbered lists, blockquote, alignment, undo/redo.',
              ),
              _Step(
                icon: Icons.add_circle_outline,
                title: '⊕ Insert & Style button',
                body:
                    'The ⊕ icon in the top-right opens a panel with:\n• RECORD — Voice note, Drawing\n• INSERT — Emoji, Sticker, GIF\n• STYLE — Font, Background, Layout\n• Formatting guide',
              ),
              _Step(
                icon: Icons.save_outlined,
                title: 'Auto-save',
                body:
                    'Your entry saves automatically 1.5 seconds after you stop typing. A tiny spinner in the top-right confirms it\'s saving. Tap Done when finished.',
              ),
            ],
          ),

          _GuideSection(
            icon: Icons.mic_rounded,
            title: 'Voice notes',
            color: colors.tertiary,
            steps: const [
              _Step(
                icon: Icons.mic_rounded,
                title: 'Recording',
                body:
                    'Tap ⊕ → Voice note. A sheet appears with a large record button. Tap it once to start, tap again to stop. The recording embeds directly in your entry.',
              ),
              _Step(
                icon: Icons.play_arrow_rounded,
                title: 'Playback',
                body:
                    'Inside the entry, tap the play button on the audio player to listen. A progress slider lets you scrub to any position.',
              ),
              _Step(
                icon: Icons.delete_outline,
                title: 'Deleting a recording',
                body:
                    'Long-press the audio player in the entry and tap Delete. This removes the embed and the file from your device.',
              ),
            ],
          ),

          _GuideSection(
            icon: Icons.menu_book_rounded,
            title: 'Journals (folders)',
            color: colors.primary,
            steps: const [
              _Step(
                icon: Icons.create_new_folder_outlined,
                title: 'Creating a journal',
                body:
                    'Go to the Journals tab → tap the + card. Choose a name, colour, and icon. Each journal groups related entries together.',
              ),
              _Step(
                icon: Icons.book_outlined,
                title: 'Reading a journal',
                body:
                    'Tap a journal card to open it in Book View — a Kindle-style page-by-page reader. Tap the left 30% of the screen to go back, right 30% to go forward. Tap the centre to show/hide the toolbar.',
              ),
              _Step(
                icon: Icons.add_outlined,
                title: 'Adding an entry to a journal',
                body:
                    'In Book View, tap the + icon in the top toolbar. The new entry will be added after the current entry.',
              ),
              _Step(
                icon: Icons.lock_outline,
                title: 'PIN-locking a journal',
                body:
                    'Long-press a journal card → Set PIN. A 4–8 digit PIN locks the journal so it won\'t appear in All Entries and requires a PIN to open.',
              ),
              _Step(
                icon: Icons.drive_file_move_outlined,
                title: 'Moving an entry to a journal',
                body:
                    'Long-press any entry card → Move to journal. A sheet shows all your journals — tap one to move the entry instantly.',
              ),
            ],
          ),

          _GuideSection(
            icon: Icons.sort_rounded,
            title: 'Sorting & finding entries',
            color: colors.secondary,
            steps: const [
              _Step(
                icon: Icons.edit_outlined,
                title: 'Sort order',
                body:
                    'At the top of All Entries, three chips let you sort: Last Edited, Created Date, or A→Z. Tap any chip to change the order.',
              ),
              _Step(
                icon: Icons.search,
                title: 'Search',
                body:
                    'Tap the 🔍 icon in the top bar to search across all entries by title or content.',
              ),
              _Step(
                icon: Icons.push_pin_outlined,
                title: 'Pinning an entry',
                body:
                    'Long-press an entry → Pin to top. Pinned entries always appear first regardless of the current sort order.',
              ),
              _Step(
                icon: Icons.archive_outlined,
                title: 'Archiving',
                body:
                    'Long-press an entry → Archive. Archived entries are hidden from the main list but not deleted. Access them from Settings.',
              ),
            ],
          ),

          _GuideSection(
            icon: Icons.palette_outlined,
            title: 'Themes & backgrounds',
            color: colors.tertiary,
            steps: const [
              _Step(
                icon: Icons.color_lens_outlined,
                title: 'App theme',
                body:
                    'Settings → Appearance → Theme. Choose from Hush (warm), Midnight (dark), Forest (green), or Ocean (blue). Each theme auto-applies a matching background.',
              ),
              _Step(
                icon: Icons.wallpaper_outlined,
                title: 'Global background',
                body:
                    'Settings → Appearance → Background. Pick a preset or tap the camera icon to use your own photo.',
              ),
              _Step(
                icon: Icons.auto_awesome_outlined,
                title: 'Entry-specific background',
                body:
                    'In the editor, tap ⊕ → Background to set a background for that entry only. It overrides the global background only for that entry.',
              ),
              _Step(
                icon: Icons.menu_book_rounded,
                title: 'Journal reading background',
                body:
                    'In Book View, tap the 🎨 palette icon in the toolbar to set a background that applies while reading that journal.',
              ),
              _Step(
                icon: Icons.format_paint_outlined,
                title: 'Page lines',
                body:
                    'Settings → Appearance → Page Lines. Choose Blank, Ruled, Dotted, or Grid to add texture behind your text.',
              ),
            ],
          ),

          _GuideSection(
            icon: Icons.people_outline_rounded,
            title: 'Shared notes',
            color: colors.primary,
            steps: const [
              _Step(
                icon: Icons.login_rounded,
                title: 'Sign in required',
                body:
                    'Shared notes require a Google account. Go to Settings → Google Account → Sign in with Google.',
              ),
              _Step(
                icon: Icons.add,
                title: 'Create a shared note',
                body:
                    'Go to the Shared tab → tap the + button. Write your note and tap Done.',
              ),
              _Step(
                icon: Icons.person_add_outlined,
                title: 'Invite collaborators',
                body:
                    'Long-press a shared note → Manage collaborators → enter an email address and choose View or Edit permission.',
              ),
              _Step(
                icon: Icons.sync_outlined,
                title: 'Syncing',
                body:
                    'Shared notes sync to the cloud. If you see "Not synced", tap the Sync button in the note. Make sure you\'re signed in with Google first.',
              ),
              _Step(
                icon: Icons.delete_outline,
                title: 'Deleting a shared note',
                body:
                    'Long-press a shared note → Delete (owners only). Collaborators can leave by choosing "Leave shared note".',
              ),
            ],
          ),

          _GuideSection(
            icon: Icons.ios_share_outlined,
            title: 'Export & import',
            color: colors.secondary,
            steps: const [
              _Step(
                icon: Icons.picture_as_pdf_outlined,
                title: 'Export as PDF',
                body:
                    'Settings → Data → Export as PDF. A PDF with one page per entry is created and shared via the Android share sheet — save to Downloads, Drive, or send via email.',
              ),
              _Step(
                icon: Icons.lock_outline,
                title: 'Encrypted backup (ZIP)',
                body:
                    'Settings → Data → Encrypted backup. Creates an AES-256-GCM encrypted archive of all your entries. Keep this file safe — you need the same device key to restore.',
              ),
              _Step(
                icon: Icons.upload_file_outlined,
                title: 'Import Markdown / text',
                body:
                    'Settings → Data → Import. Pick a .md or .txt file from your device. It becomes a new entry in your default journal.',
              ),
            ],
          ),

          _GuideSection(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy & security',
            color: colors.error,
            steps: const [
              _Step(
                icon: Icons.shield_outlined,
                title: 'End-to-end encryption',
                body:
                    'All diary entries are encrypted with AES-256-GCM on your device before being saved. Nothing is sent to any server — not even the encrypted data.',
              ),
              _Step(
                icon: Icons.screenshot_outlined,
                title: 'Screenshot protection',
                body:
                    'Screenshots are blocked by default. Enable them in Settings → Privacy & Security if you need to.',
              ),
              _Step(
                icon: Icons.lock_clock_outlined,
                title: 'Auto-lock',
                body:
                    'The app locks whenever you leave it. The master key is wiped from memory — entries cannot be read without biometric authentication.',
              ),
            ],
          ),

          _GuideSection(
            icon: Icons.notifications_outlined,
            title: 'Daily reminder',
            color: colors.tertiary,
            steps: const [
              _Step(
                icon: Icons.alarm_outlined,
                title: 'Enable reminder',
                body:
                    'Settings → Writing → Enable daily reminder. Toggle it on and pick a time. You\'ll get a notification each day prompting you to write.',
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Guide section (collapsible) ───────────────────────────────────────────────

class _GuideSection extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final List<_Step> steps;

  const _GuideSection({
    required this.icon,
    required this.title,
    required this.color,
    required this.steps,
  });

  @override
  State<_GuideSection> createState() => _GuideSectionState();
}

class _GuideSectionState extends State<_GuideSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Header — always visible
          ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: widget.color, size: 20),
            ),
            title: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            trailing: AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more, color: colors.outline),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),

          // Steps — revealed when expanded
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Column(
              children: [
                const Divider(height: 1, indent: 16, endIndent: 16),
                ...widget.steps.map((step) => _StepTile(
                      step: step,
                      accentColor: widget.color,
                    )),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Step tile ─────────────────────────────────────────────────────────────────

class _Step {
  final IconData icon;
  final String title;
  final String body;
  const _Step({required this.icon, required this.title, required this.body});
}

class _StepTile extends StatelessWidget {
  final _Step step;
  final Color accentColor;
  const _StepTile({required this.step, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(step.icon, size: 18, color: accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: colors.onSurface),
                ),
                const SizedBox(height: 3),
                Text(
                  step.body,
                  style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                      height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
