import '../../model/parse_warning.dart';
import '../model/warehouse_adapter.dart';
import '../model/warehouse_catalog.dart';
import '../model/warehouse_school.dart';

/// 从 JSON 解码学校索引。
///
/// 该入口用于宿主自建镜像或后端代理：不必让客户端理解 protobuf，只要把
/// `school_index.pb` 转成同样的 JSON 结构即可。键名同时接受 snake_case 和
/// camelCase，类别字段既可以是整数也可以是字符串。
WarehouseCatalog decodeSchoolIndexJson(Map<String, dynamic> json) {
  final warnings = <ParseWarning>[];
  final protocolVersion = _readInt(json, const <String>[
    'protocol_version',
    'protocolVersion',
  ], fallback: 1);
  final versionId = _readString(json, const <String>['version_id', 'versionId']);

  if (protocolVersion != kWarehouseProtocolVersion) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogProtocolMismatch,
      '索引协议版本为 $protocolVersion，本库支持 $kWarehouseProtocolVersion；'
      '将按兼容模式解析，部分新字段可能被忽略。',
      location: 'protocol_version',
    );
  }

  final rawSchools = json['schools'];
  if (rawSchools is! List) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogInvalidEntry,
      '索引里缺少 schools 数组。',
      location: 'schools',
    );
    return WarehouseCatalog(
      protocolVersion: protocolVersion,
      versionId: versionId,
      warnings: warnings,
    );
  }

  final schools = <WarehouseSchool>[];
  final seenSchoolIds = <String>{};
  final seenAdapterIds = <String>{};

  for (final item in rawSchools) {
    if (item is! Map) {
      addCatalogWarning(
        warnings,
        ParseWarningKind.catalogInvalidEntry,
        '学校条目不是对象，已跳过。',
        location: 'schools',
      );
      continue;
    }

    final school = _decodeSchoolJson(item.cast<String, dynamic>(), warnings);
    if (school == null) continue;

    if (!seenSchoolIds.add(school.id)) {
      addCatalogWarning(
        warnings,
        ParseWarningKind.catalogDuplicateId,
        '学校 id 重复，已保留第一条：${school.id}',
        location: 'School(${school.id})',
      );
      continue;
    }

    final adapters = <WarehouseAdapter>[];
    for (final adapter in school.adapters) {
      if (!seenAdapterIds.add(adapter.adapterId)) {
        addCatalogWarning(
          warnings,
          ParseWarningKind.catalogDuplicateId,
          '适配器 id 重复，已保留第一条：${adapter.adapterId}',
          location: 'Adapter(${adapter.adapterId})',
        );
        continue;
      }
      adapters.add(adapter);
    }

    schools.add(
      WarehouseSchool(
        id: school.id,
        name: school.name,
        initial: school.initial,
        resourceFolder: school.resourceFolder,
        adapters: adapters,
      ),
    );
  }

  if (schools.isEmpty) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogInvalidEntry,
      '索引里没有任何可用学校。',
      location: 'schools',
    );
  }

  return WarehouseCatalog(
    protocolVersion: protocolVersion,
    versionId: versionId,
    schools: schools,
    warnings: warnings,
  );
}

WarehouseSchool? _decodeSchoolJson(Map<String, dynamic> json, List<ParseWarning> warnings) {
  final id = _readString(json, const <String>['id']);
  if (id.isEmpty) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogInvalidEntry,
      '学校条目缺少 id，已跳过。',
      location: 'School',
    );
    return null;
  }

  var name = _readString(json, const <String>['name']);
  if (name.isEmpty) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogInvalidEntry,
      '学校缺少名称，将用 id 代替：$id',
      location: 'School($id)',
    );
    name = id;
  }

  var resourceFolder = _readString(json, const <String>['resource_folder', 'resourceFolder']);
  if (resourceFolder.isEmpty) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogInvalidEntry,
      '学校缺少资源目录，已回退为 id：$id',
      location: 'School($id)',
    );
    resourceFolder = id;
  }

  final adapters = <WarehouseAdapter>[];
  final rawAdapters = json['adapters'];
  if (rawAdapters is List) {
    for (final item in rawAdapters) {
      if (item is! Map) {
        addCatalogWarning(
          warnings,
          ParseWarningKind.catalogInvalidEntry,
          '适配器条目不是对象，已跳过（学校 $id）。',
          location: 'School($id).adapters',
        );
        continue;
      }
      final adapter = _decodeAdapterJson(item.cast<String, dynamic>(), id, warnings);
      if (adapter != null) adapters.add(adapter);
    }
  }

  return WarehouseSchool(
    id: id,
    name: name,
    initial: _readString(json, const <String>['initial']),
    resourceFolder: resourceFolder,
    adapters: adapters,
  );
}

WarehouseAdapter? _decodeAdapterJson(
  Map<String, dynamic> json,
  String schoolId,
  List<ParseWarning> warnings,
) {
  final adapterId = _readString(json, const <String>['adapter_id', 'adapterId']);
  if (adapterId.isEmpty) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogInvalidEntry,
      '适配器缺少 id，已跳过（学校 $schoolId）。',
      location: 'School($schoolId).Adapter',
    );
    return null;
  }

  var adapterName = _readString(json, const <String>['adapter_name', 'adapterName']);
  if (adapterName.isEmpty) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogInvalidEntry,
      '适配器缺少名称，将用 id 代替：$adapterId',
      location: 'Adapter($adapterId)',
    );
    adapterName = adapterId;
  }

  final category = _categoryFromJson(json['category']);
  if (category == WarehouseCategory.unknown) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogInvalidEntry,
      '适配器类别未知，将不展示在学校列表中：$adapterId',
      location: 'Adapter($adapterId)',
    );
  }

  final assetJsPath = _readString(json, const <String>['asset_js_path', 'assetJsPath']);
  if (assetJsPath.isEmpty) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.adapterScriptMissing,
      '适配器缺少脚本路径：$adapterId',
      location: 'Adapter($adapterId)',
    );
  }

  return WarehouseAdapter(
    adapterId: adapterId,
    schoolId: schoolId,
    adapterName: adapterName,
    category: category,
    assetJsPath: assetJsPath,
    importUrl: _readOptionalString(json, const <String>['import_url', 'importUrl']),
    description: _readOptionalString(json, const <String>['description']),
    maintainer: _readOptionalString(json, const <String>['maintainer']),
  );
}

WarehouseCategory _categoryFromJson(Object? value) {
  if (value is int) return WarehouseCategory.fromWire(value);
  if (value is String) return WarehouseCategory.fromName(value);
  return WarehouseCategory.unknown;
}

String _readString(Map<String, dynamic> json, List<String> keys, {String fallback = ''}) {
  for (final key in keys) {
    final value = json[key];
    if (value is String) return value;
  }
  return fallback;
}

String? _readOptionalString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = json[key];
    if (value is String) return value;
  }
  return null;
}

int _readInt(Map<String, dynamic> json, List<String> keys, {required int fallback}) {
  for (final key in keys) {
    final value = json[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) return parsed;
    }
  }
  return fallback;
}
