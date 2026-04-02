import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/activity_log.dart';
import '../../services/activity_log_service.dart';
import '../../widgets/common/app_background.dart';

class ActivityLogsScreen extends StatefulWidget {
  const ActivityLogsScreen({super.key});

  @override
  State<ActivityLogsScreen> createState() => _ActivityLogsScreenState();
}

class _ActivityLogsScreenState extends State<ActivityLogsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<ActivityLog> _allLogs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _loadLogs();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLogs() async {
    final logs = await ActivityLogService.getLogs();
    if (mounted) setState(() { _allLogs = logs; _loading = false; });
  }

  List<ActivityLog> _filtered(String? type) => type == null
      ? _allLogs
      : _allLogs.where((l) => l.sessionType == type).toList();

  Future<void> _deleteLog(ActivityLog log) async {
    await ActivityLogService.deleteLog(log.id);
    setState(() => _allLogs.removeWhere((l) => l.id == log.id));
  }

  Future<void> _clearLogs(String? type) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear logs?'),
        content: Text(
          type == null
              ? 'This will permanently delete all activity logs.'
              : 'This will delete all ${type == 'local' ? 'local' : 'shared'} activity logs.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    if (type == null) {
      await ActivityLogService.clearAllLogs();
      setState(() => _allLogs.clear());
    } else {
      await ActivityLogService.clearLogsByType(type);
      setState(() => _allLogs.removeWhere((l) => l.sessionType == type));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activity Log'),
        bottom: TabBar(
          controller: _tabCtrl,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Local'),
            Tab(text: 'Shared'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (v) {
              switch (v) {
                case 'clear_all':    _clearLogs(null);
                case 'clear_local':  _clearLogs('local');
                case 'clear_shared': _clearLogs('shared');
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'clear_local',  child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Clear local logs'),  contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'clear_shared', child: ListTile(leading: Icon(Icons.delete_outline), title: Text('Clear shared logs'), contentPadding: EdgeInsets.zero)),
              PopupMenuItem(value: 'clear_all',    child: ListTile(leading: Icon(Icons.delete_forever_outlined), title: Text('Clear all logs'), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: AppBackgroundWrapper(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabCtrl,
                children: [
                  _LogList(logs: _filtered(null),      onDelete: _deleteLog, colors: colors),
                  _LogList(logs: _filtered('local'),   onDelete: _deleteLog, colors: colors),
                  _LogList(logs: _filtered('shared'),  onDelete: _deleteLog, colors: colors),
                ],
              ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Log list
// ─────────────────────────────────────────────────────────────────────────────

class _LogList extends StatelessWidget {
  final List<ActivityLog> logs;
  final void Function(ActivityLog) onDelete;
  final ColorScheme colors;

  const _LogList({
    required this.logs,
    required this.onDelete,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    if (logs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.history_rounded, size: 56, color: colors.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'No activity yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: colors.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              'Actions on your notes will appear here.',
              style: TextStyle(fontSize: 13, color: colors.outline),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: logs.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        indent: 72,
        color: colors.outlineVariant.withValues(alpha: 0.5),
      ),
      itemBuilder: (ctx, i) {
        final log = logs[i];
        return Dismissible(
          key: ValueKey(log.id),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: colors.errorContainer,
            child:
                Icon(Icons.delete_outline, color: colors.onErrorContainer),
          ),
          onDismissed: (_) => onDelete(log),
          child: _LogTile(log: log, colors: colors),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single log tile
// ─────────────────────────────────────────────────────────────────────────────

class _LogTile extends StatelessWidget {
  final ActivityLog log;
  final ColorScheme colors;
  const _LogTile({required this.log, required this.colors});

  static final _dateFmt = DateFormat('MMM d, y · h:mm a');

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundColor: _badgeColor(log).withValues(alpha: 0.15),
        child: Icon(_actionIcon(log.action), size: 18, color: _badgeColor(log)),
      ),
      title: Text(
        log.noteTitle ?? log.noteId ?? 'Unknown note',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _sessionColor(log.sessionType, colors).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  log.sessionType == 'shared' ? 'Shared' : 'Local',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _sessionColor(log.sessionType, colors),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                log.actionLabel,
                style: TextStyle(fontSize: 12, color: colors.onSurface),
              ),
            ],
          ),
          if (log.detail != null && log.detail!.isNotEmpty)
            Text(
              log.detail!,
              style: TextStyle(fontSize: 11, color: colors.outline),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          Text(
            _dateFmt.format(log.createdAt.toLocal()),
            style: TextStyle(fontSize: 11, color: colors.outline),
          ),
        ],
      ),
      isThreeLine: true,
    );
  }

  Color _badgeColor(ActivityLog log) {
    return switch (log.action) {
      'created'         => const Color(0xFF4CAF50),
      'edited'          => const Color(0xFF2196F3),
      'deleted'         => const Color(0xFFF44336),
      'shared'          => const Color(0xFF9C27B0),
      'audio_added'     => const Color(0xFFFF9800),
      'invite_accepted' => const Color(0xFF00BCD4),
      _                 => colors.primary,
    };
  }

  Color _sessionColor(String type, ColorScheme colors) =>
      type == 'shared' ? colors.secondary : colors.primary;

  IconData _actionIcon(String action) => switch (action) {
        'created'         => Icons.add_circle_outline_rounded,
        'edited'          => Icons.edit_outlined,
        'deleted'         => Icons.delete_outline_rounded,
        'shared'          => Icons.share_outlined,
        'audio_added'     => Icons.mic_outlined,
        'invite_accepted' => Icons.check_circle_outline_rounded,
        _                 => Icons.info_outline_rounded,
      };
}
