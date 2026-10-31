import 'dart:convert';
import 'dart:typed_data';

/// 构造测试用 protobuf wire 数据的极简编码器。
///
/// 只覆盖 `school_index.proto` 用到的字段类型，避免测试依赖
/// `package:protobuf` 或 `protoc`。
Uint8List encodeSchoolIndex({
  int protocolVersion = 2,
  String versionId = 'TIME_TEST',
  List<Uint8List> schools = const <Uint8List>[],
}) {
  return _concat(<List<int>>[
    pbVarint(1, protocolVersion),
    pbString(2, versionId),
    for (final school in schools) pbBytes(3, school),
  ]);
}

Uint8List encodeSchool({
  required String id,
  String name = '',
  String initial = '',
  String resourceFolder = '',
  List<Uint8List> adapters = const <Uint8List>[],
}) {
  return _concat(<List<int>>[
    pbString(1, id),
    pbString(2, name),
    pbString(3, initial),
    pbString(4, resourceFolder),
    for (final adapter in adapters) pbBytes(5, adapter),
  ]);
}

Uint8List encodeAdapter({
  required String adapterId,
  String adapterName = '',
  int category = 2,
  String assetJsPath = '',
  String? importUrl,
  String? description,
  String? maintainer,
}) {
  return _concat(<List<int>>[
    pbString(1, adapterId),
    pbString(2, adapterName),
    pbVarint(3, category),
    pbString(4, assetJsPath),
    if (importUrl != null) pbString(5, importUrl),
    if (description != null) pbString(6, description),
    if (maintainer != null) pbString(7, maintainer),
  ]);
}

Uint8List pbVarint(int field, int value) =>
    _concat(<List<int>>[_varint(field << 3), _varint(value)]);

Uint8List pbString(int field, String value) => pbBytes(field, utf8.encode(value));

Uint8List pbBytes(int field, List<int> bytes) =>
    _concat(<List<int>>[_varint((field << 3) | 2), _varint(bytes.length), bytes]);

Uint8List _varint(int value) {
  final bytes = <int>[];
  var remaining = value;
  while (remaining >= 0x80) {
    bytes.add((remaining & 0x7f) | 0x80);
    remaining >>= 7;
  }
  bytes.add(remaining);
  return Uint8List.fromList(bytes);
}

Uint8List _concat(List<List<int>> parts) =>
    Uint8List.fromList(<int>[for (final part in parts) ...part]);
