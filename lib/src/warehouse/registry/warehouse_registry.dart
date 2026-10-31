import '../model/warehouse_adapter.dart';
import '../model/warehouse_catalog.dart';
import '../model/warehouse_school.dart';

/// 学校索引的查询门面。
///
/// 只做筛选、搜索和排序，不改变索引本身。App 的学校选择页可以直接消费
/// [visibleSchools] / [search] / [byCategory] 的结果。
class WarehouseRegistry {
  /// 用一份索引创建注册表。
  WarehouseRegistry(this.catalog);

  /// 底层索引。
  final WarehouseCatalog catalog;

  /// 全部学校条目，保持索引原始顺序。
  List<WarehouseSchool> get schools => catalog.schools;

  /// App 学校列表会展示的条目，按「首字母 + 名称」排序。
  List<WarehouseSchool> get visibleSchools => _sorted(catalog.visibleSchools);

  /// 适配器总数。
  int get adapterCount => catalog.adapterCount;

  /// 按 id 查找学校。
  WarehouseSchool? schoolById(String id) => catalog.schoolById(id);

  /// 按 id 查找适配器。
  WarehouseAdapter? adapterById(String adapterId) => catalog.adapterById(adapterId);

  /// 某个学校下的全部适配器。
  List<WarehouseAdapter> adaptersForSchool(String schoolId) => catalog.adaptersForSchool(schoolId);

  /// 某个学校的默认适配器。
  ///
  /// 单适配器学校直接返回唯一项；多适配器学校返回索引中的第一个。App 在
  /// 多适配器场景应当让用户显式选择，这个 getter 只用于「点击即导入」的快捷路径。
  WarehouseAdapter? preferredAdapter(String schoolId) {
    final adapters = adaptersForSchool(schoolId);
    return adapters.isEmpty ? null : adapters.first;
  }

  /// 按类别筛选学校。
  ///
  /// 只要学校下有任意一个该类别适配器就会命中，因此一个学校可能同时出现在
  /// 「本科」和「研究生」两个筛选结果里。
  List<WarehouseSchool> byCategory(WarehouseCategory category) => _sorted(
    catalog.visibleSchools.where(
      (school) => school.adapters.any((adapter) => adapter.category == category),
    ),
  );

  /// 搜索学校。
  ///
  /// 匹配名称、首字母、学校 id、适配器名称和适配器 id，全部忽略大小写。
  /// 空查询返回全部可见学校。结果按「首字母 + 名称」排序。
  List<WarehouseSchool> search(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return visibleSchools;

    return _sorted(
      catalog.visibleSchools.where((school) {
        if (school.name.toLowerCase().contains(needle)) return true;
        if (school.initial.toLowerCase().contains(needle)) return true;
        if (school.id.toLowerCase().contains(needle)) return true;
        return school.adapters.any(
          (adapter) =>
              adapter.adapterName.toLowerCase().contains(needle) ||
              adapter.adapterId.toLowerCase().contains(needle),
        );
      }),
    );
  }

  /// 返回按「首字母 + 名称」排序的学校列表。
  ///
  /// [visibleOnly] 为 false 时连未知类别的条目也返回，便于诊断页展示完整索引。
  List<WarehouseSchool> sortedSchools({bool visibleOnly = true}) =>
      _sorted(visibleOnly ? catalog.visibleSchools : catalog.schools);

  static List<WarehouseSchool> _sorted(Iterable<WarehouseSchool> schools) {
    final list = List<WarehouseSchool>.of(schools);
    list.sort(_compare);
    return List<WarehouseSchool>.unmodifiable(list);
  }

  static int _compare(WarehouseSchool a, WarehouseSchool b) {
    final keyA = '${a.initial.toUpperCase()}${a.name}';
    final keyB = '${b.initial.toUpperCase()}${b.name}';
    final byKey = keyA.compareTo(keyB);
    return byKey != 0 ? byKey : a.id.compareTo(b.id);
  }
}
