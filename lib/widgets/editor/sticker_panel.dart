import 'package:flutter/material.dart';

// Sticker panel shown as a bottom sheet from the note editor toolbar.
// Organised into two tabs matching the assets/stickers/ folders:
//   • Emotions — expressive / playful emoji
//   • Minimal  — clean / minimal emoji
//
// Each "sticker" is an emoji rendered at 40 px. Tapping it calls [onSticker]
// with the emoji string so the editor can insert it at the cursor position.
//
// When real PNG sticker assets are added to assets/stickers/emotions/ and
// assets/stickers/minimal/, replace the emoji grids below with Image.asset
// widgets and update [onSticker] to pass the asset path instead.
class StickerPanel extends StatefulWidget {
  final void Function(String sticker) onSticker;

  const StickerPanel({super.key, required this.onSticker});

  @override
  State<StickerPanel> createState() => _StickerPanelState();
}

class _StickerPanelState extends State<StickerPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _emotions = [
    '😊', '😂', '😍', '🥰', '😎', '🤩', '😢', '😭',
    '😡', '🥺', '😴', '🤔', '🙈', '🎉', '🔥', '💯',
    '❤️', '💔', '✨', '🌈', '🦋', '🌸', '☀️', '🌙',
  ];

  static const _minimal = [
    '•', '★', '♥', '✓', '✗', '→', '←', '↑',
    '↓', '◆', '○', '□', '△', '◇', '∞', '~',
    '«', '»', '…', '¿', '!', '?', '+', '=',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 300,
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Emotions'),
              Tab(text: 'Minimal'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGrid(_emotions),
                _buildGrid(_minimal),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<String> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) {
        return GestureDetector(
          onTap: () {
            Navigator.pop(context);
            widget.onSticker(items[i]);
          },
          child: Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(items[i], style: const TextStyle(fontSize: 22)),
            ),
          ),
        );
      },
    );
  }
}
