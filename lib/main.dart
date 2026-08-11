import 'package:flutter/material.dart';

import 'core/app_state.dart';
import 'core/theme/app_theme.dart';
import 'core/theme_controller.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/root_shell.dart';
import 'screens/splash/loading_screen.dart';
import 'services/auth_service.dart';
import 'services/e2ee_service.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SupabaseService.instance.initialize();
  AppState.instance.bindAuth(SupabaseService.instance.client);
  await ThemeController.instance.load();

  runApp(const OnePercentBetterApp());
}

class OnePercentBetterApp extends StatefulWidget {
  const OnePercentBetterApp({super.key});

  @override
  State<OnePercentBetterApp> createState() => _OnePercentBetterAppState();
}

class _OnePercentBetterAppState extends State<OnePercentBetterApp> {
  final AppState _app = AppState.instance;
  final ThemeController _theme = ThemeController.instance;

  @override
  void initState() {
    super.initState();
    // Warm the daily loop if a session already exists (persistent session).
    if (_app.signedIn) {
      _app.loadDailyLoop();
      E2eeService.instance.ensureKeys();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _theme,
      builder: (context, _) {
        final liquid = _theme.liquid;
        return MaterialApp(
          title: '1% Better',
          debugShowCheckedModeBanner: false,
          theme: liquid ? AppTheme.liquidGlassLight() : AppTheme.light(),
          darkTheme: liquid ? AppTheme.liquidGlassDark() : AppTheme.dark(),
          themeMode: _theme.mode,
          home: SplashGate(
            child: ListenableBuilder(
              listenable: _app,
              builder: (context, _) {
                final user = AuthService.instance.currentUser;
                if (user == null) {
                  return const AuthGate();
                }
                final profile = _app.loop?.profile;
                if (profile?.isSuspended ?? false) {
                  return const SuspendedScreen();
                }
                return const RootShell();
              },
            ),
          ),
        );
      },
    );
  }
}

/// Chooses login vs register. Small stateful wrapper so the auth flow is
/// contained in one place.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _showRegister = false;

  void _toggle() => setState(() => _showRegister = !_showRegister);

  @override
  Widget build(BuildContext context) {
    return _showRegister
        ? RegisterScreen(onSwitchToLogin: _toggle)
        : LoginScreen(onSwitchToRegister: _toggle);
  }
}

/// Shown when the signed-in account has been suspended by an admin/owner.
class SuspendedScreen extends StatelessWidget {
  const SuspendedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block, size: 72, color: theme.colorScheme.error),
                const SizedBox(height: 20),
                Text(
                  'Account suspended',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'This account has been suspended by the administrators. '
                  'If you believe this is a mistake, please contact support.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
