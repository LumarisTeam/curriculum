import 'json_utils.dart';

/// 比较两个整数列表是否逐元素相等。
///
/// 用于周次列表的比较。本库刻意不引入 `package:collection`，因此手写这个
/// 六行工具，避免为一个 `ListEquality` 增加一个运行时依赖。
bool intListsEqual(List<int> a, List<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// 一门课程，字段对齐拾光课程表的 `ImportCourseJsonModel`。
class Course {
  /// 创建一门课程。
  ///
  /// [weeks] 会在构造时归一化：升序排序、去重、包成不可变列表。这一点不是
  /// 洁癖——若不归一化，`[1,2] == [2,1]` 为 false，下游的去重与合并会静默失效。
  Course({
    this.id,
    required this.name,
    this.teacher = '',
    this.position = '',
    required this.day,
    this.startSection,
    this.endSection,
    Iterable<int> weeks = const <int>[],
    this.isCustomTime = false,
    this.customStartTime,
    this.customEndTime,
    this.color,
    this.remark,
    this.credit,
  }) : weeks = _normalizeWeeks(weeks),
       assert(day >= 1 && day <= 7, 'day 必须在 1..7（周一..周日）'),
       assert(startSection == null || startSection >= 1, 'startSection 必须 >= 1'),
       assert(endSection == null || startSection != null, 'endSection 需要同时给出 startSection');

  /// 从 JSON 对象解码。
  ///
  /// 未知键会被忽略，类型不符的字段回退到默认值，绝不抛异常。
  factory Course.fromJson(Map<String, dynamic> json) => Course(
    id: json.asStringOrNull('id'),
    name: json.asString('name'),
    teacher: json.asString('teacher'),
    position: json.asString('position'),
    day: json.asInt('day', fallback: 1),
    startSection: json.asIntOrNull('startSection'),
    endSection: json.asIntOrNull('endSection'),
    weeks: json.asIntList('weeks'),
    isCustomTime: json.asBool('isCustomTime'),
    customStartTime: json.asStringOrNull('customStartTime'),
    customEndTime: json.asStringOrNull('customEndTime'),
    color: json.asIntOrNull('color'),
    remark: json.asStringOrNull('remark'),
    credit: json.asDoubleOrNull('credit'),
  );

  /// 课程唯一标识；为 null 时由宿主分配。
  final String? id;

  /// 课程名称。
  final String name;

  /// 任课教师；缺失时为空串（并会留下一条诊断）。
  final String teacher;

  /// 上课地点；缺失时为空串。
  final String position;

  /// 星期，ISO 记法：周一 = 1 … 周日 = 7。
  final int day;

  /// 起始节次；仅 [isCustomTime] 的记录为 null。
  final int? startSection;

  /// 结束节次（闭区间）；仅 [isCustomTime] 的记录为 null。
  final int? endSection;

  /// 上课周次，已升序排序、去重、不可变。
  final List<int> weeks;

  /// 是否使用自定义上下课时间而非节次。
  final bool isCustomTime;

  /// 自定义开始时间，`HH:mm`。
  final String? customStartTime;

  /// 自定义结束时间，`HH:mm`。
  final String? customEndTime;

  /// 颜色索引。解析器恒为 null，由宿主分配。
  final int? color;

  /// 备注；[ParseOptions.keepRawCellText] 开启时存放单元格原文。
  final String? remark;

  /// 课程学分。
  ///
  /// 对齐拾光课程表 `ImportCourseJsonModel.credit`。HTML 课表通常不写学分，
  /// 因此解析器恒为 null；该字段只为线格式往返与宿主赋值而存在。
  final double? credit;

  /// 本课程跨越的节次数。
  int get sectionCount =>
      (startSection != null && endSection != null) ? endSection! - startSection! + 1 : 1;

  /// 编码为 JSON 对象。
  ///
  /// null 字段被省略，对应上游 Kotlin 侧"可空 + 默认值"的写法。
  Map<String, dynamic> toJson() => <String, dynamic>{
    if (id != null) 'id': id,
    'name': name,
    'teacher': teacher,
    'position': position,
    'day': day,
    'startSection': startSection,
    'endSection': endSection,
    'weeks': weeks,
    'isCustomTime': isCustomTime,
    'customStartTime': customStartTime,
    'customEndTime': customEndTime,
    if (color != null) 'color': color,
    if (remark != null) 'remark': remark,
    if (credit != null) 'credit': credit,
  };

  /// 返回一个替换了部分字段的副本。
  Course copyWith({
    String? id,
    String? name,
    String? teacher,
    String? position,
    int? day,
    int? startSection,
    int? endSection,
    Iterable<int>? weeks,
    bool? isCustomTime,
    String? customStartTime,
    String? customEndTime,
    int? color,
    String? remark,
    double? credit,
  }) => Course(
    id: id ?? this.id,
    name: name ?? this.name,
    teacher: teacher ?? this.teacher,
    position: position ?? this.position,
    day: day ?? this.day,
    startSection: startSection ?? this.startSection,
    endSection: endSection ?? this.endSection,
    weeks: weeks ?? this.weeks,
    isCustomTime: isCustomTime ?? this.isCustomTime,
    customStartTime: customStartTime ?? this.customStartTime,
    customEndTime: customEndTime ?? this.customEndTime,
    color: color ?? this.color,
    remark: remark ?? this.remark,
    credit: credit ?? this.credit,
  );

  static List<int> _normalizeWeeks(Iterable<int> weeks) {
    if (weeks.isEmpty) return const <int>[];
    final sorted = weeks.toSet().toList()..sort();
    return List<int>.unmodifiable(sorted);
  }

  @override
  bool operator ==(Object other) =>
      other is Course &&
      other.id == id &&
      other.name == name &&
      other.teacher == teacher &&
      other.position == position &&
      other.day == day &&
      other.startSection == startSection &&
      other.endSection == endSection &&
      intListsEqual(other.weeks, weeks) &&
      other.isCustomTime == isCustomTime &&
      other.customStartTime == customStartTime &&
      other.customEndTime == customEndTime &&
      other.color == color &&
      other.remark == remark &&
      other.credit == credit;

  @override
  int get hashCode => Object.hash(
    id,
    name,
    teacher,
    position,
    day,
    startSection,
    endSection,
    Object.hashAll(weeks),
    isCustomTime,
    customStartTime,
    customEndTime,
    color,
    remark,
    credit,
  );

  @override
  String toString() =>
      'Course($name, 周$day, 第$startSection-$endSection节, '
      '周次$weeks)';
}
