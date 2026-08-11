import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/action_service.dart';
import '../../widgets/action_card.dart';
import '../../widgets/empty_state.dart';

/// Bottom sheet where a peer picks a 1% action to recommend.
class RecommendActionSheet extends StatefulWidget {
  const RecommendActionSheet({super.key});

  @override
  State<RecommendActionSheet> createState() => _RecommendActionSheetState();
}

class _RecommendActionSheetState extends State<RecommendActionSheet> {
  List<AppAction> _actions = [];
  bool _loading = true;
  String _category = 'all';

  static const _categories = {
    'all': 'All',
    'wellbeing': 'Well-being',
    'productivity': 'Productivity',
    'study': 'Study',
    'social': 'Social',
    'physical': 'Physical',
    'reflection': 'Reflection',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ActionService.instance.fetchActions();
      if (!mounted) return;
      setState(() {
        _actions = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  List<AppAction> get _filtered =>
      _category == 'all' ? _actions : _actions.where((a) => a.category == _category).toList();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Recommend a 1% action 🌱',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  'Pick something small and doable for them, based on your talk.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      for (final entry in _categories.entries)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(entry.value),
                            selected: _category == entry.key,
                            showCheckmark: false,
                            onSelected: (_) =>
                                setState(() => _category = entry.key),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.spa_outlined,
                        title: 'No actions here',
                        message: 'Try another category.')
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filtered.length,
                        itemBuilder: (context, i) {
                          final action = _filtered[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: ActionCard(
                              action: action,
                              onTap: () => Navigator.pop(context, action),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
