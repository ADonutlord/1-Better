/// Moods the user can check in with, plus their emoji.
class Moods {
  Moods._();

  static const List<String> keys = [
    'great',
    'good',
    'okay',
    'low',
    'stressed',
  ];

  static const Map<String, String> labels = {
    'great': 'Great',
    'good': 'Good',
    'okay': 'Okay',
    'low': 'Low',
    'stressed': 'Stressed',
  };

  static const Map<String, String> emoji = {
    'great': '😄',
    'good': '🙂',
    'okay': '😐',
    'low': '😔',
    'stressed': '😣',
  };

  static String emojiFor(String? mood) => emoji[mood] ?? '🌱';
  static String labelFor(String? mood) => labels[mood] ?? 'Okay';
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
