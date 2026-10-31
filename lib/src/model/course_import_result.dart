import 'dart:convert';

import '../exceptions.dart';
import 'combo_schedule.dart';
import 'course.dart';
import 'course_config.dart';
import 'json_utils.dart';
import 'parse_warning.dart';
import 'time_slot.dart';

/// 一次解析的完整产出。
///
/// 字段对齐拾光课程表的 `CourseTableImportModel`，外加该线格式没有位置安放的
/// 诊断信息（[warnings] / [stats] / [adapterId]）。
class CourseImportResult {
  /// 创建解析结果。
  CourseImportResult({
    required Iterable<Course> courses,
    Iterable<TimeSlot> timeSlots = const <TimeSlot>[],
    this.config,
    this.comboSchedule,
    Iterable<ParseWarning> warnings = const <ParseWarning>[],
    this.adapterId,
    this.stats = ParseStats.empty,
  }) : courses = List<Course>.unmodifiable(courses),
       timeSlots = List<TimeSlot>.unmodifiable(timeSlots),
       warnings = List<ParseWarning>.unmodifiable(warnings);

  /// 从 JSON 对象解码（拾光课程表的 `CourseTableImportModel` 形状）。
  factory CourseImportResult.fromJson(Map<String, dynamic> json) {
    final rawCourses = json['courses'];
    final rawSlots = json['timeSlots'];
    final rawConfig = json['config'];
    final rawCombo = json.asMapOrNull('comboSchedule');
    return CourseImportResult(
      courses: rawCourses is List
          ? <Course>[
              for (final e in rawCourses)
                if (e is Map) Course.fromJson(e.cast<String, dynamic>()),
            ]
          : const <Course>[],
      timeSlots: rawSlots is List
          ? <TimeSlot>[
              for (final e in rawSlots)
                if (e is Map) TimeSlot.fromJson(e.cast<String, dynamic>()),
            ]
          : const <TimeSlot>[],
      config: rawConfig is Map ? CourseConfig.fromJson(rawConfig.cast<String, dynamic>()) : null,
      comboSchedule: rawCombo == null ? null : ComboSchedule.fromJson(rawCombo),
    );
  }

  /// 解析出的课程。
  final List<Course> courses;

  /// 解析出的作息时间；解析不到时为空列表。
  final List<TimeSlot> timeSlots;

  /// 学期配置。
  ///
  /// **默认恒为 null**：只有页面确实写明了学期信息、且调用方开启了
  /// [ParseOptions.emitConfig] 时才会非空。宿主拿到非空 config 会用它覆盖用户
  /// 本地的上下课时长，所以这里不能凭空发明默认值。
  final CourseConfig? config;

  /// 组合作息方案。
  ///
  /// 对齐拾光课程表 `CourseTableImportModel.comboSchedule`，是线格式里的可选
  /// 扩展。解析器不会产出它（课表页面不携带作息方案），但 `fromJson` /
  /// `toJson` 会原样保留，避免把宿主传入的数据丢掉。
  final ComboSchedule? comboSchedule;

  /// 解析过程中的诊断。
  final List<ParseWarning> warnings;

  /// 产出该结果的适配器 id。
  final String? adapterId;

  /// 统计摘要。
  final ParseStats stats;

  /// 是否没有解析出任何课程。
  bool get isEmpty => courses.isEmpty;

  /// 是否解析出了课程。
  bool get isNotEmpty => courses.isNotEmpty;

  /// 是否出现过 error 级诊断。
  bool get hasErrors => warnings.any((w) => w.severity == ParseSeverity.error);

  /// 编码为 JSON 对象，即拾光课程表 `saveImportedCourses` 接受的形状。
  Map<String, dynamic> toJson() => <String, dynamic>{
    'courses': <Map<String, dynamic>>[for (final c in courses) c.toJson()],
    'timeSlots': <Map<String, dynamic>>[for (final t in timeSlots) t.toJson()],
    'config': config?.toJson(),
    'comboSchedule': comboSchedule?.toJson(),
  };

  /// 编码为 JSON 字符串。
  String toJsonString() => jsonEncode(toJson());

  /// 若没有解析出任何课程则抛出 [ParseFailedException]。
  void throwIfEmpty() {
    if (courses.isEmpty) {
      throw ParseFailedException(
        '未解析出任何课程'
        '${adapterId == null ? '' : '（适配器 $adapterId）'}',
        warnings: warnings,
        partial: this,
      );
    }
  }

  /// 人类可读的诊断报告，适合直接粘进 issue。
  String get diagnosticReport {
    final b = StringBuffer()
      ..writeln('curriculum — adapter ${adapterId ?? '(auto/none)'}')
      ..writeln(
        'courses: ${courses.length}   '
        'timeSlots: ${timeSlots.length}   '
        'config: ${config == null ? 'none' : 'present'}',
      )
      ..writeln('stats: $stats');

    if (warnings.isEmpty) {
      b.writeln('warnings: none');
      return b.toString();
    }

    final errors = warnings.where((w) => w.severity == ParseSeverity.error);
    final warns = warnings.where((w) => w.severity == ParseSeverity.warning);
    final infos = warnings.where((w) => w.severity == ParseSeverity.info);
    b.writeln(
      'warnings: ${warnings.length} '
      '(${errors.length} error, ${warns.length} warning, '
      '${infos.length} info)',
    );
    for (final w in warnings) {
      b.writeln('  $w');
    }
    return b.toString();
  }

  @override
  String toString() =>
      'CourseImportResult(${courses.length} courses, '
      '${timeSlots.length} timeSlots, ${warnings.length} warnings)';
}
