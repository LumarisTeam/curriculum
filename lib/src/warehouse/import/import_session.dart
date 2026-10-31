import 'dart:async';

import '../../model/combo_schedule.dart';
import '../../model/course.dart';
import '../../model/course_config.dart';
import '../../model/course_import_result.dart';
import '../../model/parse_warning.dart';
import '../../model/time_slot.dart';
import '../bridge/bridge_protocol.dart';
import '../bridge/bridge_shim.dart';
import '../model/adapter_script.dart';
import '../model/warehouse_adapter.dart';
import 'import_decoder.dart';
import 'import_diagnostics.dart';
import 'import_host.dart';

/// 一次 JS 适配器导入的会话。
///
/// 会话负责把 Bridge 消息翻译成宿主 UI 调用和结构化数据，并在适配器调用
/// `notifyTaskCompletion` 时产出 [CourseImportResult]。
///
/// 它不持有 WebView：所有 JS 执行、弹窗展示都通过 [WarehouseImportHost] 完成。
/// 消息按到达顺序串行处理，避免多个 Promise 的回调交错。
class WarehouseImportSession {
  /// 创建会话。
  ///
  /// [script] 同时提供适配器元信息和 JS 源码；[host] 是宿主的 UI/JS 接口。
  WarehouseImportSession({required this.script, required this.host});

  /// 已加载的适配器脚本。
  final WarehouseAdapterScript script;

  /// 宿主接口。
  final WarehouseImportHost host;

  final List<Course> _courses = <Course>[];
  final List<TimeSlot> _timeSlots = <TimeSlot>[];
  final List<ParseWarning> _warnings = <ParseWarning>[];
  final Completer<CourseImportResult> _completer = Completer<CourseImportResult>();

  CourseConfig? _config;
  ComboSchedule? _comboSchedule;
  bool _completed = false;
  Future<void> _queue = Future<void>.value();

  /// 适配器元信息。
  WarehouseAdapter get adapter => script.adapter;

  /// 页面开始加载时注入的 shim。
  String get bootstrapScript => buildWarehouseBridgeShim();

  /// 用户点击「开始导入」时注入的适配器脚本。
  String get startScript => buildWarehouseAdapterStartScript(script.source);

  /// 适配器完成时产出的结果。
  ///
  /// 只有适配器调用 `notifyTaskCompletion` 才会完成；宿主在页面被关闭时可以
  /// 停止等待这个 Future。
  Future<CourseImportResult> get completed => _completer.future;

  /// 当前诊断快照。
  WarehouseImportDiagnostics get diagnostics => WarehouseImportDiagnostics(
    adapterId: script.adapter.adapterId,
    courseCount: _courses.length,
    timeSlotCount: _timeSlots.length,
    hasConfig: _config != null,
    hasComboSchedule: _comboSchedule != null,
    isCompleted: _completed,
    warnings: _warnings,
  );

  /// 导入过程中产生的诊断（只读快照）。
  List<ParseWarning> get warnings => List<ParseWarning>.unmodifiable(_warnings);

  /// 处理一条从 JavaScriptChannel 收到的原始消息。
  ///
  /// 消息会排队串行处理。非法外壳只记诊断，不抛异常——JS 侧的消息格式错误
  /// 不应该让整个导入页崩掉。返回的 Future 在本次消息处理完后完成，便于宿主
  /// 测试或记录日志。
  Future<void> handleMessage(String raw) {
    final next = _queue.then((_) => _handle(raw));
    _queue = next.catchError((Object _) {});
    return next;
  }

  Future<void> _handle(String raw) async {
    final WarehouseBridgeMessage message;
    try {
      message = WarehouseBridgeMessage.fromRaw(raw);
    } on FormatException catch (error) {
      _warn(ParseWarningKind.bridgeMessageInvalid, error.message);
      return;
    }

    try {
      await _dispatch(message);
    } on FormatException catch (error) {
      _warn(ParseWarningKind.bridgeActionFailed, error.message, location: message.action);
      await _replySafely(message, success: false, result: error.message);
    } catch (error) {
      _warn(ParseWarningKind.bridgeActionFailed, '$error', location: message.action);
      await _replySafely(message, success: false, result: '$error');
    }
  }

  Future<void> _dispatch(WarehouseBridgeMessage message) async {
    switch (message.action) {
      case WarehouseBridgeAction.showToast:
        await host.showToast(message.payloadString('message') ?? '');
        break;
      case WarehouseBridgeAction.showAlert:
        await host.showAlert(
          title: message.payloadString('titleText') ?? '',
          content: message.payloadString('contentText') ?? '',
          confirmText: message.payloadString('confirmText'),
        );
        await _reply(message, success: true, result: null);
        break;
      case WarehouseBridgeAction.showPrompt:
        final input = await host.showPrompt(
          title: message.payloadString('titleText') ?? '',
          tip: message.payloadString('tipText') ?? '',
          defaultText: message.payloadString('defaultText') ?? '',
          validatorJsFunction: message.payloadString('validatorJsFunction'),
        );
        await _reply(message, success: true, result: input);
        break;
      case WarehouseBridgeAction.showSingleSelection:
        final selected = await host.showSingleSelection(
          title: message.payloadString('titleText') ?? '',
          items: message.payloadJsonStringList('itemsJsonString') ?? const <String>[],
          defaultIndex: message.payloadInt('defaultSelectedIndex', fallback: -1),
        );
        await _reply(message, success: true, result: selected);
        break;
      case WarehouseBridgeAction.saveImportedCourses:
        await _handleSaveCourses(message);
        break;
      case WarehouseBridgeAction.saveCourseConfig:
        await _handleSaveConfig(message);
        break;
      case WarehouseBridgeAction.savePresetTimeSlots:
        await _handleSaveTimeSlots(message);
        break;
      case WarehouseBridgeAction.saveComboSchedule:
        await _handleSaveComboSchedule(message);
        break;
      case WarehouseBridgeAction.notifyTaskCompletion:
        _complete();
        break;
      default:
        _warn(
          ParseWarningKind.bridgeMessageInvalid,
          '未知的 Bridge 动作：${message.action}',
          location: message.action,
        );
        await _replySafely(message, success: false, result: '未知的 Bridge 动作：${message.action}');
        break;
    }
  }

