import 'dart:convert';

import 'package:curriculum/warehouse.dart';
import 'package:test/test.dart';

void main() {
  late WarehouseAdapter adapter;
  late _FakeHost host;
  late WarehouseImportSession session;

  setUp(() {
    adapter = const WarehouseAdapter(
      adapterId: 'TEST_01',
      schoolId: 'TEST',
      adapterName: '测试适配器',
      category: WarehouseCategory.bachelorAndAssociate,
      assetJsPath: 'test.js',
    );
    host = _FakeHost();
    session = WarehouseImportSession(
      script: WarehouseAdapterScript(adapter: adapter, source: 'console.log("test");'),
      host: host,
    );
  });

  test('注入脚本与 shim', () {
    expect(session.bootstrapScript, contains('window.shiguangBridgePromise'));
    expect(session.bootstrapScript, contains('shiguangBridgeNative'));
    expect(session.startScript, 'console.log("test");');
  });

  test('完整导入序列产出 CourseImportResult', () async {
    await session.handleMessage(
      _message(WarehouseBridgeAction.showToast, <String, dynamic>{'message': '开始导入'}),
    );
    expect(host.toasts, <String>['开始导入']);

    host.selectionResult = 1;
    await session.handleMessage(
      _message(WarehouseBridgeAction.showSingleSelection, <String, dynamic>{
        'titleText': '选择学期',
        'itemsJsonString': jsonEncode(<String>['秋', '春']),
        'defaultSelectedIndex': 0,
      }, callbackId: 'cb_select'),
    );
    expect(host.lastSelectionTitle, '选择学期');
    expect(host.lastSelectionItems, <String>['秋', '春']);
    expect(host.scripts.last, contains('_shiguangNativeCallback("cb_select", true, 1);'));

    await session.handleMessage(
      _message(WarehouseBridgeAction.saveCourseConfig, <String, dynamic>{
        'configJsonString': jsonEncode(<String, dynamic>{
          'semesterStartDate': '2026-09-01',
          'semesterTotalWeeks': 18,
        }),
      }, callbackId: 'cb_config'),
    );

    await session.handleMessage(
      _message(WarehouseBridgeAction.savePresetTimeSlots, <String, dynamic>{
        'timeSlotsJsonString': jsonEncode(<dynamic>[
          <String, dynamic>{'number': 1, 'startTime': '08:00', 'endTime': '08:45'},
          <String, dynamic>{'number': 2, 'startTime': '08:55', 'endTime': '09:40'},
        ]),
      }, callbackId: 'cb_slots'),
    );

    await session.handleMessage(
      _message(WarehouseBridgeAction.saveImportedCourses, <String, dynamic>{
        'coursesJsonString': jsonEncode(<dynamic>[
          <String, dynamic>{
            'name': '高等数学',
            'teacher': '张三',
            'position': '教1-101',
            'day': 1,
            'startSection': 1,
            'endSection': 2,
            'weeks': <int>[1, 2, 3],
          },
          <String, dynamic>{
            'name': '讲座',
            'day': 3,
            'isCustomTime': true,
            'customStartTime': '14:00',
            'customEndTime': '15:30',
            'weeks': <int>[4],
          },
        ]),
      }, callbackId: 'cb_courses'),
    );

    await session.handleMessage(_message(WarehouseBridgeAction.notifyTaskCompletion, null));

    final result = await session.completed;
    expect(result.courses, hasLength(2));
    expect(result.timeSlots, hasLength(2));
    expect(result.config, isNotNull);
    expect(result.config!.semesterStartDate, '2026-09-01');
    expect(result.adapterId, 'TEST_01');
    expect(result.warnings, isEmpty);

    expect(session.diagnostics.courseCount, 2);
    expect(session.diagnostics.timeSlotCount, 2);
    expect(session.diagnostics.hasConfig, isTrue);
    expect(session.diagnostics.isCompleted, isTrue);
    expect(session.diagnostics.report, contains('TEST_01'));
  });

  test('弹窗结果透传并回传 JS', () async {
    host.promptResult = '2026-2027';
    await session.handleMessage(
      _message(WarehouseBridgeAction.showPrompt, <String, dynamic>{
        'titleText': '输入学年',
        'tipText': '例如 2026-2027',
        'defaultText': '2026-2027',
        'validatorJsFunction': 'validateYear',
      }, callbackId: 'cb_prompt'),
    );

    expect(host.lastPromptTitle, '输入学年');
    expect(host.lastPromptValidator, 'validateYear');
    expect(host.scripts.last, contains('_shiguangNativeCallback("cb_prompt", true, "2026-2027");'));
  });

  test('用户取消单选时回传 null', () async {
    host.selectionResult = null;
    await session.handleMessage(
      _message(WarehouseBridgeAction.showSingleSelection, <String, dynamic>{
        'titleText': '选择学期',
        'itemsJsonString': jsonEncode(<String>['秋', '春']),
      }, callbackId: 'cb_cancel'),
    );

    expect(host.scripts.last, contains('_shiguangNativeCallback("cb_cancel", true, null);'));
  });

  test('非法课程 payload 回传 false 并记诊断', () async {
    await session.handleMessage(
      _message(WarehouseBridgeAction.saveImportedCourses, <String, dynamic>{
        'coursesJsonString': '{}',
      }, callbackId: 'cb_bad'),
    );

    expect(host.scripts.last, contains('_shiguangNativeCallback("cb_bad", false'));
    expect(session.warnings.map((w) => w.kind), contains(ParseWarningKind.invalidCoursePayload));
  });

  test('未知动作记诊断并拒绝 Promise', () async {
    await session.handleMessage(
      _message('somethingElse', <String, dynamic>{}, callbackId: 'cb_unknown'),
    );

    expect(session.warnings.map((w) => w.kind), contains(ParseWarningKind.bridgeMessageInvalid));
    expect(host.scripts.last, contains('_shiguangNativeCallback("cb_unknown", false'));
  });

  test('完成时没有课程会在结果里留下诊断', () async {
    await session.handleMessage(_message(WarehouseBridgeAction.notifyTaskCompletion, null));

    final result = await session.completed;
    expect(result.courses, isEmpty);
    expect(result.warnings.map((w) => w.kind), contains(ParseWarningKind.invalidCoursePayload));
  });

  test('非法消息外壳只记诊断，不抛异常', () async {
    await session.handleMessage('not json');
    expect(session.warnings.map((w) => w.kind), contains(ParseWarningKind.bridgeMessageInvalid));
  });
}

