import 'dart:convert';

import 'package:curriculum/curriculum.dart';
import 'package:test/test.dart';

void main() {
  group('CourseImportResult', () {
    test('线格式形状与拾光 CourseTableImportModel 一致', () {
      final result = CourseImportResult(
        courses: <Course>[
          Course(
            name: '高等数学',
            teacher: '张教授',
            position: '教101',
            day: 1,
            startSection: 1,
            endSection: 2,
            weeks: <int>[1, 2, 3],
          ),
        ],
        timeSlots: <TimeSlot>[const TimeSlot(number: 1, startTime: '08:00', endTime: '08:45')],
        adapterId: 'TEST_01',
      );

      final json = jsonDecode(result.toJsonString()) as Map<String, dynamic>;
      expect(json.keys.toSet(), <String>{'courses', 'timeSlots', 'config', 'comboSchedule'});
      expect(json['config'], isNull);
      expect(json['comboSchedule'], isNull);

      final courses = json['courses']! as List<dynamic>;
      expect(courses, hasLength(1));
      final first = courses.first as Map<String, dynamic>;
      expect(first['name'], '高等数学');
      expect(first['teacher'], '张教授');
      expect(first['position'], '教101');
      expect(first['day'], 1);
      expect(first['startSection'], 1);
      expect(first['endSection'], 2);
      expect(first['weeks'], <int>[1, 2, 3]);

      final slots = json['timeSlots']! as List<dynamic>;
      expect((slots.first as Map<String, dynamic>)['number'], 1);
    });

    test('config 默认恒为 null', () {
      final result = CourseImportResult(courses: <Course>[Course(name: 'x', day: 1)]);
      expect(result.config, isNull);
      expect(result.toJson()['config'], isNull);
    });

    test('显式给出的 config 会被序列化', () {
      final result = CourseImportResult(
        courses: const <Course>[],
        config: const CourseConfig(semesterTotalWeeks: 18),
      );
      final config = result.toJson()['config']! as Map<String, dynamic>;
      expect(config['semesterTotalWeeks'], 18);
      expect(config['defaultClassDuration'], 45);
      expect(config['firstDayOfWeek'], 1);
    });

    test('fromJson 往返', () {
      final result = CourseImportResult(
        courses: <Course>[
          Course(name: 'a', day: 1, weeks: <int>[1, 2]),
          Course(name: 'b', day: 7, startSection: 3, endSection: 4),
        ],
        timeSlots: <TimeSlot>[const TimeSlot(number: 2, startTime: '09:00', endTime: '09:45')],
        config: const CourseConfig(semesterTotalWeeks: 16),
        comboSchedule: ComboSchedule(
          name: '冬夏作息',
          publicSchedules: <PublicScheduleTemplate>[
            PublicScheduleTemplate(
              name: '夏季作息',
              startDate: '2026-05-01',
              endDate: '2026-09-30',
              timeSlots: const <TimeSlot>[
                TimeSlot(number: 1, startTime: '08:00', endTime: '08:45'),
              ],
            ),
          ],
        ),
      );
      final round = CourseImportResult.fromJson(
        jsonDecode(result.toJsonString()) as Map<String, dynamic>,
      );
      expect(round.courses, equals(result.courses));
      expect(round.timeSlots, equals(result.timeSlots));
      expect(round.config, equals(result.config));
      expect(round.comboSchedule, equals(result.comboSchedule));
    });

    test('courses 列表不可变', () {
      final result = CourseImportResult(courses: <Course>[Course(name: 'a', day: 1)]);
      expect(() => result.courses.add(Course(name: 'b', day: 1)), throwsUnsupportedError);
    });

    test('throwIfEmpty 在无课程时抛出并携带诊断', () {
      final result = CourseImportResult(
        courses: const <Course>[],
        warnings: const <ParseWarning>[ParseWarning.error(ParseWarningKind.tableNotFound, '没找到表')],
        adapterId: 'TEST_01',
      );
      expect(result.isEmpty, isTrue);
      expect(result.hasErrors, isTrue);
      expect(
        () => result.throwIfEmpty(),
        throwsA(
          isA<ParseFailedException>()
              .having((e) => e.warnings, 'warnings', hasLength(1))
              .having((e) => e.partial, 'partial', same(result)),
        ),
      );
    });

    test('throwIfEmpty 在有课程时不抛', () {
      final result = CourseImportResult(courses: <Course>[Course(name: 'a', day: 1)]);
      expect(result.throwIfEmpty, returnsNormally);
    });

    test('diagnosticReport 汇总统计与诊断', () {
      final result = CourseImportResult(
        courses: <Course>[Course(name: 'a', day: 1)],
        warnings: const <ParseWarning>[
          ParseWarning.warn(
            ParseWarningKind.unknownCellText,
            '读不懂',
            location: 'r5.c3',
            rawText: '调课通知',
          ),
        ],
        adapterId: 'TEST_01',
        stats: const ParseStats(cellsSeen: 10, cellsParsed: 1, cellsSkipped: 2),
      );
      final report = result.diagnosticReport;
      expect(report, contains('TEST_01'));
      expect(report, contains('r5.c3'));
      expect(report, contains('调课通知'));
      expect(report, contains('cells: 10 seen'));
    });
  });
}
