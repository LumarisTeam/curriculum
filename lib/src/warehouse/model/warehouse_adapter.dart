import '../../model/parse_warning.dart';

/// 适配器类别，与 `shiguang_warehouse` 的 `AdapterCategory` 对齐。
///
/// 数值映射来自 `proto/school_index.proto`：通用工具 = 1、本科/专科 = 2、
/// 研究生 = 3。协议新增但本库尚未认识的类别会落到 [unknown]，而不是抛异常。
enum WarehouseCategory {
  /// 通用工具，不针对具体学校。
  generalTool,

  /// 本科/专科教务系统。
  bachelorAndAssociate,

  /// 研究生教务系统。
  postgraduate,

  /// 未知类别；新版本索引新增的类别会落到这里。
  unknown;

  /// 从 `school_index.proto` 的枚举整数值转换。
  static WarehouseCategory fromWire(int value) => switch (value) {
    1 => generalTool,
    2 => bachelorAndAssociate,
    3 => postgraduate,
    _ => unknown,
  };

  /// 从 YAML/JSON 里的字符串名转换，例如 `BACHELOR_AND_ASSOCIATE`。
  static WarehouseCategory fromName(String value) => switch (value.toUpperCase()) {
    'GENERAL_TOOL' => generalTool,
    'BACHELOR_AND_ASSOCIATE' => bachelorAndAssociate,
    'POSTGRADUATE' => postgraduate,
    'ADAPTER_CATEGORY_UNKNOWN' => unknown,
    _ => unknown,
  };
}

/// 仓库索引里的一个适配器条目。
///
/// 对应 `school_index.proto` 的 `Adapter` 消息。`importUrl` 使用 `String?`
/// 而不是空串，是为了保留 proto 的字段存在性：字段缺失和字段为空在协议里
/// 语义不同——前者需要宿主让用户手填网址。
class WarehouseAdapter {
  /// 创建适配器条目。
  const WarehouseAdapter({
    required this.adapterId,
    required this.schoolId,
    required this.adapterName,
    required this.category,
    required this.assetJsPath,
    this.importUrl,
    this.description,
    this.maintainer,
  });

  /// 适配器唯一 id，例如 `CQU`、`XAUAT_01`。
  final String adapterId;

  /// 所属学校 id，例如 `CQU`。
  final String schoolId;

  /// 展示名称。
  final String adapterName;

  /// 适配器类别。
  final WarehouseCategory category;

  /// JS 文件相对于 `resources/<resource_folder>/` 的路径，例如 `cqu.js`。
  final String assetJsPath;

  /// 导入时打开的教务系统地址；为 null 表示索引没有提供，需要用户手填。
  final String? importUrl;

  /// 适配器说明。
  final String? description;

  /// 维护者。
  final String? maintainer;

  /// 是否属于 App 学校列表会展示的类别。
  bool get isVisible =>
      category == WarehouseCategory.generalTool ||
      category == WarehouseCategory.bachelorAndAssociate ||
      category == WarehouseCategory.postgraduate;

  @override
  String toString() => '$adapterName($adapterId)';
}

/// 把一个未知类别或非法条目的诊断记入 [warnings]。
///
/// 放在模型文件里是为了让 PB 与 JSON 两条解析路径共用同一套诊断文案。
void addCatalogWarning(
  List<ParseWarning> warnings,
  ParseWarningKind kind,
  String message, {
  String? location,
}) {
  warnings.add(ParseWarning.warn(kind, message, location: location));
}
