import 'dart:convert';

import 'package:curriculum/curriculum.dart';
import 'package:test/test.dart';

void main() {
  group('ComboSchedule JSON', () {
    test('往返：fromJson(toJson()) == 原对象', () {
      final schedule = ComboSchedule(
        name: '冬夏作息',
        publicSchedules: <PublicScheduleTemplate>[
          PublicScheduleTemplate(
            name: '夏季作息',
            startDate: '2026-05-01',
            endDate: '2026-09-30',
            defaultClassDuration: 50,
            defaultBreakDuration: 5,
            timeSlots: const <TimeSlot>[
              TimeSlot(number: 1, startTime: '08:00', endTime: '08:50'),
              TimeSlot(number: 2, startTime: '09:00', endTime: '09:50', alias: '第2节'),
            ],
          ),
        ],
      );
      final round = ComboSchedule.fromJson(
        jsonDecode(jsonEncode(schedule.toJson())) as Map<String, dynamic>,
      );
      expect(round, equals(schedule));
    });

    test('缺失字段回退到默认值', () {
      final round = ComboSchedule.fromJson(<String, dynamic>{});
      expect(round.name, isNull);
      expect(round.publicSchedules, isEmpty);

      final template = PublicScheduleTemplate.fromJson(<String, dynamic>{});
      expect(template.name, '');
      expect(template.startDate, '');
      expect(template.endDate, '');
      expect(template.defaultClassDuration, 45);
      expect(template.defaultBreakDuration, 10);
      expect(template.timeSlots, isEmpty);
    });

    test('未知键被忽略', () {
      final round = PublicScheduleTemplate.fromJson(<String, dynamic>{
        'name': '冬季作息',
        'startDate': '2026-10-01',
        'endDate': '2027-04-30',
        '未来新增字段': 1,
      });
      expect(round.name, '冬季作息');
      expect(round.startDate, '2026-10-01');
    });

    test('列表不可变', () {
      final schedule = ComboSchedule(
        publicSchedules: <PublicScheduleTemplate>[
          PublicScheduleTemplate(name: '夏', startDate: 'a', endDate: 'b'),
        ],
      );
      expect(
        () => schedule.publicSchedules.add(
          PublicScheduleTemplate(name: '冬', startDate: 'c', endDate: 'd'),
        ),
        throwsUnsupportedError,
      );
    });

    test('copyWith 保留未指定字段', () {
      final schedule = ComboSchedule(name: '原名');
      expect(schedule.copyWith(name: '新名').name, '新名');
      expect(schedule.copyWith().name, '原名');
    });
  });
}
