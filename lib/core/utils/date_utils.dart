import 'package:intl/intl.dart';

class DateUtils {
  static String formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy', 'ru_RU').format(date);
  }
  
  static String formatDateTime(DateTime date) {
    return DateFormat('dd.MM.yyyy HH:mm', 'ru_RU').format(date);
  }
  
  static String formatDateDisplay(DateTime date) {
    return DateFormat('dd.MM.yyyy', 'ru_RU').format(date);
  }
  
  static DateTime getToday() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
  
  static DateTime getStartOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
  
  static DateTime getEndOfDay(DateTime date) {
    return DateTime(date.year, date.month, date.day, 23, 59, 59);
  }
}

