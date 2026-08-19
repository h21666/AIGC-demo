import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app/controllers/asset_controller.dart';
import '../app/controllers/log_controller.dart';
import '../app/controllers/prompt_controller.dart';
import '../app/controllers/settings_controller.dart';
import '../app/controllers/task_controller.dart';
import '../app/pages/logs_page.dart';
import '../domain/entities/generated_asset_preview.dart';
import '../domain/entities/generation_task.dart';
import '../domain/entities/prompt.dart';
import '../domain/entities/prompt_version.dart';
import '../domain/enums/generation_task_status.dart';
import 'app_runtime.dart';

class AigcStudioApp extends StatelessWidget {
  const AigcStudioApp({super.key, this.runtime});

  final AppRuntime? runtime;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIGC Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: runtime == null
          ? const _RuntimeUnavailablePage()
          : _AppShell(runtime: runtime!),
    );
  }
}

class _RuntimeUnavailablePage extends StatelessWidget {
  const _RuntimeUnavailablePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AIGC Studio')),
      body: const Center(child: Text('Project skeleton ready')),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell({required this.runtime});

  final AppRuntime runtime;

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  var _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomePage(runtime: widget.runtime),
      _PromptsPage(runtime: widget.runtime),
      _TasksPage(runtime: widget.runtime),
      _AssetsPage(runtime: widget.runtime),
      _SettingsPage(runtime: widget.runtime),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: '工作台',
          ),
          NavigationDestination(
            icon: Icon(Icons.edit_note_outlined),
            selectedIcon: Icon(Icons.edit_note),
            label: '提示词',
          ),
          NavigationDestination(
            icon: Icon(Icons.queue_play_next_outlined),
            selectedIcon: Icon(Icons.queue_play_next),
            label: '任务',
          ),
          NavigationDestination(
            icon: Icon(Icons.photo_library_outlined),
            selectedIcon: Icon(Icons.photo_library),
            label: '素材',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: '设置',
          ),
        ],
      ),
    );
  }
}

class _HomePage extends StatefulWidget {
  const _HomePage({required this.runtime});

  final AppRuntime runtime;

