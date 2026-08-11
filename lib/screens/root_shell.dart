import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/progress/progress_screen.dart';

/// Responsive shell: bottom NavigationBar on phones, NavigationRail on desktop.
class RootShell extends StatefulWidget {
  const RootShell({super.key});

  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  final AppState _app = AppState.instance;
  int _index = 0;

  late final List<Widget> _pages = _buildPages();

  List<Widget> _buildPages() {
    return [
      const HomeScreen(),
      const ChatListScreen(),
      const ProgressScreen(),
      const ProfileScreen(),
    ];
  }

  void _rebuildPages() {
    _pages
      ..clear()
      ..addAll(_buildPages());
    if (_index >= _pages.length) _index = 0;
  }

  @override
  void initState() {
    super.initState();
    _app.addListener(_rebuildPages);
  }

  @override
  void dispose() {
    _app.removeListener(_rebuildPages);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final destinations = <({Widget icon, String label})>[
      (icon: const Icon(Icons.home_outlined), label: 'Home'),
      (icon: const Icon(Icons.chat_bubble_outline), label: 'Chat'),
      (icon: const Icon(Icons.insights_outlined), label: 'Progress'),
      (icon: const Icon(Icons.person_outline), label: 'Profile'),
    ];

    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= 900;
      if (isDesktop) {
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 1100,
                  selectedIndex: _index,
                  onDestinationSelected: (i) => setState(() => _index = i),
                  labelType: constraints.maxWidth >= 1100
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  leading: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: _LogoBadge(),
                  ),
                  destinations: [
                    for (final d in destinations)
                      NavigationRailDestination(
                        icon: d.icon,
                        selectedIcon: d.icon,
                        label: Text(d.label),
                      ),
                  ],
                ),
              ),
              const VerticalDivider(width: 1, thickness: 1),
              Expanded(child: _pages[_index]),
            ],
          ),
        );
      }

      return Scaffold(
        body: SafeArea(child: _pages[_index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: [
            for (final d in destinations)
              NavigationDestination(
                icon: d.icon,
                label: d.label,
              ),
          ],
        ),
      );
    });
  }
}

class _LogoBadge extends StatelessWidget {
  const _LogoBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.asset(
          'assets/logo.png',
          width: 36,
          height: 36,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
