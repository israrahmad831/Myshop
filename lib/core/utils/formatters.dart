import 'package:intl/intl.dart';

/// Formatting helpers. Currency symbol is per-shop so it is passed in.
class Formatters {
  const Formatters._();

  static final _date = DateFormat('dd MMM yyyy');
  static final _dateTime = DateFormat('dd MMM yyyy, hh:mm a');
  static final _number = NumberFormat('#,##0.##');

  static String date(DateTime d) => _date.format(d.toLocal());
  static String dateTime(DateTime d) => _dateTime.format(d.toLocal());

  /// e.g. money(1500, 'PKR') => "PKR 1,500".
  static String money(num value, String currency) =>
      '$currency ${_number.format(value)}';

  static String qty(num value) => _number.format(value);
}
