/// 容错的 JSON 读取助手。
///
/// 上游（拾光课程表的 `CourseImportExport`）用
/// `Json { ignoreUnknownKeys = true, coerceInputValues = true }` 解码，这等于
/// 声明了生态容忍脏输入。这里的所有读取器都遵循同一约定：**类型不符时回退到
/// 默认值，绝不抛异常**。
library;

/// 对 `Map<String, dynamic>` 的安全读取扩展。
extension JsonMapReader on Map<String, dynamic> {
  /// 读取字符串；缺失或类型不符时返回 null。
  String? asStringOrNull(String key) {
    final v = this[key];
    if (v == null) return null;
    if (v is String) return v;
    if (v is num || v is bool) return v.toString();
    return null;
  }

  /// 读取字符串；缺失或类型不符时返回 [fallback]。
  String asString(String key, {String fallback = ''}) => asStringOrNull(key) ?? fallback;

  /// 读取整数；缺失、类型不符或不可转换时返回 null。
  int? asIntOrNull(String key) => coerceInt(this[key]);

  /// 读取整数；缺失或不可转换时返回 [fallback]。
  int asInt(String key, {int fallback = 0}) => asIntOrNull(key) ?? fallback;

  /// 读取浮点数；缺失、类型不符或不可转换时返回 null。
  double? asDoubleOrNull(String key) => coerceDouble(this[key]);

  /// 读取浮点数；缺失或不可转换时返回 [fallback]。
  double asDouble(String key, {double fallback = 0}) => asDoubleOrNull(key) ?? fallback;

  /// 读取布尔值；缺失或类型不符时返回 [fallback]。
  ///
  /// 字符串 `'true'` / `'false'` 会被识别，其余字符串回退。
  bool asBool(String key, {bool fallback = false}) {
    final v = this[key];
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.trim().toLowerCase();
      if (s == 'true') return true;
      if (s == 'false') return false;
    }
    return fallback;
  }

  /// 读取整数列表。支持真正的 JSON 数组，也兼容 `'1,2,3'` 这种字符串形式。
  ///
  /// 数组里的非整型元素会被跳过而非报错。返回的列表已排序去重。
  List<int> asIntList(String key) => coerceIntList(this[key]);

  /// 读取字符串列表；非字符串元素会被跳过。
  List<String> asStringList(String key) {
    final v = this[key];
    if (v is! List) return const <String>[];
    return <String>[
      for (final e in v)
        if (e is String) e else if (e is num || e is bool) e.toString(),
    ];
  }

  /// 读取嵌套对象；类型不符时返回 null。
  Map<String, dynamic>? asMapOrNull(String key) {
    final v = this[key];
    if (v is Map) return v.cast<String, dynamic>();
    return null;
  }
}

/// 把任意值强制成整数。
///
/// 接受 `int`、`double`（截断）、以及可解析的数字字符串（含 `'16.0'`）。
/// 其余一律返回 null。
int? coerceInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is double) return value.isFinite ? value.toInt() : null;
  if (value is num) return value.toInt();
  if (value is bool) return value ? 1 : 0;
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return null;
    return int.tryParse(s) ?? double.tryParse(s)?.toInt();
  }
  return null;
}

/// 把任意值强制成浮点数。
///
/// 接受 `int`、`double`、以及可解析的数字字符串（含 `'3'`、`'3.5'`）。
/// 非有限值（`NaN`、无穷大）与其余类型一律返回 null。
double? coerceDouble(Object? value) {
  if (value == null) return null;
  if (value is double) return value.isFinite ? value : null;
  if (value is num) {
    final d = value.toDouble();
    return d.isFinite ? d : null;
  }
  if (value is String) {
    final parsed = double.tryParse(value.trim());
    return (parsed != null && parsed.isFinite) ? parsed : null;
  }
  return null;
}

/// 把任意值强制成整数列表。
///
/// 接受 `List`（逐元素 [coerceInt]，跳过不可转换项）或逗号分隔的字符串
/// （全角逗号与顿号也算分隔符）。返回的列表已升序排序并去重。
///
/// 注意：**不展开区间**。`'1,3,5-7'` 里的 `5-7` 不是整数，会被跳过。区间展开
/// 属于单元格文本解析的职责（`parseWeeks`），因为要处理单双周、`第`/`周` 等
/// 中文装饰；上游传进 JSON 的 `weeks` 永远是已展开的整数数组。
List<int> coerceIntList(Object? value) {
  Iterable<Object?> source;
  if (value == null) {
    return const <int>[];
  } else if (value is List) {
    source = value;
  } else if (value is String) {
    source = value.split(RegExp(r'[,，、;；\s]+'));
  } else if (value is num) {
    source = <Object?>[value];
  } else {
    return const <int>[];
  }

  final out = <int>{};
  for (final e in source) {
    final n = coerceInt(e);
    if (n != null) out.add(n);
  }
  final list = out.toList()..sort();
  return list;
}
