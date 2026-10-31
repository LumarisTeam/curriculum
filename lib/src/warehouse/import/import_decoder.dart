import 'dart:convert';

import '../../model/combo_schedule.dart';
import '../../model/course.dart';
import '../../model/course_config.dart';
import '../../model/parse_warning.dart';
import '../../model/time_slot.dart';

/// 解码 `saveImportedCourses` 的 payload。
///
/// payload 是一个 JSON **数组**（不是 `CourseTableImportModel` 外壳）。单条课程
/// 不合法时会被丢弃并记入 [warnings]，而不是让整批导入失败；只有 payload 本身
/// 不是数组、或某一条不是对象时才抛 [FormatException]。
List<Course> decodeImportedCourses(String jsonString, {List<ParseWarning>? warnings}) {
  final decoded = _decodeJson(jsonString, '课程');
  if (decoded is! List) {
    throw const FormatException('saveImportedCourses 的 payload 必须是 JSON 数组。');
  }

  final courses = <Course>[];
  for (var index = 0; index < decoded.length; index++) {
    final item = decoded[index];
    final location = 'courses[$index]';
    if (item is! Map) {
      _warn(warnings, ParseWarningKind.invalidCoursePayload, '课程记录不是对象，已跳过。', location: location);
      continue;
    }

    final course = _decodeCourse(item.cast<String, dynamic>(), warnings, location);
    if (course != null) courses.add(course);
  }
  return List<Course>.unmodifiable(courses);
}

/// 解码 `saveCourseConfig` 的 payload。
///
/// 缺失字段会回退到 [CourseConfig] 的默认值；payload 不是对象时抛
/// [FormatException]。
CourseConfig decodeCourseConfig(String jsonString, {List<ParseWarning>? warnings}) {
  final decoded = _decodeJson(jsonString, '学期配置');
  if (decoded is! Map) {
    throw const FormatException('saveCourseConfig 的 payload 必须是 JSON 对象。');
  }

  final config = CourseConfig.fromJson(decoded.cast<String, dynamic>());
  if (config.semesterTotalWeeks <= 0) {
    _warn(
      warnings,
      ParseWarningKind.invalidConfigPayload,
      '学期总周数 ${config.semesterTotalWeeks} 非法，已回退为 20。',
      location: 'config.semesterTotalWeeks',
    );
    return config.copyWith(semesterTotalWeeks: 20);
  }
  if (config.firstDayOfWeek < 1 || config.firstDayOfWeek > 7) {
    _warn(
      warnings,
      ParseWarningKind.invalidConfigPayload,
      '一周起始日 ${config.firstDayOfWeek} 非法，已回退为 1。',
      location: 'config.firstDayOfWeek',
    );
    return config.copyWith(firstDayOfWeek: 1);
  }
  return config;
}

/// 解码 `savePresetTimeSlots` 的 payload。
///
/// payload 是 `TimeSlotJsonModel` 数组。`number` 从 1 开始；非法节次会被丢弃，
/// 重复节次保留最后一条。结果按 `number` 升序排列。
List<TimeSlot> decodeImportedTimeSlots(String jsonString, {List<ParseWarning>? warnings}) {
  final decoded = _decodeJson(jsonString, '作息时间');
  if (decoded is! List) {
    throw const FormatException('savePresetTimeSlots 的 payload 必须是 JSON 数组。');
  }

  final byNumber = <int, TimeSlot>{};
  for (var index = 0; index < decoded.length; index++) {
    final item = decoded[index];
    final location = 'timeSlots[$index]';
    if (item is! Map) {
      _warn(warnings, ParseWarningKind.invalidTimeSlotPayload, '作息记录不是对象，已跳过。', location: location);
      continue;
    }

    final map = item.cast<String, dynamic>();
    final number = _asInt(map['number']);
    if (number == null || number < 1) {
      _warn(
        warnings,
        ParseWarningKind.invalidTimeSlotPayload,
        '节次编号缺失或小于 1，已跳过。',
        location: location,
      );
      continue;
    }

    final startTime = map['startTime'];
    final endTime = map['endTime'];
    if (startTime is! String || !_isClockTime(startTime)) {
      _warn(
        warnings,
        ParseWarningKind.invalidTimeSlotPayload,
        '第 $number 节缺少合法的开始时间，已跳过。',
        location: location,
      );
      continue;
    }
    if (endTime is! String || !_isClockTime(endTime)) {
      _warn(
        warnings,
        ParseWarningKind.invalidTimeSlotPayload,
        '第 $number 节缺少合法的结束时间，已跳过。',
        location: location,
      );
      continue;
    }

    if (byNumber.containsKey(number)) {
      _warn(
        warnings,
        ParseWarningKind.invalidTimeSlotPayload,
        '第 $number 节重复，保留最后一条。',
        location: location,
      );
    }
    byNumber[number] = TimeSlot(
      number: number,
      startTime: startTime,
      endTime: endTime,
      alias: map['alias'] is String ? map['alias'] as String : null,
    );
  }

  final slots = byNumber.values.toList()..sort((a, b) => a.number.compareTo(b.number));
  return List<TimeSlot>.unmodifiable(slots);
}

