import 'dart:convert';

import 'package:curriculum/warehouse.dart';
import 'package:test/test.dart';

void main() {
  group('WarehouseBridgeMessage', () {
    test('解码外壳与二次编码的 payload', () {
      final raw = jsonEncode(<String, dynamic>{
        'action': WarehouseBridgeAction.saveImportedCourses,
        'callbackId': 'cb_1',
        'payload': jsonEncode(<String, dynamic>{'coursesJsonString': '[]'}),
      });

      final message = WarehouseBridgeMessage.fromRaw(raw);
      expect(message.action, WarehouseBridgeAction.saveImportedCourses);
      expect(message.callbackId, 'cb_1');
      expect(message.hasCallback, isTrue);
      expect(message.payloadString('coursesJsonString'), '[]');
    });

    test('解码 showSingleSelection 的 itemsJsonString', () {
      final raw = jsonEncode(<String, dynamic>{
        'action': WarehouseBridgeAction.showSingleSelection,
        'callbackId': 'cb_2',
        'payload': jsonEncode(<String, dynamic>{
          'titleText': '选择学期',
          'itemsJsonString': jsonEncode(<String>['2025-2026 秋', '2025-2026 春']),
          'defaultSelectedIndex': 1,
        }),
      });

      final message = WarehouseBridgeMessage.fromRaw(raw);
      expect(message.payloadJsonStringList('itemsJsonString'), <String>[
        '2025-2026 秋',
        '2025-2026 春',
      ]);
      expect(message.payloadInt('defaultSelectedIndex'), 1);
    });

    test('非法消息抛 FormatException', () {
      expect(() => WarehouseBridgeMessage.fromRaw('not json'), throwsFormatException);
      expect(
        () => WarehouseBridgeMessage.fromRaw(jsonEncode(<String, dynamic>{})),
        throwsFormatException,
      );
      expect(
        () => WarehouseBridgeMessage.fromRaw(
          jsonEncode(<String, dynamic>{'action': 'saveImportedCourses', 'payload': '[]'}),
        ).payloadMap,
        throwsFormatException,
      );
    });
  });

  group('回调脚本', () {
    test('null / 字符串 / 布尔 / 对象都被正确编码', () {
      expect(
        buildBridgeCallbackScript(callbackId: 'cb_1', success: true),
        'window._shiguangNativeCallback("cb_1", true, null);',
      );
      expect(
        buildBridgeCallbackScript(callbackId: 'cb_2', success: false, result: '失败'),
        'window._shiguangNativeCallback("cb_2", false, "失败");',
      );
      expect(
        buildBridgeCallbackScript(callbackId: 'cb_3', success: true, result: true),
        'window._shiguangNativeCallback("cb_3", true, true);',
      );
      expect(
        buildBridgeCallbackScript(
          callbackId: 'cb_4',
          success: true,
          result: <String, dynamic>{'ok': true},
        ),
        'window._shiguangNativeCallback("cb_4", true, {"ok":true});',
      );
    });

    test('callbackId 里的引号会被转义', () {
      final script = buildBridgeCallbackScript(callbackId: 'cb_";alert(1);//', success: true);
      expect(script, contains(r'cb_\";alert(1);//'));
    });
  });

  group('bridge shim', () {
    test('挂载拾光兼容的全局对象', () {
      final shim = buildWarehouseBridgeShim();
      expect(shim, contains('window.shiguangBridgePromise'));
      expect(shim, contains('window.shiguangBridge'));
      expect(shim, contains('window._shiguangNativeCallback'));
      expect(shim, contains('window["shiguangBridgeNative"]'));
      expect(shim, contains('saveImportedCourses'));
      expect(shim, contains('savePresetTimeSlots'));
      expect(shim, contains('notifyTaskCompletion'));
    });

    test('支持自定义通道名', () {
      final shim = buildWarehouseBridgeShim(channelName: 'myChannel');
      expect(shim, contains('window["myChannel"]'));
      expect(shim, isNot(contains('window["shiguangBridgeNative"]')));
    });

    test('启动脚本可注入 currentTableId', () {
      final script = buildWarehouseAdapterStartScript(
        'console.log("adapter");',
        tableId: 'table_1',
      );
      expect(script, startsWith('window.currentTableId = "table_1";\n'));
      expect(script, contains('console.log("adapter");'));

      expect(buildWarehouseAdapterStartScript('console.log(1);'), 'console.log(1);');
    });
  });
}
