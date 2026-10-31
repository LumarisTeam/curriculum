import 'json_utils.dart';
import 'time_slot.dart';

/// 组合作息方案，字段对齐拾光课程表的 `ComboScheduleJsonModel`。
///
/// 这是导入/导出协议里的**可选扩展**：课表页面本身不会写出组合作息，因此
/// 解析器不产出它。本类只用于 `fromJson` / `toJson` 的往返，避免把宿主传进来的
/// 方案丢掉。
class ComboSchedule {
  /// 创建一个组合作息方案。
  ComboSchedule({
    this.name,
    Iterable<PublicScheduleTemplate> publicSchedules = const <PublicScheduleTemplate>[],
  }) : publicSchedules = List<PublicScheduleTemplate>.unmodifiable(publicSchedules);

  /// 从 JSON 对象解码。
  ///
  /// 未知键会被忽略，类型不符的字段回退到默认值，绝不抛异常。
  factory ComboSchedule.fromJson(Map<String, dynamic> json) {
    final rawSchedules = json['publicSchedules'];
    return ComboSchedule(
      name: json.asStringOrNull('name'),
      publicSchedules: rawSchedules is List
          ? <PublicScheduleTemplate>[
              for (final e in rawSchedules)
                if (e is Map) PublicScheduleTemplate.fromJson(e.cast<String, dynamic>()),
            ]
          : const <PublicScheduleTemplate>[],
    );
  }

  /// 方案名称，例如「夏季作息」。
  final String? name;

  /// 方案下辖的公共作息模板，已包成不可变列表。
  final List<PublicScheduleTemplate> publicSchedules;

  /// 编码为 JSON 对象。
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'publicSchedules': <Map<String, dynamic>>[
      for (final schedule in publicSchedules) schedule.toJson(),
    ],
  };

  /// 返回一个替换了部分字段的副本。
  ComboSchedule copyWith({String? name, Iterable<PublicScheduleTemplate>? publicSchedules}) =>
      ComboSchedule(
        name: name ?? this.name,
        publicSchedules: publicSchedules ?? this.publicSchedules,
      );

  @override
  bool operator ==(Object other) =>
      other is ComboSchedule &&
      other.name == name &&
      _listEquals(other.publicSchedules, publicSchedules);

  @override
  int get hashCode => Object.hash(name, Object.hashAll(publicSchedules));

  @override
  String toString() => 'ComboSchedule(${name ?? '(unnamed)'}, ${publicSchedules.length} 个模板)';
}

/// 组合作息下辖的一个公共作息模板，字段对齐拾光课程表的
/// `PublicScheduleTemplateJsonModel`。
class PublicScheduleTemplate {
  /// 创建一个公共作息模板。
  PublicScheduleTemplate({
    required this.name,
    required this.startDate,
    required this.endDate,
    this.defaultClassDuration = 45,
    this.defaultBreakDuration = 10,
    Iterable<TimeSlot> timeSlots = const <TimeSlot>[],
  }) : timeSlots = List<TimeSlot>.unmodifiable(timeSlots);

  /// 从 JSON 对象解码。
  factory PublicScheduleTemplate.fromJson(Map<String, dynamic> json) {
    final rawSlots = json['timeSlots'];
    return PublicScheduleTemplate(
      name: json.asString('name'),
      startDate: json.asString('startDate'),
      endDate: json.asString('endDate'),
      defaultClassDuration: json.asInt('defaultClassDuration', fallback: 45),
      defaultBreakDuration: json.asInt('defaultBreakDuration', fallback: 10),
      timeSlots: rawSlots is List
          ? <TimeSlot>[
              for (final e in rawSlots)
                if (e is Map) TimeSlot.fromJson(e.cast<String, dynamic>()),
            ]
          : const <TimeSlot>[],
    );
  }

  /// 公共作息名称，例如「夏季作息」。
  final String name;

  /// 生效起始日期，`yyyy-MM-dd`。
  final String startDate;

  /// 生效结束日期，`yyyy-MM-dd`。
  final String endDate;

  /// 该公共作息下的单节时长（分钟）。
  final int defaultClassDuration;

  /// 该公共作息下的休息时长（分钟）。
  final int defaultBreakDuration;

  /// 该公共作息对应的节次时间点，已包成不可变列表。
  final List<TimeSlot> timeSlots;

  /// 编码为 JSON 对象。
  Map<String, dynamic> toJson() => <String, dynamic>{
    'name': name,
    'startDate': startDate,
    'endDate': endDate,
    'defaultClassDuration': defaultClassDuration,
    'defaultBreakDuration': defaultBreakDuration,
    'timeSlots': <Map<String, dynamic>>[for (final slot in timeSlots) slot.toJson()],
  };

  /// 返回一个替换了部分字段的副本。
  PublicScheduleTemplate copyWith({
    String? name,
    String? startDate,
    String? endDate,
    int? defaultClassDuration,
    int? defaultBreakDuration,
    Iterable<TimeSlot>? timeSlots,
  }) => PublicScheduleTemplate(
    name: name ?? this.name,
    startDate: startDate ?? this.startDate,
    endDate: endDate ?? this.endDate,
    defaultClassDuration: defaultClassDuration ?? this.defaultClassDuration,
    defaultBreakDuration: defaultBreakDuration ?? this.defaultBreakDuration,
    timeSlots: timeSlots ?? this.timeSlots,
  );

  @override
  bool operator ==(Object other) =>
      other is PublicScheduleTemplate &&
      other.name == name &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.defaultClassDuration == defaultClassDuration &&
      other.defaultBreakDuration == defaultBreakDuration &&
      _listEquals(other.timeSlots, timeSlots);

  @override
  int get hashCode => Object.hash(
    name,
    startDate,
    endDate,
    defaultClassDuration,
    defaultBreakDuration,
    Object.hashAll(timeSlots),
  );

  @override
  String toString() => 'PublicScheduleTemplate($name, $startDate..$endDate)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
