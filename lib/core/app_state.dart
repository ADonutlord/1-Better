import 'package:flutter/foundation.dart';
import 'package:one_percent_better/models/models.dart';
import 'package:one_percent_better/services/action_service.dart';
import 'package:one_percent_better/services/auth_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared app state: current auth user, profile, and the daily loop bundle.
class AppState extends ChangeNotifier {
  AppState._();

  static final AppState instance = AppState._();

  User? get user => AuthService.instance.currentUser;
  DailyLoop? _loop;
  DailyLoop? get loop => _loop;
  bool loadingLoop = false;
  String? error;

  bool get signedIn => user != null;

  void refreshUser() {
    notifyListeners();
  }

  /// Reloads the daily loop bundle from the server.
  Future<void> loadDailyLoop() async {
    if (!signedIn) return;
    loadingLoop = true;
    error = null;
    notifyListeners();
    try {
      _loop = await ActionService.instance.fetchDailyLoop();
    } catch (e) {
      error = e.toString();
    } finally {
      loadingLoop = false;
      notifyListeners();
    }
  }

  /// Replaces the cached profile (e.g. after XP/streak updates).
  void patchProfile(UserProfile profile) {
    final current = _loop;
    if (current == null) return;
    _loop = DailyLoop(
      profile: profile,
      dailyProgress: current.dailyProgress,
      todayAction: current.todayAction,
      latestMood: current.latestMood,
    );
    notifyListeners();
  }

  /// Keeps the daily loop in sync with the current session.
  void bindAuth(SupabaseClient client) {
    client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedIn) {
        loadDailyLoop();
      } else if (data.event == AuthChangeEvent.signedOut) {
        _loop = null;
        notifyListeners();
      }
    });
  }
}
