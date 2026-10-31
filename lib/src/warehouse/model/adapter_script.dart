import 'warehouse_adapter.dart';

/// 一份已加载的适配器脚本。
///
/// 把「元信息」和「JS 源码」放在一起，避免会话层同时持有两个可能对不上的
/// 对象。源码由宿主从仓库缓存或内置资源中读取，`curriculum` 不负责 I/O。
class WarehouseAdapterScript {
  /// 创建脚本对象。
  const WarehouseAdapterScript({required this.adapter, required this.source});

  /// 适配器元信息。
  final WarehouseAdapter adapter;

  /// 适配器 JS 源码。
  final String source;

  /// 源码是否为空。空脚本无法导入，会话层应当直接报错而不是注入。
  bool get isEmpty => source.trim().isEmpty;

  @override
  String toString() => 'WarehouseAdapterScript(${adapter.adapterId}, ${source.length} chars)';
}
