import 'package:flutter/material.dart';
import 'package:flutter_heatmap_calendar/flutter_heatmap_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/auth/app_lock_notifier.dart';
import '../../core/constants/font_constants.dart';
import '../../core/constants/theme_constants.dart';
import '../../providers/background_provider.dart';
import '../../providers/font_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/typography_provider.dart';
import '../../services/export_service.dart';
import '../../services/import_service.dart';
import '../../services/note_service.dart';
import '../../services/reminder_service.dart';
import '../../services/security_service.dart';

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
    if (mounted) {
      setState(() {
        _reminderEnabled = enabled;
        _reminderTime = time;
      });
    }
  }

  Future<void> _loadSecuritySettings() async {
    final allowed = await SecurityService.isScreenshotAllowed();
    if (mounted) setState(() => _screenshotAllowed = allowed);
  }

  Future<void> _loadHeatmap() async {
    final data = await NoteService.getNotesPerDay();
    if (mounted) {
      setState(() {
        _heatmapData = data;
        _heatmapLoading = false;
      });
    }
  }

  Future<void> _exportZip() async {
    final masterKey = ref.read(masterKeyProvider);
    if (masterKey == null) return;
    setState(() => _exporting = true);
    try {
      await ExportService.exportEncryptedZip(masterKey);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _importFile() async {
    final masterKey = ref.read(masterKeyProvider);
    if (masterKey == null) return;
    setState(() => _importing = true);
    try {
      final id = await ImportService.importFile(
        folderId: 1,
        masterKey: masterKey,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              id != null ? 'Entry imported successfully' : 'No file selected',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  Future<void> _pickBackgroundImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    await ref.read(backgroundProvider.notifier).setImage(picked.path);
  }

  @override
  Widget build(BuildContext context) {
    final hushTheme = ref.watch(themeProvider);
    final currentFont = ref.watch(fontProvider);
    final bg = ref.watch(backgroundProvider);
    final typo = ref.watch(typographyProvider);
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Theme Picker ──────────────────────────────────────────────────
          _SectionHeader(label: 'App Theme'),
          const SizedBox(height: 12),
          _ThemePicker(current: hushTheme),
          const SizedBox(height: 32),

          // ── Background ────────────────────────────────────────────────────
          _SectionHeader(label: 'Background'),
          const SizedBox(height: 12),
          _BackgroundPresetGrid(current: bg),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Custom image from gallery'),
            subtitle: bg.type == AppBackgroundType.image && bg.imagePath != null
                ? Text(
                    bg.imagePath!.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.primary, fontSize: 12),
                  )
                : const Text('Pick a photo as your diary background'),
            onTap: _pickBackgroundImage,
          ),
          const SizedBox(height: 32),

          // ── Typography ────────────────────────────────────────────────────
          _SectionHeader(label: 'Typography'),
          const SizedBox(height: 12),

          // Font family
          Text('Font Family',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: kAppFonts.map((family) {
              final selected = family == typo.fontFamily;
              return ChoiceChip(
                label: Text(family,
                    style: TextStyle(
                      fontFamily: family,
                      fontSize: 13,
                    )),
                selected: selected,
                onSelected: (_) =>
                    ref.read(typographyProvider.notifier).setFontFamily(family),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Font scale
          Text('Text Size',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
          const SizedBox(height: 6),
          Row(
            children: kFontScales.entries.map((entry) {
              final selected = entry.value == typo.fontScale;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor:
                          selected ? colors.primary : Colors.transparent,
                      foregroundColor:
                          selected ? colors.onPrimary : colors.onSurface,
                      side: BorderSide(
                        color: selected ? colors.primary : colors.outlineVariant,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => ref
                        .read(typographyProvider.notifier)
                        .setFontScale(entry.value),
                    child: Text(entry.key,
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // Text color
          Text('Text Color',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              // Theme default chip
              GestureDetector(
                onTap: () =>
                    ref.read(typographyProvider.notifier).resetTextColor(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF757575), Color(0xFFBDBDBD)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: !typo.useCustomColor
                          ? colors.primary
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: !typo.useCustomColor
                      ? Icon(Icons.check, size: 16, color: colors.primary)
                      : null,
                ),
              ),
              ...kTextColorPresets.entries.map((entry) {
                final selected =
                    typo.useCustomColor && typo.textColor == entry.value;
                return GestureDetector(
                  onTap: () => ref
                      .read(typographyProvider.notifier)
                      .setTextColor(entry.value),
                  child: Tooltip(
                    message: entry.key,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: entry.value,
                        border: Border.all(
                          color: selected
                              ? colors.primary
                              : colors.outlineVariant,
                          width: selected ? 3 : 1,
                        ),
                      ),
                      child: selected
                          ? Icon(
                              Icons.check,
                              size: 16,
                              color: entry.value.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 32),

          // ── Global Font ───────────────────────────────────────────────────
          _SectionHeader(label: 'Default Entry Font'),
          const SizedBox(height: 8),
          ...NoteFont.values.map((font) {
            final isSelected = font == currentFont;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: isSelected
                  ? Icon(Icons.check_circle_rounded, color: colors.primary)
                  : Icon(Icons.circle_outlined, color: colors.outlineVariant),
              title: Text(font.label, style: noteFontStyle(font, fontSize: 15)),
              subtitle: Text(
                font.description,
                style: TextStyle(fontSize: 12, color: colors.outline),
              ),
              onTap: () => ref.read(fontProvider.notifier).setFont(font),
            );
          }),
          const SizedBox(height: 32),

          // ── Export ────────────────────────────────────────────────────────
          _SectionHeader(label: 'Export'),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: const Text('Export all entries as PDF'),
            subtitle: const Text('One page per entry, shared via share sheet'),
            trailing: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _exporting ? null : _exportPdf,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.lock_outline),
            title: const Text('Backup (encrypted ZIP)'),
            subtitle: const Text('All entries packed & AES-256-GCM encrypted'),
            trailing: _exporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _exporting ? null : _exportZip,
          ),
          const SizedBox(height: 32),

          // ── Import ────────────────────────────────────────────────────────
          _SectionHeader(label: 'Import'),
          const SizedBox(height: 8),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.upload_file_outlined),
            title: const Text('Import from Markdown / text file'),
            subtitle:
                const Text('Picks a .md or .txt file and creates a new entry'),
            trailing: _importing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : null,
            onTap: _importing ? null : _importFile,
          ),
          const SizedBox(height: 32),

          // ── Writing Streak ────────────────────────────────────────────────
          _SectionHeader(label: 'Writing Streak'),
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
          const SizedBox(height: 32),

          // ── Writing Reminders ─────────────────────────────────────────────
          _SectionHeader(label: 'Daily Writing Reminder'),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Enable daily reminder'),
            subtitle: Text(
              _reminderEnabled
                  ? 'Reminder set for ${_reminderTime.format(context)}'
                  : 'Tap to schedule a daily writing prompt',
            ),
            value: _reminderEnabled,
            onChanged: _toggleReminder,
          ),
          if (_reminderEnabled) ...[
            ListTile(
              leading: const Icon(Icons.access_time_outlined),
              title: const Text('Reminder time'),
              trailing: Text(
                _reminderTime.format(context),
                style: TextStyle(color: colors.primary),
              ),
              onTap: _pickReminderTime,
            ),
          ],
          const SizedBox(height: 32),

          // ── Security ──────────────────────────────────────────────────────
          _SectionHeader(label: 'Security'),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(Icons.screenshot_outlined),
            title: const Text('Allow screenshots'),
            subtitle: const Text(
              'Off by default — prevents screenshots and hides app content '
              'in the recents switcher.',
            ),
            isThreeLine: true,
            value: _screenshotAllowed,
            onChanged: (value) async {
              await SecurityService.setScreenshotAllowed(value);
              if (mounted) setState(() => _screenshotAllowed = value);
            },
          ),
          const SizedBox(height: 32),

          // ── About ─────────────────────────────────────────────────────────
          _SectionHeader(label: 'About'),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Privacy'),
            subtitle: const Text(
              'All entries are encrypted on-device with AES-256-GCM. '
              'Nothing leaves your phone.',
            ),
            isThreeLine: true,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Hush'),
            subtitle: const Text('Version 1.0.0 · Your private diary'),
          ),
        ],
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
    final picked = await showTimePicker(
      context: context,
      initialTime: _reminderTime,
    );
    if (picked == null) return;
    setState(() => _reminderTime = picked);
    await ReminderService.scheduleDaily(picked);
  }
}

// ─── Background preset grid ───────────────────────────────────────────────────
class _BackgroundPresetGrid extends ConsumerWidget {
  final AppBackground current;
  const _BackgroundPresetGrid({required this.current});

  bool _isActive(AppBackground current, BackgroundPreset preset) {
    final bg = preset.background;
    if (bg.type != current.type) return false;
    if (bg.type == AppBackgroundType.color) {
      return bg.color == current.color;
    }
    if (bg.type == AppBackgroundType.gradient) {
      final a = bg.gradientColors!;
      final b = current.gradientColors;
      return b != null && a[0] == b[0] && a[1] == b[1];
    }
    return false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kBackgroundPresets.map((preset) {
        final isSelected = _isActive(current, preset);
        final bg = preset.background;

        Widget inner;
        if (bg.type == AppBackgroundType.gradient) {
          inner = Container(
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
          inner = Container(
            decoration: BoxDecoration(
              color: bg.color,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? colors.primary : colors.outlineVariant,
                width: isSelected ? 3 : 1,
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () => ref.read(backgroundProvider.notifier).setPreset(preset),
          child: SizedBox(
            width: 64,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 64,
                  height: 48,
                  child: inner,
                ),
                const SizedBox(height: 4),
                Text(
                  preset.name,
                  style: TextStyle(
                    fontSize: 10,
                    color: isSelected ? colors.primary : colors.outline,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
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
    );
  }
}

// ─── Theme picker grid ────────────────────────────────────────────────────────
class _ThemePicker extends ConsumerWidget {
  final HushTheme current;
  const _ThemePicker({required this.current});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kHushThemes.map((theme) {
        final isSelected = theme.id == current.id;
        return GestureDetector(
          onTap: () => ref.read(themeProvider.notifier).setTheme(theme),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: theme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? theme.primary : Colors.transparent,
                width: 3,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: theme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  theme.name,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: theme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
