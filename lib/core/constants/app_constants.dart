/// Moods the user can check in with, grouped by energy and valence, plus their
/// emoji. There are 25 moods across 5 groups.
class Moods {
  Moods._();

  static const String positiveHigh = 'positive_high';
  static const String positiveLow = 'positive_low';
  static const String negativeHigh = 'negative_high';
  static const String negativeLow = 'negative_low';
  static const String neutral = 'neutral';

  /// Moods grouped by group key, in display order.
  static const Map<String, List<String>> groups = {
    positiveHigh: ['excited', 'happy', 'enthusiastic', 'elated', 'energetic'],
    positiveLow: ['calm', 'content', 'relaxed', 'peaceful', 'serene'],
    negativeHigh: ['angry', 'anxious', 'stressed', 'irritable', 'frustrated'],
    negativeLow: ['sad', 'bored', 'tired', 'depressed', 'gloomy'],
    neutral: ['confused', 'nostalgic', 'curious', 'indifferent', 'surprised'],
  };

  static const Map<String, String> groupLabels = {
    positiveHigh: 'Positive · high energy',
    positiveLow: 'Positive · low energy',
    negativeHigh: 'Negative · high energy',
    negativeLow: 'Negative · low energy',
    neutral: 'Neutral / mixed',
  };

  static const List<String> keys = [
    'excited', 'happy', 'enthusiastic', 'elated', 'energetic',
    'calm', 'content', 'relaxed', 'peaceful', 'serene',
    'angry', 'anxious', 'stressed', 'irritable', 'frustrated',
    'sad', 'bored', 'tired', 'depressed', 'gloomy',
    'confused', 'nostalgic', 'curious', 'indifferent', 'surprised',
  ];

  static const Map<String, String> labels = {
    'excited': 'Excited',
    'happy': 'Happy',
    'enthusiastic': 'Enthusiastic',
    'elated': 'Elated',
    'energetic': 'Energetic',
    'calm': 'Calm',
    'content': 'Content',
    'relaxed': 'Relaxed',
    'peaceful': 'Peaceful',
    'serene': 'Serene',
    'angry': 'Angry',
    'anxious': 'Anxious',
    'stressed': 'Stressed',
    'irritable': 'Irritable',
    'frustrated': 'Frustrated',
    'sad': 'Sad',
    'bored': 'Bored',
    'tired': 'Tired',
    'depressed': 'Depressed',
    'gloomy': 'Gloomy',
    'confused': 'Confused',
    'nostalgic': 'Nostalgic',
    'curious': 'Curious',
    'indifferent': 'Indifferent',
    'surprised': 'Surprised',
  };

  static const Map<String, String> emoji = {
    'excited': '😆',
    'happy': '😀',
    'enthusiastic': '🤩',
    'elated': '😁',
    'energetic': '⚡',
    'calm': '😌',
    'content': '🙂',
    'relaxed': '😎',
    'peaceful': '🕊️',
    'serene': '🌿',
    'angry': '😠',
    'anxious': '😰',
    'stressed': '😣',
    'irritable': '😤',
    'frustrated': '😩',
    'sad': '😢',
    'bored': '🥱',
    'tired': '😴',
    'depressed': '😞',
    'gloomy': '🌧️',
    'confused': '😕',
    'nostalgic': '🥲',
    'curious': '🤔',
    'indifferent': '😐',
    'surprised': '😲',
  };

  static String emojiFor(String? mood) => emoji[mood] ?? '🌱';
  static String labelFor(String? mood) => labels[mood] ?? 'Calm';

  /// The group a mood belongs to, or null if unknown.
  static String? groupOf(String? mood) {
    if (mood == null) return null;
    for (final entry in groups.entries) {
      if (entry.value.contains(mood)) return entry.key;
    }
    return null;
  }

  static bool isPositive(String? mood) {
    final g = groupOf(mood);
    return g == positiveHigh || g == positiveLow;
  }

  static bool isNegative(String? mood) {
    final g = groupOf(mood);
    return g == negativeHigh || g == negativeLow;
  }

  static bool isHighEnergy(String? mood) {
    final g = groupOf(mood);
    return g == positiveHigh || g == negativeHigh;
  }
}

/// Situations a user can optionally select.
class Situations {
  Situations._();

  static const List<String> keys = [
    'school',
    'work',
    'family',
    'friends',
    'relationships',
    'money',
    'loneliness',
    'stress',
    'motivation',
    'other',
  ];
}

/// Professions a user picks at signup (mandatory). The matching algorithm
/// groups these into related families so people in the same or a similar
/// profession are matched first.
class Professions {
  Professions._();

  static const List<String> keys = [
    'student',
    'teacher',
    'software_engineer',
    'engineer',
    'designer',
    'artist',
    'writer',
    'doctor',
    'nurse',
    'therapist_counselor',
    'entrepreneur',
    'sales_marketing',
    'finance_accounting',
    'lawyer',
    'trades',
    'chef',
    'hospitality_retail',
    'caregiving',
    'parent_homemaker',
    'unemployed_job_seeking',
    'retired',
    'other',
  ];

  static const Map<String, String> labels = {
    'student': 'Student',
    'teacher': 'Teacher',
    'software_engineer': 'Software engineer',
    'engineer': 'Engineer',
    'designer': 'Designer',
    'artist': 'Artist',
    'writer': 'Writer',
    'doctor': 'Doctor',
    'nurse': 'Nurse',
    'therapist_counselor': 'Therapist / counselor',
    'entrepreneur': 'Entrepreneur',
    'sales_marketing': 'Sales & marketing',
    'finance_accounting': 'Finance & accounting',
    'lawyer': 'Lawyer',
    'trades': 'Trades (electrician, plumber, builder)',
    'chef': 'Chef',
    'hospitality_retail': 'Hospitality & retail',
    'caregiving': 'Caregiver',
    'parent_homemaker': 'Parent / homemaker',
    'unemployed_job_seeking': 'Currently job hunting',
    'retired': 'Retired',
    'other': 'Something else',
  };

  static String labelFor(String? profession) =>
      labels[profession] ?? 'Something else';
}

/// XP rewards for the various events.
class XpRewards {
  XpRewards._();

  static const int dailyAction = 10;
  static const int focusSession = 15;
  static const int completeChat = 15;
  static const int positiveFeedback = 5;
}

/// Difficulty labels for the 1-5 difficulty scale.
class Difficulty {
  Difficulty._();

  static const Map<int, String> labels = {
    1: 'Very easy',
    2: 'Easy',
    3: 'Moderate',
    4: 'Challenging',
    5: 'Hard',
  };
}
