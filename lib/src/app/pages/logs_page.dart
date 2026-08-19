import 'package:flutter/material.dart';

import '../../domain/entities/app_log.dart';
import '../../domain/enums/log_level.dart';
import '../controllers/log_controller.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key, required this.controller});

  final LogController controller;

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  late Future<List<AppLog>> _logs;
  LogLevel? _minLevel;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _logs = widget.controller.loadLogs(minLevel: _minLevel, limit: 200);
  }

  Future<void> _export() async {
    final json = await widget.controller.exportLogs();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('导出日志'),
        content: SingleChildScrollView(
          child: SelectableText(json),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _clear() async {
    await widget.controller.clearLogs();
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('日志已清空')));
  }

  @override
  Widget build(BuildContext context) {
    final levels = <LogLevel?>[null, ...LogLevel.values];
    return Scaffold(
      appBar: AppBar(
        title: const Text('日志'),
        actions: [
          IconButton(
            onPressed: _export,
            icon: const Icon(Icons.file_download_outlined),
            tooltip: '导出日志',
          ),
          IconButton(
            onPressed: _clear,
            icon: const Icon(Icons.delete_outline),
            tooltip: '清空日志',
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, index) {
                final level = levels[index];
                final selected = level == _minLevel;
                final label = level == null ? '全部' : level.storageKey;
                return ChoiceChip(
                  label: Text(label),
                  selected: selected,
                  onSelected: (_) {
                    setState(() {
                      _minLevel = level;
                      _reload();
                    });
                  },
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemCount: levels.length,
            ),
          ),
          Expanded(
            child: FutureBuilder<List<AppLog>>(
              future: _logs,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final logs = snapshot.data!;
                if (logs.isEmpty) {
                  return const Center(child: Text('还没有日志'));
                }
                return RefreshIndicator(
                  onRefresh: () async => setState(_reload),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                    itemCount: logs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final log = logs[index];
                      return Card(
                        child: ListTile(
                          leading: Icon(_iconFor(log.level)),
                          title: Text(log.message),
                          subtitle: Text(
                            '${log.level.storageKey} · ${log.createdAt.toLocal()}',
                          ),
                          isThreeLine: log.context.isNotEmpty,
                          trailing: log.context.isEmpty
                              ? null
                              : const Icon(Icons.chevron_right),
                          onTap: log.context.isEmpty
                              ? null
                              : () => showDialog<void>(
                                    context: context,
                                    builder: (_) => AlertDialog(
                                      title: const Text('日志上下文'),
                                      content: SingleChildScrollView(
                                        child: SelectableText(
                                          log.context.entries
                                              .map(
                                                (entry) =>
                                                    '${entry.key}: ${entry.value}',
                                              )
                                              .join('\n'),
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.of(context).pop(),
                                          child: const Text('关闭'),
                                        ),
                                      ],
                                    ),
                                  ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(LogLevel level) {
    return switch (level) {
      LogLevel.debug => Icons.bug_report_outlined,
      LogLevel.info => Icons.info_outline,
      LogLevel.warning => Icons.warning_amber_outlined,
      LogLevel.error => Icons.error_outline,
    };
  }
}
