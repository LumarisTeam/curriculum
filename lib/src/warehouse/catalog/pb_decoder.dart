import 'dart:convert';
import 'dart:typed_data';

import '../../model/parse_warning.dart';
import '../model/warehouse_adapter.dart';
import '../model/warehouse_catalog.dart';
import '../model/warehouse_school.dart';

/// 解码 `shiguang_warehouse` 的 `school_index.pb`。
///
/// 这里刻意不引入 `package:protobuf`：整个索引只有三层消息、十个字段，
/// 一个百来行的 wire 解码器足够，也让 `curriculum` 继续维持「只有 `html`
/// 一个运行时依赖」。
///
/// 解析是**防御式**的：未知字段、未知类别、重复 id 都会产生诊断而不是
/// 抛异常；只有字节结构本身损坏（截断、非法 wire type）才抛
/// [FormatException]，因为那种输入已经无法安全地继续读取。
WarehouseCatalog decodeSchoolIndex(Uint8List bytes) {
  final warnings = <ParseWarning>[];
  final reader = _PbReader(bytes);

  var protocolVersion = 1;
  var versionId = '';
  final rawSchools = <Uint8List>[];

  while (!reader.isDone) {
    final key = reader.readVarint();
    final fieldNumber = key >> 3;
    final wireType = key & 0x7;
    switch (fieldNumber) {
      case 1:
        _expectWireType(wireType, 0, 'SchoolIndex.protocol_version');
        protocolVersion = reader.readVarint();
        break;
      case 2:
        _expectWireType(wireType, 2, 'SchoolIndex.version_id');
        versionId = reader.readString();
        break;
      case 3:
        _expectWireType(wireType, 2, 'SchoolIndex.schools');
        rawSchools.add(reader.readLengthDelimited());
        break;
      default:
        reader.skipField(wireType);
        break;
    }
  }

  if (protocolVersion != kWarehouseProtocolVersion) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogProtocolMismatch,
      '索引协议版本为 $protocolVersion，本库支持 $kWarehouseProtocolVersion；'
      '将按兼容模式解析，部分新字段可能被忽略。',
      location: 'SchoolIndex.protocol_version',
    );
  }

  final schools = <WarehouseSchool>[];
  final seenSchoolIds = <String>{};
  final seenAdapterIds = <String>{};

  for (final rawSchool in rawSchools) {
    final school = _decodeSchool(rawSchool, warnings);
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
      location: 'SchoolIndex.schools',
    );
  }

  return WarehouseCatalog(
    protocolVersion: protocolVersion,
    versionId: versionId,
    schools: schools,
    warnings: warnings,
  );
}

WarehouseSchool? _decodeSchool(Uint8List bytes, List<ParseWarning> warnings) {
  final reader = _PbReader(bytes);
  var id = '';
  var name = '';
  var initial = '';
  var resourceFolder = '';
  final rawAdapters = <Uint8List>[];

  while (!reader.isDone) {
    final key = reader.readVarint();
    final fieldNumber = key >> 3;
    final wireType = key & 0x7;
    switch (fieldNumber) {
      case 1:
        _expectWireType(wireType, 2, 'School.id');
        id = reader.readString();
        break;
      case 2:
        _expectWireType(wireType, 2, 'School.name');
        name = reader.readString();
        break;
      case 3:
        _expectWireType(wireType, 2, 'School.initial');
        initial = reader.readString();
        break;
      case 4:
        _expectWireType(wireType, 2, 'School.resource_folder');
        resourceFolder = reader.readString();
        break;
      case 5:
        _expectWireType(wireType, 2, 'School.adapters');
        rawAdapters.add(reader.readLengthDelimited());
        break;
      default:
        reader.skipField(wireType);
        break;
    }
  }

  if (id.isEmpty) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogInvalidEntry,
      '学校条目缺少 id，已跳过。',
      location: 'School',
    );
    return null;
  }

  if (name.isEmpty) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogInvalidEntry,
      '学校缺少名称，将用 id 代替：$id',
      location: 'School($id)',
    );
    name = id;
  }

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
  for (final rawAdapter in rawAdapters) {
    final adapter = _decodeAdapter(rawAdapter, id, warnings);
    if (adapter != null) adapters.add(adapter);
  }

  return WarehouseSchool(
    id: id,
    name: name,
    initial: initial,
    resourceFolder: resourceFolder,
    adapters: adapters,
  );
}

