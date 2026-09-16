import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialer pre-filled with [phone].
Future<void> dialPhone(String phone) async {
  final cleaned = phone.replaceAll(RegExp(r'[^0-9+]'), '');
  if (cleaned.isEmpty) return;
  final uri = Uri(scheme: 'tel', path: cleaned);
  try {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } catch (_) {
    // No dialer available (e.g. desktop) — silently ignore.
  }
}
