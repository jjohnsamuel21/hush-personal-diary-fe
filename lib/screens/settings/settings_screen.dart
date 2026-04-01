import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/auth/app_lock_notifier.dart';
import '../../core/constants/theme_constants.dart';
import '../../providers/auth_provider.dart';
import '../../providers/background_provider.dart';
import '../../providers/page_style_provider.dart';
import '../../providers/theme_provider.dart';
import '../../services/export_service.dart';
import '../../services/import_service.dart';
import '../../services/note_service.dart';
import '../../services/reminder_service.dart';
import '../../services/security_service.dart';
import '../../widgets/common/app_background.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _reminderEnabled = false;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);
  Map<DateTime, int> _heatmapData = {};
  bool _heatmapLoading = true;
  bool _exporting = false;
  bool _importing = false;
  bool _screenshotAllowed = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadHeatmap();
    _loadSecuritySettings();
  }

  Future<void> _loadSettings() async {
    final enabled = await ReminderService.isEnabled();
    final time = await ReminderService.getSavedTime();
    if (mounted) setState(() { _reminderEnabled = enabled; _reminderTime = time; });
  }

  Future<void> _loadSecuritySettings() async {
    final allowed = await SecurityService.isScreenshotAllowed();
    if (mounted) setState(() => _screenshotAllowed = allowed);
  }

  Future<void> _loadHeatmap() async {
    final data = await NoteService.getNotesPerDay();
    if (mounted) setState(() { _heatmapData = data; _heatmapLoading = false; });
  }

  Future<void> _exportZip() async {
    final masterKey = ref.read(masterKeyProvider);
    if (masterKey == null) return;
    setState(() => _exporting = true);
    try {
      await ExportService.exportEncryptedZip(masterKey);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _exportPdf() async {
    final masterKey = ref.read(masterKeyProvider);
    if (masterKey == null) return;
    setState(() => _exporting = true);
    try {
      await ExportService.exportJournalPdf(null, masterKey);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('PDF export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importFile() async {
    final masterKey = ref.read(masterKeyProvider);
    if (masterKey == null) return;
    setState(() => _importing = true);
    try {
      final id = await ImportService.importFile(folderId: 1, masterKey: masterKey);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(id != null ? 'Entry imported successfully' : 'No file selected'),
        ));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// Pick a custom background image — shows a confirmation dialog first if
  /// the current background is already a custom image.
  Future<void> _pickBackgroundImage() async {
    final bg = ref.read(backgroundProvider);
    if (bg.type == AppBackgroundType.image && bg.imagePath != null) {
      final confirmed = await _confirmReplaceBackground();
      if (!confirmed || !mounted) return;
    }
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null || !mounted) return;
    await ref.read(backgroundProvider.notifier).setImage(picked.path);
  }

  Future<bool> _confirmReplaceBackground() async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Replace background?'),
            content: const Text(
              'You have a custom photo set as your background. '
              'Choosing a new one will replace it.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Replace'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    // Watch all appearance providers so settings page re-renders immediately
    // on any change — no need to leave and re-enter.
    final hushTheme = ref.watch(themeProvider);
    final bg = ref.watch(backgroundProvider);
    final pageStyle = ref.watch(pageStyleProvider);
    final googleUser = ref.watch(authProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      // Wrap body in AppBackgroundWrapper so background change is visible
      // immediately within the settings page itself.
      body: AppBackgroundWrapper(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [

            // ══════════════════════════════════════════════════════════════
            // APPEARANCE
            // ══════════════════════════════════════════════════════════════
            _SectionDivider(label: 'Appearance'),

            // ── Theme ──────────────────────────────────────────────────────
            _Label(text: 'Theme'),
            const SizedBox(height: 12),
            _ThemePicker(current: hushTheme),
            const SizedBox(height: 28),

            // ── Background ─────────────────────────────────────────────────
            _Label(text: 'Background'),
            const SizedBox(height: 12),
            _BackgroundPresetGrid(
              current: bg,
              onPickCustom: _pickBackgroundImage,
            ),
            const SizedBox(height: 28),

            // ── Page Lines ─────────────────────────────────────────────────
            _Label(text: 'Page Lines'),
            const SizedBox(height: 4),
            Text(
              'Texture behind text in entries and the reading view.',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            _PageStylePicker(current: pageStyle),
            const SizedBox(height: 8),

            // ══════════════════════════════════════════════════════════════
            // WRITING
            // ══════════════════════════════════════════════════════════════
            _SectionDivider(label: 'Writing'),

            // ── Writing Streak ─────────────────────────────────────────────
            _Label(text: 'Writing Streak'),
            const SizedBox(height: 12),
            _heatmapLoading
                ? const Center(child: CircularProgressIndicator())
                : HeatMapCalendar(
                    flexible: true,
                    colorMode: ColorMode.opacity,
                    datasets: _heatmapData,
                    colorsets: {1: colors.primary},
                    defaultColor: colors.surfaceContainerHighest,
                    textColor: colors.onSurface,
                    weekTextColor: colors.outline,
                    borderRadius: 4,
                  ),
            const SizedBox(height: 28),

            // ── Daily Reminder ─────────────────────────────────────────────
            _Label(text: 'Daily Reminder'),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Enable daily reminder'),
              subtitle: Text(
                _reminderEnabled
                    ? 'Set for ${_reminderTime.format(context)}'
                    : 'Tap to schedule a daily writing prompt',
              ),
              value: _reminderEnabled,
              onChanged: _toggleReminder,
            ),
            if (_reminderEnabled)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.access_time_outlined),
                title: const Text('Reminder time'),
                trailing: Text(
                  _reminderTime.format(context),
                  style: TextStyle(color: colors.primary, fontWeight: FontWeight.w500),
                ),
                onTap: _pickReminderTime,
              ),

            // ══════════════════════════════════════════════════════════════
            // DATA
            // ══════════════════════════════════════════════════════════════
            _SectionDivider(label: 'Data'),

            _Label(text: 'Export'),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Export as PDF',
              subtitle: 'One page per entry, shared via share sheet',
              loading: _exporting,
              onTap: _exporting ? null : _exportPdf,
            ),
            _ActionTile(
              icon: Icons.lock_outline,
              title: 'Encrypted backup (ZIP)',
              subtitle: 'AES-256-GCM encrypted archive',
              loading: _exporting,
              onTap: _exporting ? null : _exportZip,
            ),
            const SizedBox(height: 16),
            _Label(text: 'Import'),
            const SizedBox(height: 8),
            _ActionTile(
              icon: Icons.upload_file_outlined,
              title: 'Import Markdown / text file',
              subtitle: 'Creates a new entry from .md or .txt',
              loading: _importing,
              onTap: _importing ? null : _importFile,
            ),

            // ══════════════════════════════════════════════════════════════
            // PRIVACY & SECURITY
            // ══════════════════════════════════════════════════════════════
            _SectionDivider(label: 'Privacy & Security'),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.screenshot_outlined),
              title: const Text('Allow screenshots'),
              subtitle: const Text(
                'Off by default — hides app in recents and blocks screenshots.',
              ),
              isThreeLine: true,
              value: _screenshotAllowed,
              onChanged: (value) async {
                await SecurityService.setScreenshotAllowed(value);
                if (mounted) setState(() => _screenshotAllowed = value);
              },
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shield_outlined),
              title: const Text('On-device encryption'),
              subtitle: const Text(
                'All entries are encrypted with AES-256-GCM. Nothing leaves your phone.',
              ),
              isThreeLine: true,
            ),

            // ══════════════════════════════════════════════════════════════
            // GOOGLE ACCOUNT
            // ══════════════════════════════════════════════════════════════
            _SectionDivider(label: 'Google Account'),
            if (googleUser == null)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.login_rounded),
                title: const Text('Sign in with Google'),
                subtitle: const Text('Required for shared and collaborative notes'),
                onTap: () async {
                  final ok = await ref.read(authProvider.notifier).signIn();
                  if (mounted && !ok) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sign-in failed or cancelled')),
                    );
                  }
                },
              )
            else ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 20,
                  backgroundImage: googleUser.avatarUrl != null
                      ? NetworkImage(googleUser.avatarUrl!)
                      : null,
                  child: googleUser.avatarUrl == null
                      ? Text(googleUser.email[0].toUpperCase(),
                          style: const TextStyle(fontWeight: FontWeight.w600))
                      : null,
                ),
                title: Text(googleUser.displayName ?? googleUser.email),
                subtitle: Text(googleUser.email,
                    style: TextStyle(fontSize: 12, color: colors.outline)),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout_rounded, color: colors.error),
                title: Text('Sign out', style: TextStyle(color: colors.error)),
                onTap: () => ref.read(authProvider.notifier).signOut(),
              ),
            ],
            const SizedBox(height: 8),

            // ══════════════════════════════════════════════════════════════
            // ABOUT
            // ══════════════════════════════════════════════════════════════
            _SectionDivider(label: 'About'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'assets/logo/hush-diary-app-logo.jpeg',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                ),
              ),
              title: const Text('Hush'),
              subtitle: const Text('Version 1.0.0 · Your private diary'),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleReminder(bool value) async {
    if (value) {
      await ReminderService.scheduleDaily(_reminderTime);
    } else {
      await ReminderService.cancelAll();
    }
    setState(() => _reminderEnabled = value);
  }

  Future<void> _pickReminderTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked == null || !mounted) return;
    setState(() => _reminderTime = picked);
    await ReminderService.scheduleDaily(picked);
  }
}

