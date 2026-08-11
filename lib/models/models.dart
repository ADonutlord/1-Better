/// Data models shared across the app. Each has `fromJson`/`toJson` matching
/// the Supabase table shapes.
library;

class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.role,
    required this.level,
    required this.totalXp,
    required this.currentStreak,
    required this.longestStreak,
    this.lastActionDate,
    this.createdAt,
    this.profession = 'other',
    this.avatarUrl,
    this.suspendedUntil,
    this.birthYear,
  });

  final String id;
  final String displayName;
  final String role;
  final int level;
  final int totalXp;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActionDate;
  final DateTime? createdAt;
  final String profession;
  final String? avatarUrl;
  final DateTime? suspendedUntil;
  final int? birthYear;

  bool get isAdmin => role == 'admin';
  bool get isOwner => role == 'owner';
  bool get isTester => role == 'testing';

  /// Current age derived from birth year, or null if not set.
  int? get age {
    final birth = birthYear;
    if (birth == null) return null;
    return DateTime.now().year - birth;
  }

  /// True while the account is suspended. Expired temporary suspensions
  /// (suspended_until in the past) count as active.
  bool get isSuspended =>
      suspendedUntil != null && suspendedUntil!.isAfter(DateTime.now());

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      displayName: (json['display_name'] as String?) ?? 'Friend',
      role: (json['role'] as String?) ?? 'user',
      level: (json['level'] as int?) ?? 1,
      totalXp: (json['total_xp'] as int?) ?? 0,
      currentStreak: (json['current_streak'] as int?) ?? 0,
      longestStreak: (json['longest_streak'] as int?) ?? 0,
      lastActionDate: _parseDate(json['last_action_date']),
      createdAt: _parseDateTime(json['created_at']),
      profession: (json['profession'] as String?) ?? 'other',
      avatarUrl: json['avatar_url'] as String?,
      suspendedUntil: _parseDateTime(json['suspended_until']),
      birthYear: json['birth_year'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'display_name': displayName,
        'role': role,
        'level': level,
        'total_xp': totalXp,
        'current_streak': currentStreak,
        'longest_streak': longestStreak,
        'last_action_date': lastActionDate?.toIso8601String(),
        'created_at': createdAt?.toIso8601String(),
      };
}

class MoodCheckin {
  const MoodCheckin({
    required this.id,
    required this.mood,
    required this.situation,
    required this.createdAt,
  });

  final String id;
  final String mood;
  final List<String> situation;
  final DateTime createdAt;

  factory MoodCheckin.fromJson(Map<String, dynamic> json) => MoodCheckin(
        id: (json['id'] as String?) ?? '',
        mood: (json['mood'] as String?) ?? 'okay',
        situation: _stringList(json['situation']),
        createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      );
}

class AppAction {
  const AppAction({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.subCategory,
    required this.estimatedMinutes,
    required this.difficulty,
    required this.requiredEnergy,
    required this.moodTags,
    required this.situationTags,
    required this.baseXp,
    required this.active,
  });

  final String id;
  final String title;
  final String description;
  final String category;
  final String subCategory;
  final int estimatedMinutes;
  final int difficulty;
  final String requiredEnergy;
  final List<String> moodTags;
  final List<String> situationTags;
  final int baseXp;
  final bool active;

