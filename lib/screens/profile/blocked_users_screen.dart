import 'package:flutter/material.dart';

import '../../models/models.dart';
import '../../services/chat_service.dart';
import '../../widgets/empty_state.dart';

class BlockedUsersScreen extends StatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  State<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends State<BlockedUsersScreen> {
  List<UserProfile> _blocked = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ChatService.instance.fetchBlockedUsers();
      if (!mounted) return;
      setState(() {
        _blocked = rows;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e;
      });
    }
  }

  Future<void> _unblock(UserProfile user) async {
    try {
      await ChatService.instance.unblockUser(user.id);
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked users')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyState(
                  icon: Icons.cloud_off_outlined,
                  title: 'Couldn\'t load blocked users',
                  action: OutlinedButton(
                      onPressed: _load, child: const Text('Retry')),
                )
              : _blocked.isEmpty
                  ? const EmptyState(
                      icon: Icons.block_outlined,
                      title: 'No blocked users',
                      message:
                          'People you block won\'t be matched with you again.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _blocked.length,
                      itemBuilder: (context, i) {
                        final user = _blocked[i];
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              child: Text(user.displayName.isNotEmpty
                                  ? user.displayName[0].toUpperCase()
                                  : '?'),
                            ),
                            title: Text(user.displayName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            subtitle: const Text('Blocked'),
                            trailing: TextButton(
                              onPressed: () => _unblock(user),
                              child: const Text('Unblock'),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
