import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../core/app_state.dart';
import '../core/theme_controller.dart';
import '../logic/level_calculator.dart';
import '../screens/chat/chat_list_screen.dart';
import '../screens/goals/goals_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/progress/progress_screen.dart';
import '../screens/study/study_screen.dart';
import '../widgets/tree.dart';

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
      const GoalsScreen(),
      const ChatListScreen(),
      const StudyScreen(),
      const ProgressScreen(),
      const ProfileScreen(),
    ];
  }

  /// The animated growth tree filling the whole screen behind the chrome,
  /// gaussian-blurred when the Liquid Glass theme is active.
  Widget _backdrop() {
    return ListenableBuilder(
      listenable: Listenable.merge([_app, ThemeController.instance]),
      builder: (context, _) {
        final liquid = ThemeController.instance.liquid;
        final blur = ThemeController.instance.blur;
        final tree = TreeGrowthIndicator(
          growth: LevelCalculator.treeGrowth(_app.loop?.profile.totalXp ?? 0),
          background: true,
          backgroundAnchor: 0.1,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            Transform.translate(
              offset: const Offset(24, 0),
              child: tree,
            ),
            if (liquid && blur)
              ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                  child: const SizedBox.expand(),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Text/icon color for the nav chrome, picked from the luminance of whatever
  /// shows through the chrome surface behind it (the growth tree).
  Color _chromeTextColor(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final liquid = ThemeController.instance.liquid;
    final growth = LevelCalculator.treeGrowth(_app.loop?.profile.totalXp ?? 0);

    final chrome = isDark
        ? (liquid ? const Color(0xB3161D18) : const Color(0xFF1D2620))
        : (liquid ? const Color(0xB3F4F8F5) : const Color(0xFFF5F9F6));
    final foliage = isDark ? const Color(0xFF2E7D32) : const Color(0xFF43A047);
    final backdrop = Color.alphaBlend(
      chrome,
      Color.lerp(theme.colorScheme.surface, foliage, growth.clamp(0.0, 1.0))!,
    );
    return backdrop.computeLuminance() > 0.45
        ? const Color(0xFF16221A)
        : Colors.white;
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
      (icon: const Icon(Icons.flag_outlined), label: 'Goals'),
      (icon: const Icon(Icons.chat_bubble_outline), label: 'Chat'),
      (icon: const Icon(Icons.school_outlined), label: 'Study'),
      (icon: const Icon(Icons.insights_outlined), label: 'Progress'),
      (icon: const Icon(Icons.person_outline), label: 'Profile'),
    ];

    return ListenableBuilder(
      listenable: Listenable.merge([_app, ThemeController.instance]),
      builder: (context, _) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final liquid = ThemeController.instance.liquid;
        final chromeColor = _chromeTextColor(context);
        final chromeBg = isDark
            ? (liquid ? const Color(0xB3161D18) : const Color(0xFF1D2620))
            : (liquid ? const Color(0xB3F4F8F5) : const Color(0xFFF5F9F6));

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;
            final extended = constraints.maxWidth >= 1100;

            return Stack(
              fit: StackFit.expand,
              children: [
                _backdrop(),
                Scaffold(
                  backgroundColor: Colors.transparent,
                  body: isDesktop
                      ? Row(
                          children: [
                            SafeArea(
                              child: Theme(
                                data: theme.copyWith(
                                  navigationRailTheme: NavigationRailThemeData(
                                    unselectedIconTheme: IconThemeData(
                                      color: chromeColor.withValues(
                                        alpha: 0.85,
                                      ),
                                    ),
                                    selectedIconTheme: IconThemeData(
                                      color: chromeColor,
                                    ),
                                    unselectedLabelTextStyle: TextStyle(
                                      color: chromeColor,
                                    ),
                                    selectedLabelTextStyle: TextStyle(
                                      color: chromeColor,
                                    ),
                                  ),
                                ),
                                child: NavigationRail(
                                  backgroundColor: chromeBg,
                                  extended: extended,
                                  selectedIndex: _index,
                                  onDestinationSelected: (i) =>
                                      setState(() => _index = i),
                                  labelType: extended
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
                            ),
                            const VerticalDivider(width: 1, thickness: 1),
                            Expanded(child: _pages[_index]),
                          ],
                        )
                      : SafeArea(child: _pages[_index]),
                  bottomNavigationBar: isDesktop
                      ? null
                      : Theme(
                          data: theme.copyWith(
                            navigationBarTheme: NavigationBarThemeData(
                              iconTheme: WidgetStateProperty.resolveWith(
                                (states) => IconThemeData(
                                  color: states.contains(WidgetState.selected)
                                      ? chromeColor
                                      : chromeColor.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                          ),
                          child: NavigationBar(
                            backgroundColor: chromeBg,
                            indicatorColor: theme.colorScheme.primaryContainer,
                            labelTextStyle: WidgetStatePropertyAll(
                              TextStyle(
                                color: chromeColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            selectedIndex: _index,
                            onDestinationSelected: (i) =>
                                setState(() => _index = i),
                            destinations: [
                              for (final d in destinations)
                                NavigationDestination(
                                  icon: d.icon,
                                  label: d.label,
                                ),
                            ],
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
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