/// 解码 `saveComboSchedule` 的 payload。
///
/// payload 不是对象时抛 [FormatException]；未知字段会被忽略。
ComboSchedule decodeComboSchedule(String jsonString, {List<ParseWarning>? warnings}) {
  final decoded = _decodeJson(jsonString, '组合作息');
  if (decoded is! Map) {
    throw const FormatException('saveComboSchedule 的 payload 必须是 JSON 对象。');
  }
  return ComboSchedule.fromJson(decoded.cast<String, dynamic>());
}

Course? _decodeCourse(Map<String, dynamic> map, List<ParseWarning>? warnings, String location) {
  final name = map['name'];
  if (name is! String || name.trim().isEmpty) {
    _warn(warnings, ParseWarningKind.missingName, '课程缺少名称，已丢弃。', location: location);
    return null;
  }

  final day = _asInt(map['day']);
  if (day == null || day < 1 || day > 7) {
    _warn(
      warnings,
      ParseWarningKind.dayOutOfRange,
      '星期字段 ${map['day']} 不在 1..7，已丢弃。',
      location: location,
    );
    return null;
  }

  final isCustomTime = map['isCustomTime'] == true;
  final startSection = _asInt(map['startSection']);
  final endSection = _asInt(map['endSection']);

  if (startSection != null && startSection < 1) {
    _warn(
      warnings,
      ParseWarningKind.sectionOutOfRange,
      '开始节次 $startSection 小于 1，已丢弃。',
      location: location,
    );
    return null;
  }
  if (endSection != null && startSection == null) {
    _warn(warnings, ParseWarningKind.sectionParseFailed, '只有结束节次、没有开始节次，已丢弃。', location: location);
    return null;
  }
  if (endSection != null && startSection != null && endSection < startSection) {
    _warn(
      warnings,
      ParseWarningKind.sectionParseFailed,
      '结束节次 $endSection 小于开始节次 $startSection，已丢弃。',
      location: location,
    );
    return null;
  }
  if (!isCustomTime && startSection == null) {
    _warn(
      warnings,
      ParseWarningKind.sectionParseFailed,
      '课程既没有节次也不是自定义时间，已丢弃。',
      location: location,
    );
    return null;
  }

  final rawWeeks = map['weeks'];
  final weeks = <int>[];
  if (rawWeeks is List) {
    for (final week in rawWeeks) {
      final value = _asInt(week);
      if (value != null && value > 0) weeks.add(value);
    }
    if (weeks.length != rawWeeks.length) {
      _warn(warnings, ParseWarningKind.weekOutOfRange, '周次里包含非正整数，已过滤。', location: location);
    }
  }

  try {
    final course = Course.fromJson(<String, dynamic>{...map, 'weeks': weeks});
    return course;
  } on AssertionError {
    _warn(warnings, ParseWarningKind.invalidCoursePayload, '课程字段不满足模型约束，已丢弃。', location: location);
    return null;
  } on FormatException {
    _warn(warnings, ParseWarningKind.invalidCoursePayload, '课程字段格式非法，已丢弃。', location: location);
    return null;
  }
}

Object? _decodeJson(String source, String label) {
  try {
    return jsonDecode(source);
  } on FormatException catch (error) {
    throw FormatException('$label payload 不是合法 JSON：${error.message}');
  }
}

int? _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool _isClockTime(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) return false;
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  return hour >= 0 && hour <= 23 && minute >= 0 && minute <= 59;
}

void _warn(
  List<ParseWarning>? warnings,
  ParseWarningKind kind,
  String message, {
  String? location,
}) {
  warnings?.add(ParseWarning.warn(kind, message, location: location));
}
