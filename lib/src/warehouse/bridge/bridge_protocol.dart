import 'dart:convert';

/// JS 与宿主之间的桥接动作名。
///
/// 名称与拾光课程表 `WebBridgeProtocol.kt` 中的字符串完全一致；适配器脚本
/// 直接调用 `window.shiguangBridgePromise.<name>`，因此这些常量不能改名。
abstract final class WarehouseBridgeAction {
  /// 显示一条轻提示，无回调。
  static const String showToast = 'showToast';

  /// 显示提示对话框，回调结果为 null。
  static const String showAlert = 'showAlert';

  /// 显示输入框，回调结果为用户输入。
  static const String showPrompt = 'showPrompt';

  /// 显示单选列表，回调结果为选中下标。
  static const String showSingleSelection = 'showSingleSelection';

  /// 保存导入的课程。
  static const String saveImportedCourses = 'saveImportedCourses';

  /// 保存学期配置。
  static const String saveCourseConfig = 'saveCourseConfig';

  /// 保存作息时间。
  static const String savePresetTimeSlots = 'savePresetTimeSlots';

  /// 保存组合作息方案。
  static const String saveComboSchedule = 'saveComboSchedule';

  /// 适配器通知任务完成。
  static const String notifyTaskCompletion = 'notifyTaskCompletion';
}

/// 一条从 JS 发往宿主的桥接消息。
///
/// 协议外壳固定为 `{action, callbackId, payload}`，其中 `payload` 本身是
/// **JSON 字符串**——需要二次解码。这个设计来自拾光，保持原样才能直接复用
/// 仓库里的适配器。
class WarehouseBridgeMessage {
  /// 创建一条消息。
  const WarehouseBridgeMessage({required this.action, this.callbackId, this.payload});

  /// 从 JSON 字符串解码。
  ///
  /// 结构非法时抛 [FormatException]；调用方（导入会话）应当把它转成诊断，
  /// 而不是让异常冒到 UI。
  factory WarehouseBridgeMessage.fromRaw(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw FormatException('Bridge 消息不是合法 JSON：${error.message}');
    }
    if (decoded is! Map) {
      throw const FormatException('Bridge 消息必须是 JSON 对象。');
    }
    final map = decoded.cast<String, dynamic>();
    final action = map['action'];
    if (action is! String || action.isEmpty) {
      throw const FormatException('Bridge 消息缺少 action。');
    }
    final callbackId = map['callbackId'];
    final payload = map['payload'];
    return WarehouseBridgeMessage(
      action: action,
      callbackId: callbackId is String && callbackId.isNotEmpty ? callbackId : null,
      payload: payload is String ? payload : null,
    );
  }

  /// 动作名，取值见 [WarehouseBridgeAction]。
  final String action;

  /// 回调 id；为空表示该动作不需要回传结果。
  final String? callbackId;

  /// 二次编码的 payload JSON 字符串。
  final String? payload;

  /// 是否需要向 JS 回传结果。
  bool get hasCallback => callbackId != null;

  /// 把 `payload` 解码成对象；`payload` 为空时返回 null。
  ///
  /// payload 不是 JSON 对象时抛 [FormatException]。
  Map<String, dynamic>? get payloadMap {
    final raw = payload;
    if (raw == null || raw.trim().isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (error) {
      throw FormatException('Bridge payload 不是合法 JSON：${error.message}');
    }
    if (decoded is! Map) {
      throw const FormatException('Bridge payload 必须是 JSON 对象。');
    }
    return decoded.cast<String, dynamic>();
  }

  /// 读取 payload 里的字符串字段；缺失或类型不符时返回 null。
  String? payloadString(String key) {
    final map = payloadMap;
    if (map == null) return null;
    final value = map[key];
    return value is String ? value : null;
  }

  /// 读取 payload 里「值是 JSON 字符串」的字段，并解码成字符串列表。
  ///
  /// 典型用法是 `showSingleSelection` 的 `itemsJsonString`。
  List<String>? payloadJsonStringList(String key) {
    final raw = payloadString(key);
    if (raw == null || raw.trim().isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! List) return null;
    return <String>[
      for (final item in decoded)
        if (item is String) item,
    ];
  }

  /// 读取 payload 里的整数字段；缺失或类型不符时返回 [fallback]。
  int payloadInt(String key, {int fallback = 0}) {
    final map = payloadMap;
    if (map == null) return fallback;
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return fallback;
  }

  @override
  String toString() => 'WarehouseBridgeMessage($action, callbackId=$callbackId)';
}

/// 构造回传 JS Promise 的脚本。
///
/// [result] 可以是 null、字符串、数字、布尔、列表或 Map。字符串会做 JSON
/// 编码，因此课程 JSON 里的引号不会破坏脚本。
String buildBridgeCallbackScript({
  required String callbackId,
  required bool success,
  Object? result,
}) {
  final id = jsonEncode(callbackId);
  final literal = _jsLiteral(result);
  final flag = success ? 'true' : 'false';
  return 'window._shiguangNativeCallback($id, $flag, $literal);';
}

String _jsLiteral(Object? value) {
  if (value == null) return 'null';
  if (value is num || value is bool) return value.toString();
  return jsonEncode(value);
}
