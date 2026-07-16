/// Reusable form field validators. Return null when valid.
class Validators {
  const Validators._();

  static String? required(String? v, {String field = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final re = RegExp(r'^[\w.\-+]+@([\w\-]+\.)+[\w\-]{2,}$');
    if (!re.hasMatch(v.trim())) return 'Enter a valid email';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'At least 6 characters';
    return null;
  }

  static String? confirm(String? v, String other) {
    if (v != other) return 'Passwords do not match';
    return null;
  }

  static String? positiveNumber(String? v, {String field = 'Value'}) {
    if (v == null || v.trim().isEmpty) return null; // optional
    final n = num.tryParse(v.trim());
    if (n == null) return '$field must be a number';
    if (n < 0) return '$field cannot be negative';
    return null;
  }
}
