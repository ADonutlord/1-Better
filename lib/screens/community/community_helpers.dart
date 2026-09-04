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
  const CommunityAuthor({required this.name, this.role, this.avatarUrl});

  final String name;
  final String? role;
  final String? avatarUrl;

  String get initial =>
      name.isEmpty ? '?' : name.characters.first.toUpperCase();

  bool get hasAvatar => avatarUrl != null && avatarUrl!.isNotEmpty;

  String? get roleLabel => switch (role) {
        'owner' => 'Owner',
        'admin' => 'Admin',
        'testing' => 'Tester',
        'wanniya' => 'Wanniya',
        'helper' => 'Helper',
        _ => null,
      };
}

/// Builds the display name/role/avatar for an author row, preferring the
/// embedded profile, then the shared author cache (populated via
/// [CommunityService.fetchAuthors] for realtime rows), then the current user's
/// cached profile for their own rows.
CommunityAuthor resolveAuthor({
  required String userId,
  UserProfile? embeddedAuthor,
}) {
  if (embeddedAuthor != null && (embeddedAuthor.displayName.isNotEmpty)) {
    return CommunityAuthor(
      name: embeddedAuthor.displayName,
      role: embeddedAuthor.role,
      avatarUrl: embeddedAuthor.avatarUrl,
    );
  }
  // Realtime rows lack the join; check the shared author cache first.
  final cached = AppState.instance.authors[userId];
  if (cached != null && cached.displayName.isNotEmpty) {
    return CommunityAuthor(
      name: cached.displayName,
      role: cached.role,
      avatarUrl: cached.avatarUrl,
    );
  }
  // Otherwise, for the signed-in user's own rows use their cached profile so
  // their display name and picture show even on realtime rows.
  final profile = AppState.instance.loop?.profile;
  if (profile != null && profile.id == userId) {
    return CommunityAuthor(
      name: profile.displayName,
      role: profile.role,
      avatarUrl: profile.avatarUrl,
    );
  }
  return const CommunityAuthor(name: 'Community member');
}
