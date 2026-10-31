import 'dart:convert';

import 'package:curriculum/curriculum.dart';
import 'package:test/test.dart';

void main() {
  group('Course JSON', () {
    test('往返：fromJson(toJson()) == 原对象', () {
      final course = Course(
        id: 'c1',
        name: '高等数学A',
        teacher: '张伟',
        position: '凌云楼101',
        day: 1,
        startSection: 1,
        endSection: 2,
        weeks: <int>[1, 2, 3],
        color: 3,
        remark: '原始文本',
        credit: 3.5,
      );
      expect(Course.fromJson(course.toJson()), equals(course));
    });

    test('toJson 省略 null 字段', () {
      final course = Course(name: '体育', day: 3);
      final json = course.toJson();
      expect(json.containsKey('id'), isFalse);
      expect(json.containsKey('color'), isFalse);
      expect(json.containsKey('remark'), isFalse);
      expect(json.containsKey('credit'), isFalse);
      expect(json['customStartTime'], isNull);
      expect(json['weeks'], isEmpty);
      // 这些字段即使为 null 也保留，与上游 Kotlin 模型一致。
      expect(json.containsKey('startSection'), isTrue);
      expect(json.containsKey('endSection'), isTrue);
    });

    test('未知键被忽略', () {
      final course = Course.fromJson(<String, dynamic>{
        'name': '线性代数',
        'day': 2,
        'weeks': <int>[1, 2],
        '未来新增字段': 'whatever',
        '另一个': <String, dynamic>{'nested': true},
      });
      expect(course.name, '线性代数');
      expect(course.day, 2);
      expect(course.weeks, <int>[1, 2]);
    });

    test('类型不符时回退而非抛异常', () {
      final course = Course.fromJson(<String, dynamic>{
        'name': 123,
        'day': '3',
        'startSection': '2',
        'endSection': 4.0,
        'weeks': <Object>['1', 2, '不是数字', 3.0],
        'isCustomTime': 'true',
      });
      expect(course.name, '123');
      expect(course.day, 3);
      expect(course.startSection, 2);
      expect(course.endSection, 4);
      expect(course.weeks, <int>[1, 2, 3]);
      expect(course.isCustomTime, isTrue);
    });

    test('name 缺失时为空串，day 缺失时回退为 1', () {
      final course = Course.fromJson(<String, dynamic>{});
      expect(course.name, '');
      expect(course.day, 1);
    });

    test('weeks 也接受逗号分隔的字符串', () {
      final course = Course.fromJson(<String, dynamic>{'name': 'x', 'day': 1, 'weeks': '1,3,5'});
      expect(course.weeks, <int>[1, 3, 5]);
    });

    test('JSON 层不展开区间——那是 parseWeeks 的职责', () {
      // 上游传过来的 weeks 永远是已展开的整数数组；区间语法属于单元格文本解析。
      final course = Course.fromJson(<String, dynamic>{'name': 'x', 'day': 1, 'weeks': '1,3,5-7'});
      expect(course.weeks, <int>[1, 3]);
    });

    test('自定义时间字段能往返', () {
      final course = Course(
        name: '测试自定义课程',
        day: 1,
        isCustomTime: true,
        customStartTime: '08:00',
        customEndTime: '09:00',
      );
      final round = Course.fromJson(
        jsonDecode(jsonEncode(course.toJson())) as Map<String, dynamic>,
      );
      expect(round.isCustomTime, isTrue);
      expect(round.customStartTime, '08:00');
      expect(round.customEndTime, '09:00');
      expect(round.startSection, isNull);
    });

    test('credit 接受整数、浮点与数字字符串', () {
      expect(Course.fromJson(<String, dynamic>{'name': 'x', 'day': 1, 'credit': 3}).credit, 3.0);
      expect(Course.fromJson(<String, dynamic>{'name': 'x', 'day': 1, 'credit': 3.5}).credit, 3.5);
      expect(
        Course.fromJson(<String, dynamic>{'name': 'x', 'day': 1, 'credit': '2.5'}).credit,
        2.5,
      );
      expect(
        Course.fromJson(<String, dynamic>{'name': 'x', 'day': 1, 'credit': 'n/a'}).credit,
        isNull,
      );
    });

    test('credit 能往返', () {
      final course = Course(name: '高等数学A', day: 1, credit: 4.5);
      final round = Course.fromJson(
        jsonDecode(jsonEncode(course.toJson())) as Map<String, dynamic>,
      );
      expect(round.credit, 4.5);
      expect(round, equals(course));
    });
  });
}
