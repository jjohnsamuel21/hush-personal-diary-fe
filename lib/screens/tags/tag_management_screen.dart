import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/tag.dart';
import '../../providers/tag_provider.dart';

// Accessible from Settings — lets users create and delete tags.
class TagManagementScreen extends ConsumerStatefulWidget {
  const TagManagementScreen({super.key});

  @override
  ConsumerState<TagManagementScreen> createState() =>
      _TagManagementScreenState();
}

class _TagManagementScreenState extends ConsumerState<TagManagementScreen> {
  final _nameController = TextEditingController();
  String _selectedColor = '#5C6BC0';

  static const _colors = [
    '#5C6BC0', '#26C6DA', '#66BB6A', '#FFA726',
    '#EF5350', '#AB47BC', '#8D6E63', '#78909C',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsAsync = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tags')),
      body: Column(
        children: [
          // ── New tag input ─────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'New tag name',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _create(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _create, child: const Text('Add')),
              ],
            ),
          ),
          // Colour picker for new tag
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              children: _colors.map((hex) {
                final color = Color(int.parse(hex.replaceFirst('#', '0xFF')));
                return GestureDetector(
                  onTap: () => setState(() => _selectedColor = hex),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: _selectedColor == hex
                          ? Border.all(
                              color:
                                  Theme.of(context).colorScheme.primary,
                              width: 3)
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const Divider(height: 24),

          // ── Existing tags ─────────────────────────────────────────────────
          Expanded(
            child: tagsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (tags) {
                if (tags.isEmpty) {
                  return Center(
                    child: Text(
                      'No tags yet — create one above',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline),
                    ),
                  );
                }
                return ListView.builder(
                  itemCount: tags.length,
                  itemBuilder: (_, i) => _TagTile(tag: tags[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    _nameController.clear();
    await ref
        .read(tagsNotifierProvider.notifier)
        .createTag(name: name, color: _selectedColor);
  }
}

class _TagTile extends ConsumerWidget {
  final Tag tag;
  const _TagTile({required this.tag});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = Color(int.parse(tag.color.replaceFirst('#', '0xFF')));
    return ListTile(
      leading: CircleAvatar(backgroundColor: color, radius: 10),
      title: Text(tag.name),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        color: Colors.red,
        onPressed: () =>
            ref.read(tagsNotifierProvider.notifier).deleteTag(tag.id!),
      ),
    );
  }
}
