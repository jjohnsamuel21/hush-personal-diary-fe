import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/folder.dart';

// A tappable card shown in the folder grid on HomeScreen.
// Displays the folder's icon, name, and note count.
// When a cover image is set, renders it as a blurred background with a
// dark gradient overlay so text remains readable.
class FolderCard extends StatelessWidget {
  final Folder folder;
  final int noteCount;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const FolderCard({
    super.key,
    required this.folder,
    required this.noteCount,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final folderColor = _hexColor(folder.color);
    final colors = Theme.of(context).colorScheme;

    final hasCover = folder.coverImagePath != null &&
        File(folder.coverImagePath!).existsSync();

    // When a cover image is present, text and icons render over a dark overlay
    // so we use white for readability.
    final textColor = hasCover ? Colors.white : null;
    final subtitleColor =
        hasCover ? Colors.white70 : colors.outline;
    final iconColor = hasCover ? Colors.white : folderColor;
    final iconBg = hasCover
        ? Colors.black.withValues(alpha: 0.25)
        : folderColor.withValues(alpha: 0.2);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: hasCover ? null : folderColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: folderColor.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (hasCover) ...[
                Image.file(
                  File(folder.coverImagePath!),
                  fit: BoxFit.cover,
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.15),
                        Colors.black.withValues(alpha: 0.55),
                      ],
                    ),
                  ),
                ),
              ],
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Folder icon + lock badge
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: iconBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _iconData(folder.icon),
                            color: iconColor,
                            size: 22,
                          ),
                        ),
                        const Spacer(),
                        if (folder.isLocked)
                          Icon(Icons.lock_outline,
                              size: 14,
                              color: hasCover ? Colors.white70 : colors.outline),
                      ],
                    ),
                    const Spacer(),
                    // Folder name
                    Text(
                      folder.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: textColor,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    // Note count
                    Text(
                      '$noteCount ${noteCount == 1 ? 'entry' : 'entries'}',
                      style: TextStyle(fontSize: 11, color: subtitleColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return const Color(0xFF5C6BC0);
    }
  }

  // Maps a string icon name to a Material icon.
  // The folder model stores icon names as strings for DB portability.
  IconData _iconData(String name) {
    const map = <String, IconData>{
      'book': Icons.menu_book_rounded, 'star': Icons.star_rounded,
      'heart': Icons.favorite_rounded, 'home': Icons.home_rounded,
      'work': Icons.work_rounded, 'school': Icons.school_rounded,
      'baby': Icons.child_care_rounded, 'family': Icons.family_restroom_rounded,
      'friends': Icons.group_rounded, 'couple': Icons.people_rounded,
      'pet': Icons.pets_rounded, 'person': Icons.person_rounded,
      'travel': Icons.flight_rounded, 'food': Icons.restaurant_rounded,
      'fitness': Icons.fitness_center_rounded, 'run': Icons.directions_run_rounded,
      'yoga': Icons.self_improvement_rounded, 'sport': Icons.sports_soccer_rounded,
      'music': Icons.music_note_rounded, 'art': Icons.palette_rounded,
      'camera': Icons.camera_alt_rounded, 'movie': Icons.movie_rounded,
      'game': Icons.videogame_asset_rounded, 'garden': Icons.yard_rounded,
      'nature': Icons.eco_rounded, 'sun': Icons.wb_sunny_rounded,
      'moon': Icons.nightlight_rounded, 'rain': Icons.umbrella_rounded,
      'snow': Icons.ac_unit_rounded, 'flower': Icons.local_florist_rounded,
      'health': Icons.monitor_heart_rounded, 'mindfulness': Icons.spa_rounded,
      'sleep': Icons.bedtime_rounded, 'mood': Icons.mood_rounded,
      'therapy': Icons.psychology_rounded, 'medicine': Icons.medication_rounded,
      'goal': Icons.flag_rounded, 'idea': Icons.lightbulb_rounded,
      'money': Icons.savings_rounded, 'career': Icons.trending_up_rounded,
      'gratitude': Icons.volunteer_activism_rounded,
      'bucket': Icons.format_list_bulleted_rounded,
    };
    return map[name] ?? Icons.folder_rounded;
  }
}
