import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/goal_service.dart';

/// Lets the user plan a big lifetime goal and break it down into yearly,
/// monthly, weekly and daily actionable tasks. Drill into a goal to see its
/// sub-goals; mark daily tasks done as you finish them.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final GoalService _svc = GoalService.instance;

  List<Goal> _roots = [];
  final List<Goal> _stack = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Goal> get _current {
    if (_stack.isEmpty) return _roots;
    final parent = _stack.last;
    return parent.children;
  }

  int get _depth => _stack.length;

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final roots = await _svc.fetchGoals();
      setState(() => _roots = roots);
    } catch (e) {
      setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reloadKeepPath() async {
    try {
      final roots = await _svc.fetchGoals();
      if (!mounted) return;
      // Rebuild the drill-down path against the fresh tree so the current
      // level stays in sync after a create/edit/delete.
      List<Goal> level = roots;
      final newStack = <Goal>[];
      for (final ancestor in _stack) {
        final match = level.where((g) => g.id == ancestor.id).firstOrNull;
        if (match == null) {
          newStack.clear();
          break;
        }
        newStack.add(match);
        level = match.children;
      }
      setState(() {
        _roots = roots;
        _stack
          ..clear()
          ..addAll(newStack);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not refresh goals: $e')),
      );
    }
  }

  GoalLevel get _addableLevel {
    final current = _stack.isNotEmpty ? _stack.last.level : GoalLevel.lifetime;
    return current == GoalLevel.daily ? GoalLevel.lifetime : _levelBelow(current);
  }

  GoalLevel _levelBelow(GoalLevel l) => switch (l) {
        GoalLevel.lifetime => GoalLevel.yearly,
        GoalLevel.yearly => GoalLevel.monthly,
        GoalLevel.monthly => GoalLevel.weekly,
        GoalLevel.weekly => GoalLevel.daily,
        GoalLevel.daily => GoalLevel.lifetime,
      };

  String get _addLabel {
    final level = _addableLevel;
    return switch (level) {
      GoalLevel.lifetime => 'New lifetime goal',
      GoalLevel.yearly => 'Add yearly goal',
      GoalLevel.monthly => 'Add monthly goal',
      GoalLevel.weekly => 'Add weekly goal',
      GoalLevel.daily => 'Add daily task',
    };
  }

  bool get _canAdd => _stack.isEmpty || _stack.last.childLevel != null;

  Future<void> _createCurrentLevel() async {
    final result = await showModalBottomSheet<
        ({String title, String desc, DateTime? dueDate})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GoalEditor(
        heading: _addLabel,
        level: _addableLevel,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await _svc.createGoal(
        title: result.title,
        description: result.desc,
        dueDate: result.dueDate,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create goal: $e')),
      );
      return;
    }
    await _reloadKeepPath();
  }

  Future<void> _createChild(Goal parent) async {
    final result = await showModalBottomSheet<
        ({String title, String desc, DateTime? dueDate})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GoalEditor(heading: 'Add ${parent.childLevel?.name ?? 'task'}'),
    );
    if (result == null || !mounted) return;
    try {
      await _svc.createChildGoal(
        parentId: parent.id,
        title: result.title,
        description: result.desc,
        dueDate: result.dueDate,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not add task: $e')),
      );
      return;
    }
    await _reloadKeepPath();
  }

  Future<void> _editGoal(Goal goal) async {
    final result = await showModalBottomSheet<
        ({String title, String desc, DateTime? dueDate})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _GoalEditor(
        heading: 'Edit ${goal.levelLabel.toLowerCase()}',
        initialTitle: goal.title,
        initialDesc: goal.description,
        initialDue: goal.dueDate,
      ),
    );
    if (result == null || !mounted) return;
    try {
      await _svc.updateGoal(
        id: goal.id,
        title: result.title,
        description: result.desc,
        dueDate: result.dueDate,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update goal: $e')),
      );
      return;
    }
    await _reloadKeepPath();
  }

  Future<void> _toggle(Goal goal) async {
    try {
      await _svc.setCompleted(goal.id, !goal.completed);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not update task: $e')),
      );
      return;
    }
    await _reloadKeepPath();
  }

  Future<void> _delete(Goal goal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this goal?'),
        content: Text(
          '"${goal.title}" will be removed${goal.children.isNotEmpty ? ' along with everything under it' : ''}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _svc.deleteGoal(goal.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete goal: $e')),
      );
      return;
    }
    await _reloadKeepPath();
  }

  void _drillInto(Goal goal) {
    setState(() => _stack.add(goal));
  }

  void _goBack() {
    if (_stack.isEmpty) return;
    setState(() => _stack.removeLast());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_title()),
        leading: _depth > 0
            ? IconButton(
                tooltip: 'Back',
                icon: const Icon(Icons.arrow_back),
                onPressed: _goBack,
              )
            : null,
        toolbarHeight: 48,
      ),
      floatingActionButton: _canAdd
          ? FloatingActionButton.extended(
              onPressed: _createCurrentLevel,
              icon: const Icon(Icons.add),
              label: Text(_addLabel),
            )
          : null,
      body: SafeArea(
        child: _buildBody(theme),
      ),
    );
  }

  String _title() {
    if (_stack.isEmpty) return 'Goals 🎯';
    final parent = _stack.last;
    if (_depth == 1) return parent.title;
    return _stack[0].title;
  }

  Widget _buildBody(ThemeData theme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Could not load your goals.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _load,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    final goals = _current;
    if (goals.isEmpty) {
      return _Empty(
        title: _emptyTitle(),
        message: _emptyMessage(),
        onAdd: _canAdd ? _createCurrentLevel : null,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: goals.length,
      itemBuilder: (context, index) {
        final goal = goals[index];
        return _GoalTile(
          goal: goal,
          onTap: goal.childLevel != null
              ? () => _drillInto(goal)
              : null,
          onToggle: () => _toggle(goal),
          onAddChild: goal.childLevel != null
              ? () => _createChild(goal)
              : null,
          onEdit: () => _editGoal(goal),
          onDelete: () => _delete(goal),
        );
      },
    );
  }

  String _emptyTitle() {
    if (_stack.isEmpty) return 'No goals yet';
    final parent = _stack.last;
    return 'No ${parent.childLevel?.name ?? 'tasks'} yet';
  }

  String _emptyMessage() {
    if (_stack.isEmpty) {
      return 'Plan the big things you want in life, then split them into '
          'yearly, monthly, weekly and daily steps.';
    }
    final parent = _stack.last;
    return 'Add ${parent.childLevel?.name ?? 'a task'} under '
        '"${parent.title}" to keep breaking it down.';
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({
    required this.goal,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.onTap,
    this.onAddChild,
  });

  final Goal goal;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onTap;
  final VoidCallback? onAddChild;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = goal.completed;
    final hasChildren = goal.children.isNotEmpty;
    final completedChildren = goal.children.where((c) => c.completed).length;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: done,
                onChanged: (_) => onToggle(),
                activeColor: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        decoration: done ? TextDecoration.lineThrough : null,
                        color: done ? theme.colorScheme.onSurfaceVariant : null,
                      ),
                    ),
                    if (goal.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        goal.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _chip(theme, goal.levelLabel),
                        if (goal.dueDate != null)
                          _chip(
                            theme,
                            'Due ${_formatDate(goal.dueDate!)}',
                            Icon(
                              _isOverdue(goal.dueDate!, goal.completed)
                                  ? Icons.warning_amber
                                  : Icons.event,
                              size: 14,
                              color: _isOverdue(goal.dueDate!, goal.completed)
                                  ? theme.colorScheme.error
                                  : theme.colorScheme.primary,
                            ),
                          ),
                        if (hasChildren)
                          _chip(
                            theme,
                            '$completedChildren/${goal.children.length} done',
                            Icon(
                              Icons.check_circle_outline,
                              size: 14,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                      ],
                    ),
                    if (onTap != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'Open →',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  switch (value) {
                    case 'add':
                      onAddChild?.call();
                      break;
                    case 'edit':
                      onEdit();
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  if (onAddChild != null)
                    const PopupMenuItem(
                      value: 'add',
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.add),
                        title: Text('Add child'),
                      ),
                    ),
                  const PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit'),
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  static bool _isOverdue(DateTime due, bool completed) {
    if (completed) return false;
    final now = DateTime.now();
    return due.isBefore(DateTime(now.year, now.month, now.day));
  }

  Widget _chip(ThemeData theme, String text, [Icon? leading]) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, const SizedBox(width: 4)],
          Text(text, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _GoalEditor extends StatefulWidget {
  const _GoalEditor({
    required this.heading,
    this.initialTitle,
    this.initialDesc,
    this.initialDue,
    this.level,
  });

  final String heading;
  final String? initialTitle;
  final String? initialDesc;
  final DateTime? initialDue;
  final GoalLevel? level;

  @override
  State<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends State<_GoalEditor> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late DateTime? _dueDate;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle ?? '');
    _descCtrl = TextEditingController(text: widget.initialDesc ?? '');
    _dueDate = widget.initialDue;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 20),
      helpText: 'When should this be done?',
    );
    if (picked == null) return;
    setState(() => _dueDate = picked);
  }

  static String _formatDue(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  void _save() {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Give your goal a title.')),
      );
      return;
    }
    Navigator.pop(
      context,
      (title: title, desc: _descCtrl.text.trim(), dueDate: _dueDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.heading,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            if (widget.level != null) ...[
              const SizedBox(height: 4),
              Text(
                widget.level!.name.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              autofocus: true,
              maxLength: 120,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.flag_outlined),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                alignLabelWithHint: true,
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDueDate,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    _dueDate == null
                        ? 'No deadline'
                        : 'Due ${_formatDue(_dueDate!)}',
                  ),
                ),
                const SizedBox(width: 8),
                if (_dueDate != null)
                  IconButton(
                    tooltip: 'Clear deadline',
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() => _dueDate = null),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.title,
    required this.message,
    this.onAdd,
  });

  final String title;
  final String message;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.emoji_events_outlined,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            if (onAdd != null)
              FilledButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
          ],
        ),
      ),
    );
  }
}