  @override
  State<_HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<_HomePage> {
  late Future<_HomeSummary> _summary;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _reload();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(_reload);
    });
  }

  void _reload() {
    _summary = _loadSummary();
  }

  Future<_HomeSummary> _loadSummary() async {
    final prompts = await widget.runtime.prompts.list();
    final tasks = await widget.runtime.tasks.listTasks(limit: 20);
    final assets = await widget.runtime.assets.list(limit: 20);
    return _HomeSummary(
      promptCount: prompts.length,
      activeTaskCount: tasks.where((task) => !task.isTerminal).length,
      assetCount: assets.length,
      recentTask: tasks.isEmpty ? null : tasks.first,
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AIGC Studio')),
      body: FutureBuilder<_HomeSummary>(
        future: _summary,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final summary = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  '创作者工作台',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '从提示词开始，创建任务并管理生成素材。',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _SummaryCard(
                      label: '提示词',
                      value: '${summary.promptCount}',
                      icon: Icons.edit_note,
                    ),
                    _SummaryCard(
                      label: '进行中任务',
                      value: '${summary.activeTaskCount}',
                      icon: Icons.sync,
                    ),
                    _SummaryCard(
                      label: '素材',
                      value: '${summary.assetCount}',
                      icon: Icons.photo,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.play_circle_outline),
                    title: const Text('开始第一条生成流程'),
                    subtitle: const Text('进入提示词页面，创建 Prompt 后启动任务'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => _PromptsPage(runtime: widget.runtime),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (summary.recentTask != null)
                  Card(
                    child: ListTile(
                      leading: Icon(_taskIcon(summary.recentTask!.status)),
                      title: const Text('最近任务'),
                      subtitle: Text(
                        '${_taskStatusLabel(summary.recentTask!.status)} · '
                        '${summary.recentTask!.completedJobs}/${summary.recentTask!.totalJobs}',
                      ),
                    ),
                  ),
                if (summary.recentTask == null)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('还没有任务。创建一个提示词后即可开始。'),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PromptsPage extends StatefulWidget {
  const _PromptsPage({required this.runtime});

  final AppRuntime runtime;

  @override
  State<_PromptsPage> createState() => _PromptsPageState();
}

class _PromptsPageState extends State<_PromptsPage> {
  late Future<List<Prompt>> _prompts;
  late final PromptController _controller;
  var _includeArchived = false;

  @override
  void initState() {
    super.initState();
    _controller = PromptController(widget.runtime);
    _reload();
  }

  void _reload() {
    _prompts = _controller.loadPrompts(includeArchived: _includeArchived);
  }

  Future<void> _editPrompt([Prompt? existing]) async {
    final result = await showDialog<PromptDraft>(
      context: context,
      builder: (_) => _PromptEditorDialog(existing: existing),
    );
    if (result == null) return;
    await _controller.savePrompt(existing: existing, draft: result);
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(existing == null ? '提示词已创建' : '提示词已保存')),
    );
  }

  Future<void> _deletePrompt(Prompt prompt) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除提示词'),
        content: Text('确定删除「${prompt.title}」吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _controller.deletePrompt(prompt);
    if (mounted) setState(_reload);
  }

  Future<void> _archivePrompt(Prompt prompt) async {
    await _controller.archivePrompt(prompt);
    if (!mounted) return;
    setState(_reload);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('提示词已归档')));
  }

  Future<void> _createTask(Prompt prompt) async {
    final count = await showDialog<int>(
      context: context,
      builder: (_) => const _TaskCountDialog(),
    );
    if (count == null) return;
    try {
      await _controller.createTaskFromPrompt(prompt: prompt, count: count);
      await widget.runtime.runQueueOnce();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('任务已创建，可在任务页面查看进度')));
    } on Object catch (error) {
      _showError(error.toString());
      return;
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _exportPrompts() async {
    final json = await _controller.exportPrompts();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('导出提示词 JSON'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(child: SelectableText(json)),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: json));
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text('已复制到剪贴板')));
            },
            child: const Text('复制'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  Future<void> _importPrompts() async {
    final json = await showDialog<String>(
      context: context,
      builder: (_) => const _JsonInputDialog(
        title: '导入提示词 JSON',
        hintText: '粘贴导出的提示词 JSON',
      ),
    );
    if (json == null || json.trim().isEmpty) return;
    try {
      final result = await _controller.importPrompts(json);
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '导入 ${result.importedCount} 条，跳过 ${result.skippedCount} 条，失败 ${result.failedCount} 条',
          ),
        ),
      );
    } on Object catch (error) {
      _showError(error.toString());
    }
  }

  Future<void> _showVersions(Prompt prompt) async {
    final List<PromptVersion> versions = await _controller.loadVersions(
      prompt.id,
    );
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${prompt.title} 的历史版本'),
        content: SizedBox(
          width: double.maxFinite,
          height: 420,
          child: versions.isEmpty
              ? const Center(child: Text('暂无历史版本'))
              : ListView.separated(
                  itemCount: versions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final version = versions[index];
                    return Card(
                      child: ListTile(
                        title: Text('V${version.versionNumber}'),
                        subtitle: Text(
                          '${version.changeNote ?? '自动保存'}\n'
                          '${version.createdAt.toLocal()}',
                        ),
                        isThreeLine: true,
                        trailing: TextButton(
                          onPressed: () async {
                            Navigator.of(dialogContext).pop();
                            try {
                              await _controller.rollbackToVersion(
                                promptId: prompt.id,
                                versionId: version.id,
                              );
                              if (!mounted) return;
                              setState(_reload);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    '已回退到 V${version.versionNumber}',
                                  ),
                                ),
                              );
                            } on Object catch (error) {
                              _showError(error.toString());
                            }
                          },
                          child: const Text('回退'),
                        ),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('关闭'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actionLabel = _includeArchived ? '隐藏归档' : '显示归档';
    return Scaffold(
      appBar: AppBar(
        title: const Text('提示词'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              switch (value) {
                case 'export':
                  _exportPrompts();
                  break;
                case 'import':
                  _importPrompts();
                  break;
                case 'toggle_archived':
                  setState(() {
                    _includeArchived = !_includeArchived;
                    _reload();
                  });
                  break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'export', child: Text('导出 JSON')),
              const PopupMenuItem(value: 'import', child: Text('导入 JSON')),
              PopupMenuItem(value: 'toggle_archived', child: Text(actionLabel)),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _editPrompt,
        icon: const Icon(Icons.add),
        label: const Text('新建'),
      ),
      body: FutureBuilder<List<Prompt>>(
        future: _prompts,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final prompts = snapshot.data!;
          if (prompts.isEmpty) {
            return Center(
              child: Text(_includeArchived ? '归档提示词为空' : '还没有提示词，点击右下角新建'),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
              itemCount: prompts.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final prompt = prompts[index];
                return Card(
                  child: ListTile(
                    title: Text(prompt.title),
                    subtitle: Text(
                      '${prompt.content}\n'
                      '${prompt.tags.isEmpty ? '无标签' : prompt.tags.join(' · ')}\n'
                      '版本 ${prompt.currentVersionId == null ? '—' : '已保存'}',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    onTap: () => _editPrompt(prompt),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) {
                        if (value == 'generate') _createTask(prompt);
                        if (value == 'versions') _showVersions(prompt);
                        if (value == 'archive') _archivePrompt(prompt);
                        if (value == 'delete') _deletePrompt(prompt);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'generate', child: Text('创建生成任务')),
                        PopupMenuItem(value: 'versions', child: Text('历史版本')),
                        PopupMenuItem(value: 'archive', child: Text('归档')),
                        PopupMenuItem(value: 'delete', child: Text('删除')),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _TasksPage extends StatefulWidget {
  const _TasksPage({required this.runtime});

  final AppRuntime runtime;

  @override
  State<_TasksPage> createState() => _TasksPageState();
}

class _TasksPageState extends State<_TasksPage> {
  late final TaskController _controller;
  late Future<List<GenerationTask>> _tasks;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = TaskController(widget.runtime);
    _reload();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (mounted) setState(_reload);
    });
  }

  void _reload() {
    _tasks = _controller.loadTasks(limit: 50);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _action(
    GenerationTask task,
    Future<void> Function(GenerationTask task) action,
  ) async {
    await action(task);
    if (mounted) setState(_reload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('任务队列')),
      body: FutureBuilder<List<GenerationTask>>(
        future: _tasks,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final tasks = snapshot.data!;
          if (tasks.isEmpty) {
            return const Center(child: Text('还没有生成任务'));
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, index) {
                final task = tasks[index];
                final progress = task.progress.clamp(0.0, 1.0).toDouble();
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(_taskIcon(task.status)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                (task.promptSnapshot['title'] as String?) ??
                                    '生成任务',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Text(_taskStatusLabel(task.status)),
                          ],
                        ),
                        const SizedBox(height: 10),
                        LinearProgressIndicator(value: progress),
                        const SizedBox(height: 6),
                        Text(
                          '${(progress * 100).round()}% · '
                          '成功 ${task.completedJobs} · 失败 ${task.failedJobs} · '
                          '共 ${task.totalJobs}',
                        ),
                        if (task.errorMessage != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            task.errorMessage!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: [
                            if (task.status == GenerationTaskStatus.running ||
                                task.status == GenerationTaskStatus.pending)
                              TextButton(
                                onPressed: () =>
                                    _action(task, _controller.pauseTask),
                                child: const Text('暂停'),
                              ),
                            if (task.status == GenerationTaskStatus.paused)
                              TextButton(
                                onPressed: () =>
                                    _action(task, _controller.resumeTask),
                                child: const Text('恢复'),
                              ),
                            if (!task.isTerminal)
                              TextButton(
                                onPressed: () =>
                                    _action(task, _controller.cancelTask),
                                child: const Text('取消'),
                              ),
                            if (task.status == GenerationTaskStatus.failed ||
                                (task.status ==
                                        GenerationTaskStatus.completed &&
                                    task.failedJobs > 0))
                              TextButton(
                                onPressed: () =>
                                    _action(task, _controller.retryTask),
                                child: const Text('重试失败项'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _AssetsPage extends StatefulWidget {
  const _AssetsPage({required this.runtime});

  final AppRuntime runtime;

  @override
  State<_AssetsPage> createState() => _AssetsPageState();
}

class _AssetsPageState extends State<_AssetsPage> {
  late final AssetController _controller;
  late Future<List<GeneratedAssetPreview>> _assets;
  final _selectedIds = <String>{};

  @override
  void initState() {
    super.initState();
    _controller = AssetController(widget.runtime);
    _reload();
  }

  void _reload() {
    _assets = _controller.loadAssets(limit: 100);
  }

  Future<void> _exportSelected() async {
    final result = await _controller.exportSelected(_selectedIds);
    if (!mounted) return;
    setState(() {
      _selectedIds.clear();
      _reload();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '导出 ${result.exportedCount} 张，跳过 ${result.skippedCount} 张，'
          '失败 ${result.failedCount} 张',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('素材库'),
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(
              onPressed: _exportSelected,
              icon: const Icon(Icons.file_download_outlined),
              tooltip: '导出选中素材',
            ),
        ],
      ),
      body: FutureBuilder<List<GeneratedAssetPreview>>(
        future: _assets,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final assets = snapshot.data!;
          if (assets.isEmpty) {
            return const Center(child: Text('生成成功的图片会显示在这里'));
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_reload),
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemCount: assets.length,
              itemBuilder: (context, index) {
                final asset = assets[index];
                final selected = _selectedIds.contains(asset.id);
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      setState(() {
                        if (selected) {
                          _selectedIds.remove(asset.id);
                        } else {
                          _selectedIds.add(asset.id);
                        }
                      });
                    },
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(asset.displayPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(Icons.broken_image_outlined, size: 42),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Checkbox(
                            value: selected,
                            onChanged: (value) {
                              setState(() {
                                if (value == true) {
                                  _selectedIds.add(asset.id);
                                } else {
                                  _selectedIds.remove(asset.id);
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _SettingsPage extends StatefulWidget {
  const _SettingsPage({required this.runtime});

  final AppRuntime runtime;

  @override
  State<_SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<_SettingsPage> {
  final _apiKeyController = TextEditingController();
  var _hasApiKey = false;
  late final LogController _logController;
  late final SettingsController _settingsController;

  @override
  void initState() {
    super.initState();
    _logController = LogController(widget.runtime);
    _settingsController = SettingsController(widget.runtime);
    _loadApiKey();
  }

  Future<void> _loadApiKey() async {
    final key = await _settingsController.loadApiKey();
    if (!mounted) return;
    setState(() {
      _hasApiKey = key != null && key.isNotEmpty;
      _apiKeyController.text = key ?? '';
    });
  }

  Future<void> _saveApiKey() async {
    final key = _apiKeyController.text.trim();
    final hasApiKey = await _settingsController.saveApiKey(key);
    if (!mounted) return;
    setState(() => _hasApiKey = hasApiKey);
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('API Key 已保存')));
  }

  Future<void> _clearCache() async {
    await _settingsController.clearCache();
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('缓存已清理')));
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('SiliconFlow', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _apiKeyController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'API Key',
              hintText: '输入 SiliconFlow API Key',
              suffixIcon: Icon(
                _hasApiKey ? Icons.check_circle : Icons.warning_amber,
                color: _hasApiKey ? Colors.green : Colors.orange,
              ),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saveApiKey,
            icon: const Icon(Icons.save_outlined),
            label: const Text('保存 API Key'),
          ),
          OutlinedButton(
            onPressed: () async {
              await _settingsController.clearApiKey();
              _apiKeyController.clear();
              if (mounted) setState(() => _hasApiKey = false);
            },
            child: const Text('清除 API Key'),
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: const Text('清理缓存'),
            subtitle: const Text('删除缩略图和本地缓存文件'),
            onTap: _clearCache,
          ),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined),
            title: const Text('查看日志'),
            subtitle: const Text('查看本地运行记录、导出或清空'),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => LogsPage(controller: _logController),
                ),
              );
            },
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('关于 AIGC Studio'),
            subtitle: Text('MVP 创作者工作台'),
          ),
        ],
      ),
    );
  }
}

class _PromptEditorDialog extends StatefulWidget {
  const _PromptEditorDialog({this.existing});

  final Prompt? existing;

  @override
  State<_PromptEditorDialog> createState() => _PromptEditorDialogState();
}

class _PromptEditorDialogState extends State<_PromptEditorDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _negativeController;
  late final TextEditingController _tagsController;

  @override
  void initState() {
    super.initState();
    final prompt = widget.existing;
    _titleController = TextEditingController(text: prompt?.title ?? '');
    _contentController = TextEditingController(text: prompt?.content ?? '');
    _negativeController = TextEditingController(
      text: prompt?.negativePrompt ?? '',
    );
    _tagsController = TextEditingController(
      text: prompt?.tags.join(', ') ?? '',
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _negativeController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) return;
    Navigator.of(context).pop(
      PromptDraft(
        title: title,
        content: content,
        negativePrompt: _negativeController.text.trim().isEmpty
            ? null
            : _negativeController.text.trim(),
        tags: _tagsController.text
            .split(',')
            .map((tag) => tag.trim())
            .where((tag) => tag.isNotEmpty)
            .toSet()
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? '新建提示词' : '编辑提示词'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: '标题'),
            ),
            TextField(
              controller: _contentController,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: '提示词内容'),
            ),
            TextField(
              controller: _negativeController,
              decoration: const InputDecoration(labelText: '反向提示词（可选）'),
            ),
            TextField(
              controller: _tagsController,
              decoration: const InputDecoration(
                labelText: '标签',
                hintText: '例如：赛博朋克, 夜景',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(onPressed: _submit, child: const Text('保存')),
      ],
    );
  }
}

class _TaskCountDialog extends StatelessWidget {
  const _TaskCountDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('创建生成任务'),
      content: const Text('请选择要生成的图片数量'),
      actions: [
        for (final count in [1, 2, 4])
          TextButton(
            onPressed: () => Navigator.of(context).pop(count),
            child: Text('$count 张'),
          ),
      ],
    );
  }
}

class _JsonInputDialog extends StatefulWidget {
  const _JsonInputDialog({required this.title, required this.hintText});

  final String title;
  final String hintText;

  @override
  State<_JsonInputDialog> createState() => _JsonInputDialogState();
}

class _JsonInputDialogState extends State<_JsonInputDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        minLines: 8,
        maxLines: 14,
        decoration: InputDecoration(
          hintText: widget.hintText,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('导入'),
        ),
      ],
    );
  }
}

class _HomeSummary {
  const _HomeSummary({
    required this.promptCount,
    required this.activeTaskCount,
    required this.assetCount,
    required this.recentTask,
  });

  final int promptCount;
  final int activeTaskCount;
  final int assetCount;
  final GenerationTask? recentTask;
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Column(
            children: [
              Icon(icon),
              const SizedBox(height: 8),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}

IconData _taskIcon(GenerationTaskStatus status) => switch (status) {
  GenerationTaskStatus.pending => Icons.schedule,
  GenerationTaskStatus.running => Icons.sync,
  GenerationTaskStatus.paused => Icons.pause_circle_outline,
  GenerationTaskStatus.failed => Icons.error_outline,
  GenerationTaskStatus.completed => Icons.check_circle_outline,
  GenerationTaskStatus.cancelled => Icons.cancel_outlined,
};

String _taskStatusLabel(GenerationTaskStatus status) => switch (status) {
  GenerationTaskStatus.pending => '等待中',
  GenerationTaskStatus.running => '生成中',
  GenerationTaskStatus.paused => '已暂停',
  GenerationTaskStatus.failed => '失败',
  GenerationTaskStatus.completed => '已完成',
  GenerationTaskStatus.cancelled => '已取消',
};
