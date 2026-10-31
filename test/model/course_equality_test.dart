import 'package:curriculum/curriculum.dart';
import 'package:test/test.dart';

void main() {
  group('Course 相等性', () {
    test('weeks 的顺序不影响相等性（构造时归一化）', () {
      final a = Course(name: 'x', day: 1, weeks: <int>[3, 1, 2]);
      final b = Course(name: 'x', day: 1, weeks: <int>[1, 2, 3]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('weeks 去重', () {
      final a = Course(name: 'x', day: 1, weeks: <int>[1, 1, 2, 2, 2]);
      expect(a.weeks, <int>[1, 2]);
    });

    test('weeks 不可变', () {
      final a = Course(name: 'x', day: 1, weeks: <int>[1, 2]);
      expect(() => a.weeks.add(3), throwsUnsupportedError);
    });

    test('默认 weeks 为 const 空列表', () {
      final a = Course(name: 'x', day: 1);
      expect(a.weeks, isEmpty);
      expect(identical(a.weeks, const <int>[]), isTrue);
    });

    test('任一字段不同即不相等', () {
      final base = Course(name: 'x', day: 1, weeks: <int>[1]);
      expect(base, isNot(equals(Course(name: 'y', day: 1, weeks: <int>[1]))));
      expect(base, isNot(equals(Course(name: 'x', day: 2, weeks: <int>[1]))));
      expect(base, isNot(equals(Course(name: 'x', day: 1, weeks: <int>[2]))));
      expect(base, isNot(equals(Course(name: 'x', day: 1, weeks: <int>[1], teacher: '张伟'))));
      expect(base, isNot(equals(Course(name: 'x', day: 1, weeks: <int>[1], credit: 3.0))));
    });

    test('intListsEqual 对 null 安全的长度比较', () {
      expect(intListsEqual(<int>[], <int>[]), isTrue);
      expect(intListsEqual(<int>[1], <int>[]), isFalse);
      expect(intListsEqual(<int>[1, 2], <int>[1, 2]), isTrue);
      expect(intListsEqual(<int>[1, 2], <int>[2, 1]), isFalse);
    });

    test('copyWith 保留未指定字段', () {
      final a = Course(name: 'x', day: 1, teacher: '张伟', weeks: <int>[1, 2], credit: 3.0);
      final b = a.copyWith(position: '教101');
      expect(b.name, 'x');
      expect(b.teacher, '张伟');
      expect(b.weeks, <int>[1, 2]);
      expect(b.credit, 3.0);
      expect(b.position, '教101');
    });

    test('sectionCount 计算跨度', () {
      expect(Course(name: 'x', day: 1, startSection: 1, endSection: 2).sectionCount, 2);
      expect(Course(name: 'x', day: 1, startSection: 3, endSection: 3).sectionCount, 1);
      expect(Course(name: 'x', day: 1).sectionCount, 1);
    });
  });
}
