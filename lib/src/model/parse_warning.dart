/// 解析过程中收集到的诊断信息。
library;

/// 诊断的严重程度。
enum ParseSeverity {
  /// 值得记录的观察，不影响结果正确性。
  info,

  /// 某些内容被跳过或回退，结果可能不完整但仍可用。
  warning,

  /// 结构性问题，部分数据已丢失。
  error,
}

/// 诊断的分类标签，便于调用方按类型过滤或统计。
enum ParseWarningKind {
  // ---- 表格结构 ----
  /// 适配器没有匹配到课表 `<table>`。
  tableNotFound,

  /// `rowspan` / `colspan` 属性不是合法非负整数。
  invalidSpan,

  /// 跨度超出表格边界，已被钳制。
  spanOverflow,

  /// `rowspan="0"`，按规范延伸到表格末尾。
  zeroRowspan,

  /// 行的单元格数少于表格最大列数，尾部被判为空洞。
  raggedRow,

  /// 整行都是上午/下午/晚上之类的分隔横幅，已跳过。
  skippedBannerRow,

  /// 某一行的节次无法确定。
  noSectionForRow,

  // ---- 适配器与探测 ----
  /// 表头/结构识别失败，例如表头里找不到任何星期标签。
  detectionFailed,

  /// 没有注册的适配器匹配该 HTML。
  noAdapterMatched,

  /// 找到了承载表格的容器但表格本身缺失。
  tableNotFoundInContainer,

  /// 内嵌 JSON 载荷未找到或无法解码。
  payloadNotFound,

  /// 无法从元素上确定 (星期, 节次) 位置。
  unknownPosition,

  // ---- 单元格内容 ----
  /// 单元格文本完全无法理解。
  unknownCellText,

  /// 单元格为空或只含占位符。
  blankCell,

  /// 记录缺少课程名，已丢弃。
  missingName,

  /// 记录缺少教师，已用空串填充。
  missingTeacher,

  /// 记录缺少上课地点，已用空串填充。
  missingPosition,

  /// 周次字段无法解析，已回退为"全部周次"。
  weekParseFailed,

  /// 节次字段无法解析。
  sectionParseFailed,

  /// 一条记录跨了多个节次跨度但无法整除，已退回完整跨度。
  unevenSectionSplit,

  /// 一个单元格的 colspan 覆盖了多个星期，已扇出为多门课。
  multiDayCell,

  // ---- 后处理 ----
  /// 完全重复的记录已丢弃。
  duplicateDropped,

  /// 同课程的多条记录已合并周次。
  mergedSameCourse,

  /// 星期不在 1..7，记录已丢弃。
  dayOutOfRange,

  /// 节次超出合理范围，已钳制。
  sectionOutOfRange,

  /// 周次超出合理范围，已丢弃。
  weekOutOfRange,

  /// 有周次超出上界被截断。
  truncatedWeeks,

  /// 警告数量触顶，后续同类警告不再记录。
  truncatedWarnings,

  // ---- 适配仓库与 JS 适配器 ----
  /// 仓库索引协议版本与本库支持版本不一致。
  catalogProtocolMismatch,

  /// 仓库索引里存在重复的学校或适配器 id。
  catalogDuplicateId,

  /// 仓库索引里有无法识别的类别、缺失必填字段或其它非法条目。
  catalogInvalidEntry,

  /// 适配器脚本缺失或内容为空。
  adapterScriptMissing,

  /// JS Bridge 消息格式非法。
  bridgeMessageInvalid,

  /// JS Bridge 动作执行失败。
  bridgeActionFailed,

  /// `saveImportedCourses` 的 payload 非法或部分课程被丢弃。
  invalidCoursePayload,

  /// `savePresetTimeSlots` 的 payload 非法。
  invalidTimeSlotPayload,

  /// `saveCourseConfig` 的 payload 非法。
  invalidConfigPayload,

  /// `saveComboSchedule` 的 payload 非法。
  invalidComboSchedulePayload,

  /// 未归类的自定义诊断。
  custom,
}

/// 一条诊断信息。
class ParseWarning {
  /// 创建一条诊断。
  const ParseWarning({
    required this.kind,
    required this.severity,
    required this.message,
    this.location,
    this.rawText,
  });

  /// 创建 info 级诊断。
  const ParseWarning.info(this.kind, this.message, {this.location, this.rawText})
    : severity = ParseSeverity.info;

  /// 创建 warning 级诊断。
  const ParseWarning.warn(this.kind, this.message, {this.location, this.rawText})
    : severity = ParseSeverity.warning;

  /// 创建 error 级诊断。
  const ParseWarning.error(this.kind, this.message, {this.location, this.rawText})
    : severity = ParseSeverity.error;

  /// 分类标签。
  final ParseWarningKind kind;

  /// 严重程度。
  final ParseSeverity severity;

  /// 人类可读的说明。
  final String message;

  /// 出错位置，例如 `r5.c3`、`#kbTable`。
  final String? location;

  /// 触发该诊断的原始文本，已截断。
  final String? rawText;

  @override
  String toString() {
    final tag = switch (severity) {
      ParseSeverity.info => 'INFO',
      ParseSeverity.warning => 'WARN',
      ParseSeverity.error => 'ERR ',
    };
    final where = location == null ? '' : ' [$location]';
    final raw = rawText == null ? '' : ' <- "$rawText"';
    return '$tag$where $message$raw';
  }
}

/// 一次解析的统计摘要。
class ParseStats {
  /// 创建统计摘要。
  const ParseStats({
    this.cellsSeen = 0,
    this.cellsParsed = 0,
    this.cellsSkipped = 0,
    this.coursesEmitted = 0,
    this.warningCount = 0,
  });

  /// 全零统计。
  static const ParseStats empty = ParseStats();

  /// 检查过的候选单元格总数（含空白格）。
  final int cellsSeen;

  /// 成功产出至少一条记录的单元格数。
  final int cellsParsed;

  /// 因空白或无法理解而跳过的单元格数。
  final int cellsSkipped;

  /// 最终产出的课程条数。
  final int coursesEmitted;

  /// 收集到的诊断条数。
  final int warningCount;

  /// 返回一个替换了部分字段的副本。
  ParseStats copyWith({
    int? cellsSeen,
    int? cellsParsed,
    int? cellsSkipped,
    int? coursesEmitted,
    int? warningCount,
  }) => ParseStats(
    cellsSeen: cellsSeen ?? this.cellsSeen,
    cellsParsed: cellsParsed ?? this.cellsParsed,
    cellsSkipped: cellsSkipped ?? this.cellsSkipped,
    coursesEmitted: coursesEmitted ?? this.coursesEmitted,
    warningCount: warningCount ?? this.warningCount,
  );

  @override
  String toString() =>
      'cells: $cellsSeen seen, $cellsParsed parsed, '
      '$cellsSkipped skipped; courses: $coursesEmitted; '
      'warnings: $warningCount';
}
