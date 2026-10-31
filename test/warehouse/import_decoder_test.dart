import 'dart:convert';

import 'package:curriculum/warehouse.dart';
import 'package:test/test.dart';

void main() {
  group('decodeImportedCourses', () {
    test('解码基本课程', () {
      final courses = decodeImportedCourses(
        jsonEncode(<dynamic>[
          <String, dynamic>{
            'name': '高等数学',
            'teacher': '张三',
            'position': '教1-101',
            'day': 1,
            'startSection': 1,
            'endSection': 2,
            'weeks': <int>[5, 3, 3, 1],
          },
        ]),
      );

      expect(courses, hasLength(1));
      final course = courses.single;
      expect(course.name, '高等数学');
      expect(course.teacher, '张三');
      expect(course.position, '教1-101');
      expect(course.day, 1);
      expect(course.startSection, 1);
      expect(course.endSection, 2);
      expect(course.weeks, <int>[1, 3, 5]);
    });

    test('自定义时间课程允许没有节次', () {
      final courses = decodeImportedCourses(
        jsonEncode(<dynamic>[
          <String, dynamic>{
            'name': '讲座',
            'day': 3,
            'isCustomTime': true,
            'customStartTime': '14:00',
            'customEndTime': '15:30',
          },
        ]),
      );

      expect(courses, hasLength(1));
      expect(courses.single.isCustomTime, isTrue);
      expect(courses.single.startSection, isNull);
      expect(courses.single.customStartTime, '14:00');
    });

    test('非法记录被丢弃并记诊断', () {
      final warnings = <ParseWarning>[];
      final courses = decodeImportedCourses(
        jsonEncode(<dynamic>[
          <String, dynamic>{'name': '', 'day': 1, 'startSection': 1},
          <String, dynamic>{'name': 'A', 'day': 9, 'startSection': 1},
          <String, dynamic>{'name': 'B', 'day': 1, 'startSection': 0},
          <String, dynamic>{'name': 'C', 'day': 1, 'startSection': 3, 'endSection': 2},
          <String, dynamic>{'name': 'D', 'day': 1},
          <String, dynamic>{
            'name': 'E',
            'day': 1,
            'startSection': 1,
            'weeks': <dynamic>[1, -2, 'x'],
          },
        ]),
        warnings: warnings,
      );

      expect(courses, hasLength(1));
      expect(courses.single.name, 'E');
      expect(courses.single.weeks, <int>[1]);
      expect(
        warnings.map((w) => w.kind),
        containsAll(<ParseWarningKind>[
          ParseWarningKind.missingName,
          ParseWarningKind.dayOutOfRange,
          ParseWarningKind.sectionOutOfRange,
          ParseWarningKind.sectionParseFailed,
          ParseWarningKind.weekOutOfRange,
        ]),
      );
    });

    test('payload 不是数组或不是 JSON 时抛 FormatException', () {
      expect(() => decodeImportedCourses('{}'), throwsFormatException);
      expect(() => decodeImportedCourses('not json'), throwsFormatException);
    });
  });

  group('decodeCourseConfig', () {
    test('解码并保留字段', () {
      final config = decodeCourseConfig(
        jsonEncode(<String, dynamic>{
          'semesterStartDate': '2026-09-01',
          'semesterTotalWeeks': 18,
          'defaultClassDuration': 50,
          'firstDayOfWeek': 1,
        }),
      );

      expect(config.semesterStartDate, '2026-09-01');
      expect(config.semesterTotalWeeks, 18);
      expect(config.defaultClassDuration, 50);
    });

    test('非法周数回退为 20 并记诊断', () {
      final warnings = <ParseWarning>[];
      final config = decodeCourseConfig(
        jsonEncode(<String, dynamic>{'semesterTotalWeeks': 0}),
        warnings: warnings,
      );

      expect(config.semesterTotalWeeks, 20);
      expect(warnings.single.kind, ParseWarningKind.invalidConfigPayload);
    });

    test('payload 不是对象时抛 FormatException', () {
      expect(() => decodeCourseConfig('[]'), throwsFormatException);
    });
  });

  group('decodeImportedTimeSlots', () {
    test('按节次排序并解析别名', () {
      final slots = decodeImportedTimeSlots(
        jsonEncode(<dynamic>[
          <String, dynamic>{'number': 2, 'startTime': '09:00', 'endTime': '09:45'},
          <String, dynamic>{'number': 1, 'startTime': '08:00', 'endTime': '08:45', 'alias': '第一小节'},
        ]),
      );

      expect(slots.map((slot) => slot.number), <int>[1, 2]);
      expect(slots.first.alias, '第一小节');
    });

    test('非法节次被丢弃，重复节次保留最后一条', () {
      final warnings = <ParseWarning>[];
      final slots = decodeImportedTimeSlots(
        jsonEncode(<dynamic>[
          <String, dynamic>{'number': 0, 'startTime': '08:00', 'endTime': '08:45'},
          <String, dynamic>{'number': 1, 'startTime': 'bad', 'endTime': '08:45'},
          <String, dynamic>{'number': 1, 'startTime': '08:00', 'endTime': '08:45'},
          <String, dynamic>{'number': 1, 'startTime': '08:10', 'endTime': '08:55'},
        ]),
        warnings: warnings,
      );

      expect(slots, hasLength(1));
      expect(slots.single.startTime, '08:10');
      expect(
        warnings.where((w) => w.kind == ParseWarningKind.invalidTimeSlotPayload),
        hasLength(3),
      );
    });

    test('payload 不是数组时抛 FormatException', () {
      expect(() => decodeImportedTimeSlots('{}'), throwsFormatException);
    });
  });

  group('decodeComboSchedule', () {
    test('解码组合作息', () {
      final combo = decodeComboSchedule(
        jsonEncode(<String, dynamic>{
          'name': '夏季作息',
          'publicSchedules': <dynamic>[
            <String, dynamic>{
              'name': '夏季',
              'startDate': '2026-05-01',
              'endDate': '2026-09-30',
              'timeSlots': <dynamic>[
                <String, dynamic>{'number': 1, 'startTime': '08:00', 'endTime': '08:45'},
              ],
            },
          ],
        }),
      );

      expect(combo.name, '夏季作息');
      expect(combo.publicSchedules, hasLength(1));
      expect(combo.publicSchedules.single.timeSlots, hasLength(1));
    });

    test('payload 不是对象时抛 FormatException', () {
      expect(() => decodeComboSchedule('[]'), throwsFormatException);
    });
  });
}
