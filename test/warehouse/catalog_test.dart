import 'dart:io';
import 'dart:typed_data';

import 'package:curriculum/warehouse.dart';
import 'package:test/test.dart';

import '../support/pb_encoder.dart';

void main() {
  group('真实索引 fixture', () {
    late WarehouseCatalog catalog;

    setUpAll(() {
      final bytes = File('test/fixtures/warehouse/school_index.pb').readAsBytesSync();
      catalog = WarehouseCatalog.fromPbBytes(bytes);
    });

    test('解析出 271 个条目、300 个适配器', () {
      expect(catalog.protocolVersion, 2);
      expect(catalog.versionId, startsWith('TIME_'));
      expect(catalog.schools, hasLength(271));
      expect(catalog.adapterCount, 300);
      expect(catalog.visibleSchools, hasLength(271));
      expect(catalog.warnings, isEmpty);
    });

    test('类别分布与仓库一致', () {
      final adapters = <WarehouseAdapter>[for (final school in catalog.schools) ...school.adapters];
      expect(adapters.where((a) => a.category == WarehouseCategory.generalTool), hasLength(8));
      expect(
        adapters.where((a) => a.category == WarehouseCategory.bachelorAndAssociate),
        hasLength(276),
      );
      expect(adapters.where((a) => a.category == WarehouseCategory.postgraduate), hasLength(16));
    });

    test('学校类别分布与仓库一致', () {
      final schools = catalog.schools;
      expect(
        schools.where((s) => s.adapters.any((a) => a.category == WarehouseCategory.generalTool)),
        hasLength(5),
      );
      expect(
        schools.where(
          (s) => s.adapters.any((a) => a.category == WarehouseCategory.bachelorAndAssociate),
        ),
        hasLength(260),
      );
      expect(
        schools.where((s) => s.adapters.any((a) => a.category == WarehouseCategory.postgraduate)),
        hasLength(16),
      );
      expect(schools.where((s) => s.adapters.length > 1), hasLength(24));
    });

    test('可以按 id 查找学校和适配器', () {
      final cqu = catalog.schoolById('CQU');
      expect(cqu, isNotNull);
      expect(cqu!.name, '重庆大学');
      expect(cqu.adapters, hasLength(1));

      final adapter = catalog.adapterById('CQU');
      expect(adapter, isNotNull);
      expect(adapter!.adapterId, 'CQU');
      expect(adapter.schoolId, 'CQU');
      expect(adapter.importUrl, 'https://my.cqu.edu.cn/');

      final xauat = catalog.adapterById('XAUAT_01');
      expect(xauat, isNotNull);
      expect(xauat!.assetJsPath, 'xauat.js');
      expect(xauat.schoolId, 'XAUAT');
    });

    test('toJson / fromJson 往返保持结构', () {
      final roundTrip = WarehouseCatalog.fromJson(catalog.toJson());
      expect(roundTrip.protocolVersion, catalog.protocolVersion);
      expect(roundTrip.versionId, catalog.versionId);
      expect(roundTrip.schools, hasLength(catalog.schools.length));
      expect(roundTrip.adapterCount, catalog.adapterCount);
      expect(roundTrip.schoolById('CQU')!.name, '重庆大学');
    });
  });

  group('合成索引', () {
    test('未知类别会记诊断且不进入可见列表', () {
      final bytes = encodeSchoolIndex(
        schools: <Uint8List>[
          encodeSchool(
            id: 'FOO',
            name: '测试大学',
            initial: 'C',
            resourceFolder: 'FOO',
            adapters: <Uint8List>[
              encodeAdapter(
                adapterId: 'FOO_01',
                adapterName: '测试适配器',
                category: 99,
                assetJsPath: 'foo.js',
              ),
            ],
          ),
        ],
      );

      final catalog = WarehouseCatalog.fromPbBytes(bytes);
      expect(catalog.schools, hasLength(1));
      expect(catalog.visibleSchools, isEmpty);
      expect(catalog.warnings.map((w) => w.kind), contains(ParseWarningKind.catalogInvalidEntry));
    });

    test('重复学校和适配器 id 只保留第一条', () {
      final bytes = encodeSchoolIndex(
        schools: <Uint8List>[
          encodeSchool(
            id: 'FOO',
            name: '第一所',
            resourceFolder: 'FOO',
            adapters: <Uint8List>[
              encodeAdapter(adapterId: 'A_01', category: 2, assetJsPath: 'a.js'),
              encodeAdapter(adapterId: 'A_01', category: 2, assetJsPath: 'a2.js'),
            ],
          ),
          encodeSchool(
            id: 'FOO',
            name: '重复学校',
            resourceFolder: 'FOO2',
            adapters: <Uint8List>[
              encodeAdapter(adapterId: 'B_01', category: 2, assetJsPath: 'b.js'),
            ],
          ),
        ],
      );

      final catalog = WarehouseCatalog.fromPbBytes(bytes);
      expect(catalog.schools, hasLength(1));
      expect(catalog.schools.single.name, '第一所');
      expect(catalog.schools.single.adapters, hasLength(1));
      expect(catalog.schools.single.adapters.single.assetJsPath, 'a.js');
      expect(
        catalog.warnings.where((w) => w.kind == ParseWarningKind.catalogDuplicateId),
        hasLength(2),
      );
    });

    test('缺失 import_url 与空字符串可区分', () {
      final bytes = encodeSchoolIndex(
        schools: <Uint8List>[
          encodeSchool(
            id: 'FOO',
            name: '测试大学',
            resourceFolder: 'FOO',
            adapters: <Uint8List>[
              encodeAdapter(adapterId: 'A_01', category: 2, assetJsPath: 'a.js'),
              encodeAdapter(adapterId: 'A_02', category: 2, assetJsPath: 'b.js', importUrl: ''),
            ],
          ),
        ],
      );

      final catalog = WarehouseCatalog.fromPbBytes(bytes);
      expect(catalog.adapterById('A_01')!.importUrl, isNull);
      expect(catalog.adapterById('A_02')!.importUrl, '');
    });

    test('截断的字节流抛 FormatException', () {
      final bytes = encodeSchoolIndex(schools: <Uint8List>[encodeSchool(id: 'FOO')]);
      expect(
        () => WarehouseCatalog.fromPbBytes(Uint8List.sublistView(bytes, 0, bytes.length - 1)),
        throwsFormatException,
      );
    });

    test('空字节流按 proto3 默认值解析并给出诊断', () {
      final catalog = WarehouseCatalog.fromPbBytes(Uint8List(0));
      expect(catalog.protocolVersion, 1);
      expect(catalog.schools, isEmpty);
      expect(
        catalog.warnings.map((w) => w.kind),
        containsAll(<ParseWarningKind>[
          ParseWarningKind.catalogProtocolMismatch,
          ParseWarningKind.catalogInvalidEntry,
        ]),
      );
    });
  });

  group('JSON 索引', () {
    test('接受 snake_case、camelCase 和字符串类别', () {
      final catalog = WarehouseCatalog.fromJson(<String, dynamic>{
        'protocolVersion': 2,
        'versionId': 'TIME_JSON',
        'schools': <dynamic>[
          <String, dynamic>{
            'id': 'FOO',
            'name': '测试大学',
            'initial': 'C',
            'resourceFolder': 'FOO',
            'adapters': <dynamic>[
              <String, dynamic>{
                'adapterId': 'FOO_01',
                'adapterName': '测试适配器',
                'category': 'BACHELOR_AND_ASSOCIATE',
                'assetJsPath': 'foo.js',
                'importUrl': 'https://example.com',
              },
            ],
          },
        ],
      });

      expect(catalog.versionId, 'TIME_JSON');
      final adapter = catalog.adapterById('FOO_01');
      expect(adapter, isNotNull);
      expect(adapter!.category, WarehouseCategory.bachelorAndAssociate);
      expect(adapter.importUrl, 'https://example.com');
      expect(catalog.warnings, isEmpty);
    });
  });
}