  Future<void> _handleSaveCourses(WarehouseBridgeMessage message) async {
    try {
      final raw = message.payloadString('coursesJsonString');
      if (raw == null) {
        const error = 'saveImportedCourses 缺少 coursesJsonString。';
        _warn(ParseWarningKind.invalidCoursePayload, error, location: message.action);
        await _replySafely(message, success: false, result: error);
        return;
      }

      final courses = decodeImportedCourses(raw, warnings: _warnings);
      _courses.addAll(courses);
      await _replySafely(message, success: true, result: true);
    } on FormatException catch (error) {
      _warn(ParseWarningKind.invalidCoursePayload, error.message, location: message.action);
      await _replySafely(message, success: false, result: error.message);
    }
  }

  Future<void> _handleSaveConfig(WarehouseBridgeMessage message) async {
    try {
      final raw = message.payloadString('configJsonString');
      if (raw == null) {
        const error = 'saveCourseConfig 缺少 configJsonString。';
        _warn(ParseWarningKind.invalidConfigPayload, error, location: message.action);
        await _replySafely(message, success: false, result: error);
        return;
      }

      _config = decodeCourseConfig(raw, warnings: _warnings);
      await _replySafely(message, success: true, result: true);
    } on FormatException catch (error) {
      _warn(ParseWarningKind.invalidConfigPayload, error.message, location: message.action);
      await _replySafely(message, success: false, result: error.message);
    }
  }

  Future<void> _handleSaveTimeSlots(WarehouseBridgeMessage message) async {
    try {
      final raw = message.payloadString('timeSlotsJsonString');
      if (raw == null) {
        const error = 'savePresetTimeSlots 缺少 timeSlotsJsonString。';
        _warn(ParseWarningKind.invalidTimeSlotPayload, error, location: message.action);
        await _replySafely(message, success: false, result: error);
        return;
      }

      _timeSlots
        ..clear()
        ..addAll(decodeImportedTimeSlots(raw, warnings: _warnings));
      await _replySafely(message, success: true, result: true);
    } on FormatException catch (error) {
      _warn(ParseWarningKind.invalidTimeSlotPayload, error.message, location: message.action);
      await _replySafely(message, success: false, result: error.message);
    }
  }

  Future<void> _handleSaveComboSchedule(WarehouseBridgeMessage message) async {
    try {
      final raw = message.payloadString('comboScheduleJsonString');
      if (raw == null) {
        const error = 'saveComboSchedule 缺少 comboScheduleJsonString。';
        _warn(ParseWarningKind.invalidComboSchedulePayload, error, location: message.action);
        await _replySafely(message, success: false, result: error);
        return;
      }

      _comboSchedule = decodeComboSchedule(raw, warnings: _warnings);
      await _replySafely(message, success: true, result: true);
    } on FormatException catch (error) {
      _warn(ParseWarningKind.invalidComboSchedulePayload, error.message, location: message.action);
      await _replySafely(message, success: false, result: error.message);
    }
  }

  void _complete() {
    if (_completed) return;
    _completed = true;

    if (_courses.isEmpty) {
      _warn(
        ParseWarningKind.invalidCoursePayload,
        '适配器已通知完成，但没有保存任何课程。',
        location: script.adapter.adapterId,
      );
    }

    final result = CourseImportResult(
      courses: _courses,
      timeSlots: _timeSlots,
      config: _config,
      comboSchedule: _comboSchedule,
      warnings: _warnings,
      adapterId: script.adapter.adapterId,
    );
    if (!_completer.isCompleted) _completer.complete(result);
  }

  Future<void> _reply(
    WarehouseBridgeMessage message, {
    required bool success,
    Object? result,
  }) async {
    final callbackId = message.callbackId;
    if (callbackId == null) return;
    await host.evaluateJavascript(
      buildBridgeCallbackScript(callbackId: callbackId, success: success, result: result),
    );
  }

  Future<void> _replySafely(
    WarehouseBridgeMessage message, {
    required bool success,
    Object? result,
  }) async {
    try {
      await _reply(message, success: success, result: result);
    } catch (error) {
      _warn(ParseWarningKind.bridgeActionFailed, '回传 JS 回调失败：$error', location: message.action);
    }
  }

  void _warn(ParseWarningKind kind, String message, {String? location}) {
    _warnings.add(ParseWarning.warn(kind, message, location: location));
  }
}
