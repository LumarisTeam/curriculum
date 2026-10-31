import 'dart:io';

import 'package:curriculum/warehouse.dart';
import 'package:test/test.dart';

void main() {
  late WarehouseRegistry registry;

  setUpAll(() {
    final bytes = File('test/fixtures/warehouse/school_index.pb').readAsBytesSync();
    registry = WarehouseRegistry(WarehouseCatalog.fromPbBytes(bytes));
  });

  test('可见学校数量与索引一致', () {
    expect(registry.schools, hasLength(271));
    expect(registry.visibleSchools, hasLength(271));
    expect(registry.adapterCount, 300);
  });

  test('按类别筛选', () {
    expect(registry.byCategory(WarehouseCategory.generalTool), hasLength(5));
    expect(registry.byCategory(WarehouseCategory.bachelorAndAssociate), hasLength(260));
    expect(registry.byCategory(WarehouseCategory.postgraduate), hasLength(16));
  });

  test('搜索名称、首字母和适配器名', () {
    expect(registry.search('重庆').map((s) => s.id), containsAll(<String>['CQU', 'CQJTU']));
    expect(registry.search('cqu').map((s) => s.id), contains('CQU'));
    expect(registry.search('XAUAT').map((s) => s.id), contains('XAUAT'));
    expect(registry.search('西安建筑科技大学').map((s) => s.id), contains('XAUAT'));
    expect(registry.search('   '), hasLength(271));
  });

  test('多适配器学校保留全部适配器', () {
    final gdou = registry.schoolById('GDOU');
    expect(gdou, isNotNull);
    expect(registry.adaptersForSchool('GDOU'), hasLength(4));
    expect(registry.preferredAdapter('GDOU')!.adapterId, 'GDOU_01');
  });

  test('结果按首字母与名称排序', () {
    final schools = registry.visibleSchools;
    for (var i = 1; i < schools.length; i++) {
      final prev = '${schools[i - 1].initial.toUpperCase()}${schools[i - 1].name}';
      final current = '${schools[i].initial.toUpperCase()}${schools[i].name}';
      expect(prev.compareTo(current) <= 0, isTrue);
    }
  });

  test('找不到的学校/适配器返回 null 或空列表', () {
    expect(registry.schoolById('NOT_EXIST'), isNull);
    expect(registry.adapterById('NOT_EXIST'), isNull);
    expect(registry.preferredAdapter('NOT_EXIST'), isNull);
    expect(registry.adaptersForSchool('NOT_EXIST'), isEmpty);
  });
}
