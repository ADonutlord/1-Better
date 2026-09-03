import 'package:flutter/material.dart';

import '../../core/app_state.dart';
import '../../models/models.dart';

/// Resolves how a post/answer author should be displayed.
///
/// Real-time streamed rows don't carry the embedded `profiles` join (only the
/// REST-fetched rows do), so when [embeddedAuthor] is null we fall back to the
/// cached current-user profile whenever the row belongs to the signed-in user.
/// That keeps the current user's display name visible on their own posts and
/// answers immediately, even on rows pushed over realtime.
class CommunityAuthor {
  const CommunityAuthor({required this.name, this.role});

  final String name;
  final String? role;

  String get initial =>
      name.isEmpty ? '?' : name.characters.first.toUpperCase();

  String? get roleLabel => switch (role) {
        'helper' => 'Helper',
        'admin' || 'owner' => 'Team',
        _ => null,
      };
}

/// Builds the display name/role for an author row, preferring the embedded
/// profile and falling back to the current user's cached profile.
CommunityAuthor resolveAuthor({
  required String userId,
  UserProfile? embeddedAuthor,
}) {
  if (embeddedAuthor != null && (embeddedAuthor.displayName.isNotEmpty)) {
    return CommunityAuthor(name: embeddedAuthor.displayName, role: embeddedAuthor.role);
  }
  // If the row is the signed-in user's own, use the cached profile so their
  // display name shows even on realtime rows that lack the join.
  final profile = AppState.instance.loop?.profile;
  if (profile != null && profile.id == userId) {
    return CommunityAuthor(name: profile.displayName, role: profile.role);
  }
  return const CommunityAuthor(name: 'Community member');
}
