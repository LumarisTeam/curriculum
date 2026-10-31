import 'warehouse_adapter.dart';

/// 仓库索引里的一个学校条目。
///
/// 对应 `school_index.proto` 的 `School` 消息。一个学校可以有多个适配器
/// （本科/研究生、不同教务系统），因此 [adapters] 不是单个对象。
class WarehouseSchool {
  /// 创建学校条目。
  ///
  /// [adapters] 会被复制成不可变列表，避免调用方在注册表建好后再改学校结构。
  WarehouseSchool({
    required this.id,
    required this.name,
    required this.initial,
    required this.resourceFolder,
    Iterable<WarehouseAdapter> adapters = const <WarehouseAdapter>[],
  }) : adapters = List<WarehouseAdapter>.unmodifiable(adapters);

  /// 学校唯一 id，例如 `CQU`。
  final String id;

  /// 展示名称，例如 `重庆大学`。
  final String name;

  /// 用于排序/搜索的拼音首字母。
  final String initial;

  /// 资源文件夹名称；适配器 JS 位于 `resources/<resourceFolder>/`。
  final String resourceFolder;

  /// 该学校下所有适配器。
  final List<WarehouseAdapter> adapters;

  /// 是否至少有一个 App 会展示的适配器。
  bool get isVisible => adapters.any((adapter) => adapter.isVisible);

  /// 按类别筛选适配器。
  List<WarehouseAdapter> adaptersIn(WarehouseCategory category) =>
      List<WarehouseAdapter>.unmodifiable(
        adapters.where((adapter) => adapter.category == category),
      );

  @override
  String toString() => '$name($id, ${adapters.length} adapters)';
}
