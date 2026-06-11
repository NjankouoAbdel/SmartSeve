import 'package:intl/intl.dart';

class DateUtilsX {
  static String short(DateTime date, {String? localeCode}) {
    return DateFormat('dd MMM yyyy', localeCode).format(date);
  }

  static String monthShort(DateTime date, {String? localeCode}) {
    return DateFormat('MMM', localeCode).format(date);
  }
}