WarehouseAdapter? _decodeAdapter(Uint8List bytes, String schoolId, List<ParseWarning> warnings) {
  final reader = _PbReader(bytes);
  var adapterId = '';
  var adapterName = '';
  var category = WarehouseCategory.unknown;
  var assetJsPath = '';
  String? importUrl;
  String? description;
  String? maintainer;

  while (!reader.isDone) {
    final key = reader.readVarint();
    final fieldNumber = key >> 3;
    final wireType = key & 0x7;
    switch (fieldNumber) {
      case 1:
        _expectWireType(wireType, 2, 'Adapter.adapter_id');
        adapterId = reader.readString();
        break;
      case 2:
        _expectWireType(wireType, 2, 'Adapter.adapter_name');
        adapterName = reader.readString();
        break;
      case 3:
        _expectWireType(wireType, 0, 'Adapter.category');
        category = WarehouseCategory.fromWire(reader.readVarint());
        break;
      case 4:
        _expectWireType(wireType, 2, 'Adapter.asset_js_path');
        assetJsPath = reader.readString();
        break;
      case 5:
        _expectWireType(wireType, 2, 'Adapter.import_url');
        importUrl = reader.readString();
        break;
      case 6:
        _expectWireType(wireType, 2, 'Adapter.description');
        description = reader.readString();
        break;
      case 7:
        _expectWireType(wireType, 2, 'Adapter.maintainer');
        maintainer = reader.readString();
        break;
      default:
        reader.skipField(wireType);
        break;
    }
  }

  if (adapterId.isEmpty) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogInvalidEntry,
      '适配器缺少 id，已跳过（学校 $schoolId）。',
      location: 'School($schoolId).Adapter',
    );
    return null;
  }

  if (adapterName.isEmpty) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogInvalidEntry,
      '适配器缺少名称，将用 id 代替：$adapterId',
      location: 'Adapter($adapterId)',
    );
    adapterName = adapterId;
  }

  if (assetJsPath.isEmpty) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.adapterScriptMissing,
      '适配器缺少脚本路径：$adapterId',
      location: 'Adapter($adapterId)',
    );
  }

  if (category == WarehouseCategory.unknown) {
    addCatalogWarning(
      warnings,
      ParseWarningKind.catalogInvalidEntry,
      '适配器类别未知，将不展示在学校列表中：$adapterId',
      location: 'Adapter($adapterId)',
    );
  }

  return WarehouseAdapter(
    adapterId: adapterId,
    schoolId: schoolId,
    adapterName: adapterName,
    category: category,
    assetJsPath: assetJsPath,
    importUrl: importUrl,
    description: description,
    maintainer: maintainer,
  );
}

void _expectWireType(int actual, int expected, String field) {
  if (actual != expected) {
    throw FormatException('$field 的 wire type 是 $actual，期望 $expected。');
  }
}

/// 极简 protobuf wire 读取器。
class _PbReader {
  _PbReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  bool get isDone => _offset >= _bytes.length;

  int readVarint() {
    var result = 0;
    var shift = 0;
    var count = 0;
    while (true) {
      if (_offset >= _bytes.length) {
        throw const FormatException('varint 被截断。');
      }
      final byte = _bytes[_offset++];
      count++;
      result |= (byte & 0x7f) << shift;
      if ((byte & 0x80) == 0) return result;
      shift += 7;
      if (count >= 10) {
        throw const FormatException('varint 超过 10 字节。');
      }
    }
  }

  Uint8List readLengthDelimited() {
    final length = readVarint();
    if (length < 0 || _offset + length > _bytes.length) {
      throw FormatException('长度前缀 $length 超出剩余字节数 ${_bytes.length - _offset}。');
    }
    final slice = _bytes.sublist(_offset, _offset + length);
    _offset += length;
    return slice;
  }

  String readString() => utf8.decode(readLengthDelimited(), allowMalformed: true);

  void skipField(int wireType) {
    switch (wireType) {
      case 0:
        readVarint();
        break;
      case 1:
        _skipBytes(8);
        break;
      case 2:
        final length = readVarint();
        _skipBytes(length);
        break;
      case 5:
        _skipBytes(4);
        break;
      default:
        throw FormatException('不支持的 wire type：$wireType');
    }
  }

  void _skipBytes(int length) {
    if (length < 0 || _offset + length > _bytes.length) {
      throw FormatException('字段长度 $length 超出剩余字节数 ${_bytes.length - _offset}。');
    }
    _offset += length;
  }
}
