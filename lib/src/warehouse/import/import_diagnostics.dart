import '../../model/parse_warning.dart';

/// 一次 JS 适配器导入的诊断快照。
///
/// 与会话分离，便于在导入失败后仍能把适配器 id、课程数、作息数和 warning
/// 一起打进日志/反馈。
class WarehouseImportDiagnostics {
  /// 创建诊断快照。
  WarehouseImportDiagnostics({
    required this.adapterId,
    required this.courseCount,
    required this.timeSlotCount,
    required this.hasConfig,
    required this.hasComboSchedule,
    required this.isCompleted,
    Iterable<ParseWarning> warnings = const <ParseWarning>[],
  }) : warnings = List<ParseWarning>.unmodifiable(warnings);

  /// 适配器 id。
  final String adapterId;

  /// 已接收的课程数。
  final int courseCount;

  /// 已接收的作息节次数。
  final int timeSlotCount;

  /// 是否收到学期配置。
  final bool hasConfig;

  /// 是否收到组合作息方案。
  final bool hasComboSchedule;

  /// 适配器是否已经调用 `notifyTaskCompletion`。
  final bool isCompleted;

  /// 导入过程中的诊断。
  final List<ParseWarning> warnings;

  /// 人类可读的诊断报告，适合直接写进日志。
  String get report {
    final buffer = StringBuffer()
      ..writeln('warehouse — adapter $adapterId')
      ..writeln(
        'courses: $courseCount   timeSlots: $timeSlotCount   '
        'config: ${hasConfig ? 'present' : 'none'}   '
        'combo: ${hasComboSchedule ? 'present' : 'none'}   '
        'completed: $isCompleted',
      );
    if (warnings.isEmpty) {
      buffer.writeln('warnings: none');
      return buffer.toString();
    }
    buffer.writeln('warnings: ${warnings.length}');
    for (final warning in warnings) {
      buffer.writeln('  $warning');
    }
    return buffer.toString();
  }

  @override
  String toString() => report;
}
