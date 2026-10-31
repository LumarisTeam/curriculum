/// 导入会话向宿主借用的能力。
///
/// 这个接口刻意只包含「UI + 执行 JS」两件事：`curriculum` 不知道 WebView、
/// SnackBar、Dialog 的存在，宿主负责把这些方法映射到自己的平台上。
///
/// 所有方法都可能被适配器脚本间接触发，因此实现方需要保证在主线程/UI
/// 线程上执行，并且不要在等待用户输入时阻塞 WebView 的消息通道。
abstract interface class WarehouseImportHost {
  /// 在页面里执行一段 JavaScript，并返回执行结果。
  ///
  /// 会话用它来注入 shim、执行适配器脚本、以及回传 Promise 的 resolve/reject。
  /// 不要求实现方对返回值做特殊处理；WebView 通常返回 JSON 字符串。
  Future<String?> evaluateJavascript(String script);

  /// 显示一条轻提示。
  Future<void> showToast(String message);

  /// 显示一个确认对话框。
  ///
  /// [confirmText] 为空时由宿主决定默认按钮文案。
  Future<void> showAlert({required String title, required String content, String? confirmText});

  /// 显示输入框并返回用户输入；用户取消时返回 null。
  ///
  /// [validatorJsFunction] 是适配器提供的 JS 校验函数名。宿主需要在用户提交时
  /// 执行 `validatorJsFunction(输入)`：返回非空字符串表示校验失败，应把该字符串
  /// 展示给用户并保持对话框打开；返回空串/`false`/`null` 表示通过。
  ///
  /// 把校验逻辑留给宿主，是因为执行它需要 WebView 上下文，而会话层不持有
  /// WebView。会话只负责把原始函数名透传过去。
  Future<String?> showPrompt({
    required String title,
    required String tip,
    String defaultText = '',
    String? validatorJsFunction,
  });

  /// 显示单选列表并返回选中下标；用户取消时返回 null。
  Future<int?> showSingleSelection({
    required String title,
    required List<String> items,
    int defaultIndex = -1,
  });
}
