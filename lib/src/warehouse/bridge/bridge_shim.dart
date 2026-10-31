import 'dart:convert';

/// 默认的 JavaScriptChannel 名称。
///
/// `webview_flutter` 的 `addJavaScriptChannel` 会把它挂成
/// `window.<name>.postMessage`，正好匹配 shim 的首选发送管道。
const String kWarehouseBridgeChannel = 'shiguangBridgeNative';

/// 生成注入页面的 bridge shim。
///
/// 这段 JS 与拾光课程表的 `JS_BRIDGE_INIT` 行为一致：挂载
/// `window.shiguangBridgePromise` / `window.shiguangBridge`，把调用包装成
/// Promise，并通过 [channelName] 指定的通道把消息发给宿主。适配器脚本无需
/// 任何修改即可运行。
///
/// 注入是幂等的：重复注入不会覆盖已有回调表，避免页面内多次点击「开始导入」
/// 时丢失未完成的 Promise。
String buildWarehouseBridgeShim({String channelName = kWarehouseBridgeChannel}) {
  final channel = jsonEncode(channelName);
  return '''
(function() {
    if (window._shiguangBridgeInjected) return;
    window._shiguangBridgeInjected = true;

    var callbacks = {};
    var callbackCounter = 0;

    function postRawMessage(msg) {
        var channel = window[$channel];
        if (channel && typeof channel.postMessage === 'function') {
            channel.postMessage(msg);
            return;
        }
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.shiguangBridge) {
            window.webkit.messageHandlers.shiguangBridge.postMessage(msg);
            return;
        }
        if (typeof window.cefQuery === 'function') {
            window.cefQuery({ request: msg });
            return;
        }
        console.warn("[ShiguangBridge] Native bridge unavailable:", msg);
    }

    function postMessageToNative(action, payload, callbackId) {
        var msg = JSON.stringify({
            action: action,
            callbackId: callbackId || null,
            payload: payload ? JSON.stringify(payload) : null
        });
        postRawMessage(msg);
    }

    window._shiguangNativeCallback = function(callbackId, isSuccess, result) {
        var cb = callbacks[callbackId];
        if (cb) {
            if (isSuccess) {
                cb.resolve(result);
            } else {
                cb.reject(result);
            }
            delete callbacks[callbackId];
        }
    };

    function promiseAction(action, payload) {
        return new Promise(function(resolve, reject) {
            var id = 'cb_' + (++callbackCounter) + '_' + Date.now();
            callbacks[id] = { resolve: resolve, reject: reject };
            postMessageToNative(action, payload, id);
        });
    }

    var shiguangBridgePromise = {
        showAlert: function(titleText, contentText, confirmText) {
            return promiseAction('showAlert', {
                titleText: titleText || '',
                contentText: contentText || '',
                confirmText: confirmText || null
            });
        },
        showPrompt: function(titleText, tipText, defaultText, validatorJsFunction) {
            return promiseAction('showPrompt', {
                titleText: titleText || '',
                tipText: tipText || '',
                defaultText: defaultText || '',
                validatorJsFunction: validatorJsFunction || ''
            });
        },
        showSingleSelection: function(titleText, items, defaultSelectedIndex) {
            var itemsJson = (typeof items === 'string') ? items : JSON.stringify(items || []);
            return promiseAction('showSingleSelection', {
                titleText: titleText || '',
                itemsJsonString: itemsJson,
                defaultSelectedIndex: defaultSelectedIndex !== undefined ? defaultSelectedIndex : -1
            });
        },
        saveImportedCourses: function(coursesJsonString) {
            return promiseAction('saveImportedCourses', { coursesJsonString: coursesJsonString });
        },
        saveCourseConfig: function(configJsonString) {
            return promiseAction('saveCourseConfig', { configJsonString: configJsonString });
        },
        savePresetTimeSlots: function(timeSlotsJsonString) {
            return promiseAction('savePresetTimeSlots', { timeSlotsJsonString: timeSlotsJsonString });
        },
        saveComboSchedule: function(comboScheduleJsonString) {
            var comboJson = (typeof comboScheduleJsonString === 'string')
                ? comboScheduleJsonString
                : JSON.stringify(comboScheduleJsonString || {});
            return promiseAction('saveComboSchedule', { comboScheduleJsonString: comboJson });
        }
    };

    var shiguangBridge = {
        showToast: function(message) {
            postMessageToNative('showToast', { message: message });
        },
        notifyTaskCompletion: function() {
            postMessageToNative('notifyTaskCompletion');
        }
    };

    window.shiguangBridgePromise = shiguangBridgePromise;
    window.shiguangBridge = shiguangBridge;
    window.AndroidBridgePromise = shiguangBridgePromise;
    window.AndroidBridge = shiguangBridge;
})();
''';
}

/// 生成执行适配器脚本的启动脚本。
///
/// [tableId] 是拾光用来让适配器选择目标课表的可选变量。当前仓库里的适配器
/// 都没有读取 `window.currentTableId`，但保留它可以兼容未来的脚本。
String buildWarehouseAdapterStartScript(String source, {String? tableId}) {
  if (tableId == null || tableId.isEmpty) return source;
  return 'window.currentTableId = ${jsonEncode(tableId)};\n$source';
}
