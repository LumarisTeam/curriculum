import 'dart:typed_data';

import '../../model/parse_warning.dart';
import '../catalog/catalog_json.dart';
import '../catalog/pb_decoder.dart';
import 'warehouse_adapter.dart';
import 'warehouse_school.dart';

/// 当前库完整支持的索引协议版本。
///
/// 与 `shiguang_warehouse` 的 `scripts/build_data.py` 中 `PROTOCOL_VERSION` 对齐。
const int kWarehouseProtocolVersion = 2;

/// 一次加载得到的学校/适配器索引。
///
/// 数据来源是 `shiguang_warehouse` 的 `school_index.pb`；本类只负责把字节
/// 解析成内存结构，不负责下载、缓存或版本检查——那些是宿主的职责。
class WarehouseCatalog {
  /// 创建索引。
  ///
  /// [schools] 与 [warnings] 都会被复制成不可变列表。
  WarehouseCatalog({
    required this.protocolVersion,
    required this.versionId,
    Iterable<WarehouseSchool> schools = const <WarehouseSchool>[],
    Iterable<ParseWarning> warnings = const <ParseWarning>[],
  }) : schools = List<WarehouseSchool>.unmodifiable(schools),
       warnings = List<ParseWarning>.unmodifiable(warnings);

  /// 从 `school_index.pb` 的字节解码。
  factory WarehouseCatalog.fromPbBytes(Uint8List bytes) => decodeSchoolIndex(bytes);

  /// 从索引的 JSON 表示解码。
  ///
  /// 接受 snake_case 与 camelCase 两种键名，类别字段既可以是整数也可以是
  /// `BACHELOR_AND_ASSOCIATE` 这类字符串。宿主用后端代理或自建镜像时，
  /// 不必先转成 protobuf。
  factory WarehouseCatalog.fromJson(Map<String, dynamic> json) => decodeSchoolIndexJson(json);

  /// 索引协议版本。
  final int protocolVersion;

  /// 数据版本 id，通常是 `TIME_yyyyMMddHHmmss_SSS`。
  final String versionId;

  /// 全部学校条目。
  final List<WarehouseSchool> schools;

  /// 加载过程中产生的诊断（协议版本不一致、重复 id、未知类别等）。
  final List<ParseWarning> warnings;

  /// 是否没有解析出任何学校。
  bool get isEmpty => schools.isEmpty;

  /// 是否解析出了学校。
  bool get isNotEmpty => schools.isNotEmpty;

  /// 适配器总数。
  int get adapterCount => schools.fold(0, (sum, school) => sum + school.adapters.length);

  /// App 学校列表会展示的条目。
  ///
  /// 只排除「所有适配器都是未知类别」的条目；协议扩展出新的可见类别时，
  /// 需要同步更新 [WarehouseAdapter.isVisible]。
  List<WarehouseSchool> get visibleSchools =>
      List<WarehouseSchool>.unmodifiable(schools.where((school) => school.isVisible));

  /// 按 id 查找学校；先精确匹配，再忽略大小写匹配。
  WarehouseSchool? schoolById(String id) {
    final needle = id.trim();
    if (needle.isEmpty) return null;
    for (final school in schools) {
      if (school.id == needle) return school;
    }
    final lower = needle.toLowerCase();
    for (final school in schools) {
      if (school.id.toLowerCase() == lower) return school;
    }
    return null;
  }

  /// 按 id 查找适配器；先精确匹配，再忽略大小写匹配。
  WarehouseAdapter? adapterById(String adapterId) {
    final needle = adapterId.trim();
    if (needle.isEmpty) return null;
    for (final school in schools) {
      for (final adapter in school.adapters) {
        if (adapter.adapterId == needle) return adapter;
      }
    }
    final lower = needle.toLowerCase();
    for (final school in schools) {
      for (final adapter in school.adapters) {
        if (adapter.adapterId.toLowerCase() == lower) return adapter;
      }
    }
    return null;
  }

  /// 某个学校下的全部适配器；学校不存在时返回空列表。
  List<WarehouseAdapter> adaptersForSchool(String schoolId) =>
      schoolById(schoolId)?.adapters ?? const <WarehouseAdapter>[];

  /// 编码为 JSON 对象，便于测试与调试。
  Map<String, dynamic> toJson() => <String, dynamic>{
    'protocol_version': protocolVersion,
    'version_id': versionId,
    'schools': <Map<String, dynamic>>[
      for (final school in schools)
        <String, dynamic>{
          'id': school.id,
          'name': school.name,
          'initial': school.initial,
          'resource_folder': school.resourceFolder,
          'adapters': <Map<String, dynamic>>[
            for (final adapter in school.adapters)
              <String, dynamic>{
                'adapter_id': adapter.adapterId,
                'adapter_name': adapter.adapterName,
                'category': adapter.category.name,
                'asset_js_path': adapter.assetJsPath,
                if (adapter.importUrl != null) 'import_url': adapter.importUrl,
                if (adapter.description != null) 'description': adapter.description,
                if (adapter.maintainer != null) 'maintainer': adapter.maintainer,
              },
          ],
        },
    ],
  };

  @override
  String toString() =>
      'WarehouseCatalog($versionId, ${schools.length} schools, $adapterCount adapters)';
}