  factory AppAction.fromJson(Map<String, dynamic> json) => AppAction(
        id: (json['id'] as String?) ?? '',
        title: (json['title'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        category: (json['category'] as String?) ?? '',
        subCategory: (json['sub_category'] as String?) ?? '',
        estimatedMinutes: (json['estimated_minutes'] as int?) ?? 5,
        difficulty: (json['difficulty'] as int?) ?? 1,
        requiredEnergy: (json['required_energy'] as String?) ?? 'low',
        moodTags: _stringList(json['mood_tags']),
        situationTags: _stringList(json['situation_tags']),
        baseXp: (json['base_xp'] as int?) ?? 10,
        active: (json['active'] as bool?) ?? true,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'sub_category': subCategory,
        'estimated_minutes': estimatedMinutes,
        'difficulty': difficulty,
        'required_energy': requiredEnergy,
        'mood_tags': moodTags,
        'situation_tags': situationTags,
        'base_xp': baseXp,
        'active': active,
      };
}

/// One assignment (and possibly completion) of an action for a user.
/// Carries a snapshot of the action for offline scoring.
class ActionHistory {
  const ActionHistory({
    required this.id,
    required this.userId,
    required this.actionId,
    required this.assignedAt,
    required this.completed,
    this.completedAt,
    this.moodAtAssignment,
    this.situationAtAssignment = const [],
    this.xpEarned = 0,
    this.source = 'algorithm',
    this.action,
  });

  final String id;
  final String userId;
  final String actionId;
  final DateTime assignedAt;
  final bool completed;
  final DateTime? completedAt;
  final String? moodAtAssignment;
  final List<String> situationAtAssignment;
  final int xpEarned;
  final String source;
  final AppAction? action;

  String? get actionTitle => action?.title;
  String? get actionCategory => action?.category;
  int? get actionDifficulty => action?.difficulty;

  factory ActionHistory.fromJson(Map<String, dynamic> json) {
    final action = json['action'] is Map<String, dynamic>
        ? AppAction.fromJson(json['action'] as Map<String, dynamic>)
        : null;
    return ActionHistory(
      id: (json['id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      actionId: (json['action_id'] as String?) ?? '',
      assignedAt: _parseDateTime(json['assigned_at']) ?? DateTime.now(),
      completed: (json['completed'] as bool?) ?? false,
      completedAt: _parseDateTime(json['completed_at']),
      moodAtAssignment: json['mood_at_assignment'] as String?,
      situationAtAssignment: _stringList(json['situation_at_assignment']),
      xpEarned: (json['xp_earned'] as int?) ?? 0,
      source: (json['source'] as String?) ?? 'algorithm',
      action: action,
    );
  }
}

class Conversation {
  const Conversation({
    required this.id,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.endedAt,
    this.assignedActionId,
  });

  final String id;
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final String? assignedActionId;

  bool get isActive => status == 'active';
  bool get isWaiting => status == 'waiting';
  bool get isEnded => status == 'ended';

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
        id: (json['id'] as String?) ?? '',
        status: (json['status'] as String?) ?? 'waiting',
        createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
        startedAt: _parseDateTime(json['started_at']),
        endedAt: _parseDateTime(json['ended_at']),
        assignedActionId: json['assigned_action_id'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'status': status,
        'created_at': createdAt.toIso8601String(),
        'started_at': startedAt?.toIso8601String(),
        'ended_at': endedAt?.toIso8601String(),
        'assigned_action_id': assignedActionId,
      };
}

class ConversationParticipant {
  const ConversationParticipant({
    required this.conversationId,
    required this.userId,
    required this.participantRole,
    required this.joinedAt,
    this.leftAt,
    this.displayName,
    this.profession,
    this.avatarUrl,
  });

  final String conversationId;
  final String userId;
  final String participantRole;
  final DateTime joinedAt;
  final DateTime? leftAt;
  final String? displayName;
  final String? profession;
  final String? avatarUrl;

  factory ConversationParticipant.fromJson(Map<String, dynamic> json) {
    String? name;
    String? profession;
    String? avatarUrl;
    final profile = json['profiles'] is Map<String, dynamic>
        ? json['profiles'] as Map<String, dynamic>
        : json['profile'] is Map<String, dynamic>
            ? json['profile'] as Map<String, dynamic>
            : null;
    if (profile != null) {
      name = profile['display_name'] as String?;
      profession = profile['profession'] as String?;
      avatarUrl = profile['avatar_url'] as String?;
    }
    name ??= json['display_name'] as String?;
    profession ??= json['profession'] as String?;
    avatarUrl ??= json['avatar_url'] as String?;

    return ConversationParticipant(
      conversationId: (json['conversation_id'] as String?) ?? '',
      userId: (json['user_id'] as String?) ?? '',
      participantRole: (json['participant_role'] as String?) ?? 'user',
      joinedAt: _parseDateTime(json['joined_at']) ?? DateTime.now(),
      leftAt: _parseDateTime(json['left_at']),
      displayName: name,
      profession: profession,
      avatarUrl: avatarUrl,
    );
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.message,
    required this.messageType,
    required this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String message;
  final String messageType;
  final DateTime createdAt;

  bool get isSystem => messageType == 'system';
  bool get isActionRecommendation => messageType == 'action_recommendation';

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: (json['id'] as String?) ?? '',
        conversationId: (json['conversation_id'] as String?) ?? '',
        senderId: (json['sender_id'] as String?) ?? '',
        message: (json['message'] as String?) ?? '',
        messageType: (json['message_type'] as String?) ?? 'text',
        createdAt: _parseDateTime(json['created_at']) ?? DateTime.now(),
      );
}

class DailyProgress {
  const DailyProgress({
    required this.userId,
    required this.date,
    this.moodCompleted = false,
    this.conversationCompleted = false,
    this.actionId,
    this.actionCompleted = false,
    this.xpAwarded = 0,
  });

  final String userId;
  final DateTime date;
  final bool moodCompleted;
  final bool conversationCompleted;
  final String? actionId;
  final bool actionCompleted;
  final int xpAwarded;

  factory DailyProgress.fromJson(Map<String, dynamic> json) => DailyProgress(
        userId: (json['user_id'] as String?) ?? '',
        date: _parseDate(json['date']) ?? DateTime.now(),
        moodCompleted: (json['mood_completed'] as bool?) ?? false,
        conversationCompleted:
            (json['conversation_completed'] as bool?) ?? false,
        actionId: json['action_id'] as String?,
        actionCompleted: (json['action_completed'] as bool?) ?? false,
        xpAwarded: (json['xp_awarded'] as int?) ?? 0,
      );
}

class DailyLoop {
  const DailyLoop({
    required this.profile,
    this.dailyProgress,
    this.todayAction,
    this.latestMood,
  });

  final UserProfile profile;
  final DailyProgress? dailyProgress;
  final ActionHistory? todayAction;
  final MoodCheckin? latestMood;

  factory DailyLoop.fromJson(Map<String, dynamic> json) {
    final profileJson = json['profile'];
    final progressJson = json['daily_progress'];
    final actionJson = json['today_action'];
    final moodJson = json['latest_mood'];
    return DailyLoop(
      profile: profileJson is Map<String, dynamic>
          ? UserProfile.fromJson(profileJson)
          : const UserProfile(
              id: '', displayName: '', role: 'user', level: 1, totalXp: 0,
              currentStreak: 0, longestStreak: 0),
      dailyProgress: progressJson is Map<String, dynamic>
          ? DailyProgress.fromJson(progressJson)
          : null,
      todayAction: actionJson is Map<String, dynamic>
          ? ActionHistory.fromJson(actionJson)
          : null,
      latestMood: moodJson is Map<String, dynamic>
          ? MoodCheckin.fromJson(moodJson)
          : null,
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------
DateTime? _parseDateTime(Object? value) {
  if (value == null) return null;
  // Postgres serialises 'infinity' as-is; map it to a far-future sentinel
  // so permanent suspensions parse to a non-null date.
  if (value.toString() == 'infinity') return DateTime(2999);
  return DateTime.tryParse(value.toString())?.toLocal();
}

DateTime? _parseDate(Object? value) {
  if (value == null) return null;
  final parsed = DateTime.tryParse(value.toString());
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

List<String> _stringList(Object? value) {
  if (value is List) return value.map((e) => e.toString()).toList();
  if (value is String) {
    if (value.startsWith('{') && value.endsWith('}')) {
      final inner = value.substring(1, value.length - 1);
      if (inner.isEmpty) return const [];
      return inner.split(',').map((e) => e.trim()).toList();
    }
    return [value];
  }
  return const [];
}
