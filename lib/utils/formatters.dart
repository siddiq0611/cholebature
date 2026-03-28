import 'package:intl/intl.dart';

final _currencyFmt = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 2,
);

final _compactFmt = NumberFormat.compact(locale: 'en_IN');

String formatCurrency(double amount) => _currencyFmt.format(amount);

String formatCompact(double amount) => '₹${_compactFmt.format(amount)}';

String formatDate(DateTime date) => DateFormat('d MMM yyyy').format(date);

String formatMonth(DateTime date) => DateFormat('MMMM yyyy').format(date);

String formatYear(int year) => year.toString();

String formatDayMonth(DateTime date) => DateFormat('d MMM').format(date);

String formatTime(DateTime date) => DateFormat('h:mm a').format(date);

String monthName(int month) => DateFormat('MMMM').format(DateTime(2000, month));