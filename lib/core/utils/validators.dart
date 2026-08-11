/// Input validation and friendly error messages.
library;

class Validator {
  Validator._();

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v);
    return ok ? null : 'Enter a valid email';
  }

  /// Turns Supabase API errors into human-friendly messages.
  static String readableError(Object e) {
    final raw = e.toString();
    if (raw.contains('Invalid login credentials')) {
      return 'Wrong email or password.';
    }
    if (raw.contains('already registered')) {
      return 'That email is already registered.';
    }
    if (raw.contains('rate limit') || raw.contains('Over rate limit')) {
      return 'Too many attempts. Please wait a moment.';
    }
    if (raw.contains('network') ||
        raw.contains('SocketException') ||
        raw.contains('ClientException') ||
        raw.contains('Connection refused')) {
      return 'You\'re offline. Reconnect and try again.';
    }
    if (raw.contains('Password should be at least 6 characters')) {
      return 'Password must be at least 6 characters.';
    }
    // Strip "PostgrestException(message: ...)" noise.
    final m = RegExp(r'message:\s*"([^"]+)"').firstMatch(raw);
    if (m != null) return m.group(1)!;
    return raw;
  }
}