String _message(String action, Map<String, dynamic>? payload, {String? callbackId}) {
  return jsonEncode(<String, dynamic>{
    'action': action,
    'callbackId': callbackId,
    'payload': payload == null ? null : jsonEncode(payload),
  });
}

class _FakeHost implements WarehouseImportHost {
  final List<String> scripts = <String>[];
  final List<String> toasts = <String>[];

  String? promptResult;
  int? selectionResult;

  String? lastPromptTitle;
  String? lastPromptValidator;
  String? lastSelectionTitle;
  List<String>? lastSelectionItems;

  @override
  Future<String?> evaluateJavascript(String script) async {
    scripts.add(script);
    return null;
  }

  @override
  Future<void> showToast(String message) async {
    toasts.add(message);
  }

  @override
  Future<void> showAlert({
    required String title,
    required String content,
    String? confirmText,
  }) async {}

  @override
  Future<String?> showPrompt({
    required String title,
    required String tip,
    String defaultText = '',
    String? validatorJsFunction,
  }) async {
    lastPromptTitle = title;
    lastPromptValidator = validatorJsFunction;
    return promptResult;
  }

  @override
  Future<int?> showSingleSelection({
    required String title,
    required List<String> items,
    int defaultIndex = -1,
  }) async {
    lastSelectionTitle = title;
    lastSelectionItems = items;
    return selectionResult;
  }
}