// ─── Section divider header ───────────────────────────────────────────────────
class _SectionDivider extends StatelessWidget {
  final String label;
  const _SectionDivider({required this.label});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 28, bottom: 16),
      child: Row(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Divider(
              color: colors.outlineVariant,
              thickness: 1,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Small label above a widget group ────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  const _Label({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

// ─── Action tile (export / import) ───────────────────────────────────────────
class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: loading
          ? const SizedBox(
              width: 20, height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
      onTap: onTap,
    );
  }
}

// ─── Page style picker ────────────────────────────────────────────────────────
class _PageStylePicker extends ConsumerWidget {
  final PageStyle current;
  const _PageStylePicker({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    final options = [
      (PageStyle.blank,  'None',   Icons.crop_landscape_outlined),
      (PageStyle.ruled,  'Ruled',  Icons.format_align_left_outlined),
      (PageStyle.dotted, 'Dotted', Icons.grain_outlined),
      (PageStyle.grid,   'Grid',   Icons.grid_on_outlined),
    ];

    return Row(
      children: options.map((opt) {
        final (style, label, icon) = opt;
        final selected = current == style;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => ref.read(pageStyleProvider.notifier).setStyle(style),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: selected
                      ? colors.primary.withValues(alpha: 0.12)
                      : colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? colors.primary : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon,
                        size: 20,
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant),
                    const SizedBox(height: 4),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            selected ? FontWeight.w600 : FontWeight.normal,
                        color: selected
                            ? colors.primary
                            : colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Background preset grid ───────────────────────────────────────────────────
class _BackgroundPresetGrid extends ConsumerStatefulWidget {
  final AppBackground current;
  final VoidCallback onPickCustom;

  const _BackgroundPresetGrid({
    required this.current,
    required this.onPickCustom,
  });

  @override
  ConsumerState<_BackgroundPresetGrid> createState() =>
      _BackgroundPresetGridState();
}

class _BackgroundPresetGridState
    extends ConsumerState<_BackgroundPresetGrid> {
  bool _isActive(BackgroundPreset preset) {
    final bg = preset.background;
    final cur = widget.current;
    if (bg.type != cur.type) return false;
    if (bg.type == AppBackgroundType.color) return bg.color == cur.color;
    if (bg.type == AppBackgroundType.gradient) {
      final a = bg.gradientColors!;
      final b = cur.gradientColors;
      return b != null && a[0] == b[0] && a[1] == b[1];
    }
    return false;
  }

  Future<void> _onPresetTap(BackgroundPreset preset) async {
    // If current background is a custom image, confirm before replacing
    final cur = widget.current;
    if (cur.type == AppBackgroundType.image && cur.imagePath != null) {
      final confirmed = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Replace background?'),
              content: const Text(
                'This will remove your custom photo and use a preset instead.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Replace'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirmed) return;
    }
    await ref.read(backgroundProvider.notifier).setPreset(preset);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final hasCustomBg = widget.current.type == AppBackgroundType.image &&
        widget.current.imagePath != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: kBackgroundPresets.map((preset) {
            final isSelected = _isActive(preset);
            final bg = preset.background;
            Widget swatch;
            if (bg.type == AppBackgroundType.gradient) {
              swatch = Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: bg.gradientColors!,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? colors.primary : Colors.transparent,
                    width: 3,
                  ),
                ),
              );
            } else {
              swatch = Container(
                decoration: BoxDecoration(
                  color: bg.color,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected
                        ? colors.primary
                        : colors.outlineVariant,
                    width: isSelected ? 3 : 1,
                  ),
                ),
              );
            }
            return GestureDetector(
              onTap: () => _onPresetTap(preset),
              child: SizedBox(
                width: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 60,
                      height: 44,
                      child: swatch,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      preset.name,
                      style: TextStyle(
                        fontSize: 9,
                        color: isSelected ? colors.primary : colors.outline,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: widget.onPickCustom,
          icon: const Icon(Icons.photo_library_outlined, size: 18),
          label: Text(
            hasCustomBg
                ? 'Photo: ${widget.current.imagePath!.split('/').last}'
                : 'Custom photo from gallery',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─── Theme picker ─────────────────────────────────────────────────────────────
class _ThemePicker extends ConsumerWidget {
  final HushTheme current;
  const _ThemePicker({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: kHushThemes.map((theme) {
        final isSelected = theme.id == current.id;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => ref.read(themeProvider.notifier).setTheme(theme),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 88,
                decoration: BoxDecoration(
                  color: theme.background,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? theme.primary : Colors.transparent,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Primary color dot
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: theme.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Accent color dot
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: theme.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      theme.name,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: theme.textPrimary.withValues(alpha: 0.8),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (isSelected) ...[
                      const SizedBox(height: 3),
                      Container(
                        width: 16,
                        height: 3,
                        decoration: BoxDecoration(
                          color: theme.primary,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
