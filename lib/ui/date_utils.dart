import 'package:intl/intl.dart';

/// 仅到天的日期格式，统一 'yyyy-MM-dd'。
final DateFormat ymd = DateFormat('yyyy-MM-dd');

String todayYmd() => ymd.format(DateTime.now());

DateTime parseYmd(String s) => ymd.parse(s);
